module Games
  class ComputerPlayer
    # コンピューターの応答を生成する
    # @param last_word [String] 前回の単語
    # @param game_id [Integer] ゲームID
    # @return [Hash] 応答結果
    def self.generate_response(last_word, game_id)
      next_starting_letter = WordValidator.get_next_starting_letter(last_word)

      # 単語の検索条件：適切な文字から始まり、かつ未使用の単語
      words = Word.by_first_letter(next_starting_letter).unused_in_game(game_id)

      if words.empty?
        # コンピューターが応答できない場合は投了
        return {
          valid: false,
          surrender: true,
          message: "コンピューターは#{next_starting_letter}から始まる単語を思いつきませんでした。あなたの勝ちです！"
        }
      end

      # ランダムに単語を選択
      computer_word = words.sample

      {
        valid: true,
        word: computer_word,
        message: "コンピューターは「#{computer_word.word}」と答えました。あなたの番です。"
      }
    end
  end
end