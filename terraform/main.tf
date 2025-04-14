terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # より安定したバージョンを指定
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"  # 最新の安定バージョンを指定
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.aws_region
}

# 現在のAWSアカウントIDを取得するためのデータソース
data "aws_caller_identity" "current" {}

# 既存のECRリポジトリを参照するためのデータソース
data "aws_ecr_repository" "shiritoruby" {
  count = var.use_existing_infrastructure ? 1 : 0
  name  = var.app_name
}

# ECRリポジトリ
resource "aws_ecr_repository" "shiritoruby" {
  count                = var.use_existing_infrastructure ? 0 : 1
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECRリポジトリのURLを取得するためのローカル変数
locals {
  ecr_repository_url = var.use_existing_infrastructure ? (
    var.existing_ecr_repository_url != "" ? var.existing_ecr_repository_url : data.aws_ecr_repository.shiritoruby[0].repository_url
  ) : aws_ecr_repository.shiritoruby[0].repository_url
}

# 既存のVPCを参照するためのデータソース
data "aws_vpc" "main" {
  count = var.use_existing_infrastructure && var.existing_vpc_id != "" ? 1 : 0
  id    = var.existing_vpc_id
}

# 既存のサブネットを参照するためのデータソース
data "aws_subnet" "public" {
  count = var.use_existing_infrastructure && length(var.existing_public_subnet_ids) > 0 ? length(var.existing_public_subnet_ids) : 0
  id    = var.existing_public_subnet_ids[count.index]
}

data "aws_subnet" "private" {
  count = var.use_existing_infrastructure && length(var.existing_private_subnet_ids) > 0 ? length(var.existing_private_subnet_ids) : 0
  id    = var.existing_private_subnet_ids[count.index]
}

# VPC設定
resource "aws_vpc" "main" {
  count                = var.use_existing_infrastructure ? 0 : 1
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# サブネット
resource "aws_subnet" "public_1" {
  count                   = var.use_existing_infrastructure ? 0 : 1
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  count                   = var.use_existing_infrastructure ? 0 : 1
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-2"
  }
}

resource "aws_subnet" "private_1" {
  count             = var.use_existing_infrastructure ? 0 : 1
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.app_name}-private-1"
  }
}

resource "aws_subnet" "private_2" {
  count             = var.use_existing_infrastructure ? 0 : 1
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.app_name}-private-2"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  count  = var.use_existing_infrastructure ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "public" {
  count  = var.use_existing_infrastructure ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  count          = var.use_existing_infrastructure ? 0 : 1
  subnet_id      = aws_subnet.public_1[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "public_2" {
  count          = var.use_existing_infrastructure ? 0 : 1
  subnet_id      = aws_subnet.public_2[0].id
  route_table_id = aws_route_table.public[0].id
}

# VPCとサブネットのIDを取得するためのローカル変数
locals {
  vpc_id = var.use_existing_infrastructure ? (
    var.existing_vpc_id != "" ? var.existing_vpc_id : ""
  ) : aws_vpc.main[0].id

  public_subnet_ids = var.use_existing_infrastructure ? (
    length(var.existing_public_subnet_ids) > 0 ? var.existing_public_subnet_ids : [for s in data.aws_subnet.public : s.id]
  ) : [aws_subnet.public_1[0].id, aws_subnet.public_2[0].id]

  private_subnet_ids = var.use_existing_infrastructure ? (
    length(var.existing_private_subnet_ids) > 0 ? var.existing_private_subnet_ids : [for s in data.aws_subnet.private : s.id]
  ) : [aws_subnet.private_1[0].id, aws_subnet.private_2[0].id]
}

# 既存のセキュリティグループを参照するためのデータソース
data "aws_security_group" "alb" {
  count = var.use_existing_infrastructure && lookup(var.existing_security_group_ids, "alb", "") != "" ? 1 : 0
  id    = var.existing_security_group_ids["alb"]
}

data "aws_security_group" "ecs" {
  count = var.use_existing_infrastructure && lookup(var.existing_security_group_ids, "ecs", "") != "" ? 1 : 0
  id    = var.existing_security_group_ids["ecs"]
}

data "aws_security_group" "db" {
  count = var.use_existing_infrastructure && lookup(var.existing_security_group_ids, "db", "") != "" ? 1 : 0
  id    = var.existing_security_group_ids["db"]
}

# セキュリティグループ
resource "aws_security_group" "alb" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}-alb-sg"
  description = "ALB Security Group"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}-ecs-sg"
  description = "ECS Security Group"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [local.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ecs-sg"
  }
}

resource "aws_security_group" "db" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}-db-sg"
  description = "Database Security Group"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [local.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-db-sg"
  }
}

# セキュリティグループのIDを取得するためのローカル変数
locals {
  alb_security_group_id = var.use_existing_infrastructure ? (
    lookup(var.existing_security_group_ids, "alb", "") != "" ? var.existing_security_group_ids["alb"] : try(data.aws_security_group.alb[0].id, "")
  ) : aws_security_group.alb[0].id

  ecs_security_group_id = var.use_existing_infrastructure ? (
    lookup(var.existing_security_group_ids, "ecs", "") != "" ? var.existing_security_group_ids["ecs"] : try(data.aws_security_group.ecs[0].id, "")
  ) : aws_security_group.ecs[0].id

  db_security_group_id = var.use_existing_infrastructure ? (
    lookup(var.existing_security_group_ids, "db", "") != "" ? var.existing_security_group_ids["db"] : try(data.aws_security_group.db[0].id, "")
  ) : aws_security_group.db[0].id
}

# 既存のRDSインスタンスを参照するためのデータソース
data "aws_db_instance" "main" {
  count      = var.use_existing_infrastructure ? 1 : 0
  db_instance_identifier = "${var.app_name}-db"
}

# RDS PostgreSQLデータベース
resource "aws_db_subnet_group" "main" {
  count      = var.use_existing_infrastructure ? 0 : 1
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = local.private_subnet_ids

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  count                = var.use_existing_infrastructure ? 0 : 1
  identifier             = "${var.app_name}-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  db_name                = "${var.app_name}_production"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres14"
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [local.db_security_group_id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "${var.app_name}-db"
  }
}

# データベースのエンドポイントを取得するためのローカル変数
locals {
  db_endpoint = var.use_existing_infrastructure ? (
    try(data.aws_db_instance.main[0].endpoint, "")
  ) : aws_db_instance.main[0].endpoint
}

# 既存のSecretsを参照するためのデータソース
data "aws_secretsmanager_secret" "rails_master_key" {
  count = var.use_existing_infrastructure ? 1 : 0
  name  = "${var.app_name}/RAILS_MASTER_KEY"
}

data "aws_secretsmanager_secret" "database_url" {
  count = var.use_existing_infrastructure ? 1 : 0
  name  = "${var.app_name}/DATABASE_URL"
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "rails_master_key" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}/RAILS_MASTER_KEY"
  description = "Rails Master Key for ${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  count         = var.use_existing_infrastructure ? 0 : 1
  secret_id     = aws_secretsmanager_secret.rails_master_key[0].id
  secret_string = var.rails_master_key
}

resource "aws_secretsmanager_secret" "database_url" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}/DATABASE_URL"
  description = "Database URL for ${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "database_url" {
  count         = var.use_existing_infrastructure ? 0 : 1
  secret_id     = aws_secretsmanager_secret.database_url[0].id
  secret_string = "postgres://${var.db_username}:${var.db_password}@${local.db_endpoint}/${var.app_name}_production"
}

# Secretsのarnを取得するためのローカル変数
locals {
  rails_master_key_arn = var.use_existing_infrastructure ? (
    try(data.aws_secretsmanager_secret.rails_master_key[0].arn, "")
  ) : aws_secretsmanager_secret.rails_master_key[0].arn

  database_url_arn = var.use_existing_infrastructure ? (
    try(data.aws_secretsmanager_secret.database_url[0].arn, "")
  ) : aws_secretsmanager_secret.database_url[0].arn
}

# 既存のIAMロールを参照するためのデータソース
data "aws_iam_role" "ecs_task_execution_role" {
  count = var.use_existing_infrastructure && var.existing_ecs_task_execution_role_arn != "" ? 1 : 0
  name  = "${var.app_name}-ecs-task-execution-role"
}

# IAMロール
resource "aws_iam_role" "ecs_task_execution_role" {
  count = var.use_existing_infrastructure ? 0 : 1
  name  = "${var.app_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count      = var.use_existing_infrastructure ? 0 : 1
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "secrets_access" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}-secrets-access"
  description = "Allow access to the application secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.app_name}/*",
          local.rails_master_key_arn,
          local.database_url_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  count      = var.use_existing_infrastructure ? 0 : 1
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = aws_iam_policy.secrets_access[0].arn
}

# IAMロールのARNを取得するためのローカル変数
locals {
  ecs_task_execution_role_arn = var.use_existing_infrastructure ? (
    var.existing_ecs_task_execution_role_arn != "" ? var.existing_ecs_task_execution_role_arn : try(data.aws_iam_role.ecs_task_execution_role[0].arn, "")
  ) : aws_iam_role.ecs_task_execution_role[0].arn
}

# Secrets ManagerのVPCエンドポイント
resource "aws_vpc_endpoint" "secretsmanager" {
  count               = var.use_existing_infrastructure ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [local.ecs_security_group_id]
  private_dns_enabled = true
}

# 既存のECSクラスターを参照するためのデータソース
data "aws_ecs_cluster" "main" {
  count        = var.use_existing_infrastructure && var.existing_ecs_cluster_name != "" ? 1 : 0
  cluster_name = var.existing_ecs_cluster_name != "" ? var.existing_ecs_cluster_name : "${var.app_name}-cluster"
}

# ECSクラスター
resource "aws_ecs_cluster" "main" {
  count = var.use_existing_infrastructure ? 0 : 1
  name  = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECSクラスターのARNを取得するためのローカル変数
locals {
  ecs_cluster_id = var.use_existing_infrastructure ? (
    var.existing_ecs_cluster_name != "" ? var.existing_ecs_cluster_name : try(data.aws_ecs_cluster.main[0].id, "")
  ) : aws_ecs_cluster.main[0].id
}

# 既存のCloudWatch Logsグループを参照するためのデータソース
data "aws_cloudwatch_log_group" "app" {
  count = var.use_existing_infrastructure && var.existing_cloudwatch_log_group_name != "" ? 1 : 0
  name  = var.existing_cloudwatch_log_group_name != "" ? var.existing_cloudwatch_log_group_name : "/ecs/${var.app_name}"
}

# ECSタスク定義
resource "aws_ecs_task_definition" "app" {
  count                  = var.use_existing_infrastructure ? 0 : 1
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${local.ecr_repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "RAILS_ENV"
          value = "production"
        },
        {
          name  = "RAILS_LOG_TO_STDOUT"
          value = "true"
        },
        {
          name  = "RAILS_MASTER_KEY"
          value = var.rails_master_key
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_username}:${var.db_password}@${local.db_endpoint}/${var.app_name}_production"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# CloudWatch Logsグループ
resource "aws_cloudwatch_log_group" "app" {
  count             = var.use_existing_infrastructure ? 0 : 1
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
}

# CloudWatch Logsグループ名を取得するためのローカル変数
locals {
  cloudwatch_log_group_name = var.use_existing_infrastructure ? (
    var.existing_cloudwatch_log_group_name != "" ? var.existing_cloudwatch_log_group_name : try(data.aws_cloudwatch_log_group.app[0].name, "/ecs/${var.app_name}")
  ) : "/ecs/${var.app_name}"
}

# ALB
resource "aws_lb" "main" {
  count              = var.use_existing_infrastructure ? 0 : 1
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_security_group_id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# 既存のALBを参照するためのデータソース
data "aws_lb" "main" {
  count = var.use_existing_infrastructure ? 1 : 0
  name  = "${var.app_name}-alb"
}

resource "aws_lb_target_group" "app" {
  count       = var.use_existing_infrastructure ? 0 : 1
  name        = "${var.app_name}-tg-3000"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  # Sticky Sessionsの設定を追加
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 1日（秒単位）
    enabled         = true
  }
}

# 既存のターゲットグループを参照するためのデータソース
data "aws_lb_target_group" "app" {
  count = var.use_existing_infrastructure ? 1 : 0
  name  = "${var.app_name}-tg-3000"
}

# ACM証明書（条件付き作成）
resource "aws_acm_certificate" "cert" {
  count             = var.create_acm_certificate && var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.app_name}-certificate"
  }
}

# 証明書のARNを決定するためのローカル変数
locals {
  certificate_arn = var.create_acm_certificate ? (
    var.domain_name != "" ? aws_acm_certificate.cert[0].arn : null
  ) : var.acm_certificate_arn
}

# HTTPSリスナー
resource "aws_lb_listener" "https" {
  count             = var.use_existing_infrastructure ? 0 : (local.certificate_arn != null ? 1 : 0)
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  # 明示的な依存関係を設定
  depends_on = [aws_lb_target_group.app]
}

# HTTPリスナー（証明書がない場合のフォールバック）
resource "aws_lb_listener" "http" {
  count             = var.use_existing_infrastructure ? 0 : (local.certificate_arn == null ? 1 : 0)
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  depends_on = [aws_lb_target_group.app]
}
# ターゲットグループのARNを取得するためのローカル変数
locals {
  target_group_arn = var.use_existing_infrastructure ? (
    var.existing_lb_target_group_arn != "" ? var.existing_lb_target_group_arn : try(data.aws_lb_target_group.app[0].arn, "")
  ) : aws_lb_target_group.app[0].arn

  lb_arn = var.use_existing_infrastructure ? (
    var.existing_lb_arn != "" ? var.existing_lb_arn : try(data.aws_lb.main[0].arn, "")
  ) : aws_lb.main[0].arn
}

# ECSサービス
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = local.ecs_cluster_id
  task_definition = var.use_existing_infrastructure ? "${var.app_name}:${var.task_definition_revision}" : aws_ecs_task_definition.app[0].arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [local.ecs_security_group_id]
    subnets          = local.public_subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = local.target_group_arn
    container_name   = var.app_name
    container_port   = 3000
  }
  # 明示的な依存関係を設定
  depends_on = [
    aws_lb_target_group.app
  ]
}

# GitHub OIDC Providerのサムプリントを自動的に取得
data "external" "github_thumbprint" {
  program = ["bash", "-c", <<-EOT
    THUMBPRINT=$(openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha1 -noout | cut -d '=' -f 2 | tr -d ':' | tr '[:upper:]' '[:lower:]')
# GitHub Actions用の追加ポリシー
resource "aws_iam_policy" "github_actions_additional_permissions" {
  name        = "${var.app_name}-github-actions-additional-permissions"
  description = "Additional permissions for GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "rds:DescribeDBInstances",
          "secretsmanager:DescribeSecret",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_additional_permissions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_additional_permissions.arn
}
    echo "{\"thumbprint\": \"$THUMBPRINT\"}"
  EOT
  ]
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.github_thumbprint.result.thumbprint]
}

# GitHub Actions用のIAMロール
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:urugus/shiritoruby:*"
          }
        }
      }
    ]
  })
}

# ECRとECSの権限をロールに付与
resource "aws_iam_role_policy" "github_actions_ecr_ecs" {
  name = "github-actions-ecr-ecs-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RunTask"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
