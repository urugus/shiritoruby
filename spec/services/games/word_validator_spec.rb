RSpec.describe Games::WordValidator do
  before do
    @ruby = create(:word, word: 'ruby', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', description: 'Rubyのキーワード')
    @class_with_question = create(:word, word: 'class?', description: 'クラスを定義する')
    @string = create(:word, word: 'string', description: '文字列クラス')
  end

  describe '.validate' do
    context '有効な単語の場合' do
      it '検証に成功する' do
        expect(described_class.validate('ruby')).to be true
      end

      it '前の単語の最後の文字と一致する場合、検証に成功する' do
        expect(described_class.validate('yield', 'ruby')).to be true
      end
    end

    context '無効な単語の場合' do
      it '2文字未満の単語はエラーになる' do
        expect {
          described_class.validate('r')
        }.to raise_error(Games::WordValidator::InvalidWordError)
      end

      it '使用済み単語はエラーになる' do
        expect {
          described_class.validate('ruby', nil, [ 'ruby' ])
        }.to raise_error(Games::WordValidator::WordAlreadyUsedError)
      end

      it '前の単語の最後の文字と一致しない場合はエラーになる' do
        expect {
          described_class.validate('string', 'ruby')
        }.to raise_error(Games::WordValidator::InvalidFirstLetterError)
      end
    end
  end

  describe '.get_next_starting_letter' do
    it '通常の単語の場合、最後の文字を返す' do
      expect(described_class.get_next_starting_letter('ruby')).to eq('y')
    end

    it '記号で終わる単語の場合、末尾から遡った最初のアルファベットを返す' do
      expect(described_class.get_next_starting_letter('class?')).to eq('s')
    end
  end

  describe '.validate_ruby_related' do
    it 'DBに存在する単語の場合、単語レコードを返す' do
      result = described_class.validate_ruby_related('ruby')
      expect(result).to eq(@ruby)
    end

    it 'DBに存在しない単語の場合、エラーになる' do
      expect {
        described_class.validate_ruby_related('nonexistent')
      }.to raise_error(Games::WordValidator::InvalidWordError)
    end

    context 'OpenAI APIが設定されている場合' do
      before do
        # 環境変数をモック
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('dummy_key')

        # validate_with_openaiメソッドをモック
        allow(described_class).to receive(:validate_with_openai).and_raise(Games::WordValidator::InvalidWordError, "その単語はRuby関連の単語ではありません")
      end

      it 'DBに存在しない単語の場合、OpenAI APIを使用して検証する' do
        expect(described_class).to receive(:validate_with_openai).with('nonexistent')

        # エラーは発生するが、validate_with_openaiが呼ばれることを確認
        expect {
          described_class.validate_ruby_related('nonexistent')
        }.to raise_error(Games::WordValidator::InvalidWordError)
      end
    end
  end

  describe '.validate_with_openai' do
    it '現在は実装されておらず、エラーを発生させる' do
      expect {
        described_class.validate_with_openai('test')
      }.to raise_error(Games::WordValidator::InvalidWordError)
    end
  end
end
