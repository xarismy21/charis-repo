output "repository_url" {
  description = "Full ECR repository URL"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.this.arn
}

output "registry_id" {
  description = "AWS account ID (ECR registry)"
  value       = aws_ecr_repository.this.registry_id
}
