variable "namespace" {
  description = "Namespace для стеку моніторингу"
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Ім'я Helm-релізу kube-prometheus-stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Версія Helm-чарта kube-prometheus-stack (порожній рядок = остання)"
  type        = string
  default     = ""
}

variable "storage_class_name" {
  description = "Ім'я StorageClass на базі EBS CSI для PVC Prometheus/Grafana"
  type        = string
  default     = "gp3"
}

variable "grafana_admin_password" {
  description = "Пароль адміністратора Grafana (обов'язковий; root передає згенерований random_password)"
  type        = string
  sensitive   = true
}

variable "grafana_storage_size" {
  description = "Розмір PVC для Grafana"
  type        = string
  default     = "5Gi"
}

variable "prometheus_storage_size" {
  description = "Розмір PVC для Prometheus"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention" {
  description = "Термін зберігання метрик у Prometheus"
  type        = string
  default     = "7d"
}
