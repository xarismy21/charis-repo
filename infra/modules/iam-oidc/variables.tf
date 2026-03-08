variable "name" {
  description = "Base name prefix for IAM resources"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the deploy role can push to"
  type        = list(string)
}

variable "ecs_role_arns" {
  description = "ECS task/execution role ARNs that the deploy role can pass to ECS"
  type        = list(string)
}

variable "tf_state_bucket" {
  description = "S3 bucket name used for Terraform remote state"
  type        = string
}

variable "tf_lock_table" {
  description = "DynamoDB table name used for Terraform state locking"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
