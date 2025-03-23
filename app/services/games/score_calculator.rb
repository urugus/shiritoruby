module Games
  class ScoreCalculator
    # スコア計算のパラメータ
    BASE_SCORE_PER_TURN = 100

    # スコアを計算する
    # @param turn_count [Integer] ターン数
    # @param duration_seconds [Integer] ゲーム時間（秒）
    # @return [Hash] スコア情報
    def calculate(turn_count, duration_seconds)
      # スコア = ターン数 * BASE_SCORE_PER_TURN
      score = turn_count * BASE_SCORE_PER_TURN

      {
        score: score,
        turn_score: score
      }
    end
  end
end
