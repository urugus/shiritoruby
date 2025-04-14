RSpec.describe Games::ScoreCalculator do
  describe '.calculate' do
    context 'テストモードの場合' do
      it '単語数をそのままスコアとして返す' do
        result = described_class.calculate(5, 60, true)

        expect(result[:score]).to eq(5)
        expect(result[:time_bonus]).to be_nil
      end
    end

    context '通常モードの場合' do
      it '単語数と時間に基づいてスコアを計算する' do
        # 5単語を50秒で完了（平均10秒/ターン）
        result = described_class.calculate(5, 50, false)

        expect(result[:score]).to eq(500) # 5 * 100 * 1.0
        expect(result[:time_bonus]).to eq(1.0)
      end

      it '平均時間が速い場合、ボーナスが増加する' do
        # 5単語を25秒で完了（平均5秒/ターン）
        result = described_class.calculate(5, 25, false)

        expect(result[:score]).to eq(750) # 5 * 100 * 1.5
        expect(result[:time_bonus]).to eq(1.5)
      end

      it '平均時間が遅い場合、ボーナスが減少する' do
        # 5単語を100秒で完了（平均20秒/ターン）
        result = described_class.calculate(5, 100, false)

        expect(result[:score]).to eq(250) # 5 * 100 * 0.5
        expect(result[:time_bonus]).to eq(0.5)
      end
    end
  end
end
