terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# ── Resource Group ────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "this" {
  name     = "${var.name}-rg"
  location = var.location

  tags = var.tags
}

# ── App Service Plan (Linux B1 — cheapest tier that supports containers) ──────
resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = var.tags
}

# ── Web App for Containers ────────────────────────────────────────────────────
resource "azurerm_linux_web_app" "this" {
  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true

  site_config {

    always_on         = var.sku_name != "F1" && var.sku_name != "D1"
    health_check_path = "/healthz"

    application_stack {
      docker_image_name        = "${var.docker_image}:${var.image_tag}"
      docker_registry_url      = "https://${var.docker_registry_url}"
      docker_registry_username = var.docker_registry_username
      docker_registry_password = var.docker_registry_password
    }

    http2_enabled = true
  }

  app_settings = merge(
    {
      PORT             = "8080"
      ENVIRONMENT      = var.environment
      WEBSITES_PORT    = "8080"
      DOCKER_ENABLE_CI = "true"
    },
    var.app_settings
  )

  logs {
    application_logs {
      file_system_level = "Information"
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ── Application Insights ──────────────────────────────────────────────────────
resource "azurerm_application_insights" "this" {
  name                = "${var.name}-appinsights"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name}-logs"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_linux_web_app_slot" "staging" {
  count          = var.enable_staging_slot ? 1 : 0
  name           = "staging"
  app_service_id = azurerm_linux_web_app.this.id

  site_config {

    health_check_path = "/healthz"
    application_stack {
      docker_image_name        = "${var.docker_image}:${var.image_tag}"
      docker_registry_url      = "https://${var.docker_registry_url}"
      docker_registry_username = var.docker_registry_username
      docker_registry_password = var.docker_registry_password
    }
  }

  tags = var.tags
}
