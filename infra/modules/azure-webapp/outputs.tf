output "webapp_url" {
  description = "Default hostname of the Web App"
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}

output "webapp_name" {
  description = "Web App name"
  value       = azurerm_linux_web_app.this.name
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "principal_id" {
  description = "Managed identity principal ID (for Key Vault access policy)"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.this.id
}
