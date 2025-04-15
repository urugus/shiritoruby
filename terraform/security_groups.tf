# セキュリティグループ
resource "aws_security_group" "alb" {
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}-alb-sg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main[0].id

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
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}-ecs-sg"
  description = "ECS Security Group"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb[0].id]
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
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}-db-sg"
  description = "Database Security Group"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs[0].id]
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