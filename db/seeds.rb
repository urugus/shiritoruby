# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=== シードデータの準備を開始します ==="

# 先頭または末尾が記号の単語を削除
puts "先頭または末尾が記号の単語を削除しています..."
invalid_words_count = Word.where("word ~ '^[^a-zA-Z0-9]' OR word ~ '[^a-zA-Z0-9]$'").delete_all
puts "#{invalid_words_count}件の無効な単語を削除しました"

# Rubyキーワードのインポート
Rake::Task["words:import_keywords"].invoke

# Rubyドキュメントから単語をインポート
Rake::Task["words:import_from_doctree"].invoke

# 単語の説明を更新
Rake::Task["words:update_descriptions"].invoke

puts "=== シードデータの準備が完了しました ==="
