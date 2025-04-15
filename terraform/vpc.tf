# VPC設定（既存のVPCを使用する場合はこのセクションをコメントアウト）
resource "aws_vpc" "main" {
  count = var.use_existing_infrastructure ? 0 : 1

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# サブネット
resource "aws_subnet" "public_1" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-1"
  }
}

resource "aws_subnet" "public_2" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-2"
  }
}

resource "aws_subnet" "private_1" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.app_name}-private-1"
  }
}

resource "aws_subnet" "private_2" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.app_name}-private-2"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "public" {
  count = var.use_existing_infrastructure ? 0 : 1

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
  count = var.use_existing_infrastructure ? 0 : 1

  subnet_id      = aws_subnet.public_1[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "public_2" {
  count = var.use_existing_infrastructure ? 0 : 1

  subnet_id      = aws_subnet.public_2[0].id
  route_table_id = aws_route_table.public[0].id
}

# Secrets ManagerのVPCエンドポイント
resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.use_existing_infrastructure ? 0 : 1

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1[0].id, aws_subnet.private_2[0].id]
  security_group_ids  = [aws_security_group.ecs[0].id]
  private_dns_enabled = true
}