# RDS PostgreSQLデータベース
resource "aws_db_subnet_group" "main" {
  count = var.use_existing_infrastructure ? 0 : 1

  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1[0].id, aws_subnet.private_2[0].id]

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  count = var.use_existing_infrastructure ? 0 : 1

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
  vpc_security_group_ids = [aws_security_group.db[0].id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "${var.app_name}-db"
  }
}