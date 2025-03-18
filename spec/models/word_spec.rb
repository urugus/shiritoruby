RSpec.describe Word, type: :model do
  # アソシエーションのテスト
  describe 'associations' do
    it { should have_many(:game_words).dependent(:destroy) }
    it { should have_many(:games).through(:game_words) }
  end

  # バリデーションのテスト
  describe 'validations' do
    it { should validate_presence_of(:word) }
    it { should validate_presence_of(:category) }
    it { should validate_uniqueness_of(:word).case_insensitive }
    it { should validate_length_of(:word).is_at_least(2) }
  end

  # enumのテスト
  describe 'enums' do
    it { should define_enum_for(:category).with_values(
      method: 'method',
      class_or_module: 'class_module',
      gem: 'gem',
      term: 'term',
      keyword: 'keyword'
    )}
  end

  # スコープのテスト
  describe 'scopes' do
    describe '.by_first_letter' do
      before do
        create(:word, word: 'ruby')
        create(:word, word: 'rails')
        create(:word, word: 'yield')
      end

      it '指定された文字で始まる単語を返す' do
        expect(Word.by_first_letter('r').count).to eq(2)
        expect(Word.by_first_letter('y').count).to eq(1)
      end

      it '大文字小文字を区別しない' do
        expect(Word.by_first_letter('R').count).to eq(2)
      end
    end

    describe '.unused_in_game' do
      let(:game) { create(:game) }
      let!(:word1) { create(:word, word: 'ruby') }
      let!(:word2) { create(:word, word: 'rails') }
      let!(:word3) { create(:word, word: 'yield') }

      before do
        create(:game_word, game: game, word: word1)
      end

      it 'ゲームで使用されていない単語を返す' do
        unused_words = Word.unused_in_game(game.id)
        expect(unused_words).to include(word2, word3)
        expect(unused_words).not_to include(word1)
      end
    end
  end

  # コールバックのテスト
  describe 'callbacks' do
    describe '#downcase_word' do
      it '保存前に単語を小文字に変換する' do
        word = create(:word, word: 'RUBY')
        expect(word.reload.word).to eq('ruby')
      end
    end
  end
end