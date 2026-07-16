variable "namespace" {
  description = "Namespace, у якому встановлюється Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Версія Helm-чарта argo-cd (argo/argo-cd)"
  type        = string
  default     = "7.7.11"
}

variable "app_name" {
  description = "Ім'я Argo CD Application для django-app"
  type        = string
  default     = "django-app"
}

variable "repo_url" {
  description = "Git-репозиторій, який стежить Argo CD (той самий, що оновлює Jenkins)"
  type        = string
  default     = "https://github.com/roman-zubach/devops-hw.git"
}

variable "repo_target_revision" {
  description = "Гілка/тег, за якою стежить Argo CD"
  type        = string
  default     = "main"
}

variable "chart_path" {
  description = "Шлях до Helm-чарта django-app усередині репозиторію"
  type        = string
  default     = "lesson-8-9/charts/django-app"
}

variable "destination_namespace" {
  description = "Namespace у кластері, куди Argo CD розгортає застосунок"
  type        = string
  default     = "default"
}

variable "image_repository" {
  description = "URL ECR-репозиторію образу (для передачі як value чарту)"
  type        = string
  default     = ""
}
