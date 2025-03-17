require "test_helper"

class Api::GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # テストデータの準備
    @word1 = FactoryBot.create(:word, word: "ruby", category: "term", description: "A programming language")
    @word2 = FactoryBot.create(:word, word: "yield", category: "keyword", description: "A Ruby keyword")
    @word3 = FactoryBot.create(:word, word: "datetime", category: "class_or_module", description: "A Ruby class")
    @word4 = FactoryBot.create(:word, word: "each", category: "method", description: "An enumerable method")

    # 単語の先頭文字が前の単語の最後の文字と一致するようにデータを準備
    @ruby_to_yield = FactoryBot.create(:word, word: "yield", category: "keyword", description: "A keyword in Ruby")
    @yield_to_do = FactoryBot.create(:word, word: "do", category: "keyword", description: "A keyword in Ruby")
    @do_to_open = FactoryBot.create(:word, word: "open", category: "method", description: "A method in Ruby")

    # セッションをリセット
    reset_session
  end

  test "should get index" do
    # 高スコアのゲームを作成
    FactoryBot.create_list(:game, 3)

    get api_games_url, as: :json
    assert_response :success

    # 返されるJSONが配列であることを確認
    assert_kind_of Array, JSON.parse(@response.body)
  end

  test "should create game" do
    post api_games_url, params: { player_name: "Test Player" }, as: :json
    assert_response :created

    # 返されるJSONにゲーム情報が含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_not_nil response_json["game"]
    assert_equal "Test Player", response_json["game"]["player_name"]
  end

  test "should show current game" do
    # 新しいゲームを作成してセッションに保存
    post api_games_url, params: { player_name: "Test Player" }, as: :json

    # 現在のゲーム状態を取得
    get current_api_games_url, as: :json
    assert_response :success

    # 返されるJSONにゲーム情報が含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_equal "Test Player", response_json["player_name"]
  end

  test "should submit valid word" do
    # 新しいゲームを作成
    post api_games_url, params: { player_name: "Test Player" }, as: :json

    # 有効な単語を提出
    post submit_word_api_games_url, params: { word: "ruby" }, as: :json
    assert_response :success

    # 返されるJSONに成功メッセージが含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_equal true, response_json["valid"]
    assert_equal "ruby", response_json["word"]
  end

  test "should reject invalid word" do
    # 新しいゲームを作成
    post api_games_url, params: { player_name: "Test Player" }, as: :json

    # まず有効な単語を提出
    post submit_word_api_games_url, params: { word: "ruby" }, as: :json

    # 先頭文字が前の単語の最後の文字と一致しない単語を提出
    post submit_word_api_games_url, params: { word: "sinatra" }, as: :json
    assert_response :unprocessable_entity

    # 返されるJSONにエラーメッセージが含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_not_nil response_json["error"]
  end

  test "should reject already used word" do
    # 新しいゲームを作成
    post api_games_url, params: { player_name: "Test Player" }, as: :json

    # 単語を提出
    post submit_word_api_games_url, params: { word: "ruby" }, as: :json

    # 同じ単語をもう一度提出
    post submit_word_api_games_url, params: { word: "ruby" }, as: :json
    assert_response :unprocessable_entity

    # 返されるJSONにエラーメッセージが含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_not_nil response_json["error"]
  end

  test "should handle timeout" do
    # 新しいゲームを作成
    post api_games_url, params: { player_name: "Test Player" }, as: :json

    # タイムアウト処理
    post timeout_api_games_url, as: :json
    assert_response :success

    # 返されるJSONにゲームオーバーメッセージが含まれていることを確認
    response_json = JSON.parse(@response.body)
    assert_equal true, response_json["game_over"]
  end
end
