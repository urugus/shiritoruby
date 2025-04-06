output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.shiritoruby.repository_url
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "database_endpoint" {
  description = "The endpoint of the database"
  value       = aws_db_instance.main.endpoint
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
  --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.private_1.id}],securityGroups=[${aws_security_group.ecs.id}],assignPublicIp=ENABLED}" \\
  --overrides '{"containerOverrides": [{"name": "${var.app_name}", "command": ["./bin/rails", "db:migrate"]}]}'
EOF
}
