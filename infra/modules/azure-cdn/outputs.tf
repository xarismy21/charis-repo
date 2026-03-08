output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.static.name
}

output "storage_primary_web_endpoint" {
  description = "Static site web endpoint (direct, without CDN)"
  value       = azurerm_storage_account.static.primary_web_endpoint
}

output "cdn_static_endpoint_fqdn" {
  description = "CDN endpoint fqdn for static site"
  value       = azurerm_cdn_endpoint.static.fqdn
}

output "cdn_api_endpoint_fqdn" {
  description = "CDN endpoint fqdn for API"
  value       = azurerm_cdn_endpoint.api.fqdn
}

output "cdn_profile_name" {
  description = "CDN profile name"
  value       = azurerm_cdn_profile.this.name
}
