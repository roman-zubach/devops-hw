output "namespace" {
  description = "Namespace стеку моніторингу"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "storage_class_name" {
  description = "Ім'я створеного StorageClass (EBS gp3)"
  value       = kubernetes_storage_class.gp3.metadata[0].name
}

output "grafana_service" {
  description = "Ім'я сервісу Grafana"
  value       = "grafana"
}

output "grafana_port_forward_command" {
  description = "Команда для доступу до UI Grafana"
  value       = "kubectl -n ${kubernetes_namespace.monitoring.metadata[0].name} port-forward svc/grafana 3000:80"
}

output "prometheus_port_forward_command" {
  description = "Команда для доступу до UI Prometheus"
  value       = "kubectl -n ${kubernetes_namespace.monitoring.metadata[0].name} port-forward svc/${var.release_name}-kube-prometheus-prometheus 9090:9090"
}

output "grafana_admin_user" {
  description = "Логін адміністратора Grafana"
  value       = "admin"
}
