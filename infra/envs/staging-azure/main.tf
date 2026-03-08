locals {
  name        = "charis-api-staging"
  environment = "staging"
  short_name  = "charisapi" # used for storage account (no hyphens, max 24 chars)

  common_tags = {
    Project     = "charis-api"
    Environment = "staging"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

# ── Web App for Containers ────────────────────────────────────────────────────
module "webapp" {
  count  = var.pause_deploy ? 0 : 1
  source = "../../modules/azure-webapp"

  name        = local.name
  location    = var.location
  environment = local.environment

  # B1 plan — $13/month. Cheapest tier with always-on and custom domains.
  sku_name = "B1"

  docker_registry_url      = var.ecr_registry
  docker_image             = "charis-api"
  image_tag                = var.image_tag
  docker_registry_username = "AWS"
  docker_registry_password = var.ecr_password

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = module.webapp[0].app_insights_connection_string
  }

  tags = local.common_tags
}

# ── Azure CDN + Static Storage ────────────────────────────────────────────────
#module "cdn" {
# source = "../../modules/azure-cdn"

# name                 = local.name
# resource_group_name  = module.webapp[0].resource_group_name
# location             = var.location
# storage_account_name = "${local.short_name}stg"
# webapp_hostname      = replace(module.webapp.webapp_url, "https://", "")

# tags = local.common_tags
#}

# ── Application Insights alert rules ─────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "${local.name}-error-rate"
  resource_group_name = module.webapp[0].resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${module.webapp[0].resource_group_name}/providers/Microsoft.Web/sites/${module.webapp[0].webapp_name}"]
  description         = "SLO burn: HTTP 5xx rate over 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }
}

resource "azurerm_monitor_metric_alert" "p95_latency" {
  name                = "${local.name}-p95-latency"
  resource_group_name = module.webapp[0].resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${module.webapp[0].resource_group_name}/providers/Microsoft.Web/sites/${module.webapp[0].webapp_name}"]
  description         = "SLO breach: average response time > 300ms"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "AverageResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0.3 # seconds
  }
}

data "azurerm_client_config" "current" {}
