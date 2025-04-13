RSpec.describe Game, type: :model do
  # アソシエーションのテスト
  describe 'associations' do
    it { should have_many(:game_words).dependent(:destroy) }
    it { should have_many(:words).through(:game_words) }
  end

  # バリデーションのテスト
  describe 'validations' do
    it { should validate_presence_of(:player_name) }
    it { should validate_length_of(:player_name).is_at_most(50) }
    it { should validate_presence_of(:score) }
    it { should validate_numericality_of(:score).only_integer.is_greater_than_or_equal_to(0) }

    context 'プレイヤー名の形式' do
      it '英数字と日本語が使用可能' do
        game = build(:game, player_name: 'テスト Player 123')
        expect(game).to be_valid
      end

      it '特殊文字が含まれる場合は無効' do
        game = build(:game, player_name: 'テスト Player <script>')
        expect(game).not_to be_valid
        expect(game.errors[:player_name]).to include('には英数字、日本語、スペースのみ使用できます')
      end
    end
  end

  # スコープのテスト
  describe 'scopes' do
    describe '.high_scores' do
      before do
        @game1 = create(:game, score: 10)
        @game2 = create(:game, score: 5)
        @game3 = create(:game, score: 15)
      end

      it 'スコアの高い順に並べる' do
        expect(Game.high_scores).to eq([ @game3, @game1, @game2 ])
      end
    end

    describe '.recent' do
      before do
        @game1 = create(:game, created_at: 3.days.ago)
        @game2 = create(:game, created_at: 1.day.ago)
        @game3 = create(:game, created_at: 2.days.ago)
      end

      it '作成日時の新しい順に並べる' do
        expect(Game.recent).to eq([ @game2, @game3, @game1 ])
      end
    end
  end
end
