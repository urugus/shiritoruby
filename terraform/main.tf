# このファイルは以下のファイルに分割されました：
# - providers.tf: Terraformプロバイダー設定
# - vpc.tf: VPC関連リソース
# - security_groups.tf: セキュリティグループ
# - rds.tf: RDSデータベース
# - secrets.tf: AWS Secrets Manager
# - iam.tf: IAMロール
# - ecs.tf: ECSクラスター、タスク定義、サービス
# - alb.tf: ALBとターゲットグループ
# - github.tf: GitHub OIDC Provider

# 各ファイルには、関連するリソースが論理的にグループ化されています。
# 変数は variables.tf に、出力は outputs.tf に定義されています。
