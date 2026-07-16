output "namespace" {
  description = "Namespace, у якому встановлено Jenkins"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "release_name" {
  description = "Ім'я Helm-релізу Jenkins"
  value       = helm_release.jenkins.name
}

output "admin_user" {
  description = "Логін адміністратора Jenkins"
  value       = var.admin_user
}

output "admin_password" {
  description = "Пароль адміністратора Jenkins"
  value       = var.admin_password
  sensitive   = true
}

output "agent_role_arn" {
  description = "ARN IRSA-ролі для агентів Jenkins (пуш у ECR)"
  value       = aws_iam_role.agent.arn
}

output "agent_service_account" {
  description = "Service account, під яким запускаються агенти Kaniko"
  value       = var.agent_service_account
}

output "port_forward_command" {
  description = "Команда для доступу до UI Jenkins"
  value       = "kubectl -n ${var.namespace} port-forward svc/jenkins 8080:8080"
}
