RSpec.describe Games::ComputerPlayer do
  let(:player_name) { 'テストプレイヤー' }
  let(:game) { create(:game, player_name: player_name) }

  before do
    @ruby = create(:word, word: 'ruby', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', description: 'Rubyのキーワード')
    @do = create(:word, word: 'do', description: 'ブロックを開始するキーワード')
  end

  describe '.generate_response' do
    context '応答可能な単語がある場合' do
      it '有効な応答を返す' do
        result = described_class.generate_response('ruby', game.id)

        expect(result[:valid]).to be true
        expect(result[:word]).to be_a(Word)
        expect(result[:word].word[0].downcase).to eq('y')
      end
    end

    context '応答可能な単語がない場合' do
      before do
        # 'y'から始まる単語を削除
        Word.where("word LIKE 'y%'").destroy_all
      end

      it '投了を返す' do
        result = described_class.generate_response('ruby', game.id)

        expect(result[:valid]).to be false
        expect(result[:surrender]).to be true
        expect(result[:message]).to include('思いつきませんでした')
      end
    end
  end
end
