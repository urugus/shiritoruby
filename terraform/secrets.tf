# AWS Secrets Manager
resource "aws_secretsmanager_secret" "rails_master_key" {
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}/RAILS_MASTER_KEY_NEW"
  description = "Rails Master Key for ${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  count = var.use_existing_infrastructure ? 0 : 1

  secret_id     = aws_secretsmanager_secret.rails_master_key[0].id
  secret_string = var.rails_master_key
}

resource "aws_secretsmanager_secret" "database_url" {
  count = var.use_existing_infrastructure ? 0 : 1

  name        = "${var.app_name}/DATABASE_URL_NEW"
  description = "Database URL for ${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "database_url" {
  count = var.use_existing_infrastructure ? 0 : 1

  secret_id     = aws_secretsmanager_secret.database_url[0].id
  secret_string = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main[0].endpoint}/${var.app_name}_production"
}