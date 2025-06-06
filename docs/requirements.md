# 要件

## 概要

- Rubyしりとりゲーム「ShiritoRuby」の要件を記述
  - 例： ruby -> yield -> do -> open -> net/http ...


## ゲームのルール

### ゲームの基本ルール

- プレイヤー VS コンピューターのターン制
- 単語の最後の文字で初まる単語を回答する (英単語のみ使用可)
  - 末尾が記号(?, !, _, etc)で終わる単語の場合、次の単語の先頭文字は末尾から遡った最初のアルファベットを先頭文字とする
- 同じ単語は再利用不可

### 勝敗、終了条件

- ゲーム終了条件:
  - コンピューターが投了した場合
  - ユーザーが制限時間内に回答できなかった場合
- 勝敗:
  - ターン数が多い方が負け
  - どちらかが投了した場合、投了した方が負け

### 制約

- 使用可能な単語は以下
    - Rubyの組み込みメソッド（例: puts, gets, chomp）
    - クラス名/モジュール名（例: Array, Enumerable, Net::HTTP）
    - 主要なGemの名前（例: rails, sinatra, devise）
    - 一般的なRuby関連用語（例: rubygems, mri, rbenv）
    - コード内の予約語（例: def, if, do, end）
- 大文字、小文字は区別しない(例: Array と array は同じ単語として扱う)
- 2文字以上の単語のみ使用可能
- 1ターンの制限時間は **10秒**
- 先攻は **プレイヤー**

### ランキング

- ランキング: スコアの高い順
