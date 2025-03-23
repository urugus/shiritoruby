# ShiritoRuby

ShiritoRubyは、Ruby関連の単語を使用してコンピューターと対戦する「しりとり」ゲームです。

## アプリケーション概要

- プレイヤーVSコンピューターのターン制しりとりゲーム
- 使用可能な単語：
  - Rubyの組み込みメソッド（例: puts, gets, chomp）
  - クラス名/モジュール名（例: Array, Enumerable, Net::HTTP）
  - 主要なGemの名前（例: rails, sinatra, devise）
  - 一般的なRuby関連用語（例: rubygems, mri, rbenv）
  - コード内の予約語（例: def, if, do, end）
- ルール：
  - 単語の最後の文字で始まる単語を回答する
  - 末尾が記号(?, !, _, etc)で終わる単語の場合、次の単語の先頭文字は末尾から遡った最初のアルファベットを先頭文字とする（例：class? → string）
  - 同じ単語は再利用不可
- 1ターンの制限時間は10秒
- ランキング機能あり

## 必要要件

* Ruby 3.3.5
* PostgreSQL
* Node.js

## セットアップ

1. リポジトリのクローン
```bash
git clone https://github.com/your-username/shiritoruby.git
cd shiritoruby
```

2. 依存関係のインストール
```bash
bundle install
```

3. データベースの作成と初期化
```bash
bin/rails db:create
bin/rails db:migrate
```

4. 初期データの準備
```bash
# 初期データの投入（単語のインポートと説明の更新を行います）
bin/rails db:seed
```

5. アプリケーションの起動
```bash
bin/rails s
```

その後、ブラウザで http://localhost:3000 にアクセスしてください。

## テスト

```bash
rspec
```

## Lint

- auto-correct を利用する
```bash
rubocop -a
```

## ライセンス

MIT License
