import { Controller } from "@hotwired/stimulus";

// ゲーム画面の機能を管理するコントローラー
export default class extends Controller {
  static targets = [
    "startScreen",
    "gameArea",
    "gameOver",
    "wordInput",
    "wordList",
    "currentWord",
    "turnIndicator",
    "timer",
    "errorMessage",
    "resultMessage",
    "finalScore",
    "countdown",
    "countdownNumber",
  ];

  static values = {
    timerDuration: { type: Number, default: 10 },
  };

  // APIエンドポイントのベースURL
  get apiBaseUrl() {
    return "/api/games";
  }

  // セッションIDを保存する
  sessionId = null;

  connect() {
    this.resetGameState();
    // イベントリスナーを設定
    this.setupEventListeners();
  }

  resetGameState() {
    this.gameState = {
      inProgress: false,
      playerTurn: true, // プレイヤーから開始するのでtrueに設定
      lastWord: "",
      usedWords: [],
      timerInterval: null,
      timeLeft: this.timerDurationValue,
    };
  }

  setupEventListeners() {
    // プレイヤー名入力フォームの送信
    document.getElementById("player-form").addEventListener("submit", (e) => {
      e.preventDefault();
      this.startGame();
    });

    // 単語入力フォームの送信
    document.getElementById("word-form").addEventListener("submit", (e) => {
      e.preventDefault();
      this.submitWord();
    });

    // リプレイボタン
    document.getElementById("replay-button").addEventListener("click", () => {
      this.resetGame();
    });
  }

  // ゲームを開始する
  startGame() {
    const playerName = document.getElementById("player-name").value || "ゲスト";

    fetch(this.apiBaseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken(),
      },
      body: JSON.stringify({ player_name: playerName }),
    })
      .then((response) => {
        if (!response.ok) {
          // レスポンスのContent-Typeをチェック
          const contentType = response.headers.get("content-type");
          if (contentType && contentType.includes("application/json")) {
            return response.json().then((data) => {
              throw new Error(data.error || "ゲームの開始に失敗しました");
            });
          } else {
            // JSONでない場合はテキストとして読み込む
            return response.text().then((text) => {
              console.error("非JSONレスポンス:", text);
              throw new Error(
                "サーバーからの応答が不正です。管理者に連絡してください。"
              );
            });
          }
        }
        return response.json();
      })
      .then((data) => {
        // セッションIDを保存（レスポンスヘッダーから取得）
        if (data.session_id) {
          // セッションIDを確実に文字列として扱う
          this.sessionId = String(data.session_id);

          // オブジェクトかどうかをチェック
          if (typeof data.session_id === "object") {
            console.warn(
              "セッションIDがオブジェクトとして受信されました:",
              data.session_id
            );
            // オブジェクトの場合は、JSONに変換して文字列化
            if (data.session_id !== null) {
              try {
                this.sessionId = JSON.stringify(data.session_id);
              } catch (e) {
                console.error("セッションIDのJSON変換に失敗:", e);
              }
            }
          }

          console.log(
            "セッションID保存:",
            this.sessionId,
            typeof this.sessionId
          );
        } else {
          console.warn("セッションIDがレスポンスに含まれていません");
        }
        return data;
      })
      .then((data) => {
        // ゲーム状態をリセット
        this.resetGameState();

        // UIを更新
        this.startScreenTarget.classList.add("hidden");
        this.countdownTarget.classList.remove("hidden");
        this.gameOverTarget.classList.add("hidden");
        this.wordListTarget.innerHTML = "";
        this.currentWordTarget.textContent =
          "ゲーム開始！最初の単語を入力してください";
        this.turnIndicatorTarget.textContent = "あなた";
        this.wordInputTarget.value = "";
        this.errorMessageTarget.textContent = "";

        // カウントダウンを開始
        this.startCountdown();
      })
      .catch((error) => {
        console.error("ゲーム開始エラー:", error);
        // より詳細なエラーメッセージを表示
        this.showError(
          error.message ||
            "ゲームを開始できませんでした。もう一度お試しください。"
        );
        // エラー発生時にスタート画面を表示したままにする
        this.startScreenTarget.classList.remove("hidden");
        this.countdownTarget.classList.add("hidden");
      });
  }

  // 単語をサーバーに送信する
  submitWord() {
    const word = this.wordInputTarget.value.trim();

    if (!word) {
      this.showError("単語を入力してください");
      return;
    }

    // タイマーを停止
    this.stopTimer();

    if (!this.gameState.playerTurn) {
      this.showError("現在はプレイヤーのターンではありません");
      return;
    }

    // APIエンドポイントを設定
    const url = `${this.apiBaseUrl}/submit_word`;

    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken(),
        // セッションIDをヘッダーに含める
        ...(this.sessionId ? { "X-Session-ID": this.sessionId } : {}),
      },
      body: JSON.stringify({ word }),
    })
      .then((response) => {
        if (!response.ok) {
          // レスポンスのContent-Typeをチェック
          const contentType = response.headers.get("content-type");
          if (contentType && contentType.includes("application/json")) {
            return response.json().then((data) => {
              throw new Error(data.error || "単語の送信に失敗しました");
            });
          } else {
            // JSONでない場合はテキストとして読み込む
            return response.text().then((text) => {
              console.error("非JSONレスポンス:", text);
              throw new Error(
                "サーバーからの応答が不正です。管理者に連絡してください。"
              );
            });
          }
        }
        return response.json();
      })
      .then((data) => {
        // 入力をクリア
        this.wordInputTarget.value = "";
        this.errorMessageTarget.textContent = "";

        // プレイヤーの単語を表示
        this.addWordToHistory(word, "player");
        this.gameState.lastWord = word;
        this.gameState.usedWords.push(word.toLowerCase());

        // ゲームオーバーかどうかをチェック
        if (data.game_over) {
          this.handleGameOver(data);
          return;
        }

        // コンピューターの応答を処理
        if (data.computer_response) {
          if (data.computer_response.surrender) {
            // コンピューターが投了した場合
            this.handleGameOver({
              game_over: true,
              message:
                data.computer_response.message ||
                "コンピューターが投了しました。あなたの勝ちです！",
              game: data.game,
            });
            return;
          } else if (data.computer_response.valid) {
            // コンピューターが有効な応答をした場合
            const computerWord = data.computer_response.word;
            this.addWordToHistory(computerWord, "computer");
            this.currentWordTarget.textContent = computerWord;
            this.gameState.lastWord = computerWord;
            this.gameState.usedWords.push(computerWord.toLowerCase());

            // コンピューターのメッセージを表示（存在する場合）
            if (data.computer_response.message) {
              this.showMessage(data.computer_response.message);
            }

            // ターン表示を更新
            this.turnIndicatorTarget.textContent = "あなた";
            this.gameState.playerTurn = true;
          }
        } else {
          // エラーまたは想定外の応答
          this.showError("コンピューターからの応答がありませんでした");
          this.turnIndicatorTarget.textContent = "あなた";
          this.gameState.playerTurn = true;
        }

        // タイマーをリセットして再開
        this.resetTimer();
        this.startTimer();

        // 入力フォームにフォーカス
        this.wordInputTarget.focus();
      })
      .catch((error) => {
        console.error("単語送信エラー:", error);
        this.showError(error.message);
        this.wordInputTarget.value = ""; // エラー発生時に入力をクリア
        this.wordInputTarget.focus();

        // 単語がDBにない場合は、単語履歴やゲーム状態を更新しない
        // タイマーを継続（リセットせず再開）
        this.startTimer();
      });
  }

  // タイムアウト時の処理
  handleTimeout() {
    // APIエンドポイントを設定
    const url = `${this.apiBaseUrl}/timeout`;

    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken(),
        // セッションIDをヘッダーに含める
        ...(this.sessionId ? { "X-Session-ID": this.sessionId } : {}),
      },
    })
      .then((response) => {
        // レスポンスのContent-Typeをチェック
        const contentType = response.headers.get("content-type");
        if (contentType && contentType.includes("application/json")) {
          return response.json();
        } else {
          // JSONでない場合はテキストとして読み込む
          return response.text().then((text) => {
            console.error("非JSONレスポンス:", text);
            throw new Error(
              "サーバーからの応答が不正です。管理者に連絡してください。"
            );
          });
        }
      })
      .then((data) => {
        if (data.game_over) {
          this.handleGameOver(data);
        }
      })
      .catch((error) => {
        console.error("タイムアウト処理エラー:", error);
        this.showError(
          "タイムアウト処理中にエラーが発生しました。ゲームをリセットします。"
        );
        // エラー発生時にゲームをリセット
        setTimeout(() => {
          this.resetGame();
        }, 3000);
      });
  }

  // ゲームオーバー時の処理
  handleGameOver(data) {
    this.gameState.inProgress = false;
    this.stopTimer();

    // ゲームオーバー画面を表示
    this.gameAreaTarget.classList.add("hidden");
    this.gameOverTarget.classList.remove("hidden");

    // 結果を表示
    this.resultMessageTarget.textContent = data.message || "ゲーム終了！";

    // スコア情報
    const score = data.game.score || 0;
    this.finalScoreTarget.textContent = score;

    // ゲーム時間とタイムボーナスが含まれている場合は表示
    if (data.game.duration_seconds) {
      const duration = data.game.duration_seconds;
      const durationText = `プレイ時間: ${this.formatDuration(duration)}`;

      // スコア詳細を表示する要素を作成
      const scoreDetails = document.createElement("div");
      scoreDetails.className = "score-details";
      scoreDetails.innerHTML = `
        <div class="duration-info">${durationText}</div>
        ${
          data.time_bonus
            ? `<div class="bonus-info">タイムボーナス: ×${data.time_bonus}</div>`
            : ""
        }
      `;

      // すでに詳細が表示されている場合は置き換え、なければ追加
      const existingDetails =
        this.gameOverTarget.querySelector(".score-details");
      if (existingDetails) {
        existingDetails.replaceWith(scoreDetails);
      } else {
        this.gameOverTarget.querySelector(".score-display").after(scoreDetails);
      }
    }
  }

  // 秒数を「○分○秒」の形式にフォーマット
  formatDuration(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return `${minutes}分${remainingSeconds}秒`;
    } else {
      return `${remainingSeconds}秒`;
    }
  }

  // タイマーを開始
  startTimer() {
    // ゲームが進行中でない場合は開始しない
    if (!this.gameState.inProgress) {
      return;
    }

    // 既存のタイマーをクリア
    this.stopTimer();

    // タイマーの表示を更新
    this.timerTarget.textContent = this.gameState.timeLeft;
    this.timerTarget.classList.remove("time-critical");

    // 新しいタイマーを開始
    this.gameState.timerInterval = setInterval(() => {
      // ゲームが進行中でない場合はタイマーを停止
      if (!this.gameState.inProgress) {
        this.stopTimer();
        return;
      }

      this.gameState.timeLeft -= 1;
      this.timerTarget.textContent = this.gameState.timeLeft;

      // タイマーが0になったらタイムアウト
      if (this.gameState.timeLeft <= 0) {
        this.stopTimer();
        if (this.gameState.playerTurn) {
          this.handleTimeout();
        }
      }

      // 残り時間が少なくなったら視覚的フィードバックを提供
      if (this.gameState.timeLeft <= 3) {
        this.timerTarget.classList.add("time-critical");
      } else {
        this.timerTarget.classList.remove("time-critical");
      }
    }, 1000);
  }

  // タイマーを停止
  stopTimer() {
    if (this.gameState.timerInterval) {
      clearInterval(this.gameState.timerInterval);
      this.gameState.timerInterval = null;
    }
  }

  // タイマーをリセット
  resetTimer() {
    this.gameState.timeLeft = this.timerDurationValue;
    this.timerTarget.textContent = this.gameState.timeLeft;
    this.timerTarget.classList.remove("time-critical");
  }

  // ゲームをリセット
  resetGame() {
    this.gameOverTarget.classList.add("hidden");
    this.startScreenTarget.classList.remove("hidden");
    this.resetGameState();
    document.getElementById("player-name").focus();
  }

  // 単語履歴に追加
  addWordToHistory(word, player) {
    const li = document.createElement("li");
    li.className = player === "player" ? "player-word" : "computer-word";

    // 単語と番号を表示
    const turnNumber = this.gameState.usedWords.length + 1;
    const turnNumberSpan = document.createElement("span");
    turnNumberSpan.textContent = `${turnNumber}. ${word}`;
    const playerSpan = document.createElement("span");
    playerSpan.textContent = player === "player" ? "あなた" : "コンピューター";
    li.appendChild(turnNumberSpan);
    li.appendChild(playerSpan);
    this.wordListTarget.appendChild(li);

    // 最新の単語が見えるようにスクロール
    this.wordListTarget.scrollTop = this.wordListTarget.scrollHeight;
  }
  // エラーメッセージを表示
  showError(message) {
    this.errorMessageTarget.textContent = message;
    this.errorMessageTarget.classList.add("error");

    // エラーの場合は、現在の単語を更新せず、明確にエラー表示する
    this.currentWordTarget.innerHTML = `<span class="error-highlight">${
      this.gameState.lastWord || "ゲーム開始"
    }</span>`;

    // 5秒後にエラーメッセージを消去（時間を延長）
    setTimeout(() => {
      this.errorMessageTarget.textContent = "";
      this.errorMessageTarget.classList.remove("error");
    }, 5000);
  }

  // 情報メッセージを表示
  showMessage(message) {
    this.errorMessageTarget.textContent = message;
    this.errorMessageTarget.classList.add("info");

    // 3秒後にメッセージを消去
    setTimeout(() => {
      this.errorMessageTarget.textContent = "";
      this.errorMessageTarget.classList.remove("info");
    }, 3000);
  }

  // カウントダウンを開始
  startCountdown() {
    let count = 3;
    this.countdownNumberTarget.textContent = count;

    const countdownInterval = setInterval(() => {
      count--;
      this.countdownNumberTarget.textContent = count;

      if (count <= 0) {
        clearInterval(countdownInterval);
        this.countdownTarget.classList.add("hidden");
        this.gameAreaTarget.classList.remove("hidden");
        this.wordInputTarget.focus();

        // ゲーム状態を更新
        this.gameState.inProgress = true;
        this.gameState.playerTurn = true;
        this.gameState.timeLeft = this.timerDurationValue;

        // タイマーを開始
        this.startTimer();
      }
    }, 1000);
  }

  // CSRFトークンを取得
  getCSRFToken() {
    return document
      .querySelector('meta[name="csrf-token"]')
      .getAttribute("content");
  }
}
