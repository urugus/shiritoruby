module Games
  class ComputerPlayer
    # コンピュータプレイヤーの応答を管理する
    # @param game_id [Integer] ゲームID
    def initialize(game_id)
      @game_id = game_id
    end

    # 次の単語を選択する
    # @param last_letter [String] 前の単語の最後の文字
    # @return [Hash] 応答結果（単語が見つからない場合）または [Word] 選択された単語
    def respond(last_letter)
      words = find_valid_words(last_letter)

      if words.empty?
        # コンピューターが応答できない場合は投了
        return {
          valid: false,
          surrender: true,
          message: "コンピューターは#{last_letter}から始まる単語を思いつきませんでした。あなたの勝ちです！"
        }
      end

      # ランダムに単語を選択して返す（Word オブジェクトをそのまま返す）
      words.sample
    end

    private

    # 有効な単語のリストを検索する
    # @param last_letter [String] 前の単語の最後の文字
    # @return [Array<Word>] 単語のリスト
    def find_valid_words(last_letter)
      # 単語の検索条件：最後の文字から始まり、かつ未使用の単語
      Word.by_first_letter(last_letter).unused_in_game(@game_id)
    end
  end
end
