# ECRリポジトリ
resource "aws_ecr_repository" "shiritoruby" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECSタスク定義
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.shiritoruby.repository_url}:latest"
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
          value = var.use_existing_infrastructure ? "" : "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main[0].endpoint}/${var.app_name}_production"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.app_name}"
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
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
}

# ECSサービス
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    security_groups  = var.use_existing_infrastructure ? [] : [aws_security_group.ecs[0].id]
    subnets          = var.use_existing_infrastructure ? [] : [aws_subnet.public_1[0].id, aws_subnet.public_2[0].id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.use_existing_infrastructure ? var.existing_lb_target_group_arn : aws_lb_target_group.app[0].arn
    container_name   = var.app_name
    container_port   = 3000
  }
}