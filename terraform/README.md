# ShiritoRuby AWS Fargate デプロイ

このディレクトリには、ShiritoRubyアプリケーションをAWS Fargateにデプロイするためのterraformコードが含まれています。

## 前提条件

- [Terraform](https://www.terraform.io/downloads.html) v1.0.0以上がインストールされていること
- [AWS CLI](https://aws.amazon.com/cli/) がインストールされ、設定されていること
- [Docker](https://www.docker.com/get-started) がインストールされていること

## セットアップ手順

### 1. 変数の設定

`terraform.tfvars.example` ファイルをコピーして `terraform.tfvars` を作成し、必要な値を設定します。

```bash
cp terraform.tfvars.example terraform.tfvars
```

以下の変数を必ず設定してください：
- `db_username` - データベースのユーザー名
- `db_password` - データベースのパスワード
- `rails_master_key` - Railsアプリケーションのマスターキー（`config/master.key`の内容）

### 2. Terraformの初期化

```bash
terraform init
```

### 3. 実行計画の確認

```bash
terraform plan
```

### 4. インフラストラクチャのデプロイ

```bash
terraform apply
```

確認メッセージが表示されたら、`yes`と入力してデプロイを実行します。

### 5. Dockerイメージのビルドとプッシュ

Terraformの実行が完了すると、ECRリポジトリURLとDockerイメージをビルド・プッシュするためのコマンドが出力されます。これらのコマンドを実行してDockerイメージをECRにプッシュします。

```bash
# 出力されたecr_push_commandsの内容を実行
```

### 6. データベースマイグレーションの実行

アプリケーションがデプロイされた後、データベースマイグレーションを実行します。

```bash
# 出力されたdb_migration_commandの内容を実行
```

### 7. アプリケーションへのアクセス

デプロイが完了すると、ALBのDNS名が出力されます。このDNS名を使用してアプリケーションにアクセスできます。

```
http://<alb_dns_name>
```

## リソースの削除

不要になったリソースを削除するには、以下のコマンドを実行します。

```bash
terraform destroy
```

確認メッセージが表示されたら、`yes`と入力して削除を実行します。

## 注意事項

- このTerraformコードは、新しいVPCとサブネットを作成します。既存のVPCを使用する場合は、`main.tf`ファイルのVPC関連のリソースをコメントアウトし、変数を適切に設定してください。
- 本番環境では、ALBにHTTPSを設定することをお勧めします。
- データベースのバックアップ設定を適切に行ってください。
- セキュリティのため、IAMポリシーとセキュリティグループの設定を環境に合わせて調整してください。
- RDSのマスターユーザーパスワード（`db_password`）には、`'/'`, `'@'`, `'"'`, スペースを除く印刷可能なASCII文字のみを使用できます。これらの文字を含むパスワードを設定するとデプロイが失敗します。