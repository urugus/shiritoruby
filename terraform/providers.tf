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