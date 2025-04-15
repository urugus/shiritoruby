# Route 53 ホストゾーン
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name

  tags = {
    Name = "${var.app_name}-zone"
  }
}

# ACM証明書のDNS検証レコード
resource "aws_route53_record" "cert_validation" {
  count = var.create_acm_certificate && var.domain_name != "" ? length(aws_acm_certificate.cert[0].domain_validation_options) : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = element(aws_acm_certificate.cert[0].domain_validation_options.*.resource_record_name, count.index)
  type    = element(aws_acm_certificate.cert[0].domain_validation_options.*.resource_record_type, count.index)
  records = [element(aws_acm_certificate.cert[0].domain_validation_options.*.resource_record_value, count.index)]
  ttl     = 60
}

# ACM証明書の検証完了を待機
resource "aws_acm_certificate_validation" "cert" {
  count = var.create_acm_certificate && var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = aws_route53_record.cert_validation.*.fqdn
}

# ALBへのエイリアスレコード
resource "aws_route53_record" "alb" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.use_existing_infrastructure ? var.existing_lb_dns_name : aws_lb.main[0].dns_name
    zone_id                = var.use_existing_infrastructure ? var.existing_lb_zone_id : aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

# www サブドメインのエイリアスレコード
resource "aws_route53_record" "www" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.use_existing_infrastructure ? var.existing_lb_dns_name : aws_lb.main[0].dns_name
    zone_id                = var.use_existing_infrastructure ? var.existing_lb_zone_id : aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}