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