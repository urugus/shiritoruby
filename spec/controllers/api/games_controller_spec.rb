require 'rails_helper'

RSpec.describe Api::GamesController, type: :controller do
  render_views

  before do
    # テスト用の単語を作成
    @ruby = create(:word, word: 'ruby', category: 'term', description: 'プログラミング言語')
    @yield = create(:word, word: 'yield', category: 'keyword', description: 'Rubyのキーワード')
    @do = create(:word, word: 'do', category: 'keyword', description: 'ブロックを開始するキーワード')
    @open = create(:word, word: 'open', category: 'method', description: 'ファイルを開くメソッド')
    @net = create(:word, word: 'net', category: 'class_or_module', description: 'ネットワーク関連のモジュール')
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
        # まず有効な単語を提出
        post :submit_word, params: { word: 'ruby' }, format: :json
        # コンピュータの応答後、不正な単語を提出（先頭文字が一致しない）
        post :submit_word, params: { word: 'do' }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
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
      # プレイヤーのターンからコンピューターのターンに切り替え
      post :submit_word, params: { word: 'ruby' }, format: :json
      post :timeout, format: :json

      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('現在プレイヤーのターンではありません')
    end
  end
end