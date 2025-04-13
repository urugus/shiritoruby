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

      # セッションIDをレスポンスに含める
      session_id = request.session.id.to_s

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

    begin
      @session_manager = Games::SessionService.retrieve_session_manager(session_id, session)
    rescue Games::SessionService::SessionNotFoundError => e
      render json: { error: e.message }, status: :not_found
    rescue Games::SessionService::SessionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
