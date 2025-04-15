output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.shiritoruby.repository_url
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = var.use_existing_infrastructure ? "Using existing load balancer" : aws_lb.main[0].dns_name
}

output "database_endpoint" {
  description = "The endpoint of the database"
  value       = var.use_existing_infrastructure ? "Using existing database" : aws_db_instance.main[0].endpoint
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "ecr_push_commands" {
  description = "Commands to build and push Docker image to ECR"
  value       = <<EOF
# ECRにログイン
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.shiritoruby.repository_url}

# 通常のDockerビルド（ローカル開発用）
docker build -t ${var.app_name} .
docker tag ${var.app_name}:latest ${aws_ecr_repository.shiritoruby.repository_url}:latest
docker push ${aws_ecr_repository.shiritoruby.repository_url}:latest

# マルチアーキテクチャイメージのビルドとプッシュ（本番デプロイ用）
# Docker Buildxビルダーを作成
docker buildx create --name mybuilder --use

# マルチアーキテクチャイメージをビルドしてプッシュ
docker buildx build --platform linux/amd64,linux/arm64 -t ${aws_ecr_repository.shiritoruby.repository_url}:latest --push .

# ビルダーを削除（オプション）
# docker buildx rm mybuilder
EOF
}

output "db_migration_command" {
  description = "Command to run database migrations"
  value       = <<EOF
# データベースマイグレーションを実行するためのECSタスクを実行
aws ecs run-task \\
  --cluster ${aws_ecs_cluster.main.name} \\
  --task-definition ${aws_ecs_task_definition.app.family}:${aws_ecs_task_definition.app.revision} \\
  --launch-type FARGATE \\
  --network-configuration "awsvpcConfiguration={subnets=[${var.use_existing_infrastructure ? "subnet-xxxxx" : aws_subnet.private_1[0].id}],securityGroups=[${var.use_existing_infrastructure ? "sg-xxxxx" : aws_security_group.ecs[0].id}],assignPublicIp=ENABLED}" \\
  --overrides '{"containerOverrides": [{"name": "${var.app_name}", "command": ["./bin/rails", "db:migrate"]}]}'
EOF
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_oidc_setup" {
  description = "Instructions for setting up GitHub Actions OIDC authentication"
  value       = <<EOF
# GitHub ActionsでOIDC認証を使用するための設定手順

1. GitHubリポジトリの「Settings」→「Secrets and variables」→「Actions」で以下のシークレットを設定します：
   - AWS_ACCOUNT_ID: ${data.aws_caller_identity.current.account_id}
   - AWS_REGION: ${var.aws_region}

2. 既存のIAMユーザー認証情報のシークレットは、OIDC認証が正常に機能することを確認した後に削除できます：
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY

3. GitHub Actionsワークフローファイル（.github/workflows/deploy.yml）が正しく設定されていることを確認します：
   - permissions セクションに id-token: write と contents: read が含まれていること
   - aws-actions/configure-aws-credentials@v4 アクションで role-to-assume パラメータが設定されていること

   ```yaml
   permissions:
     id-token: write
     contents: read

   steps:
     - name: Configure AWS credentials
       uses: aws-actions/configure-aws-credentials@v4
       with:
         role-to-assume: ${aws_iam_role.github_actions.arn}
         aws-region: $${{ secrets.AWS_REGION }}
   ```
EOF
}
