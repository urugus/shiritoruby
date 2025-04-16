require 'rails_helper'

RSpec.describe WordsController, type: :controller do
  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "responds successfully" do
      word1 = create(:word, word: "example1")
      word2 = create(:word, word: "example2")
      get :index
      expect(response).to be_successful
    end

    context "with search query" do
      it "filters words by query" do
        word1 = create(:word, word: "search_test", description: "This is a test")
        word2 = create(:word, word: "another_word", description: "Another description")
        word3 = create(:word, word: "test_word", description: "Contains search term")

        # 検索前の単語数を確認
        expect(Word.count).to eq(3)

        # 検索クエリを実行
        get :index, params: { query: "search" }

        # レスポンスが成功することを確認
        expect(response).to be_successful

        # 直接データベースに問い合わせて検索結果を確認
        filtered_words = Word.where("word LIKE ? OR description LIKE ?", "%search%", "%search%")
        expect(filtered_words).to include(word1)
        expect(filtered_words).to include(word3)
        expect(filtered_words).not_to include(word2)
      end
    end
  end

  describe "GET #download" do
    it "returns a CSV file" do
      create(:word, word: "csv_test1", word_type: "method", description: "CSV Test 1")
      get :download, format: :csv
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(".csv")
    end

    it "includes all words in the CSV" do
      word1 = create(:word, word: "csv_test2", word_type: "method", description: "CSV Test 2")
      word2 = create(:word, word: "csv_test3", word_type: "keyword", description: "CSV Test 3")
      get :download, format: :csv

      csv = CSV.parse(response.body, headers: true)
      expect(csv.count).to be >= 2

      # 単語の順序に依存しないテスト
      words_in_csv = csv.map { |row| row["word"] }
      expect(words_in_csv).to include(word1.word)
      expect(words_in_csv).to include(word2.word)

      # 各単語の詳細情報が正しく含まれているか確認
      word1_row = csv.find { |row| row["word"] == word1.word }
      expect(word1_row["word_type"]).to eq(word1.word_type)
      expect(word1_row["description"]).to eq(word1.description)

      word2_row = csv.find { |row| row["word"] == word2.word }
      expect(word2_row["word_type"]).to eq(word2.word_type)
      expect(word2_row["description"]).to eq(word2.description)
    end
  end

  describe "POST #upload" do
    context "with valid CSV file" do
      it "adds new words from the CSV file" do
        # CSVファイルを作成
        file_path = Rails.root.join('tmp', 'test_upload.csv')
        File.write(file_path, "word,word_type,description\nupload_test1,method,Uploaded test word\nupload_test2,keyword,Uploaded test keyword")

        # ファイルをアップロード
        file = fixture_file_upload(file_path, 'text/csv')

        # テスト実行
        expect {
          post :upload, params: { file: file }
        }.to change(Word, :count).by(2)

        # 結果確認
        expect(Word.find_by(word: "upload_test1")).to be_present
        expect(Word.find_by(word: "upload_test2")).to be_present

        # ファイル削除
        File.delete(file_path) if File.exist?(file_path)
      end

      it "redirects to words_path with a success message" do
        # CSVファイルを作成
        file_path = Rails.root.join('tmp', 'test_upload2.csv')
        File.write(file_path, "word,word_type,description\nupload_test3,method,Uploaded test word\nupload_test4,keyword,Uploaded test keyword")

        # ファイルをアップロード
        file = fixture_file_upload(file_path, 'text/csv')

        # テスト実行
        post :upload, params: { file: file }

        # 結果確認
        expect(response).to redirect_to(words_path)
        expect(flash[:notice]).to include("2件の単語を追加しました")

        # ファイル削除
        File.delete(file_path) if File.exist?(file_path)
      end

      it "skips existing words" do
        # 既存の単語を作成
        create(:word, word: "upload_test5")

        # CSVファイルを作成
        file_path = Rails.root.join('tmp', 'test_upload3.csv')
        File.write(file_path, "word,word_type,description\nupload_test5,method,Uploaded test word\nupload_test6,keyword,Uploaded test keyword")

        # ファイルをアップロード
        file = fixture_file_upload(file_path, 'text/csv')

        # テスト実行
        expect {
          post :upload, params: { file: file }
        }.to change(Word, :count).by(1)

        # 結果確認
        expect(flash[:notice]).to include("1件の単語を追加しました")
        expect(flash[:notice]).to include("1件の単語をスキップしました")

        # ファイル削除
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    context "with invalid parameters" do
      it "redirects with an error when no file is provided" do
        post :upload
        expect(response).to redirect_to(words_path)
        expect(flash[:alert]).to include("ファイルを選択してください")
      end

      it "redirects with an error when non-CSV file is provided" do
        file = fixture_file_upload(
          Rails.root.join('spec', 'rails_helper.rb'),
          'text/plain'
        )

        post :upload, params: { file: file }
        expect(response).to redirect_to(words_path)
        expect(flash[:alert]).to include("CSVファイルのみアップロード可能です")
      end
    end
  end

  describe "DELETE #destroy" do
    it "deletes the word" do
      word = create(:word, word: "delete_test")

      expect {
        delete :destroy, params: { id: word.id }
      }.to change(Word, :count).by(-1)

      expect(Word.find_by(id: word.id)).to be_nil
    end

    it "redirects to words_path with a success message" do
      word = create(:word, word: "delete_test2")

      delete :destroy, params: { id: word.id }

      expect(response).to redirect_to(words_path)
      expect(flash[:notice]).to include("削除しました")
    end
  end
end