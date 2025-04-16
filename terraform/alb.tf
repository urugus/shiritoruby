# ALB
resource "aws_lb" "main" {
  count = var.use_existing_infrastructure ? 0 : 1

  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = [aws_subnet.public_1[0].id, aws_subnet.public_2[0].id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.app_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}-tg-3000"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main[0].id
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

# ACM証明書（条件付き作成）
resource "aws_acm_certificate" "cert" {
  count             = var.create_acm_certificate && var.domain_name != "" && !var.use_existing_infrastructure ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.app_name}-certificate"
  }
}

# HTTPSリスナー
resource "aws_lb_listener" "https" {
  count = (!var.use_existing_infrastructure && var.create_acm_certificate && var.domain_name != "") ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  # 明示的な依存関係を設定
  depends_on = [aws_lb_target_group.app, aws_acm_certificate.cert]
}

# 既存の証明書を使用する場合のHTTPSリスナー
resource "aws_lb_listener" "https_existing_cert" {
  count = (!var.use_existing_infrastructure && !var.create_acm_certificate && var.acm_certificate_arn != "") ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }

  # 明示的な依存関係を設定
  depends_on = [aws_lb_target_group.app]
}