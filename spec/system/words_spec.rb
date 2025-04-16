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
end