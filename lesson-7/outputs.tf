output "s3_bucket_name" {
  description = "Назва S3-бакета для стейтів"
  value       = module.s3_backend.s3_bucket_name
}

output "dynamodb_table_name" {
  description = "Назва таблиці DynamoDB для блокування стейтів"
  value       = module.s3_backend.dynamodb_table_name
}

output "vpc_id" {
  description = "ID створеної VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Список ID публічних підмереж"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Список ID приватних підмереж"
  value       = module.vpc.private_subnets
}

output "ecr_repository_url" {
  description = "URL ECR репозиторію"
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "Ім'я EKS-кластера"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint API-сервера EKS-кластера"
  value       = module.eks.cluster_endpoint
}

output "eks_configure_kubectl" {
  description = "Команда для налаштування kubectl"
  value       = "aws eks update-kubeconfig --region us-west-2 --name ${module.eks.cluster_name}"
}
