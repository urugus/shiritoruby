module Games
  class ScoreCalculator
    # スコア計算のパラメータ
    BASE_SCORE_PER_TURN = 100
    MAX_TIME_BONUS = 1.5
    OPTIMAL_SECONDS_PER_TURN = 10.0
    MIN_SECONDS_PER_TURN = 1.0

    # スコアを計算する
    # @param turn_count [Integer] ターン数
    # @param duration_seconds [Integer] ゲーム時間（秒）
    # @return [Hash] スコア情報
    def calculate(turn_count, duration_seconds)
      # 基本スコア = ターン数 * BASE_SCORE_PER_TURN
      turn_score = turn_count * BASE_SCORE_PER_TURN

      # 時間に応じたボーナス係数を計算
      time_bonus = calculate_time_bonus(turn_count, duration_seconds)

      # 最終スコア = ターンスコア * 時間ボーナス
      final_score = (turn_score * time_bonus).to_i

      {
        score: final_score,
        time_bonus: time_bonus.round(2),
        turn_score: turn_score
      }
    end

    private

    # 時間ボーナスを計算する
    # @param turn_count [Integer] ターン数
    # @param duration_seconds [Integer] ゲーム時間（秒）
    # @return [Float] 時間ボーナス係数
    def calculate_time_bonus(turn_count, duration_seconds)
      # ターン数や時間が0以下の場合はボーナスなし
      return 1.0 if turn_count <= 0 || duration_seconds <= 0

      # 平均ターン時間（秒）を計算
      avg_seconds_per_turn = duration_seconds.to_f / turn_count

      # 最適時間とのレシオを求め、ボーナスを計算
      # 平均5秒/ターンなら1.5倍、平均20秒/ターンなら0.75倍など
      ratio = OPTIMAL_SECONDS_PER_TURN / [ avg_seconds_per_turn, MIN_SECONDS_PER_TURN ].max
      [ ratio, MAX_TIME_BONUS ].min
    end
  end
end
