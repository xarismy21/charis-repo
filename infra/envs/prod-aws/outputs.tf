output "ecr_repository_url" {
  description = "ECR repository URL — used in CI to build and push images"
  value       = module.ecr.repository_url
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain — public URL for the app"
  value       = module.cdn.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used by CI for cache invalidation"
  value       = module.cdn.cloudfront_distribution_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.ecs_service_name
}

output "github_deploy_role_arn" {
  description = "GitHub OIDC deploy role ARN — set as AWS_DEPLOY_ROLE_ARN in GitHub secrets"
  value       = module.iam_oidc.deploy_role_arn
}

output "waf_web_acl_arn" {
  description = "WAF WebACL ARN"
  value       = module.waf.web_acl_arn
}
