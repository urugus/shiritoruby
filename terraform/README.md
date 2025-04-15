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

## アーキテクチャ図

以下は、ShiritoRubyアプリケーションのAWS Fargateデプロイアーキテクチャを示しています：

```mermaid
flowchart TB
    subgraph "AWS Cloud"
        subgraph "VPC"
            subgraph "Public Subnet AZ-a"
                ALB["Application Load Balancer"]
                ECS_a["ECS Fargate Tasks"]
            end

            subgraph "Public Subnet AZ-c"
                ECS_c["ECS Fargate Tasks"]
            end

            subgraph "Private Subnet AZ-a"
                RDS_a["RDS PostgreSQL\nPrimary"]
                SM_a["Secrets Manager\nVPC Endpoint"]
            end

            subgraph "Private Subnet AZ-c"
                RDS_c["RDS PostgreSQL\nStandby"]
            end

            IGW["Internet Gateway"]
        end

        ECR["ECR Repository"]
        CW["CloudWatch Logs"]
        SM["Secrets Manager"]

        subgraph "IAM"
            ECS_Role["ECS Task Execution Role"]
            GitHub_Role["GitHub Actions Role"]
        end

        subgraph "Route 53"
            R53["DNS Zone"]
            ACM["ACM Certificate"]
        end
    end

    GitHub["GitHub Actions"]
    User["User"]

    %% 接続関係
    User -->|HTTPS| R53
    R53 -->|DNS| ALB
    GitHub -->|OIDC| GitHub_Role
    GitHub_Role -->|Push| ECR
    GitHub_Role -->|Deploy| ECS_a

    IGW <-->|Internet| ALB
    ALB -->|Target Group| ECS_a
    ALB -->|Target Group| ECS_c
    ECS_a -->|Logs| CW
    ECS_c -->|Logs| CW
    ECS_a -->|DB Connection| RDS_a
    ECS_c -->|DB Connection| RDS_a
    ECS_a -->|Secrets| SM
    ECS_c -->|Secrets| SM
    ECS_a -->|VPC Endpoint| SM_a
    ECS_c -->|VPC Endpoint| SM_a
    ECS_Role -->|Assume Role| ECS_a
    ECS_Role -->|Assume Role| ECS_c
    ECR -->|Image| ECS_a
    ECR -->|Image| ECS_c
    ACM -->|Certificate| ALB

    %% スタイル
    classDef aws fill:#FF9900,stroke:#232F3E,color:#232F3E
    classDef subnet fill:#F8F8F8,stroke:#999999
    classDef external fill:#FFFFFF,stroke:#232F3E,color:#232F3E

    class ALB,ECS_a,ECS_c,RDS_a,RDS_c,ECR,CW,SM,SM_a,ECS_Role,GitHub_Role,R53,ACM,IGW aws
    class "Public Subnet AZ-a" subnet
    class "Public Subnet AZ-c" subnet
    class "Private Subnet AZ-a" subnet
    class "Private Subnet AZ-c" subnet
    class GitHub,User external
```

この図は以下のコンポーネントを示しています：

1. **ネットワーク構成**：
   - VPC内の2つのアベイラビリティゾーン（AZ-aとAZ-c）
   - 各AZにパブリックサブネットとプライベートサブネット
   - インターネットゲートウェイによる外部接続

2. **コンピューティング**：
   - ECS Fargateタスク（複数のAZに分散）
   - ECRリポジトリ（コンテナイメージの保存）

3. **データベース**：
   - RDS PostgreSQLインスタンス（プライベートサブネット内）

4. **ネットワーキング**：
   - Application Load Balancer（パブリックサブネット内）
   - Route 53 DNSゾーン
   - ACM証明書（HTTPS用）

5. **セキュリティ**：
   - IAMロール（ECSタスク実行用とGitHub Actions用）
   - Secrets Manager（機密情報の管理）
   - VPCエンドポイント（プライベートサブネットからのAWSサービスアクセス）

6. **モニタリング**：
   - CloudWatchログ（アプリケーションログの収集）

7. **CI/CD**：
   - GitHub ActionsからのOIDC認証によるデプロイ