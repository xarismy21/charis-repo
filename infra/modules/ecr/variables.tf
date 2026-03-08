variable "name" {
  description = "ECR repository name"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9/_.-]{1,255}$", var.name))
    error_message = "Repository name must be lowercase alphanumeric with hyphens."
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
