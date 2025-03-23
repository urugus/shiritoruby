RSpec.describe Games::SessionManager do
  let(:player_name) { 'テストプレイヤー' }
  let(:session_manager) { described_class.new(player_name) }

  # テスト用の単語を作成
  before do
    @ruby = create(:word, word: 'ruby', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', description: 'Rubyのキーワード')
    @do = create(:word, word: 'do', description: 'ブロックを開始するキーワード')
    @open = create(:word, word: 'open', description: 'ファイルを開くメソッド')
    @net = create(:word, word: 'net', description: 'ネットワーク関連のモジュール')
  end

  describe '#initialize' do
    it '新しいゲームセッションを初期化する' do
      expect(session_manager.game).to be_a(Game)
      expect(session_manager.game.player_name).to eq(player_name)
      expect(session_manager.game.score).to eq(0)
      expect(session_manager.current_state).to eq(Games::GameState::STATES[:player_turn])
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
      it '単語を記録し、コンピューターの応答を返す' do
        allow_any_instance_of(Games::ComputerPlayer).to receive(:respond).and_return(@yield)

        result = session_manager.player_turn('ruby')

        expect(result[:valid]).to be true
        expect(result[:word]).to eq('ruby')
        # player_turnメソッドはコンピューターのターンも処理するため、最終的にはプレイヤーのターンに戻る
        expect(session_manager.current_state).to eq(Games::GameState::STATES[:player_turn])
        expect(session_manager.game.game_words.count).to eq(2) # プレイヤーとコンピューターの単語
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
        # リファクタリング後はGameStateオブジェクトを通して状態を設定する必要がある
        game_state = session_manager.instance_variable_get(:@game_state)
        game_state.instance_variable_set(:@current_state, Games::GameState::STATES[:player_turn])
      end

      it 'WordAlreadyUsedErrorを発生させる' do
        expect {
          session_manager.player_turn('ruby')
        }.to raise_error(Games::SessionManager::WordAlreadyUsedError)
      end
    end

    context '前の単語の最後の文字と一致しない場合' do
      before do
        # モックを使用してコンピューターの応答を制御し、rubyの後にyieldが返されるようにする
        allow_any_instance_of(Games::ComputerPlayer).to receive(:respond).and_return(@yield)

        # プレイヤーが'ruby'を入力し、コンピューターが'yield'と応答
        session_manager.player_turn('ruby')
      end

      it 'InvalidFirstLetterErrorを発生させる' do
        # 'yield'の最後は'd'なので、'open'は'd'で始まらないためエラーになるはず
        expect {
          session_manager.player_turn('open')
        }.to raise_error(Games::SessionManager::InvalidFirstLetterError)
      end
    end

    context 'プレイヤーのターンでない場合' do
      before do
        game_state = session_manager.instance_variable_get(:@game_state)
        game_state.instance_variable_set(:@current_state, Games::GameState::STATES[:computer_turn])
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
      # player_turnメソッドをスキップして直接コンピューターのターンにする
      session_manager.player_turn('ruby')
      # 状態を強制的にコンピューターターンに設定
      game_state = session_manager.instance_variable_get(:@game_state)
      game_state.instance_variable_set(:@current_state, Games::GameState::STATES[:computer_turn])
    end

    context '応答可能な単語がある場合' do
      it '単語を選択し、プレイヤーのターンに切り替える' do
        # 別の単語を使用する (@yieldではなく@do)
        allow_any_instance_of(Games::ComputerPlayer).to receive(:respond).and_return(@do)

        result = session_manager.computer_turn

        expect(result[:valid]).to be true
        expect(result[:word]).to be_present
        expect(session_manager.current_state).to eq(Games::GameState::STATES[:player_turn])
      end
    end

    context '応答可能な単語がない場合' do
      before do
        # コンピューターが単語を見つけられない場合をシミュレート
        allow_any_instance_of(Games::ComputerPlayer).to receive(:respond).and_return({
          valid: false,
          surrender: true,
          message: "コンピューターは応答できませんでした"
        })
      end

      it 'コンピューターが投了し、ゲームを終了する' do
        result = session_manager.computer_turn

        expect(result[:surrender]).to be true
        expect(session_manager.current_state).to eq(Games::GameState::STATES[:game_over])
        expect(session_manager.end_reason).to eq(Games::GameState::END_REASONS[:computer_surrender])
      end
    end

    context 'コンピューターのターンでない場合' do
      before do
        game_state = session_manager.instance_variable_get(:@game_state)
        game_state.instance_variable_set(:@current_state, Games::GameState::STATES[:player_turn])
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

      expect(session_manager.current_state).to eq(Games::GameState::STATES[:game_over])
      expect(session_manager.end_reason).to eq(Games::GameState::END_REASONS[:player_timeout])
    end
  end

  describe '#end_game' do
    it '指定された理由でゲームを終了する' do
      # 単語を記録してからゲーム終了
      allow_any_instance_of(Games::ComputerPlayer).to receive(:respond).and_return(@yield)
      session_manager.player_turn('ruby')
      game_state = session_manager.instance_variable_get(:@game_state)
      game_state.instance_variable_set(:@current_state, Games::GameState::STATES[:player_turn])

      # ScoreCalculatorをモックして、テスト用のスコアを返すようにする
      allow_any_instance_of(Games::ScoreCalculator).to receive(:calculate).and_return({
        score: 200,
        time_bonus: 1.0,
        turn_score: 200
      })

      result = session_manager.end_game(Games::GameState::END_REASONS[:player_timeout])

      expect(session_manager.current_state).to eq(Games::GameState::STATES[:game_over])
      expect(session_manager.end_reason).to eq(Games::GameState::END_REASONS[:player_timeout])
      expect(session_manager.game.score).to eq(200) # スコア計算による値
    end
  end

  describe '#game_state' do
    it '現在のゲーム状態を返す' do
      state = session_manager.game_state

      expect(state[:id]).to eq(session_manager.game.id)
      expect(state[:player_name]).to eq(player_name)
      expect(state[:state]).to eq(Games::GameState::STATES[:player_turn])
    end
  end
end
