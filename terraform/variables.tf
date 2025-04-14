variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "shiritoruby"
}

variable "app_count" {
  description = "Number of application instances to run"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for the ECS task"
  type        = string
  default     = "512"
}

variable "db_username" {
  description = "Username for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "rails_master_key" {
  description = "Rails master key for the application"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the application (e.g., example.com)"
  type        = string
  default     = ""
}

variable "create_acm_certificate" {
  description = "Whether to create a new ACM certificate"
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate (if create_acm_certificate is false)"
  type        = string
  default     = ""
}

# 既存のインフラストラクチャを参照するための変数
variable "use_existing_infrastructure" {
  description = "Whether to use existing infrastructure"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "IDs of existing public subnets"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "IDs of existing private subnets"
  type        = list(string)
  default     = []
}

variable "existing_security_group_ids" {
  description = "IDs of existing security groups"
  type        = map(string)
  default     = {}
}

variable "existing_ecr_repository_url" {
  description = "URL of an existing ECR repository"
  type        = string
  default     = ""
}

variable "existing_ecs_cluster_name" {
  description = "Name of an existing ECS cluster"
  type        = string
  default     = ""
}

variable "existing_ecs_task_execution_role_arn" {
  description = "ARN of an existing ECS task execution role"
  type        = string
  default     = ""
}

variable "existing_cloudwatch_log_group_name" {
  description = "Name of an existing CloudWatch log group"
  type        = string
  default     = ""
}

variable "existing_lb_arn" {
  description = "ARN of an existing load balancer"
  type        = string
  default     = ""
}

variable "existing_lb_target_group_arn" {
  description = "ARN of an existing load balancer target group"
  type        = string
  default     = ""
}

variable "task_definition_revision" {
  description = "Revision of the existing ECS task definition"
  type        = string
  default     = "1"  # デフォルトは1を設定
}