# GitHub Actions OIDC認証の設定手順

このドキュメントでは、GitHub ActionsからAWSリソースにアクセスするためのOIDC（OpenID Connect）認証の設定手順を説明します。

## OIDCのメリット

従来のIAMユーザー認証情報（アクセスキーとシークレットキー）を使用する代わりに、OIDCを使用することで以下のメリットがあります：

1. **セキュリティの向上**: 長期的な認証情報をGitHubに保存する必要がなくなります
2. **認証情報の自動ローテーション**: 一時的な認証情報が自動的に生成されます
3. **最小権限の原則**: 特定のワークフローに必要な権限のみを付与できます
4. **管理の簡素化**: IAMユーザーの認証情報を管理する必要がなくなります

## 設定手順

### 1. AWSでOIDCプロバイダーとIAMロールを設定

Terraformを使用して、OIDCプロバイダーとIAMロールを設定します：

```bash
cd terraform
AWS_PROFILE=shiritoruby terraform apply
```

Terraformの実行が完了すると、以下のリソースが作成されます：

- GitHub OIDC Provider
- GitHub Actions用のIAMロール（ECRとECSの権限を持つ）

### 2. GitHub Secretsの設定

GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下のシークレットを設定します：

1. `AWS_ACCOUNT_ID`: AWSアカウントID
   - AWSコンソールの右上のアカウント名をクリックすると表示されます
   - または、AWS CLIで以下のコマンドを実行して取得できます：
     ```bash
     aws sts get-caller-identity --query "Account" --output text
     ```

2. `AWS_REGION`: AWSリージョン（ap-northeast-1）
   - 既存のシークレットがある場合は、そのまま使用できます

### 3. 既存のIAMユーザー認証情報のシークレットを削除（オプション）

OIDC認証が正常に機能することを確認した後、以下の既存のシークレットは削除できます：

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 4. GitHub Actionsワークフローファイルの確認

`.github/workflows/deploy.yml`ファイルが以下のように設定されていることを確認します：

```yaml
permissions:
  id-token: write  # OIDCトークンの取得に必要
  contents: read   # リポジトリのコードを読み取るために必要

steps:
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
      aws-region: ${{ secrets.AWS_REGION }}
```

## 動作確認

設定が完了したら、以下の手順で動作確認を行います：

1. 変更をコミットしてプッシュします
2. GitHub Actionsのワークフローが正常に実行されることを確認します
3. ワークフローのログで、AWS認証が成功していることを確認します

## トラブルシューティング

### OIDC認証が失敗する場合

1. GitHub Actionsのログを確認して、エラーメッセージを特定します
2. AWS IAMコンソールで、OIDCプロバイダーとIAMロールが正しく設定されていることを確認します
3. GitHub Secretsが正しく設定されていることを確認します
4. IAMロールの信頼ポリシーが正しく設定されていることを確認します：
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
             "token.actions.githubusercontent.com:sub": "repo:urugus/shiritoruby:*"
           }
         }
       }
     ]
   }
   ```

### IAMロールの権限が不足している場合

1. AWS IAMコンソールで、IAMロールに必要な権限が付与されていることを確認します
2. 必要に応じて、以下の権限を追加します：
   - ECR関連の権限（`ecr:GetAuthorizationToken`など）
   - ECS関連の権限（`ecs:DescribeTaskDefinition`など）
   - IAM:PassRole権限

## サムプリントの自動更新について

GitHub OIDC Providerのサムプリント（Thumbprint）は、GitHubのTLS証明書のフィンガープリントです。証明書が更新されると、サムプリントも更新する必要があります。

このプロジェクトでは、サムプリントを自動的に取得するように設定されています：

1. **自動取得の仕組み**:
   - Terraformの`external`データソースを使用して、実行時に最新のサムプリントを取得します
   - 取得したサムプリントは、OIDCプロバイダーの設定に自動的に適用されます

2. **メリット**:
   - 手動でのサムプリント更新が不要になります
   - 証明書が更新されても、次回のTerraform適用時に自動的に最新のサムプリントが使用されます
   - OIDC認証の失敗リスクが低減します

3. **実装詳細**:
   ```hcl
   # required_providersブロックにexternalプロバイダーを追加
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 5.0"
       }
       external = {
         source  = "hashicorp/external"
         version = "~> 2.3"
       }
     }
     required_version = ">= 1.0.0"
   }
   ```

   サムプリントを自動取得するための設定:
   ```hcl
   data "external" "github_thumbprint" {
     program = ["bash", "-c", <<-EOT
       THUMBPRINT=$(openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha1 -noout | cut -d '=' -f 2 | tr -d ':' | tr '[:upper:]' '[:lower:]')
       echo "{\"thumbprint\": \"$THUMBPRINT\"}"
     EOT
     ]
   }

   resource "aws_iam_openid_connect_provider" "github" {
     url             = "https://token.actions.githubusercontent.com"
     client_id_list  = ["sts.amazonaws.com"]
     thumbprint_list = [data.external.github_thumbprint.result.thumbprint]
   }
   ```

この自動化により、GitHubのTLS証明書が更新されても、Terraformを適用するだけで最新のサムプリントが使用されるようになります。定期的なメンテナンスの手間が削減され、OIDC認証の信頼性が向上します。