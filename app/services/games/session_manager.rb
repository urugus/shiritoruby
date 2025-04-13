module Games
  class SessionManager
    # ゲームセッションのエラー
    class GameSessionError < StandardError; end
    class TimeoutError < GameSessionError; end

    # ゲームの状態を表す定数
    GAME_STATE = {
      waiting_for_player: "waiting_for_player",
      player_turn: "player_turn",
      computer_turn: "computer_turn",
      game_over: "game_over"
    }.freeze

    # ゲームの終了理由
    GAME_END_REASON = {
      computer_surrender: "computer_surrender",
      player_timeout: "player_timeout"
    }.freeze

    attr_reader :game, :current_state, :last_word, :time_limit, :end_reason

    # 新しいゲームセッションを初期化
    # @param player_name [String] プレイヤー名
    # @param time_limit [Integer] 制限時間（秒）
    def initialize(player_name, time_limit = 10)
      @player_name = player_name
      @time_limit = time_limit
      @current_state = GAME_STATE[:waiting_for_player]
      @used_words = []
      @end_reason = nil
      @start_time = Time.current
      create_game
    end

    # ゲームを作成し、初期化する
    # @return [Game] 作成されたゲームのインスタンス
    def create_game
      begin
        @game = Game.create!(
          player_name: @player_name,
          score: 0
        )
        @current_state = GAME_STATE[:player_turn]
        @player_turn = true
        @game
      rescue ActiveRecord::RecordInvalid => e
        # バリデーションエラーの詳細なメッセージを含める
        error_message = "ゲームの作成に失敗しました: #{e.message}"
        Rails.logger.error error_message
        raise GameSessionError, error_message
      rescue => e
        # その他のエラー
        error_message = "予期せぬエラーが発生しました: #{e.message}"
        Rails.logger.error error_message
        Rails.logger.error e.backtrace.join("\n")
        raise GameSessionError, error_message
      end
    end

    # プレイヤーのターンを処理
    # @param word [String] プレイヤーが入力した単語
    # @return [Hash] ターン処理結果
    def player_turn(word)
      raise GameSessionError, "現在はプレイヤーのターンではありません" unless @current_state == GAME_STATE[:player_turn]

      begin
        # 単語の検証
        WordValidator.validate(word, @last_word, @used_words)

        # 単語がRuby関連かどうかを検証
        word_record = WordValidator.validate_ruby_related(word)

        # ゲームに単語を記録
        record_word(word_record)

        # コンピューターのターンに変更
        @current_state = GAME_STATE[:computer_turn]
        @player_turn = false

        {
          valid: true,
          word: word
        }
      rescue WordValidator::ValidationError => e
        # 検証エラーをそのまま再送出
        raise e
      end
    end

    # コンピューターのターンを処理
    # @return [Hash] コンピューターの応答結果
    def computer_turn
      unless @current_state == GAME_STATE[:computer_turn]
        raise GameSessionError, "現在はコンピューターのターンではありません"
      end

      # コンピューターの応答を生成
      response = ComputerPlayer.generate_response(@last_word, @game.id)

      if response[:surrender]
        # コンピューターが投了した場合
        end_game(GAME_END_REASON[:computer_surrender])
        return response
      end

      # ゲームに単語を記録
      record_word(response[:word])

      # プレイヤーのターンに変更
      @current_state = GAME_STATE[:player_turn]
      @player_turn = true

      response
    end

    # 時間切れによるゲーム終了処理
    def timeout
      return unless @current_state == GAME_STATE[:player_turn]

      end_game(GAME_END_REASON[:player_timeout])
    end

    # ゲームの終了処理
    # @param reason [String] ゲーム終了の理由
    def end_game(reason)
      @end_reason = reason
      @current_state = GAME_STATE[:game_over]

      # ゲーム時間（秒）を計算
      duration = (Time.current - @start_time).to_i

      # スコアを計算
      score_result = ScoreCalculator.calculate(
        @used_words.length,
        duration,
        Rails.env.test?
      )

      # ゲーム情報を更新
      @game.update(
        score: score_result[:score],
        duration_seconds: duration
      )

      {
        game_over: true,
        reason: reason,
        score: @game.score,
        duration: duration,
        time_bonus: score_result[:time_bonus]
      }
    end

    # ゲームの現在の状態を取得
    # @return [Hash] ゲームの状態情報
    def game_state
      {
        id: @game.id,
        player_name: @game.player_name,
        score: @game.score,
        state: @current_state,
        last_word: @last_word,
        used_words_count: @used_words.length,
        game_over: @current_state == GAME_STATE[:game_over],
        end_reason: @end_reason
      }
    end

    private

    # 単語を記録
    # @param word_record [Word] 記録する単語のレコード
    def record_word(word_record)
      turn_number = @used_words.length + 1

      game_word = @game.game_words.create!(
        word: word_record,
        turn: turn_number
      )

      @used_words << word_record.word
      @last_word = word_record.word

      game_word
    end
  end
end
