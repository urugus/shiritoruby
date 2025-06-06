# 開発ロードマップ

## 1. 初期セットアップとデータベース準備
- [x] プロジェクトの初期セットアップ
  - [x] 必要なGemのインストールと設定
    - [x] solargraph
    - [x] rubocop
    - [x] factorybot
    - [x] faker
    - [x] annotate
    - [x] rspec-rails
    - [x] shoulda-matchers
    - [x] database_cleaner-active_record
  - [x] アプリケーション構成の設定
  - [x] 開発環境の準備
- [x] データベース設計の実装
  - [x] `words`テーブルの作成（単語リスト）
    - [x] マイグレーションファイルの作成
    - [x] モデル実装
  - [x] `games`テーブルの作成（ゲーム履歴）
    - [x] マイグレーションファイルの作成
    - [x] モデル実装
  - [x] `game_words`テーブルの作成（ゲーム内単語使用履歴）
    - [x] マイグレーションファイルの作成
    - [x] モデル実装
  - [x] モデル間のリレーション設定

## 2. ゲームロジックの実装
- [x] ゲームセッション管理機能の実装
  - [x] セッションの作成と管理
  - [x] ゲーム状態の保存と復元
- [x] ターン制の実装
  - [x] プレイヤーとコンピューターの交代制御
  - [x] ターン数のカウント
- [x] 単語の検証ロジックの実装
  - [x] 入力単語の先頭文字チェック（前の単語の最後の文字と一致するか）
  - [x] 2文字以上の単語かチェック
- [x] 使用済み単語のチェック機能
  - [x] 大文字小文字を区別しない比較ロジック
  - [x] ゲーム内での単語の重複使用防止
- [x] コンピューターの応答ロジックの実装
  - [x] 最後の文字に基づく単語検索
  - [x] 使用済み単語の除外処理
  - [x] 回答候補からのランダム選択
  - [x] 回答不能時の投了判定
- [x] 制限時間（10秒）の実装
  - [x] タイマー機能の基盤
  - [x] 時間切れ判定の基盤
- [x] ゲーム終了条件と勝敗判定の実装
  - [x] コンピューター投了時の処理
  - [x] 時間切れ時の処理
  - [x] 最終スコア計算

## 3. ユーザーインターフェース開発
- [x] ゲーム画面のデザイン
  - [x] 全体レイアウトの設計
  - [x] レスポンシブデザインの実装
  - [x] CSS/スタイリングの適用
- [x] 単語入力フォームの実装
  - [x] フォームのバリデーション
  - [x] 入力補助機能
  - [x] エラーメッセージの表示
- [x] ターン表示の実装
  - [x] 現在のターン（プレイヤー/コンピューター）の表示
  - [x] ターン数の表示
- [x] 残り時間の表示
  - [x] カウントダウンタイマーのUI実装
  - [x] 残り時間の視覚的フィードバック
- [x] 使用済み単語リストの表示
  - [x] 履歴の視覚的表現
  - [x] 最新の単語のハイライト表示
- [x] ゲーム結果画面の実装
  - [x] 勝敗表示
  - [x] スコア表示
  - [x] リプレイオプション

## 4. ランキング機能の実装
- [x] スコア計算ロジックの基本実装
  - [x] ターン数に基づくスコア計算（現在はターン数をスコアとして採用）
  - [x] ゲーム時間も考慮したスコア計算の改善
  - [ ] 難易度調整機能（オプション）
- [x] プレイヤー名の登録機能
  - [x] 名前入力フォーム（スタート画面に実装済み）
  - [x] バリデーション（基本的な長さ制限を実装）
  - [ ] ユーザー識別機能の拡張（クッキーベースなど）
- [x] ランキングデータの保存と取得の基本実装
  - [x] データベース設計と基本クエリ（high_scoresスコープ）
  - [x] 時間範囲やカテゴリによるフィルタリング機能
- [x] ランキング表示画面の実装
  - [x] 専用ランキングページの作成
  - [x] ランキングリストのUI改善
  - [x] フィルタリングやソート機能
  - [x] ページネーション
- [ ] このフェーズで完了済みとなっているタスクが完了していることの確認とロードマップ全体のリプランニング

## 5. OpenAI API連携
- [ ] OpenAI APIとの連携設定
  - [ ] API認証情報の管理（環境変数を使用）
  - [ ] 環境変数の設定（開発/本番環境の分離）
  - [ ] APIクライアントの実装（Ruby OpenAIラッパーライブラリの検討）
- [ ] 単語の検証機能の実装
  - [ ] 単語がRuby関連かどうかの判定ロジック
  - [ ] プロンプト設計と最適化（効率的な単語検証のための指示）
  - [ ] 応答解析（JSON形式でのレスポンス処理）
  - [ ] 検証済み単語のDBへの自動登録機能
- [ ] API応答のエラーハンドリング
  - [ ] タイムアウト処理
  - [ ] レート制限対応
  - [ ] エラー応答の適切な処理
  - [ ] フォールバックメカニズム（API障害時のゲーム継続方法）
- [ ] APIリクエスト最適化
  - [ ] キャッシング戦略（検証済み単語の一時保存）
  - [ ] バッチ処理（可能な場合）
  - [ ] コスト最適化（トークン数の削減）
  - [ ] リクエスト頻度の管理
- [ ] このフェーズで完了済みとなっているタスクが完了していることの確認とロードマップ全体のリプランニング

## 6. 単語データベース構築
- [ ] Ruby組み込みメソッドの収集と登録
  - [x] メソッドリストの収集 → DeepSearch で生成させる
  - [ ] データベースへの一括登録
  - [ ] 単語の説明文章の追加
- [ ] Rubyクラス/モジュール名の収集と登録
  - [ ] クラス/モジュールリストの取得（標準ライブラリから取得する方針）
  - [ ] データベースへの登録
  - [ ] 単語の説明文章の追加
- [ ] 主要なGem名の収集と登録
  - [ ] 人気Gemのリスト作成（RubyGemsのAPIから取得予定）
  - [ ] データベースへの登録
  - [ ] 単語の説明文章の追加
- [ ] Ruby関連用語の収集と登録
  - [ ] 用語リストの作成（Rubyドキュメントから抽出予定）
  - [ ] データベースへの登録
  - [ ] 単語の説明文章の追加
- [x] 予約語の収集と登録
  - [x] 予約語リストの作成
  - [x] データベースへの登録
  - [x] 単語の説明文章の追加
- [ ] 初期データの投入スクリプト作成
  - [ ] 各カテゴリごとのデータ投入処理の実装
  - [ ] シードスクリプトの実行とテスト
- [ ] このフェーズで完了済みとなっているタスクが完了していることの確認とロードマップ全体のリプランニング

## 7. テストと品質向上
- [x] ユニットテストのセットアップ
  - [x] RSpecの設定（spec_helper, rails_helper）
  - [x] FactoryBotのセットアップ
- [x] ベーシックモデルテストの作成
  - [x] Wordモデルのバリデーションとスコープのテスト
  - [x] Gameモデルのテスト
  - [x] GameWordモデルのテスト
- [x] サービスクラステストの基本実装
  - [x] SessionManagerの基本テスト
  - [x] 複雑なゲームフローのテスト強化
- [ ] コントローラーテストの拡充
  - [x] 基本的なAPIエンドポイントのテスト
  - [x] エラーケースの詳細テスト
  - [ ] 認証・認可のテスト（必要に応じて）
- [ ] 統合テストの作成
  - [ ] ゲーム全体フローのE2Eテスト
  - [ ] UI/UXテスト（JavaScriptとの連携）
- [ ] パフォーマンステスト
  - [ ] 応答時間の計測
  - [ ] N+1クエリ問題の解決
  - [ ] ボトルネック分析
- [ ] エッジケースのテスト
  - [ ] 特殊なゲーム状況のテスト
  - [ ] エラー発生時の挙動テスト
  - [ ] タイムアウト処理の正確性検証
- [ ] コードリファクタリング
  - [x] RuboCopによる静的解析
  - [x] コード品質の改善
  - [ ] パフォーマンス最適化
- [ ] このフェーズで完了済みとなっているタスクが完了していることの確認とロードマップ全体のリプランニング

## 8. PWA (Progressive Web App) 対応
- [x] 基本PWA設定
  - [x] マニフェストファイルの設定（app/views/pwa/manifest.json.erb）
  - [x] Service Workerの基本実装（app/views/pwa/service-worker.js）
  - [x] ルート設定（config/routes.rb）
- [ ] オフライン対応の強化
  - [ ] キャッシュ戦略の実装
  - [ ] オフラインモードのUX改善
- [ ] インストール体験の最適化
  - [ ] インストールプロンプトの実装
  - [ ] ホーム画面アイコンとスプラッシュ画面の設計
- [ ] プッシュ通知
  - [ ] 通知許可のリクエスト実装
  - [ ] 定期的な通知機能（オプション）

## 9. UI/UX改善
- [ ] モバイル対応の強化
  - [ ] レスポンシブデザインの微調整
  - [ ] タッチ操作の最適化
- [ ] アクセシビリティ対応
  - [ ] スクリーンリーダー対応
  - [ ] キーボードナビゲーション
  - [ ] コントラスト比の確認
- [ ] UI改善
  - [ ] アニメーションの追加
  - [ ] カラースキームの洗練
  - [ ] タイポグラフィの改善

## 10. デプロイと最終調整
- [ ] 本番環境の準備
  - [ ] サーバー/クラウド環境の設定（kamalファイルが存在するため、kamalによるデプロイを検討）
  - [ ] 環境変数の設定（OpenAI API Key等）
  - [x] ドメイン設定とSSL証明書
- [x] デプロイ設定
  - [x] デプロイスクリプトの作成
  - [x] CIパイプラインの構築（GitHub Actions等）
  - [x] デプロイ自動化の設定
- [ ] パフォーマンス最適化
  - [ ] アセット最適化（CSS/JSの圧縮、画像最適化）
  - [ ] データベースインデックス調整
  - [ ] キャッシュ戦略の実装
  - [x] ロードバランサーのSticky Sessions設定（セッション管理の改善）
- [ ] 最終テスト
  - [ ] 本番環境でのシステムテスト
  - [ ] セキュリティチェック（brakemanツールあり）
  - [ ] 負荷テスト
- [ ] リリース準備
  - [ ] リリースノート作成
  - [ ] ユーザーマニュアル/ガイド作成
  - [ ] バックアップ戦略の確認
  - [ ] 監視とアラートの設定