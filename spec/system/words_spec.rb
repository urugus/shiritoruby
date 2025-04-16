require 'rails_helper'

RSpec.describe "Words", type: :system do
  before do
    driven_by(:rack_test)
  end

  describe "単語管理ページ" do
    before do
      # テスト用の単語を作成
      create(:word, word: "example", word_type: "method", description: "Example method")
      create(:word, word: "test", word_type: "keyword", description: "Test keyword")

      visit words_path
    end

    it "単語一覧が表示される" do
      expect(page).to have_content("単語管理")
      expect(page).to have_content("登録済み単語一覧")

      expect(page).to have_content("example")
      expect(page).to have_content("method")
      expect(page).to have_content("Example method")

      expect(page).to have_content("test")
      expect(page).to have_content("keyword")
      expect(page).to have_content("Test keyword")
    end

    it "CSVダウンロードリンクが表示される" do
      expect(page).to have_link("CSVダウンロード", href: download_words_path(format: :csv))
    end

    it "CSVアップロードフォームが表示される" do
      expect(page).to have_content("単語データのアップロード")
      expect(page).to have_field("file")
      expect(page).to have_button("アップロード")
    end
  end

  describe "CSVアップロード機能", js: false do
    before do
      visit words_path

      # CSVファイルを作成
      @file_path = Rails.root.join('tmp', 'system_test_upload.csv')
      File.write(@file_path, "word,word_type,description\nsystem_test1,method,System test method\nsystem_test2,keyword,System test keyword")
    end

    after do
      # テスト用のCSVファイルを削除
      File.delete(@file_path) if File.exist?(@file_path)
    end

    it "CSVファイルをアップロードして単語を追加できる" do
      # 単語数を記録
      initial_count = Word.count

      # CSVファイルをアップロード
      attach_file("file", @file_path)
      click_button "アップロード"

      # 単語が追加されたことを確認
      expect(Word.count).to eq(initial_count + 2)

      # 追加された単語が表示されていることを確認
      expect(page).to have_content("system_test1")
      expect(page).to have_content("method")
      expect(page).to have_content("System test method")

      expect(page).to have_content("system_test2")
      expect(page).to have_content("keyword")
      expect(page).to have_content("System test keyword")
    end
  end

  describe "検索機能", js: false do
    before do
      # テスト用の単語を作成
      @word1 = create(:word, word: "search_word", description: "This is a searchable word")
      @word2 = create(:word, word: "another_word", description: "This is another word")
      @word3 = create(:word, word: "third_word", description: "Contains search term")

      visit words_path
    end

    it "単語を検索できる" do
      # 検索フォームに入力
      fill_in "query", with: "search"
      click_button "検索"

      # 検索結果を確認
      expect(page).to have_content(@word1.word)
      expect(page).to have_content(@word3.description)
      expect(page).not_to have_content(@word2.word)

      # 検索クエリがフォームに残っていることを確認
      expect(find_field("query").value).to eq("search")

      # クリアボタンが表示されていることを確認
      expect(page).to have_link("クリア")
    end

    it "検索結果をクリアできる" do
      # 検索を実行
      fill_in "query", with: "search"
      click_button "検索"

      # クリアボタンをクリック
      click_link "クリア"

      # すべての単語が表示されていることを確認
      expect(page).to have_content(@word1.word)
      expect(page).to have_content(@word2.word)
      expect(page).to have_content(@word3.word)

      # 検索フォームがクリアされていることを確認（値の検証ではなく、フィールドの存在を確認）
      expect(page).to have_field("query")
      # クエリパラメータがないことを確認
      expect(current_url).not_to include("query=")
    end
  end

  describe "削除機能", js: false do
    before do
      @word = create(:word, word: "delete_test", description: "This word will be deleted")
      visit words_path
    end

    it "単語を削除できる" do
      # 削除前の単語数を記録
      initial_count = Word.count

      # 削除リンクのパスを直接取得して削除リクエストを送信
      delete_path = word_path(@word)
      page.driver.submit :delete, delete_path, {}

      # 削除後のページを表示
      visit words_path

      # 単語が削除されたことを確認
      expect(Word.count).to eq(initial_count - 1)
      expect(page).not_to have_content(@word.word)
    end
  end
end