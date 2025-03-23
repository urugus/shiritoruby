module Games
  class ScoreCalculator
    # スコアを計算する
    # @param turn_count [Integer] ターン数
    # @param duration_seconds [Integer] ゲーム時間（秒）
    # @return [Hash] スコア情報
    def calculate(turn_count, duration_seconds)
      # スコア = ターン数（単純にターン数のみをスコアとする）
      score = turn_count

      {
        score: score,
        turn_score: score
      }
    end
  end
end
