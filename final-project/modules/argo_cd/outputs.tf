output "namespace" {
  description = "Namespace, у якому встановлено Argo CD"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Ім'я Helm-релізу Argo CD"
  value       = helm_release.argocd.name
}

output "application_name" {
  description = "Ім'я створеного Argo CD Application"
  value       = var.app_name
}

output "server_service" {
  description = "Kubernetes-сервіс Argo CD API/UI"
  value       = "argocd-server"
}

output "port_forward_command" {
  description = "Команда для доступу до UI Argo CD"
  value       = "kubectl -n ${var.namespace} port-forward svc/argocd-server 8081:443"
}

output "initial_admin_password_command" {
  description = "Команда для отримання початкового паролю admin"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
