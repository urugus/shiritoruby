# GitHub Actions OIDC認証のトラブルシューティング

このドキュメントでは、GitHub ActionsのOIDC認証に関する問題を解決するための手順を説明します。

## よくある問題と解決策

### 1. `Not authorized to perform sts:AssumeRoleWithWebIdentity`エラー

このエラーは、GitHub ActionsがOIDCトークンを使用してAWSのIAMロールを引き受ける権限がないことを示しています。

#### 確認事項

1. **IAMロールの信頼ポリシー**:
   - リポジトリ名が正確に一致しているか
   - ブランチ名やプルリクエストの条件が正しいか
   - `audience`の値が正しいか

2. **OIDCプロバイダーの設定**:
   - URLが`https://token.actions.githubusercontent.com`であるか
   - クライアントIDリストに`sts.amazonaws.com`が含まれているか
   - サムプリントが最新であるか

3. **GitHub Actionsワークフローの設定**:
   - `permissions`セクションに`id-token: write`が含まれているか
   - `aws-actions/configure-aws-credentials`アクションで`audience: sts.amazonaws.com`が設定されているか

#### 解決手順

1. **IAMロールの信頼ポリシーを確認**:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": [
               "repo:urugus/shiritoruby:ref:refs/heads/main",
               "repo:urugus/shiritoruby:pull_request"
             ]
           }
         }
       }
     ]
   }
   ```

2. **OIDCトークンの内容を確認**:

   GitHub Actionsのワークフローログで、デバッグステップの出力を確認します。特に`sub`クレームの値に注目してください。この値がIAMロールの信頼ポリシーの条件と一致している必要があります。

   例えば、`sub`クレームの値が`repo:urugus/shiritoruby:ref:refs/heads/main`の場合、IAMロールの信頼ポリシーの条件も同じ値を含んでいる必要があります。

3. **手動でIAMロールを設定**:

   Terraformでの設定が難しい場合は、AWSコンソールで直接IAMロールを設定することもできます：

   a. AWSマネジメントコンソールにログイン
   b. IAMサービスに移動
   c. 左側のメニューから「Roles」を選択
   d. 「Create role」をクリック
   e. 「Web identity」を選択
   f. Identity provider: `token.actions.githubusercontent.com`
   g. Audience: `sts.amazonaws.com`
   h. GitHub organization: `urugus`
   i. GitHub repository: `shiritoruby`
   j. 必要な権限ポリシーを追加（ECRとECSの権限）
   k. ロール名を「github-actions-role」に設定して作成

### 2. サムプリントの更新

GitHub OIDCプロバイダーのサムプリントは時々更新されることがあります。最新のサムプリントを取得するには：

```bash
openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha1 -noout | cut -d '=' -f 2 | tr -d ':'
```

このコマンドの出力を`thumbprint_list`に設定します。

### 3. デバッグ情報の取得

問題が解決しない場合は、以下のデバッグ情報を取得してください：

1. **OIDCトークンの内容**:
   GitHub Actionsのワークフローに追加したデバッグステップの出力を確認します。

   注意: `ACTIONS_ID_TOKEN_REQUEST_URL`と`ACTIONS_ID_TOKEN_REQUEST_TOKEN`は、GitHub Actionsが自動的に提供する特別な環境変数です。これらはワークフローで`id-token: write`パーミッションを設定している場合にのみ利用可能になります。ユーザーが明示的に設定する必要はありません。

2. **IAMロールの信頼ポリシー**:
   AWSコンソールでIAMロールの信頼ポリシーを確認します。

3. **OIDCプロバイダーの設定**:
   AWSコンソールでOIDCプロバイダーの設定を確認します。

4. **GitHub Actionsのワークフローログ**:
   ワークフローの実行ログを確認し、エラーメッセージの詳細を確認します。

### 4. 一般的な解決策

1. **IAMロールの信頼ポリシーを更新**:
   - リポジトリ名を正確に設定
   - ブランチ名を具体的に指定
   - `audience`の値を確認

2. **GitHub Actionsワークフローを更新**:
   - `permissions`セクションを確認
   - `audience`パラメータを設定

3. **AWSリソースを再作成**:
   - OIDCプロバイダーを削除して再作成
   - IAMロールを削除して再作成

4. **GitHub Secretsを確認**:
   - `AWS_ACCOUNT_ID`が正しく設定されているか確認
   - `AWS_REGION`が正しく設定されているか確認