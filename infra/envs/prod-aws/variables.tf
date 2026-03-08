variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "image_tag" {
  description = "Docker image tag to deploy — injected by CI"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "charis-repo"
}

variable "domain_aliases" {
  description = "Custom domain aliases for CloudFront (optional)"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (us-east-1 only)"
  type        = string
  default     = ""
}

variable "pause_deploy" {
  description = "Emergency toggle — set true in CI environment to prevent prod deploys"
  type        = bool
  default     = false
}
