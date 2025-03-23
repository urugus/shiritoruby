# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=== シードデータの準備を開始します ==="

# Rubyキーワードのインポート
Rake::Task["words:import_keywords"].invoke

# Rubyドキュメントから単語をインポート
Rake::Task["words:import_from_doctree"].invoke

# 単語の説明を更新
Rake::Task["words:update_descriptions"].invoke

puts "=== シードデータの準備が完了しました ==="
