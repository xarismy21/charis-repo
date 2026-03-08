variable "name" {
  description = "Base name for all resources"
  type        = string
}

variable "environment" {
  description = "Environment (staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to deploy into"
  type        = list(string)
}

variable "ecr_repository_url" {
  description = "Full ECR repository URL (without tag)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256, 512, 1024...)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_count" {
  description = "Minimum tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum tasks for autoscaling"
  type        = number
  default     = 10
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on ALB"
  type        = string
  default     = ""
}

variable "access_log_bucket" {
  description = "S3 bucket for ALB access logs. Empty string disables logging."
  type        = string
  default     = ""
}

# RDS stub — not provisioned, but wired for future use
variable "db_enabled" {
  description = "Stub: set true to provision RDS (not implemented — extend module)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
