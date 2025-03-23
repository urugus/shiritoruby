module Games
  class SessionManager
    # ゲームセッションのエラー - 互換性のため元のエラークラスを維持
    class GameSessionError < StandardError; end

    # サブクラスのエラーをこのクラスでも利用できるようにする
    InvalidWordError = WordValidator::InvalidWordError
    WordAlreadyUsedError = WordValidator::WordAlreadyUsedError
    InvalidFirstLetterError = WordValidator::InvalidFirstLetterError
    class TimeoutError < GameSessionError; end

    # 互換性のための定数エイリアス
    GAME_STATE = GameState::STATES
    GAME_END_REASON = GameState::END_REASONS

    attr_reader :game, :time_limit

    # 新しいゲームセッションを初期化
    # @param player_name [String] プレイヤー名
    # @param time_limit [Integer] 制限時間（秒）
    def initialize(player_name, time_limit = 10)
      @player_name = player_name
      @time_limit = time_limit
      @start_time = Time.current

      # サブシステムの初期化
      @game_state = GameState.new

      # ゲームを作成
      create_game
    end

    # ゲームを作成し、初期化する
    # @return [Game] 作成されたゲームのインスタンス
    def create_game
      @game = Game.create!(
        player_name: @player_name,
        score: 0
      )

      # 各サブシステムを初期化
      @word_recorder = WordRecorder.new(@game)
      @word_validator = WordValidator.new(@word_recorder.used_words)
      @computer_player = ComputerPlayer.new(@game.id)

      # ゲーム状態を更新
      @game_state.start_game

      @game
    end

    # プレイヤーのターンを処理
    # @param word [String] プレイヤーが入力した単語
    # @return [Hash] ターン処理結果
    def player_turn(word)
      raise GameSessionError, "現在はプレイヤーのターンではありません" unless @game_state.player_turn?

      word = word.downcase.strip

      # 単語の検証
      @word_validator.validate(word, @word_recorder.last_word)

      # DBから単語を検索
      word_record = Word.find_by("LOWER(word) = ?", word)

      if word_record.nil?
        # TODO: 単語がDBに存在しない場合はOpenAI APIで検証する処理を実装
        raise InvalidWordError, "その単語はRuby関連の単語ではありません"
      end

      # ゲームに単語を記録
      @word_recorder.record(word_record)

      # コンピューターのターンに変更
      @game_state.to_computer_turn

      # コンピューターの応答を準備
      computer_response = computer_turn

      {
        valid: true,
        word: word,
        computer_response: computer_response
      }
    end

    # コンピューターのターンを処理
    # @return [Hash] コンピューターの応答結果
    def computer_turn
      unless @game_state.computer_turn?
        raise GameSessionError, "現在はコンピューターのターンではありません"
      end

      # コンピュータの応答を取得
      response = @computer_player.respond(@word_recorder.last_letter)

      # 応答がHashの場合、投了を意味する
      if response.is_a?(Hash) && response[:surrender]
        # コンピューターが応答できない場合は投了
        end_game(GAME_END_REASON[:computer_surrender])
        return response
      end

      # 選択された単語（Word オブジェクト）
      computer_word = response

      # ゲームに単語を記録
      @word_recorder.record(computer_word)

      # プレイヤーのターンに変更
      @game_state.to_player_turn

      {
        valid: true,
        word: computer_word.word,
        message: "コンピューターは「#{computer_word.word}」と答えました。あなたの番です。"
      }
    end

    # 時間切れによるゲーム終了処理
    def timeout
      return unless @game_state.player_turn?

      end_game(GAME_END_REASON[:player_timeout])
    end

    # ゲームの終了処理
    # @param reason [String] ゲーム終了の理由
    def end_game(reason)
      @game_state.end_game(reason)

      # ゲーム時間（秒）を計算
      duration = (Time.current - @start_time).to_i

      # スコア計算（ターン数をスコアとして使用）
      score = @word_recorder.count

      # ゲーム情報を更新
      @game.update(
        score: score,
        duration_seconds: duration
      )

      {
        game_over: true,
        reason: reason,
        score: @game.score,
        duration: duration
      }
    end

    # ゲームの現在の状態を取得
    # @return [Hash] ゲームの状態情報
    def game_state
      {
        id: @game.id,
        player_name: @game.player_name,
        score: @game.score,
        state: @game_state.current_state,
        last_word: @word_recorder&.last_word,
        used_words_count: @word_recorder&.count || 0,
        game_over: @game_state.game_over?,
        end_reason: @game_state.end_reason
      }
    end

    # 互換性のためのメソッド
    def current_state
      @game_state.current_state
    end

    def last_word
      @word_recorder&.last_word
    end

    def end_reason
      @game_state.end_reason
    end
  end
end
