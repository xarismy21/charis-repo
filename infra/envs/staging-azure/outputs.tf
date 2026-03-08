output "webapp_url" {
  description = "Staging Web App URL"
  value       = module.webapp[0].webapp_url
}

output "webapp_name" {
  description = "Web App name — used by Azure Pipelines to update the container image"
  value       = module.webapp[0].webapp_name
}

#output "cdn_static_url" {
# description = "CDN endpoint for static assets"
# value       = "https://${module.cdn.cdn_static_endpoint_fqdn}"
#}

#output "cdn_api_url" {
# description = "CDN endpoint for API"
# value       = "https://${module.cdn.cdn_api_endpoint_fqdn}"
#}

output "resource_group_name" {
  description = "Resource group name"
  value       = module.webapp[0].resource_group_name
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.webapp[0].app_insights_instrumentation_key
  sensitive   = true
}
