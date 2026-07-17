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

# --- Jenkins ---
output "jenkins_namespace" {
  description = "Namespace Jenkins"
  value       = module.jenkins.namespace
}

output "jenkins_admin_user" {
  description = "Логін адміністратора Jenkins"
  value       = module.jenkins.admin_user
}

output "jenkins_port_forward" {
  description = "Команда для доступу до UI Jenkins"
  value       = module.jenkins.port_forward_command
}

output "jenkins_agent_role_arn" {
  description = "IRSA-роль агента Jenkins (пуш у ECR)"
  value       = module.jenkins.agent_role_arn
}

# --- RDS ---
output "rds_endpoint" {
  description = "Endpoint БД (writer)"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Порт підключення до БД"
  value       = module.rds.port
}

output "rds_security_group_id" {
  description = "ID Security Group БД"
  value       = module.rds.security_group_id
}

output "rds_is_aurora" {
  description = "Чи розгорнуто Aurora"
  value       = module.rds.is_aurora
}

# --- Argo CD ---
output "argocd_namespace" {
  description = "Namespace Argo CD"
  value       = module.argo_cd.namespace
}

output "argocd_application" {
  description = "Ім'я Argo CD Application"
  value       = module.argo_cd.application_name
}

output "argocd_port_forward" {
  description = "Команда для доступу до UI Argo CD"
  value       = module.argo_cd.port_forward_command
}

output "argocd_admin_password_command" {
  description = "Команда для отримання початкового паролю admin Argo CD"
  value       = module.argo_cd.initial_admin_password_command
}
