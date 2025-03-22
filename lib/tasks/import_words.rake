require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'tmpdir'
require 'json'

namespace :words do
  RUBY_KEYWORDS = %w[
    BEGIN END alias and begin break case class def defined? do else elsif end
    ensure false for if in module next nil not or redo rescue retry return self
    super then true undef unless until when while yield
  ].freeze

  desc 'Import Ruby keywords'
  task import_keywords: :environment do
    puts 'Importing Ruby keywords...'

    RUBY_KEYWORDS.each do |keyword|
      begin
        Word.find_or_create_by!(word: keyword) do |w|
          w.normalized_word = keyword.downcase
          w.description = "Ruby keyword: #{get_keyword_description(keyword)}"
          w.word_type = 'keyword'
        end
        print '.'
      rescue ActiveRecord::RecordInvalid => e
        puts "\nSkipped '#{keyword}': #{e.message}"
      end
    end

    puts "\nKeywords import completed!"
  end

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

  def get_keyword_description(keyword)
    case keyword
    when 'BEGIN'
      'Runs before the main program execution begins'
    when 'END'
      'Runs after the main program execution ends'
    when 'alias'
      'Creates an alias for an existing method, operator, or global variable'
    when 'and'
      'Logical operator that returns true if both operands are true'
    when 'begin'
      'Begins a code block or method definition that may raise an exception'
    when 'break'
      'Terminates a loop or switch statement and transfers control'
    when 'case'
      'Starts a case expression for pattern matching'
    when 'class'
      'Defines a new class'
    when 'def'
      'Defines a new method'
    when 'defined?'
      'Tests whether a given expression is defined'
    when 'do'
      'Starts a block'
    when 'else'
      'Alternative condition in if/unless/case statements'
    when 'elsif'
      'Alternative condition if previous conditions are false'
    when 'end'
      'Ends a code block, class, module, or method definition'
    when 'ensure'
      'Ensures that a block of code is always executed'
    when 'false'
      'Boolean false value'
    when 'for'
      'Loop construct for iterating over a collection'
    when 'if'
      'Conditional statement that executes code if condition is true'
    when 'in'
      'Used in pattern matching to specify patterns'
    when 'module'
      'Defines a module'
    when 'next'
      'Jumps to the next iteration of a loop'
    when 'nil'
      'Represents absence of a value'
    when 'not'
      'Logical operator that returns the opposite of a boolean value'
    when 'or'
      'Logical operator that returns true if either operand is true'
    when 'redo'
      'Restarts the current iteration of a loop'
    when 'rescue'
      'Handles exceptions in begin/end blocks'
    when 'retry'
      'Retries a begin/end block after an exception'
    when 'return'
      'Returns a value from a method'
    when 'self'
      'References the current object'
    when 'super'
      'Calls the same method in the parent class'
    when 'then'
      'Optional separator in if/when statements'
    when 'true'
      'Boolean true value'
    when 'undef'
      'Removes a method definition'
    when 'unless'
      'Conditional statement that executes code if condition is false'
    when 'until'
      'Loop that executes while condition is false'
    when 'when'
      'Condition in case statements'
    when 'while'
      'Loop that executes while condition is true'
    when 'yield'
      'Calls the block passed to a method'
    else
      'Ruby language keyword'
    end
  end

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