class WordsController < ApplicationController
  require "csv"

  def index
    @query = params[:query]
    @words = Word.all

    # 検索クエリがある場合は絞り込み
    if @query.present?
      @words = @words.where("word LIKE ? OR description LIKE ?", "%#{@query}%", "%#{@query}%")
    end

    @words = @words.order(:word).page(params[:page]).per(50)
  end

  def destroy
    @word = Word.find(params[:id])

    if @word.destroy
      flash[:notice] = "単語「#{@word.word}」を削除しました。"
    else
      flash[:alert] = "単語の削除に失敗しました。"
    end

    redirect_to words_path
  end

  def bulk_destroy
    if params[:word_ids].blank?
      flash[:alert] = "削除する単語を選択してください。"
      redirect_to words_path
      return
    end

    word_ids = params[:word_ids].keys
    deleted_count = 0

    begin
      Word.transaction do
        words = Word.where(id: word_ids)
        deleted_count = words.count
        words.destroy_all
      end

      flash[:notice] = "#{deleted_count}件の単語を削除しました。"
    rescue => e
      flash[:alert] = "単語の削除に失敗しました。エラー: #{e.message}"
    end

    redirect_to words_path
  end

  def download
    @words = Word.all.order(:word)

    respond_to do |format|
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          # ヘッダー行
          csv << ["word", "word_type", "description"]

          # データ行
          @words.each do |word|
            csv << [word.word, word.word_type, word.description]
          end
        end

        send_data csv_data, filename: "words_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
      end
    end
  end

  def upload
    if params[:file].blank?
      flash[:alert] = "ファイルを選択してください"
      redirect_to words_path
      return
    end

    # CSVファイルかどうかのチェック
    content_type = params[:file].respond_to?(:content_type) ? params[:file].content_type : nil
    filename = params[:file].respond_to?(:original_filename) ? params[:file].original_filename : File.basename(params[:file].path)

    unless content_type == "text/csv" || filename.end_with?(".csv")
      flash[:alert] = "CSVファイルのみアップロード可能です"
      redirect_to words_path
      return
    end

    begin
      added_count = 0
      skipped_count = 0
      errors = []

      # ファイルの内容を読み込む
      file_content = File.read(params[:file].path)

      # CSVパース
      csv_data = CSV.parse(file_content, headers: true)

      # 各行を処理
      csv_data.each do |row|
        word_text = row["word"]

        # 単語が空の場合はスキップ
        if word_text.blank?
          skipped_count += 1
          next
        end

        # 単語が既に存在する場合はスキップ
        if Word.exists?(word: word_text)
          skipped_count += 1
          next
        end

        # 単語データを作成
        word_data = {
          word: word_text,
          normalized_word: word_text.downcase, # normalized_wordを明示的に設定
          word_type: row["word_type"] || "method",
          description: row["description"]
        }

        # 単語を登録
        word = Word.new(word_data)
        if word.save
          added_count += 1
        else
          errors << "#{word_data[:word]}: #{word.errors.full_messages.join(', ')}"
          skipped_count += 1
        end
      end

      if errors.any?
        flash[:alert] = "#{added_count}件の単語を追加しました。#{skipped_count}件の単語をスキップしました。エラー: #{errors.join(', ')}"
      else
        flash[:notice] = "#{added_count}件の単語を追加しました。#{skipped_count}件の単語をスキップしました。"
      end
    rescue CSV::MalformedCSVError => e
      flash[:alert] = "CSVファイルの形式が不正です: #{e.message}"
    rescue => e
      flash[:alert] = "エラーが発生しました: #{e.message}"
    end

    redirect_to words_path
  end
end