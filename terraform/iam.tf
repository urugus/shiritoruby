# IAMロール
resource "aws_iam_role" "ecs_task_execution_role" {
  count = var.use_existing_infrastructure ? 0 : 1
  name = "${var.app_name}-ecs-task-execution-role"

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
  count = var.use_existing_infrastructure ? 0 : 1

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
          aws_secretsmanager_secret.rails_master_key[0].arn,
          aws_secretsmanager_secret.database_url[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_access" {
  count = var.use_existing_infrastructure ? 0 : 1

  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = aws_iam_policy.secrets_access[0].arn
}

# ECS Execを有効にするためのタスクロール
resource "aws_iam_role" "ecs_task_role" {
  count = var.use_existing_infrastructure ? 0 : 1
  name = "${var.app_name}-ecs-task-role"

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

# ECS Execを有効にするためのポリシー
resource "aws_iam_policy" "ecs_exec_policy" {
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}-ecs-exec-policy"
  description = "Allow ECS Exec functionality"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# タスクロールにECS Execポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ecs_exec_policy_attachment" {
  count = var.use_existing_infrastructure ? 0 : 1

  role       = aws_iam_role.ecs_task_role[0].name
  policy_arn = var.use_existing_infrastructure ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.app_name}-ecs-exec-policy" : aws_iam_policy.ecs_exec_policy[0].arn
}