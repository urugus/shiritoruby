module Games
  class ScoreCalculator
    # スコアを計算する
    # @param used_words_count [Integer] 使用した単語の数
    # @param duration [Integer] ゲーム時間（秒）
    # @param test_mode [Boolean] テストモードかどうか
    # @return [Hash] スコア計算結果
    def self.calculate(used_words_count, duration, test_mode = false)
      # テスト環境では単純にターン数（使用単語数）をスコアとする
      if test_mode
        return {
          score: used_words_count,
          time_bonus: nil
        }
      end

      # スコア計算（ターン数とゲーム時間を考慮）
      # 基本スコア = ターン数 * 100（ターンごとに100点）
      # 時間ボーナス = 最大50%（短時間ほどボーナス大）
      turn_score = used_words_count * 100

      # 時間に応じたボーナス係数を計算（ターンあたり平均10秒を基準）
      # 例：平均5秒/ターンなら1.5倍、平均20秒/ターンなら0.75倍
      time_bonus = 1.0
      if used_words_count > 0 && duration > 0
        avg_seconds_per_turn = duration.to_f / used_words_count
        time_bonus = [10.0 / [avg_seconds_per_turn, 1].max, 1.5].min
      end

      # 最終スコア = ターンスコア * 時間ボーナス
      final_score = (turn_score * time_bonus).to_i

      {
        score: final_score,
        time_bonus: time_bonus.round(2)
      }
    end
  end
end
