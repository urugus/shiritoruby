require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'tmpdir'
require 'json'

namespace :words do
  desc 'Import words from rurema/doctree repository'
  task import_from_doctree: :environment do
    # クローンするリポジトリのURL
    repo_url = 'https://github.com/rurema/doctree.git'

    Dir.mktmpdir do |tmp_dir|
      puts 'Cloning rurema/doctree repository...'
      system("git clone --depth 1 #{repo_url} #{tmp_dir}")

      puts 'Scanning rdoc files...'
      words = extract_words_from_rdoc("#{tmp_dir}/refm/api/src")

      puts "Found #{words.length} potential terms"
      import_words(words)

      puts "\nImport completed!"
    end
  end

  desc 'Update descriptions for Ruby methods from documentation'
  task update_descriptions: :environment do
    puts 'Updating descriptions from Ruby documentation...'

    Dir.mktmpdir do |tmp_dir|
      # ruremaリポジトリをクローン
      repo_url = 'https://github.com/rurema/doctree.git'
      system("git clone --depth 1 #{repo_url} #{tmp_dir}")

      # メソッドの説明を更新
      update_method_descriptions("#{tmp_dir}/refm/api/src")

      # RubyGemsのAPIから人気のGemの説明を取得
      update_gem_descriptions
    end

    puts "\nDescription update completed!"
  end

  private

  def extract_words_from_rdoc(base_path)
    words = Set.new

    # rdocファイルを再帰的に検索
    Dir.glob("#{base_path}/**/*.rd").each do |file|
      content = File.read(file)

      # クラス名、モジュール名、メソッド名を抽出
      content.scan(/\b[A-Z][A-Za-z0-9_]*[a-z][A-Za-z0-9_]*\b/).each do |word|
        words.add(word) if word.match?(/\A[A-Za-z0-9_]+\z/)
      end

      # メソッド名を抽出（例：each_with_index, map!, etc.）
      content.scan(/\b[a-z][a-z0-9_]*[?!=]?\b/).each do |word|
        words.add(word) if word.match?(/\A[A-Za-z0-9_?!=]+\z/)
      end
    end

    words.to_a
  end

  def import_words(words)
    words.each do |word|
      normalized_word = word.downcase

      begin
        Word.find_or_create_by!(word: word) do |w|
          w.normalized_word = normalized_word
          w.description = "Ruby standard library term"
        end
        print '.'
      rescue ActiveRecord::RecordInvalid => e
        puts "\nSkipped '#{word}': #{e.message}"
      end
    end
  end

  def update_method_descriptions(base_path)
    puts 'Updating method descriptions...'
    Word.find_each do |word|
      # メソッド名に対応するドキュメントファイルを検索
      method_files = Dir.glob("#{base_path}/**/*.rd").select do |file|
        content = File.read(file)
        content.include?(" #{word.word} ") || content.include?("##{word.word}")
      end

      next if method_files.empty?

      # 最初に見つかったファイルから説明を抽出
      content = File.read(method_files.first)
      if (match = content.match(/--- .*#{word.word}.*\n+(.*?)(\n\n|\z)/m))
        description = match[1].strip
        word.update(description: description) unless description.empty?
        print '.'
      end
    end
  end

  def update_gem_descriptions
    puts "\nUpdating gem descriptions..."
    # RubyGemsのAPIから人気のGemを取得
    gems_url = 'https://rubygems.org/api/v1/search.json?query=&page=1&order=downloads'
    response = URI.open(gems_url).read
    gems = JSON.parse(response)

    gems.each do |gem_info|
      gem_name = gem_info['name']
      # gemの名前に対応する単語があれば説明を更新
      if (word = Word.find_by(normalized_word: gem_name.downcase))
        word.update(
          description: "Ruby gem: #{gem_info['info']}"
        )
        print '.'
      end
    end
  end
end