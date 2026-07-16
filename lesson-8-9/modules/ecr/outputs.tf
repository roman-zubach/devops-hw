output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "URL used to push Docker images"
  value       = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  description = "AWS registry ID"
  value       = aws_ecr_repository.this.registry_id
}