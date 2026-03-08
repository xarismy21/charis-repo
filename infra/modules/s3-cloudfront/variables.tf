variable "name" {
  description = "Base name for resources"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name — must be globally unique"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF WebACL ARN to attach to CloudFront"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for API origin. Leave empty to serve static only."
  type        = string
  default     = ""
}

variable "origin_verify_secret" {
  description = "Secret header value CloudFront sends to ALB to reject direct access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "domain_aliases" {
  description = "Custom domain aliases for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
