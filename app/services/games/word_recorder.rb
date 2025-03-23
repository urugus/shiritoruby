module Games
  class WordRecorder
    attr_reader :used_words, :last_word

    # 単語の記録を管理する
    # @param game [Game] ゲームインスタンス
    def initialize(game)
      @game = game
      @used_words = []
      @last_word = nil
    end

    # 単語を記録する
    # @param word_record [Word] 記録する単語のレコード
    # @return [GameWord] 作成されたGameWordレコード
    def record(word_record)
      turn_number = @used_words.length + 1

      game_word = @game.game_words.create!(
        word: word_record,
        turn: turn_number
      )

      @used_words << word_record.word
      @last_word = word_record.word

      game_word
    end

    # 単語の記録数を取得する
    # @return [Integer] 記録された単語の数
    def count
      @used_words.length
    end

    # 最後の文字を取得する
    # @return [String] 最後の単語の最後の文字 (nil if no words used)
    def last_letter
      @last_word&.[](-1)
    end
  end
end
