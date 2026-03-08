terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# ── Storage Account for static site ──────────────────────────────────────────
resource "azurerm_storage_account" "static" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  static_website {
    index_document     = "index.html"
    error_404_document = "index.html"
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# ── Azure CDN Profile + Endpoint ──────────────────────────────────────────────
# Using Standard_Microsoft tier — free egress within Azure, cheapest external egress
resource "azurerm_cdn_profile" "this" {
  name                = "${var.name}-cdn"
  resource_group_name = var.resource_group_name
  location            = "global"
  sku                 = "Standard_Microsoft"

  tags = var.tags
}

resource "azurerm_cdn_endpoint" "static" {
  name                = "${var.name}-static"
  profile_name        = azurerm_cdn_profile.this.name
  resource_group_name = var.resource_group_name
  location            = "global"

  origin_host_header = azurerm_storage_account.static.primary_web_host

  origin {
    name      = "static-origin"
    host_name = azurerm_storage_account.static.primary_web_host
  }

  # Cache static assets for 1 day; bypass cache for HTML to ensure fresh deploys
  delivery_rule {
    name  = "CacheHtml"
    order = 1

    request_uri_condition {
      operator     = "EndsWith"
      match_values = [".html"]
    }

    cache_expiration_action {
      behavior = "Override"
      duration = "00:05:00"
    }
  }

  delivery_rule {
    name  = "CacheAssets"
    order = 2

    request_uri_condition {
      operator     = "EndsWith"
      match_values = [".js", ".css", ".png", ".jpg", ".svg", ".woff2"]
    }

    cache_expiration_action {
      behavior = "Override"
      duration = "7.00:00:00"
    }
  }

  # Redirect HTTP → HTTPS at CDN layer
  delivery_rule {
    name  = "EnforceHTTPS"
    order = 3

    request_scheme_condition {
      operator     = "Equal"
      match_values = ["HTTP"]
    }

    url_redirect_action {
      redirect_type = "PermanentRedirect"
      protocol      = "Https"
    }
  }

  is_compression_enabled = true
  content_types_to_compress = [
    "text/html",
    "text/css",
    "application/javascript",
    "application/json",
    "image/svg+xml"
  ]

  tags = var.tags
}

resource "azurerm_cdn_endpoint" "api" {
  name                = "${var.name}-api"
  profile_name        = azurerm_cdn_profile.this.name
  resource_group_name = var.resource_group_name
  location            = "global"

  origin_host_header = var.webapp_hostname

  origin {
    name      = "api-origin"
    host_name = var.webapp_hostname
  }

  # API responses are not cached — pass-through only
  delivery_rule {
    name  = "NoCache"
    order = 1

    request_scheme_condition {
      operator     = "Equal"
      match_values = ["HTTP"]
    }

    url_redirect_action {
      redirect_type = "PermanentRedirect"
      protocol      = "Https"
    }
  }

  tags = var.tags
}
