module Games
  class WordValidator
    class InvalidWordError < StandardError; end
    class WordAlreadyUsedError < StandardError; end
    class InvalidFirstLetterError < StandardError; end

    def initialize(used_words = [])
      @used_words = used_words
    end

    def validate(word, last_word = nil)
      word = word.downcase.strip

      # 2文字以上の単語かチェック
      raise InvalidWordError, "単語は2文字以上である必要があります" if word.length < 2

      # 使用済み単語かチェック
      if @used_words.any? { |w| w.downcase == word.downcase }
        raise WordAlreadyUsedError, "「#{word}」は既に使用されています"
      end

      # 前の単語の最後の文字と一致するかチェック（最初のターンを除く）
      return true unless last_word.present?

      last_char = last_word[-1]
      first_char = word[0]

      return true if last_char.downcase == first_char.downcase

      raise InvalidFirstLetterError, "単語は「#{last_char}」で始まる必要があります"
    end

    def valid_word?(word, last_word = nil)
      begin
        validate(word, last_word)
        true
      rescue StandardError
        false
      end
    end
  end
end
