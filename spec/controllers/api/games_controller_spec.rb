RSpec.describe Api::GamesController, type: :controller do
  render_views

  before do
    # テスト用の単語を作成
    @ruby = create(:word, word: 'ruby', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', description: 'Rubyのキーワード')
    @do = create(:word, word: 'do', description: 'ブロックを開始するキーワード')
    @open = create(:word, word: 'open', description: 'ファイルを開くメソッド')
    @net = create(:word, word: 'net', description: 'ネットワーク関連のモジュール')
  end

  describe 'GET #index' do
    it 'ゲームの高スコアリストを返す' do
      create_list(:game, 3, :high_score)

      get :index, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to be >= 3
    end
  end

  describe 'POST #create' do
    it '新しいゲームを作成する' do
      post :create, params: { player_name: 'テストプレイヤー' }, format: :json

      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('新しいゲームを開始しました')
      expect(json_response['game']['player_name']).to eq('テストプレイヤー')
      expect(session[:game_id]).to be_present
    end

    it 'プレイヤー名が指定されない場合はデフォルト名を使用する' do
      post :create, format: :json

      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['game']['player_name']).to eq('ゲスト')
    end
  end

  describe 'GET #show' do
    context 'セッションにゲームがある場合' do
      before do
        post :create, params: { player_name: 'テストプレイヤー' }, format: :json
      end

      it '現在のゲーム状態を返す' do
        get :show, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['player_name']).to eq('テストプレイヤー')
        expect(json_response['state']).to eq(Games::SessionManager::GAME_STATE[:player_turn])
      end
    end

    context 'セッションにゲームがない場合' do
      it 'エラーを返す' do
        get :show, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end

    context 'セッションIDを使用する場合' do
      let(:game) { create(:game, player_name: 'セッションIDテスト') }
      let(:session_record) { instance_double(ActiveRecord::SessionStore::Session, data: { "game_id" => game.id }.to_json) }
      let(:session_id) { "test_session_id" }

      before do
        allow(ActiveRecord::SessionStore::Session).to receive(:find_by).with(session_id: session_id).and_return(session_record)
        allow(Game).to receive(:find_by).with(id: game.id).and_return(game)
      end

      it 'セッションIDを使用してゲーム状態を取得する' do
        request.headers["X-Session-ID"] = session_id
        get :show, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['player_name']).to eq('セッションIDテスト')
      end

      it '無効なセッションIDでエラーが返される' do
        request.headers["X-Session-ID"] = "invalid_session_id"
        allow(ActiveRecord::SessionStore::Session).to receive(:find_by).and_return(nil)
        allow(ActiveRecord::SessionStore::Session).to receive(:where).and_return([])

        get :show, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end
  end

  describe 'POST #submit_word' do
    before do
      post :create, params: { player_name: 'テストプレイヤー' }, format: :json
    end

    context '有効な単語が提出された場合' do
      it '成功レスポンスを返す' do
        post :submit_word, params: { word: 'ruby' }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['word']).to eq('ruby')
        expect(json_response['computer_response']).to be_present
      end
    end

    context '単語が提供されない場合' do
      it 'バッドリクエストを返す' do
        post :submit_word, format: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('単語が提供されていません')
      end
    end

    context '不正な単語が提出された場合' do
      it 'エラーを返す' do
        # 手動でコントローラーをモックしてエラーをシミュレート
        allow_any_instance_of(Games::SessionManager).to receive(:player_turn).and_raise(
          Games::WordValidator::InvalidFirstLetterError, "単語は「t」で始まる必要があります"
        )

        post :submit_word, params: { word: 'do' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include("単語は「t」で始まる必要があります")
      end
    end
  end

  describe 'POST #timeout' do
    before do
      post :create, params: { player_name: 'テストプレイヤー' }, format: :json
    end

    it 'プレイヤーのターン時にタイムアウト処理を行う' do
      post :timeout, format: :json

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['game_over']).to be true
      expect(json_response['message']).to include('制限時間を超過しました')
    end

    it 'プレイヤーのターンでない場合はエラーを返す' do
      # モックを使用してコンピューターのターンの状態をシミュレート
      allow_any_instance_of(Games::SessionManager).to receive(:current_state).and_return(Games::SessionManager::GAME_STATE[:computer_turn])

      post :timeout, format: :json

      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('現在プレイヤーのターンではありません')
    end
  end
end
