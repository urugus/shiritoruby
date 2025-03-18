RSpec.describe GameWord, type: :model do
  # アソシエーションのテスト
  describe 'associations' do
    it { should belong_to(:game) }
    it { should belong_to(:word) }
  end

  # バリデーションのテスト
  describe 'validations' do
    it { should validate_presence_of(:turn) }
    it { should validate_numericality_of(:turn).only_integer.is_greater_than(0) }

    describe 'uniqueness of word_id within a game' do
      let(:game) { create(:game) }
      let(:word) { create(:word) }
      let!(:game_word) { create(:game_word, game: game, word: word, turn: 1) }

      it '同じゲーム内での単語の重複を許可しない' do
        duplicate_game_word = build(:game_word, game: game, word: word, turn: 2)
        expect(duplicate_game_word).not_to be_valid
        expect(duplicate_game_word.errors[:word_id]).to include('は既にこのゲームで使用されています')
      end

      it '異なるゲームでの同じ単語の使用を許可する' do
        different_game = create(:game)
        different_game_word = build(:game_word, game: different_game, word: word, turn: 1)
        expect(different_game_word).to be_valid
      end
    end
  end

  # スコープのテスト
  describe 'scopes' do
    describe '.by_turn_order' do
      let(:game) { create(:game) }
      let!(:game_word3) { create(:game_word, game: game, turn: 3) }
      let!(:game_word1) { create(:game_word, game: game, turn: 1) }
      let!(:game_word2) { create(:game_word, game: game, turn: 2) }

      it 'ターン順に並べる' do
        expect(game.game_words.by_turn_order).to eq([ game_word1, game_word2, game_word3 ])
      end
    end
  end
end
