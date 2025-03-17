class Api::GamesController < ApplicationController
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }
  before_action :set_session_manager, except: [:create, :index]

  # GET /api/games
  # 直近の高スコアを返す
  def index
    @games = Game.high_scores.limit(10)
    render json: @games.map { |game|
      {
        id: game.id,
        player_name: game.player_name,
        score: game.score,
        created_at: game.created_at
      }
    }
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
    rescue Games::SessionManager::InvalidWordError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Games::SessionManager::WordAlreadyUsedError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Games::SessionManager::InvalidFirstLetterError => e
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
    game_id = session[:game_id]
    return nil unless game_id

    game = Game.find_by(id: game_id)
    return nil unless game

    # 既存のゲームからセッションマネージャーを再構築
    # 注：実際の実装では、ゲームの状態も再現する必要があります
    @session_manager = Games::SessionManager.new(game.player_name)
    @session_manager.instance_variable_set(:@game, game)

    # 使用済み単語を復元
    game_words = game.game_words.includes(:word).by_turn_order
    @session_manager.instance_variable_set(
      :@used_words,
      game_words.map { |gw| gw.word.word }
    )

    # 最後に使用した単語を設定
    last_game_word = game_words.last
    @session_manager.instance_variable_set(
      :@last_word,
      last_game_word&.word&.word
    )

    # ゲームの状態を設定
    if game.game_words.count.odd?
      @session_manager.instance_variable_set(
        :@current_state,
        Games::SessionManager::GAME_STATE[:player_turn]
      )
    else
      @session_manager.instance_variable_set(
        :@current_state,
        Games::SessionManager::GAME_STATE[:computer_turn]
      )
    end

    @session_manager
  end
end
