variable "name" {
  description = "Web app name — must be globally unique across Azure"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$", var.name))
    error_message = "Name must be 3-60 chars, lowercase alphanumeric and hyphens."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "sku_name" {
  description = "App Service Plan SKU (B1 = cheapest with always-on)"
  type        = string
  default     = "B1"
}

variable "docker_registry_url" {
  description = "Container registry hostname (e.g. your-account.dkr.ecr.us-east-1.amazonaws.com)"
  type        = string
}

variable "docker_image" {
  description = "Image name without tag"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
}

variable "docker_registry_username" {
  description = "Registry username (AWS: 'AWS')"
  type        = string
  sensitive   = true
}

variable "docker_registry_password" {
  description = "Registry password / ECR token"
  type        = string
  sensitive   = true
}

variable "app_settings" {
  description = "Additional app settings map"
  type        = map(string)
  default     = {}
}

variable "enable_staging_slot" {
  description = "Create a staging deployment slot (requires Standard or higher)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
