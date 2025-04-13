class Api::GamesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_session_manager, except: [ :create, :index ]

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

      # セッションIDをレスポンスに含める
      session_id = request.session.id

      # セッションIDの型をログに出力
      Rails.logger.info "セッションID: #{session_id} (Original Type: #{session_id.class})"
      session_id = session_id.to_s

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
    rescue Games::SessionManager::InvalidWordError,
           Games::SessionManager::WordAlreadyUsedError,
           Games::SessionManager::InvalidFirstLetterError => e
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

    if session_id.present?
      # セッションIDの情報をログに出力
      Rails.logger.info "セッションID検索: #{session_id}"

      # セッションIDからセッションを復元（完全一致）
      session_record = ActiveRecord::SessionStore::Session.find_by(session_id: session_id)

      # セッションレコードが見つからない場合、部分一致で検索を試みる
      unless session_record
        Rails.logger.info "完全一致するセッションレコードが見つかりません。部分一致で検索します。"
        session_record = ActiveRecord::SessionStore::Session.where("session_id LIKE ?", "%#{session_id}%").first
      end

      if session_record
        Rails.logger.info "セッションレコード発見: #{session_record.id}, データ存在: #{session_record.data.present?}"

        if session_record.data.present?
          begin
            # セッションデータの型をログに出力
            Rails.logger.info "セッションデータの型: #{session_record.data.class}"

            # セッションデータを解析
            if session_record.data.is_a?(String)
              session_data = JSON.parse(session_record.data)
            elsif session_record.data.is_a?(Hash)
              session_data = session_record.data
            else
              session_data = session_record.data.to_h rescue {}
            end

            # ゲームIDを取得
            game_id = session_data["game_id"]
            Rails.logger.info "セッションからゲームID取得: #{game_id}"
          rescue JSON::ParserError => e
            Rails.logger.error "セッションデータの解析に失敗しました: #{e.message}"
            render json: { error: "セッションデータが無効です" }, status: :unprocessable_entity
            return
          rescue => e
            Rails.logger.error "セッションデータ処理中にエラーが発生しました: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            render json: { error: "セッションデータの処理に失敗しました" }, status: :unprocessable_entity
            return
          end
        else
          Rails.logger.warn "セッションレコードにデータがありません"
        end
      else
        Rails.logger.warn "セッションレコードが見つかりません: #{params[:session_id]}"
      end
    end

    # セッションからゲームIDを取得（URLパラメータからの取得に失敗した場合）
    if game_id.nil?
      game_id = session[:game_id]
      Rails.logger.info "現在のセッションからゲームID取得: #{game_id}"
    end

    unless game_id
      Rails.logger.error "ゲームIDが見つかりません。セッションID: #{session_id}, 現在のセッション: #{session.id}"
      render json: { error: "ゲームセッションが見つかりません" }, status: :not_found
      return
    end

    begin
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
    rescue => e
      # エラーをログに記録
      Rails.logger.error "セッションマネージャー復元エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # JSONレスポンスを返す
      render json: {
        error: "ゲームセッションの復元に失敗しました: #{e.message}"
      }, status: :unprocessable_entity
      nil
    end
  end
end
