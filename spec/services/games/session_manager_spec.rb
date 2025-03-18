RSpec.describe Games::SessionManager do
  let(:player_name) { 'テストプレイヤー' }
  let(:session_manager) { described_class.new(player_name) }

  # テスト用の単語を作成
  before do
    @ruby = create(:word, word: 'ruby', category: 'term', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', category: 'keyword', description: 'Rubyのキーワード')
    @do = create(:word, word: 'do', category: 'keyword', description: 'ブロックを開始するキーワード')
    @open = create(:word, word: 'open', category: 'method', description: 'ファイルを開くメソッド')
    @net = create(:word, word: 'net', category: 'class_or_module', description: 'ネットワーク関連のモジュール')
  end

  describe '#initialize' do
    it '新しいゲームセッションを初期化する' do
      expect(session_manager.game).to be_a(Game)
      expect(session_manager.game.player_name).to eq(player_name)
      expect(session_manager.game.score).to eq(0)
      expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:player_turn])
    end
  end

  describe '#create_game' do
    it '新しいゲームを作成する' do
      game = session_manager.create_game
      expect(game).to be_persisted
      expect(game.player_name).to eq(player_name)
    end
  end

  describe '#player_turn' do
    context '有効な単語が入力された場合' do
      it '単語を記録し、コンピューターのターンに切り替える' do
        result = session_manager.player_turn('ruby')

        expect(result[:valid]).to be true
        expect(result[:word]).to eq('ruby')
        expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:computer_turn])
        expect(session_manager.game.game_words.count).to eq(1)
      end
    end

    context '2文字未満の単語が入力された場合' do
      it 'InvalidWordErrorを発生させる' do
        expect {
          session_manager.player_turn('r')
        }.to raise_error(Games::SessionManager::InvalidWordError)
      end
    end

    context '既に使用された単語が入力された場合' do
      before do
        session_manager.player_turn('ruby')
        session_manager.instance_variable_set(:@current_state, Games::SessionManager::GAME_STATE[:player_turn])
      end

      it 'WordAlreadyUsedErrorを発生させる' do
        expect {
          session_manager.player_turn('ruby')
        }.to raise_error(Games::SessionManager::WordAlreadyUsedError)
      end
    end

    context '前の単語の最後の文字と一致しない場合' do
      before do
        session_manager.player_turn('ruby')
        session_manager.instance_variable_set(:@current_state, Games::SessionManager::GAME_STATE[:player_turn])
      end

      it 'InvalidFirstLetterErrorを発生させる' do
        expect {
          session_manager.player_turn('do')
        }.to raise_error(Games::SessionManager::InvalidFirstLetterError)
      end
    end

    context 'プレイヤーのターンでない場合' do
      before do
        session_manager.instance_variable_set(:@current_state, Games::SessionManager::GAME_STATE[:computer_turn])
      end

      it 'GameSessionErrorを発生させる' do
        expect {
          session_manager.player_turn('ruby')
        }.to raise_error(Games::SessionManager::GameSessionError)
      end
    end
  end

  describe '#computer_turn' do
    before do
      # プレイヤーが先に単語を入力
      session_manager.player_turn('ruby')
    end

    context '応答可能な単語がある場合' do
      it '単語を選択し、プレイヤーのターンに切り替える' do
        result = session_manager.computer_turn

        expect(result[:valid]).to be true
        expect(result[:word]).to be_present
        expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:player_turn])
      end
    end

    context '応答可能な単語がない場合' do
      before do
        # 'y'から始まる単語を削除
        Word.where("word LIKE 'y%'").destroy_all
      end

      it 'コンピューターが投了し、ゲームを終了する' do
        result = session_manager.computer_turn

        expect(result[:valid]).to be false
        expect(result[:surrender]).to be true
        expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:game_over])
        expect(session_manager.end_reason).to eq(Games::SessionManager::GAME_END_REASON[:computer_surrender])
      end
    end

    context 'コンピューターのターンでない場合' do
      before do
        session_manager.instance_variable_set(:@current_state, Games::SessionManager::GAME_STATE[:player_turn])
      end

      it 'GameSessionErrorを発生させる' do
        expect {
          session_manager.computer_turn
        }.to raise_error(Games::SessionManager::GameSessionError)
      end
    end
  end

  describe '#timeout' do
    it 'プレイヤーのターン時にゲームを終了する' do
      result = session_manager.timeout

      expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:game_over])
      expect(session_manager.end_reason).to eq(Games::SessionManager::GAME_END_REASON[:player_timeout])
    end
  end

  describe '#end_game' do
    it '指定された理由でゲームを終了する' do
      # 単語を記録してからゲーム終了
      session_manager.player_turn('ruby')
      session_manager.instance_variable_set(:@current_state, Games::SessionManager::GAME_STATE[:player_turn])

      result = session_manager.end_game(Games::SessionManager::GAME_END_REASON[:player_timeout])

      expect(session_manager.current_state).to eq(Games::SessionManager::GAME_STATE[:game_over])
      expect(session_manager.end_reason).to eq(Games::SessionManager::GAME_END_REASON[:player_timeout])
      expect(session_manager.game.score).to eq(1) # 1単語使用
    end
  end

  describe '#game_state' do
    it '現在のゲーム状態を返す' do
      state = session_manager.game_state

      expect(state[:id]).to eq(session_manager.game.id)
      expect(state[:player_name]).to eq(player_name)
      expect(state[:state]).to eq(Games::SessionManager::GAME_STATE[:player_turn])
    end
  end
end