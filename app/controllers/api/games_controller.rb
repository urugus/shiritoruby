class Api::GamesController < ApplicationController
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }
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
    @session_manager = Games::SessionManager.new(player_name)
    session[:game_id] = @session_manager.game.id

    render json: {
      message: "新しいゲームを開始しました",
      game: @session_manager.game_state
    }, status: :created
  end

  # POST /api/games/submit_word
  # プレイヤーが単語を提出
  def submit_word
    return render json: { error: "単語が提供されていません" }, status: :bad_request unless params[:word].present?

    begin
      result = @session_manager.player_turn(params[:word])
      render json: result
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
    if @session_manager.current_state == Games::GameState::STATES[:player_turn]
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
    game_id = session[:game_id]
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

    # ゲームを設定
    # セッションマネージャー内部の各コンポーネントを適切に再構築する
    @session_manager.instance_variable_set(:@game, game)
    @session_manager.instance_variable_set(:@start_time, game.created_at)

    # ゲーム内で使用された単語を取得
    game_words = game.game_words.includes(:word).by_turn_order

    # 内部コンポーネントを再設定
    word_recorder = Games::WordRecorder.new(game)
    used_words = game_words.map { |gw| gw.word.word }

    # 最後に使用した単語を設定
    last_game_word = game_words.last
    last_word = last_game_word&.word&.word

    # 内部コンポーネントを手動で初期化
    if last_word.present?
      used_words.each do |word|
        word_record = Word.find_by(word: word)
        word_recorder.record(word_record) if word_record
      end
    end

    @session_manager.instance_variable_set(:@word_recorder, word_recorder)
    @session_manager.instance_variable_set(:@word_validator, Games::WordValidator.new(used_words))
    @session_manager.instance_variable_set(:@computer_player, Games::ComputerPlayer.new(game.id))
    @session_manager.instance_variable_set(:@score_calculator, Games::ScoreCalculator.new)

    # ゲームの状態を設定
    game_state = Games::GameState.new
    current_state = if game.game_words.count.zero?
      # 単語がまだない場合（ゲーム開始直後）はプレイヤーのターン
      Games::GameState::STATES[:player_turn]
    elsif game.game_words.count.odd?
      # 単語数が奇数の場合はコンピューターのターン
      Games::GameState::STATES[:computer_turn]
    else
      # 単語数が偶数かつ0でない場合はプレイヤーのターン
      Games::GameState::STATES[:player_turn]
    end

    # 状態を設定
    game_state.instance_variable_set(:@current_state, current_state)
    @session_manager.instance_variable_set(:@game_state, game_state)

    @session_manager
  end
end
