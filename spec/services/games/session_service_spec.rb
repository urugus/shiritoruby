RSpec.describe Games::SessionService do
  let(:player_name) { 'テストプレイヤー' }
  let(:session_manager) { Games::SessionManager.new(player_name) }
  let(:game) { session_manager.game }
  let(:session_id) { "test_session_id" }

  describe '.retrieve_session_manager' do
    context 'セッションIDが有効な場合' do
      before do
        # セッションレコードをモック
        session_record = instance_double(
          ActiveRecord::SessionStore::Session,
          data: { "game_id" => game.id }.to_json
        )
        allow(ActiveRecord::SessionStore::Session).to receive(:find_by).with(session_id: session_id).and_return(session_record)
      end

      it '有効なセッションマネージャーを返す' do
        allow(Game).to receive(:find_by).with(id: game.id).and_return(game)

        result = described_class.retrieve_session_manager(session_id)
        expect(result).to be_a(Games::SessionManager)
        expect(result.game.id).to eq(game.id)
      end
    end

    context 'セッションIDが無効な場合' do
      before do
        allow(ActiveRecord::SessionStore::Session).to receive(:find_by).and_return(nil)
        allow(ActiveRecord::SessionStore::Session).to receive(:where).and_return([])
      end

      it '現在のセッションからゲームIDを取得しようとする' do
        current_session = { game_id: game.id }
        allow(Game).to receive(:find_by).with(id: game.id).and_return(game)

        result = described_class.retrieve_session_manager(nil, current_session)
        expect(result).to be_a(Games::SessionManager)
        expect(result.game.id).to eq(game.id)
      end

      it 'ゲームIDが見つからない場合はエラーを発生させる' do
        expect {
          described_class.retrieve_session_manager(nil, {})
        }.to raise_error(Games::SessionService::SessionNotFoundError)
      end
    end
  end

  describe '.rebuild_session_manager' do
    context '有効なゲームIDの場合' do
      before do
        # 単語を作成
        @word1 = create(:word, word: 'ruby')
        @word2 = create(:word, word: 'yield')

        # ゲーム単語を作成
        game.game_words.create!(word: @word1, turn: 1)
        game.game_words.create!(word: @word2, turn: 2)
      end

      it 'ゲームの状態を正しく復元する' do
        result = described_class.rebuild_session_manager(game.id)

        expect(result).to be_a(Games::SessionManager)
        expect(result.game.id).to eq(game.id)
        expect(result.instance_variable_get(:@used_words)).to eq([ 'ruby', 'yield' ])
        expect(result.instance_variable_get(:@last_word)).to eq('yield')
        expect(result.instance_variable_get(:@current_state)).to eq(Games::SessionManager::GAME_STATE[:player_turn])
      end
    end

    context '無効なゲームIDの場合' do
      it 'エラーを発生させる' do
        expect {
          described_class.rebuild_session_manager('invalid_id')
        }.to raise_error(Games::SessionService::SessionNotFoundError)
      end
    end
  end

  describe '.determine_game_state' do
    it '単語がない場合はプレイヤーのターン' do
      result = described_class.determine_game_state(game)
      expect(result).to eq(Games::SessionManager::GAME_STATE[:player_turn])
    end

    it '単語数が奇数の場合はコンピューターのターン' do
      create(:game_word, game: game, turn: 1)
      result = described_class.determine_game_state(game)
      expect(result).to eq(Games::SessionManager::GAME_STATE[:computer_turn])
    end

    it '単語数が偶数かつ0でない場合はプレイヤーのターン' do
      create(:game_word, game: game, turn: 1)
      create(:game_word, game: game, turn: 2)
      result = described_class.determine_game_state(game)
      expect(result).to eq(Games::SessionManager::GAME_STATE[:player_turn])
    end
  end
end
