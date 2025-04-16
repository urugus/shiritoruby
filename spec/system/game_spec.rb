require 'rails_helper'

RSpec.describe 'Game', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'displays the game page' do
    visit root_path
    expect(page).to have_content('ShiritoRuby')
    expect(page).to have_content('Rubyしりとりゲーム')
  end

  describe 'game over screen' do
    before do
      # テスト用の単語を作成
      @word1 = create(:word, word: "ruby", word_type: "keyword", description: "プログラミング言語")
      @word2 = create(:word, word: "yield", word_type: "keyword", description: "ブロックに制御を渡すキーワード")

      # テスト用のゲームを作成
      @game = create(:game, player_name: "テストプレイヤー", score: 10)

      # ゲームに単語を関連付け
      create(:game_word, game: @game, word: @word1, turn: 1)
      create(:game_word, game: @game, word: @word2, turn: 2)
    end

    it 'displays word descriptions in the game over screen', js: true do
      # APIレスポンスをモック
      page.execute_script(<<~JS)
        // オリジナルのfetchを保存
        window._originalFetch = window.fetch;

        // fetchをモック
        window.fetch = function(url, options) {
          if (url.includes('/api/games/timeout')) {
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({
                game_over: true,
                message: "制限時間を超過しました。コンピューターの勝利です。",
                game: {
                  id: #{@game.id},
                  player_name: "テストプレイヤー",
                  score: 10,
                  duration_seconds: 60
                },
                words_with_descriptions: [
                  {
                    word: "ruby",
                    description: "プログラミング言語",
                    player: "player"
                  },
                  {
                    word: "yield",
                    description: "ブロックに制御を渡すキーワード",
                    player: "computer"
                  }
                ]
              })
            });
          }

          // その他のリクエストは通常通り処理
          return window._originalFetch(url, options);
        };
      JS

      # ゲームページにアクセス
      visit root_path

      # プレイヤー名を入力してゲーム開始
      fill_in "player-name", with: "テストプレイヤー"
      click_button "ゲーム開始"

      # カウントダウンが終わるまで待機
      sleep 4

      # タイムアウトをシミュレート - APIレスポンスを直接処理
      page.execute_script(<<~JS)
        // ゲームオーバー状態を直接設定
        const gameController = document.querySelector('[data-controller="game"]');
        const event = new CustomEvent('game:timeout', {
          detail: {
            game_over: true,
            message: "制限時間を超過しました。コンピューターの勝利です。",
            game: {
              id: #{@game.id},
              player_name: "テストプレイヤー",
              score: 10,
              duration_seconds: 60
            },
            words_with_descriptions: [
              {
                word: "ruby",
                description: "プログラミング言語",
                player: "player"
              },
              {
                word: "yield",
                description: "ブロックに制御を渡すキーワード",
                player: "computer"
              }
            ]
          }
        });

        // handleGameOverメソッドを直接呼び出す
        const controller = window.Stimulus.getControllerForElementAndIdentifier(gameController, "game");
        controller.handleGameOver(event.detail);
      JS

      # ゲーム終了画面が表示されるまで待機
      expect(page).to have_content("ゲーム終了")

      # 単語一覧のヘッダーが表示されていることを確認
      within "#game-over-word-list" do
        expect(page).to have_content("ターン")
        expect(page).to have_content("単語")
        expect(page).to have_content("プレイヤー")
        expect(page).to have_content("説明")
      end

      # 単語とその説明が表示されていることを確認
      expect(page).to have_content("ruby")
      expect(page).to have_content("プログラミング言語")
      expect(page).to have_content("yield")
      expect(page).to have_content("ブロックに制御を渡すキーワード")
    end
  end
end
