import { Controller } from "@hotwired/stimulus"

// ゲーム画面の機能を管理するコントローラー
export default class extends Controller {
  static targets = [
    "startScreen", "gameArea", "gameOver",
    "wordInput", "wordList", "currentWord",
    "turnIndicator", "timer", "errorMessage",
    "resultMessage", "finalScore"
  ]

  static values = {
    apiUrl: String,
    timerDuration: { type: Number, default: 10 }
  }

  connect() {
    this.gameState = {
      inProgress: false,
      playerTurn: false,
      lastWord: "",
      usedWords: [],
      timerInterval: null,
      timeLeft: this.timerDurationValue
    }

    // イベントリスナーを設定
    this.setupEventListeners()
  }

  setupEventListeners() {
    // プレイヤー名入力フォームの送信
    document.getElementById("player-form").addEventListener("submit", (e) => {
      e.preventDefault()
      this.startGame()
    })

    // 単語入力フォームの送信
    document.getElementById("word-form").addEventListener("submit", (e) => {
      e.preventDefault()
      this.submitWord()
    })

    // リプレイボタン
    document.getElementById("replay-button").addEventListener("click", () => {
      this.resetGame()
    })
  }

  // ゲームを開始する
  startGame() {
    const playerName = document.getElementById("player-name").value || "ゲスト"

    fetch("/api/games", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({ player_name: playerName })
    })
    .then(response => response.json())
    .then(data => {
      // ゲーム状態を初期化
      this.gameState.inProgress = true
      this.gameState.playerTurn = true
      this.gameState.usedWords = []
      this.gameState.lastWord = ""

      // UIを更新
      this.startScreenTarget.classList.add("hidden")
      this.gameAreaTarget.classList.remove("hidden")
      this.gameOverTarget.classList.add("hidden")
      this.wordListTarget.innerHTML = ""
      this.currentWordTarget.textContent = "ゲーム開始！最初の単語を入力してください"
      this.turnIndicatorTarget.textContent = "あなた"
      this.wordInputTarget.value = ""
      this.wordInputTarget.focus()
      this.errorMessageTarget.textContent = ""

      // タイマーを開始
      this.startTimer()
    })
    .catch(error => {
      console.error("ゲーム開始エラー:", error)
      this.showError("ゲームを開始できませんでした。もう一度お試しください。")
    })
  }

  // 単語をサーバーに送信する
  submitWord() {
    const word = this.wordInputTarget.value.trim()

    if (!word) {
      this.showError("単語を入力してください")
      return
    }

    // タイマーを停止
    this.stopTimer()

    fetch("/api/games/submit_word", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({ word })
    })
    .then(response => {
      if (!response.ok) {
        return response.json().then(data => {
          throw new Error(data.error || "単語の送信に失敗しました")
        })
      }
      return response.json()
    })
    .then(data => {
      // 入力をクリア
      this.wordInputTarget.value = ""
      this.errorMessageTarget.textContent = ""

      // プレイヤーの単語を表示
      this.addWordToHistory(word, "player")
      this.gameState.lastWord = word
      this.gameState.usedWords.push(word.toLowerCase())

      // ゲームオーバーかどうかをチェック
      if (data.game_over) {
        this.handleGameOver(data)
        return
      }

      // コンピューターの応答を表示
      if (data.computer_word) {
        this.addWordToHistory(data.computer_word, "computer")
        this.currentWordTarget.textContent = data.computer_word
        this.gameState.lastWord = data.computer_word
        this.gameState.usedWords.push(data.computer_word.toLowerCase())
      }

      // ターン表示を更新
      this.turnIndicatorTarget.textContent = "あなた"
      this.gameState.playerTurn = true

      // タイマーをリセットして再開
      this.resetTimer()
      this.startTimer()

      // 入力フォームにフォーカス
      this.wordInputTarget.focus()
    })
    .catch(error => {
      console.error("単語送信エラー:", error)
      this.showError(error.message)
      this.wordInputTarget.focus()

      // タイマーを再開
      this.resetTimer()
      this.startTimer()
    })
  }

  // タイムアウト時の処理
  handleTimeout() {
    fetch("/api/games/timeout", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.game_over) {
        this.handleGameOver(data)
      }
    })
    .catch(error => {
      console.error("タイムアウト処理エラー:", error)
    })
  }

  // ゲームオーバー時の処理
  handleGameOver(data) {
    this.gameState.inProgress = false
    this.stopTimer()

    // ゲームオーバー画面を表示
    this.gameAreaTarget.classList.add("hidden")
    this.gameOverTarget.classList.remove("hidden")

    // 結果を表示
    this.resultMessageTarget.textContent = data.message || "ゲーム終了！"
    this.finalScoreTarget.textContent = data.game.score || 0
  }

  // タイマーを開始
  startTimer() {
    if (this.gameState.timerInterval) {
      clearInterval(this.gameState.timerInterval)
    }

    this.gameState.timeLeft = this.timerDurationValue
    this.timerTarget.textContent = this.gameState.timeLeft

    this.gameState.timerInterval = setInterval(() => {
      this.gameState.timeLeft -= 1
      this.timerTarget.textContent = this.gameState.timeLeft

      // タイマーが0になったらタイムアウト
      if (this.gameState.timeLeft <= 0) {
        clearInterval(this.gameState.timerInterval)
        this.gameState.timerInterval = null

        if (this.gameState.playerTurn) {
          this.handleTimeout()
        }
      }

      // 残り時間が少なくなったら視覚的フィードバックを提供
      if (this.gameState.timeLeft <= 3) {
        this.timerTarget.classList.add("time-critical")
      } else {
        this.timerTarget.classList.remove("time-critical")
      }
    }, 1000)
  }

  // タイマーを停止
  stopTimer() {
    if (this.gameState.timerInterval) {
      clearInterval(this.gameState.timerInterval)
      this.gameState.timerInterval = null
    }
  }

  // タイマーをリセット
  resetTimer() {
    this.gameState.timeLeft = this.timerDurationValue
    this.timerTarget.textContent = this.gameState.timeLeft
    this.timerTarget.classList.remove("time-critical")
  }

  // ゲームをリセット
  resetGame() {
    this.gameOverTarget.classList.add("hidden")
    this.startScreenTarget.classList.remove("hidden")
    document.getElementById("player-name").focus()
  }

  // 単語履歴に追加
  addWordToHistory(word, player) {
    const li = document.createElement("li")
    li.className = player === "player" ? "player-word" : "computer-word"

    // 単語と番号を表示
    const turnNumber = this.gameState.usedWords.length + 1
    const turnNumberSpan = document.createElement("span");
    turnNumberSpan.textContent = `${turnNumber}. ${word}`;
    const playerSpan = document.createElement("span");
    playerSpan.textContent = player === "player" ? "あなた" : "コンピューター";
    li.appendChild(turnNumberSpan);
    li.appendChild(playerSpan);
    this.wordListTarget.appendChild(li)

    // 最新の単語が見えるようにスクロール
    this.wordListTarget.scrollTop = this.wordListTarget.scrollHeight
  }

  // エラーメッセージを表示
  showError(message) {
    this.errorMessageTarget.textContent = message
  }

  // CSRFトークンを取得
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').getAttribute("content")
  }
}