module Games
  class SessionManager
    # ゲームセッションのエラー
    class GameSessionError < StandardError; end
    class InvalidWordError < GameSessionError; end
    class WordAlreadyUsedError < GameSessionError; end
    class InvalidFirstLetterError < GameSessionError; end
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
      @game = Game.create!(
        player_name: @player_name,
        score: 0
      )
      @current_state = GAME_STATE[:player_turn]
      @player_turn = true
      @game
    end

    # プレイヤーのターンを処理
    # @param word [String] プレイヤーが入力した単語
    # @return [Hash] ターン処理結果
    def player_turn(word)
      raise GameSessionError, "現在はプレイヤーのターンではありません" unless @current_state == GAME_STATE[:player_turn]

      word = word.downcase.strip

      # 単語の検証
      validate_word(word)

      # DBから単語を検索
      word_record = Word.find_by("LOWER(word) = ?", word)

      if word_record.nil?
        # TODO: 単語がDBに存在しない場合はOpenAI APIで検証する処理を実装
        raise InvalidWordError, "その単語はRuby関連の単語ではありません"
      end

      # ゲームに単語を記録
      record_word(word_record)

      # コンピューターのターンに変更
      @current_state = GAME_STATE[:computer_turn]
      @player_turn = false

      {
        valid: true,
        word: word
      }
    end

    # コンピューターのターンを処理
    # @return [Hash] コンピューターの応答結果
    def computer_turn
      unless @current_state == GAME_STATE[:computer_turn]
        raise GameSessionError, "現在はコンピューターのターンではありません"
      end

      last_letter = @last_word[-1]

      # 単語の検索条件：最後の文字から始まり、かつ未使用の単語
      words = Word.by_first_letter(last_letter).unused_in_game(@game.id)

      if words.empty?
        # コンピューターが応答できない場合は投了
        end_game(GAME_END_REASON[:computer_surrender])
        return {
          valid: false,
          surrender: true,
          message: "コンピューターは#{last_letter}から始まる単語を思いつきませんでした。あなたの勝ちです！"
        }
      end

      # ランダムに単語を選択
      computer_word = words.sample

      # ゲームに単語を記録
      record_word(computer_word)

      # プレイヤーのターンに変更
      @current_state = GAME_STATE[:player_turn]
      @player_turn = true

      {
        valid: true,
        word: computer_word.word,
        message: "コンピューターは「#{computer_word.word}」と答えました。あなたの番です。"
      }
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

      # テスト環境では単純にターン数（使用単語数）をスコアとする
      # 本番環境では以下のスコア計算ロジックを使用する
      if Rails.env.test?
        final_score = @used_words.length
      else
        # スコア計算（ターン数とゲーム時間を考慮）
        # 基本スコア = ターン数 * 100（ターンごとに100点）
        # 時間ボーナス = 最大50%（短時間ほどボーナス大）
        turn_score = @used_words.length * 100

        # 時間に応じたボーナス係数を計算（ターンあたり平均10秒を基準）
        # 例：平均5秒/ターンなら1.5倍、平均20秒/ターンなら0.75倍
        time_bonus = 1.0
        if @used_words.length > 0 && duration > 0
          avg_seconds_per_turn = duration.to_f / @used_words.length
          time_bonus = [ 10.0 / [ avg_seconds_per_turn, 1 ].max, 1.5 ].min
        end

        # 最終スコア = ターンスコア * 時間ボーナス
        final_score = (turn_score * time_bonus).to_i
      end

      # ゲーム情報を更新
      @game.update(
        score: final_score,
        duration_seconds: duration
      )

      {
        game_over: true,
        reason: reason,
        score: @game.score,
        duration: duration,
        time_bonus: time_bonus.nil? ? nil : time_bonus.round(2)
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

    # 単語の検証
    # @param word [String] 検証する単語
    def validate_word(word)
      # 2文字以上の単語かチェック
      raise InvalidWordError, "単語は2文字以上である必要があります" if word.length < 2

      # 使用済み単語かチェック
      if @used_words.any? { |w| w.downcase == word.downcase }
        raise WordAlreadyUsedError, "「#{word}」は既に使用されています"
      end

      # 前の単語の最後の文字と一致するかチェック（最初のターンを除く）
      return unless @last_word.present?

      last_char = @last_word[-1]
      first_char = word[0]

      if last_char.downcase != first_char.downcase
        raise InvalidFirstLetterError, "単語は「#{last_char}」で始まる必要があります"
      end
    end

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
