variable "name" {
  description = "Base name for CDN resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "storage_account_name" {
  description = "Storage account name — must be globally unique, 3-24 lowercase alphanumeric"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase letters and numbers."
  }
}

variable "webapp_hostname" {
  description = "Web App hostname for the API CDN endpoint"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
