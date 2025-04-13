module Games
  class WordValidator
    # 単語検証のエラー
    class ValidationError < StandardError; end
    class InvalidWordError < ValidationError; end
    class WordAlreadyUsedError < ValidationError; end
    class InvalidFirstLetterError < ValidationError; end

    # 単語を検証する
    # @param word [String] 検証する単語
    # @param last_word [String, nil] 前回の単語
    # @param used_words [Array<String>] 使用済み単語のリスト
    # @return [Boolean] 検証結果
    def self.validate(word, last_word = nil, used_words = [])
      word = word.downcase.strip

      # 2文字以上の単語かチェック
      if word.length < 2
        raise InvalidWordError, "単語は2文字以上である必要があります"
      end

      # 使用済み単語かチェック
      if used_words.any? { |w| w.downcase == word.downcase }
        raise WordAlreadyUsedError, "「#{word}」は既に使用されています"
      end

      # 前の単語の最後の文字と一致するかチェック（最初のターンを除く）
      if last_word.present?
        next_starting_letter = get_next_starting_letter(last_word)
        first_char = word[0]

        if next_starting_letter.downcase != first_char.downcase
          raise InvalidFirstLetterError, "単語は「#{next_starting_letter}」で始まる必要があります"
        end
      end

      true
    end

    # 次の単語の先頭文字を取得する
    # @param word [String] 現在の単語
    # @return [String] 次の単語の先頭文字
    def self.get_next_starting_letter(word)
      # 単語の末尾から遡って最初のアルファベットを探す
      i = word.length - 1
      while i >= 0
        if word[i] =~ /[a-z]/i
          return word[i]
        end
        i -= 1
      end

      # 見つからない場合は最後の文字を返す（通常はここには到達しない）
      word[-1]
    end

    # 単語がRuby関連かどうかを検証する
    # @param word [String] 検証する単語
    # @return [Word] 検証された単語オブジェクト
    def self.validate_ruby_related(word)
      # DBから単語を検索
      word_record = Word.find_by("LOWER(word) = ?", word.downcase)

      if word_record.nil?
        # TODO: 単語がDBに存在しない場合はOpenAI APIで検証する処理を実装
        raise InvalidWordError, "その単語はRuby関連の単語ではありません"
      end

      word_record
    end
  end
end
