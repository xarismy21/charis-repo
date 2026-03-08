terraform {
  backend "azurerm" {
    resource_group_name  = "charis-tf-state-rg"
    storage_account_name = "charistfstate"
    container_name       = "tfstate"
    key                  = "staging-azure/terraform.tfstate"
  }

  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
