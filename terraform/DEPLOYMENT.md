# AWS Fargateデプロイ手順

このドキュメントでは、ShiritoRubyアプリケーションをAWS Fargateにデプロイするための手順を説明します。

## 前提条件

- Terraform v1.0.0以上がインストールされていること
- AWS CLIがインストールされ、設定されていること
- Docker Desktop（またはDocker Engine）がインストールされていること
- AWS認証情報が設定されていること（プロファイル名：shiritoruby）

## デプロイ手順

### 1. Terraformの初期化

```bash
cd terraform
AWS_PROFILE=shiritoruby terraform init
```

### 2. デプロイ計画の確認

```bash
AWS_PROFILE=shiritoruby terraform plan
```

このコマンドは、作成されるリソースの計画を表示します。

### 3. インフラストラクチャのデプロイ

```bash
AWS_PROFILE=shiritoruby terraform apply
```

確認メッセージが表示されたら、`yes`と入力してデプロイを実行します。

### 4. Dockerイメージのビルドとプッシュ

デプロイが完了すると、ECRリポジトリURLとDockerイメージをビルド・プッシュするためのコマンドが出力されます。

```bash
# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 --profile shiritoruby | docker login --username AWS --password-stdin <ECRリポジトリURL>

# Dockerイメージをビルド
docker build -t shiritoruby .

# イメージにタグを付ける
docker tag shiritoruby:latest <ECRリポジトリURL>:latest

# イメージをECRにプッシュ
docker push <ECRリポジトリURL>:latest
```

### 5. データベースマイグレーションの実行

アプリケーションがデプロイされた後、データベースマイグレーションを実行します。

```bash
AWS_PROFILE=shiritoruby aws ecs run-task \
  --cluster shiritoruby-cluster \
  --task-definition shiritoruby:1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<サブネットID>],securityGroups=[<セキュリティグループID>],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides": [{"name": "shiritoruby", "command": ["./bin/rails", "db:migrate"]}]}'
```

### 6. アプリケーションへのアクセス

デプロイが完了すると、ALBのDNS名が出力されます。このDNS名を使用してアプリケーションにアクセスできます。

```
http://<ALB DNS名>
```

## リソースの削除

不要になったリソースを削除するには、以下のコマンドを実行します。

```bash
AWS_PROFILE=shiritoruby terraform destroy
```

確認メッセージが表示されたら、`yes`と入力して削除を実行します。

## 注意事項

- 本番環境では、ALBにHTTPSを設定することをお勧めします。
- データベースのバックアップ設定を適切に行ってください。
- セキュリティのため、IAMポリシーとセキュリティグループの設定を環境に合わせて調整してください。
- コスト管理のため、使用していないリソースは削除してください。

## トラブルシューティング

### Terraformプラグインのタイムアウトエラー

Terraformプラグインの起動中にタイムアウトエラーが発生した場合は、以下の方法を試してください：

1. Terraformのキャッシュをクリアする
   ```bash
   rm -rf .terraform*
   ```

2. Terraformを再初期化する
   ```bash
   terraform init
   ```

3. AWS認証情報が正しく設定されていることを確認する
   ```bash
   aws sts get-caller-identity --profile shiritoruby
   ```

4. 別のマシンでTerraformを実行する