# 技術的設計 


## データベース設計

### **テーブル一覧**

#### **words (単語リスト)**
| カラム名     | 型          | 制約                  | 説明                       |
|-------------|------------|----------------------|--------------------------|
| id          | UUID       | PRIMARY KEY         | 一意の識別子              |
| word        | STRING     | UNIQUE, NOT NULL   | 単語（小文字で統一）      |
| category    | STRING     | NOT NULL           | 単語の種類（メソッド, クラス, etc.）|
| created_at  | TIMESTAMP  | DEFAULT now()      | 作成日時                  |
| updated_at  | TIMESTAMP  | DEFAULT now()      | 更新日時                  |


#### **games (ゲーム履歴)**
| カラム名     | 型          | 制約                  | 説明                       |
|-------------|------------|----------------------|--------------------------|
| id          | UUID       | PRIMARY KEY         | 一意の識別子              |
| player_name | STRING     | NOT NULL           | プレイヤー名               |
| score       | INTEGER    | NOT NULL           | 繋げた単語の数            |
| created_at  | TIMESTAMP  | DEFAULT now()      | 作成日時                  |


#### **game_words (ゲーム内単語使用履歴)**
| カラム名     | 型          | 制約                  | 説明                       |
|-------------|------------|----------------------|--------------------------|
| id          | UUID       | PRIMARY KEY         | 一意の識別子              |
| game_id     | UUID       | FOREIGN KEY         | 関連するゲーム ID         |
| word_id     | UUID       | FOREIGN KEY         | 使用された単語 ID         |
| turn        | INTEGER    | NOT NULL           | 何ターン目の単語か        |
| created_at  | TIMESTAMP  | DEFAULT now()      | 作成日時                  |


### ER図

```mermaid
erDiagram
    words {
        UUID id PK
        STRING word 
        STRING category NOT NULL
        TIMESTAMP created_at DEFAULT now()
        TIMESTAMP updated_at DEFAULT now()
    }
    
    games {
        UUID id PK
        STRING player_name NOT NULL
        INTEGER score NOT NULL
        TIMESTAMP created_at DEFAULT now()
    }
    
    game_words {
        UUID id PK
        UUID game_id FK
        UUID word_id FK
        INTEGER turn NOT NULL
        TIMESTAMP created_at DEFAULT now()
    }
    
    words ||--o{ game_words : contains
    games ||--o{ game_words : has
```

## ゲームロジック

### ゲームの流れ

- ユーザーが先攻
- 交互に入力する
```mermaid
stateDiagram-v2

    state CPU: コンピューターのターン {
        state is_found <<choice>>
        searchDB: DBから使用済み単語を除外して検索
        answer_by_random: 検索結果からランダムに回答

        [*] --> searchDB: 最後の文字(アルファベット)を元に検索
        searchDB --> is_found
        is_found --> answer_by_random: 検索結果がある
        answer_by_random --> [*]: 回答(ターン終了)
    }
    state USER: ユーザーのターン {
        state if_state <<choice>> 
        state judge <<choice>> 
        start: ユーザーが入力する
        validate_alphabet: 先頭文字が正しいか検証
        validate_reuse: 使用済み単語か検証
        use_api: OpenAI API で検証
        save: DBに保存
        search: DBから検索

        [*] --> start
        start --> validate_alphabet
        validate_alphabet --> validate_reuse
        validate_alphabet --> start: 先頭文字が正しくない場合<br/>再入力を要求
        validate_reuse --> start: 使用済み単語の場合<br />再入力を要求
        validate_reuse --> search
        search --> if_state
        if_state --> [*]: 検索結果がある(ターン終了)
        if_state --> use_api: DBに検索結果がない
        use_api --> judge
        judge --> start: 検証結果が正しくない場合<br />再入力を要求
        judge --> save: 検証結果が正しい場合<br />DBに保存
        save --> [*]: 保存完了(ターン終了)
    }

    game_over: ゲームオーバー
    if_state --> game_over: 制限時間切れ
    is_found --> game_over: 検索結果がない

```

