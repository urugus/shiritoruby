class Api::GamesController < ApplicationController
  # APIリクエストにはCSRFトークンを検証する
  # JavaScriptからのリクエストの場合、X-CSRF-Tokenヘッダーを使用
  protect_from_forgery with: :exception
  before_action :set_session_manager, except: [:create, :index]

  # GET /api/games
  # 直近の高スコアを返す
  def index
    @games = Game.high_scores.limit(10)
    render json: @games.map do |game|
      {
        id: game.id,
        player_name: game.player_name,
        score: game.score,
        created_at: game.created_at
      }
    end
  end

  # GET /api/games/current
  # 現在のゲーム状態を返す
  def show
    if @session_manager
      render json: @session_manager.game_state
    else
      render json: { error: "現在進行中のゲームがありません" }, status: :not_found
    end
  end

  # POST /api/games
  # 新しいゲームを作成
  def create
    player_name = params[:player_name] || "ゲスト"

    begin
      @session_manager = Games::SessionManager.new(player_name)
      session[:game_id] = @session_manager.game.id

      # デバッグ用ログ出力
      Rails.logger.debug "create: セッションオプション = #{request.session_options.inspect}"
      Rails.logger.debug "create: セッションID = #{request.session_options[:id]}"
      Rails.logger.debug "create: セッションデータ = #{session.to_h}"

      # セッションIDをレスポンスに含める
      # request.session.id ではなく request.session_options[:id] を使用
      session_id = request.session_options[:id].to_s

      # デバッグ用ログ出力
      Rails.logger.debug "create: レスポンスに含めるセッションID = #{session_id}"

      render json: {
        message: "新しいゲームを開始しました",
        game: @session_manager.game_state,
        session_id: session_id
      }, status: :created
    rescue => e
      # エラーをログに記録
      Rails.logger.error "ゲーム作成エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # JSONレスポンスを返す
      render json: {
        error: "ゲームの作成に失敗しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # POST /api/games/submit_word
  # プレイヤーが単語を提出
  def submit_word
    return render json: { error: "単語が提供されていません" }, status: :bad_request unless params[:word].present?

    begin
      result = @session_manager.player_turn(params[:word])
      # プレイヤーの入力を処理した後、コンピューターの応答も取得
      computer_response = @session_manager.computer_turn if @session_manager.current_state == Games::SessionManager::GAME_STATE[:computer_turn]

      render json: result.merge(
        computer_response: computer_response
      )
    rescue Games::WordValidator::InvalidWordError,
           Games::WordValidator::WordAlreadyUsedError,
           Games::WordValidator::InvalidFirstLetterError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Games::SessionManager::GameSessionError => e
      render json: { error: e.message }, status: :bad_request
    end
  end

  # POST /api/games/timeout
  # タイムアウト処理
  def timeout
    if @session_manager.current_state == Games::SessionManager::GAME_STATE[:player_turn]
      result = @session_manager.timeout
      render json: {
        game_over: true,
        message: "制限時間を超過しました。コンピューターの勝利です。",
        game: @session_manager.game_state
      }
    else
      render json: { error: "現在プレイヤーのターンではありません" }, status: :bad_request
    end
  end

  private
  # セッションからゲームセッションマネージャーを取得
  def set_session_manager
    # セッションIDを取得（ヘッダーまたはURLパラメータから）
    session_id = request.headers["X-Session-ID"] || params[:session_id]

    # デバッグ用ログ出力
    Rails.logger.debug "セッションID: #{session_id}"
    Rails.logger.debug "現在のセッションオプション: #{request.session_options.inspect}"
    Rails.logger.debug "現在のセッションID: #{request.session_options[:id]}"

    # セッションIDからゲームIDを取得
    game_id = extract_game_id_from_session(session_id) || session[:game_id]

    unless game_id
      render json: { error: "ゲームセッションが見つかりません" }, status: :not_found
      return
    end

    game = Game.find_by(id: game_id)
    unless game
      render json: { error: "ゲームが見つかりません" }, status: :not_found
      return
    end

    # 既存のゲームからセッションマネージャーを再構築
    @session_manager = Games::SessionManager.new(game.player_name)
    @session_manager.instance_variable_set(:@game, game)
    @session_manager.instance_variable_set(:@start_time, game.created_at)

    # 使用済み単語を復元
    game_words = game.game_words.includes(:word).by_turn_order
    used_words = game_words.map { |gw| gw.word.word }
    @session_manager.instance_variable_set(:@used_words, used_words)
    # 最後に使用した単語を設定
    last_game_word = game_words.last
    last_word = last_game_word&.word&.word
    @session_manager.instance_variable_set(:@last_word, last_word)

    # ゲームの状態を設定
    current_state = if game.game_words.count.zero?
      # 単語がまだない場合（ゲーム開始直後）はプレイヤーのターン
      Games::SessionManager::GAME_STATE[:player_turn]
    elsif game.game_words.count.odd?
      # 単語数が奇数の場合はコンピューターのターン
      Games::SessionManager::GAME_STATE[:computer_turn]
    else
      # 単語数が偶数かつ0でない場合はプレイヤーのターン
      Games::SessionManager::GAME_STATE[:player_turn]
    end
    @session_manager.instance_variable_set(:@current_state, current_state)

    # プレイヤーのターン状態を設定
    @session_manager.instance_variable_set(
      :@player_turn,
      current_state == Games::SessionManager::GAME_STATE[:player_turn]
    )

    @session_manager
  end

  # セッションレコードからゲームIDを抽出
  # @param session_id [String] セッションID
  # @return [String, nil] ゲームID
  def extract_game_id_from_session(session_id)
    return nil unless session_id.present?

    # デバッグ用ログ出力
    Rails.logger.debug "extract_game_id_from_session: セッションID = #{session_id}"

    # セッションレコードを検索
    session_record = ActiveRecord::SessionStore::Session.find_by(session_id: session_id)

    # デバッグ用ログ出力
    if session_record
      Rails.logger.debug "セッションレコードが見つかりました: #{session_record.inspect}"
    else
      Rails.logger.debug "セッションレコードが見つかりませんでした"
    end

    return nil unless session_record&.data.present?

    # セッションデータを解析
    begin
      # セッションデータの形式に応じて適切に解析
      # ActiveRecord::SessionStoreはRailsのバージョンや環境によって
      # JSONまたはMarshal.dumpでシリアライズされる可能性がある
      session_data = nil

      # まずJSONとしてパースを試みる
      begin
        if session_record.data.start_with?('{')
          session_data = JSON.parse(session_record.data)
          Rails.logger.debug "JSONとしてパースに成功: #{session_data.inspect}"
        end
      rescue JSON::ParserError => e
        Rails.logger.debug "JSONとしてパースに失敗: #{e.message}"
      end

      # JSONパースに失敗した場合、Marshalとしてデシリアライズを試みる
      if session_data.nil?
        begin
          session_data = Marshal.load(session_record.data)
          Rails.logger.debug "Marshalとしてデシリアライズに成功: #{session_data.inspect}"
        rescue TypeError, ArgumentError => e
          Rails.logger.error "Marshalとしてデシリアライズに失敗: #{e.message}"
        end
      end

      # それでもnilの場合はエラー
      if session_data.nil?
        Rails.logger.error "セッションデータの解析に失敗しました"
        return nil
      end

      # ゲームIDを取得
      game_id = session_data["game_id"]
      Rails.logger.debug "取得したゲームID: #{game_id}"
      game_id
    rescue NoMethodError, SecurityError, EncodingError => e
      Rails.logger.error "セッションデータの型エラーが発生しました: #{e.message}"
      nil
    end
  end
end
