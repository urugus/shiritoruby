# CI/CDパイプライン設定

このドキュメントでは、ShiritoRubyアプリケーションのCI/CDパイプラインの設定方法について説明します。

## 概要

ShiritoRubyアプリケーションでは、以下のCI/CDパイプラインを使用しています：

1. **CI（継続的インテグレーション）**: プルリクエストとmainブランチへのプッシュ時に実行され、コードの品質とセキュリティを確保します。
2. **CD（継続的デリバリー）**: mainブランチへのマージ時に実行され、アプリケーションを自動的にAWS Fargateにデプロイします。

## CIパイプライン

CIパイプラインは、`.github/workflows/ci.yml`で定義されており、以下のジョブを実行します：

- **scan_ruby**: Brakemanを使用してRailsのセキュリティ脆弱性をスキャン
- **scan_js**: JavaScriptの依存関係のセキュリティ脆弱性をスキャン
- **lint**: Rubocopを使用してコードスタイルをチェック
- **test**: RSpecを使用してテストを実行

## CDパイプライン

CDパイプラインは、`.github/workflows/deploy.yml`で定義されており、以下のステップを実行します：

1. コードのチェックアウト
2. AWS認証情報の設定
3. Amazon ECRへのログイン
4. Docker Buildxのセットアップ
5. Dockerイメージのビルド、タグ付け、ECRへのプッシュ
6. 現在のECSタスク定義のダウンロード
7. 新しいイメージIDでタスク定義を更新
8. 更新されたタスク定義をECSにデプロイ
9. データベースマイグレーションの実行

## 必要な設定

### OIDC認証（推奨）

GitHub ActionsとAWSの連携には、OpenID Connect（OIDC）を使用した認証方法を推奨します。この方法では、長期的なIAMユーザー認証情報をGitHubに保存する必要がなく、一時的な認証情報を自動的に取得するため、セキュリティが向上します。

#### 必要なAWS設定

Terraformを使用して、以下のリソースを作成します：

1. GitHub OIDC Provider
2. GitHub Actions用のIAMロール（必要な権限を付与）

これらの設定は`terraform/main.tf`に含まれています。

#### GitHub Secrets

OIDCを使用する場合、以下のGitHub Secretsを設定する必要があります：

1. `AWS_ACCOUNT_ID`: AWSアカウントID
2. `AWS_REGION`: AWSリージョン（ap-northeast-1）

### IAMユーザー認証（従来の方法）

従来の方法として、IAMユーザーの長期的な認証情報を使用することもできます。

#### GitHub Secrets

CDパイプラインを実行するためには、以下のGitHub Secretsを設定する必要があります：

1. `AWS_ACCESS_KEY_ID`: AWS認証情報のアクセスキーID
2. `AWS_SECRET_ACCESS_KEY`: AWS認証情報のシークレットアクセスキー
3. `AWS_REGION`: AWSリージョン（ap-northeast-1）

### AWS IAMユーザーの作成

デプロイ用のIAMユーザーを作成し、以下の権限を付与する必要があります：

1. `AmazonECR-FullAccess`: ECRリポジトリへのアクセス権
2. `AmazonECS-FullAccess`: ECSクラスター、サービス、タスク定義へのアクセス権

以下のポリシーを持つIAMユーザーを作成することをお勧めします：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:RunTask"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
```

### GitHub Secretsの設定方法

1. GitHubリポジトリのページ（https://github.com/urugus/shiritoruby）にアクセスします。

2. 上部のタブから「Settings」（設定）をクリックします。
   - リポジトリのメインページで、「Code」「Issues」「Pull requests」などのタブの右側にあります。

3. 左側のサイドバーメニューから「Secrets and variables」をクリックします。
   - これは通常、サイドバーの下の方にあります。

4. 「Secrets and variables」のサブメニューから「Actions」を選択します。
   - これでGitHub Actionsで使用するシークレットの管理画面が表示されます。

5. 「New repository secret」（新しいリポジトリシークレット）ボタンをクリックします。
   - このボタンは通常、画面の右上または中央上部にあります。

6. 以下の3つのシークレットをそれぞれ追加します：

   a. 1つ目のシークレット：
   - 「Name」欄に: `AWS_ACCESS_KEY_ID`
   - 「Value」欄に: AWSのIAMユーザーのアクセスキーID
   - 「Add secret」ボタンをクリック

   b. 2つ目のシークレット：
   - 再度「New repository secret」ボタンをクリック
   - 「Name」欄に: `AWS_SECRET_ACCESS_KEY`
   - 「Value」欄に: AWSのIAMユーザーのシークレットアクセスキー
   - 「Add secret」ボタンをクリック

   c. 3つ目のシークレット：
   - 再度「New repository secret」ボタンをクリック
   - 「Name」欄に: `AWS_REGION`
   - 「Value」欄に: `ap-northeast-1`
   - 「Add secret」ボタンをクリック

7. すべてのシークレットが追加されると、「Actions secrets」のリストに3つのシークレットが表示されます。

これらのシークレットは暗号化されて保存され、GitHub Actionsのワークフロー内でのみ参照できます。値自体はGitHubの管理画面でも表示されないため、セキュリティが確保されています。

### OIDC認証への移行手順

既存のIAMユーザー認証からOIDC認証に移行するには、以下の手順を実行します：

1. Terraformを適用して、OIDCプロバイダーとIAMロールを作成します：
   ```bash
   cd terraform
   AWS_PROFILE=shiritoruby terraform apply
   ```

2. GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下のシークレットを設定します：
   - `AWS_ACCOUNT_ID`: AWSアカウントID
   - `AWS_REGION`: ap-northeast-1（既存のシークレットを確認）

3. 既存のIAMユーザー認証情報のシークレットは、OIDC認証が正常に機能することを確認した後に削除できます：
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## デプロイフロー

1. 開発者がfeatureブランチで機能を開発します。
2. プルリクエストを作成すると、CIパイプラインが実行されます。
3. レビューが完了し、プルリクエストがmainブランチにマージされると、CDパイプラインが実行されます。
4. CDパイプラインが正常に完了すると、アプリケーションが自動的にAWS Fargateにデプロイされます。

## 手動デプロイ

何らかの理由で手動デプロイが必要な場合は、`terraform/DEPLOYMENT.md`に記載されている手順に従ってください。

## トラブルシューティング

### デプロイが失敗する場合

1. GitHub Actionsのログを確認して、エラーメッセージを特定します。
2. AWS認証情報が正しく設定されていることを確認します。
3. 認証方法に応じて確認します：
   - IAMユーザー認証の場合：IAMユーザーに必要な権限が付与されていることを確認します。
   - OIDC認証の場合：IAMロールに必要な権限が付与されていることを確認します。
4. ECRリポジトリ、ECSクラスター、サービス名が正しいことを確認します。

### ECSタスク定義のデプロイエラー

ECSタスク定義をデプロイする際に以下のようなエラーが発生する場合があります：

1. 不要なプロパティによるエラー：

```
Error: Failed to register task definition in ECS: There were 2 validation errors:
* UnexpectedParameter: Unexpected key 'registeredAt' found in params
* UnexpectedParameter: Unexpected key 'registeredBy' found in params
```

これは、`aws ecs describe-task-definition`コマンドで取得したタスク定義に、新しいタスク定義を登録する際には不要（または許可されていない）プロパティが含まれているためです。以下のプロパティが問題になることがあります：

- compatibilities
- taskDefinitionArn
- requiresAttributes
- revision
- status
- registeredAt
- registeredBy

解決策：

1. タスク定義をダウンロードした後、不要なプロパティを削除するステップをワークフローに追加します：

```yaml
- name: Clean task definition
  run: |
    # 不要なプロパティを削除
    jq 'del(.taskDefinitionArn, .status, .revision, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' task-definition.json > cleaned-task-definition.json
    mv cleaned-task-definition.json task-definition.json
```

2. この修正を`.github/workflows/deploy.yml`ファイルの「Download task definition」ステップの後に追加します。

2. デプロイコントローラーのエラー：

```
Error: Unsupported deployment controller: ECS
```

これは、GitHub Actionsで使用しているアクションのバージョンが古い場合に発生することがあります。以下のアクションを最新バージョンに更新することで解決できます：

1. `aws-actions/amazon-ecs-render-task-definition`
2. `aws-actions/amazon-ecs-deploy-task-definition`

例：
```yaml
- name: Fill in the new image ID in the Amazon ECS task definition
  id: task-def
  uses: aws-actions/amazon-ecs-render-task-definition@v1.7.1
  with:
    task-definition: task-definition.json
    container-name: shiritoruby
    image: ${{ steps.build-image.outputs.image }}

- name: Deploy Amazon ECS task definition
  uses: aws-actions/amazon-ecs-deploy-task-definition@v2.3.1
  with:
    task-definition: ${{ steps.task-def.outputs.task-definition }}
    service: shiritoruby-service
    cluster: shiritoruby-cluster
    wait-for-service-stability: true
```

### アプリケーションが正常に動作しない場合

1. ECSサービスのログを確認します：
   ```bash
   aws ecs describe-services --cluster shiritoruby-cluster --services shiritoruby-service
   ```

2. CloudWatchログを確認します：
   ```bash
   aws logs get-log-events --log-group-name /ecs/shiritoruby --log-stream-name <ログストリーム名>
   ```

3. データベースマイグレーションが正常に実行されたことを確認します。