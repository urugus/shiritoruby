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

### GitHub Secrets

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
3. IAMユーザーに必要な権限が付与されていることを確認します。
4. ECRリポジトリ、ECSクラスター、サービス名が正しいことを確認します。

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