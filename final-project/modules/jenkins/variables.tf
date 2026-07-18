variable "namespace" {
  description = "Namespace, у якому встановлюється Jenkins"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Версія Helm-чарта jenkins (jenkins/jenkins)"
  type        = string
  default     = "5.7.15"
}

variable "admin_user" {
  description = "Логін адміністратора Jenkins"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Пароль адміністратора Jenkins"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "cluster_name" {
  description = "Ім'я EKS-кластера (для іменування IAM-ролей)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN OIDC-провайдера кластера (для IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL OIDC-провайдера кластера (без https://)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN ECR-репозиторію, у який агент Jenkins пушить образи"
  type        = string
}

variable "agent_service_account" {
  description = "Ім'я service account, під яким запускаються агенти (Kaniko)"
  type        = string
  default     = "jenkins-agent"
}

variable "job_repo_url" {
  description = "Git-репозиторій, з якого seed-джоба тягне Jenkinsfile"
  type        = string
  default     = "https://github.com/roman-zubach/devops-hw.git"
}

variable "job_repo_branch" {
  description = "Гілка з Jenkinsfile"
  type        = string
  default     = "main"
}

variable "jenkinsfile_path" {
  description = "Шлях до Jenkinsfile всередині репозиторію"
  type        = string
  default     = "final-project/Jenkinsfile"
}

variable "tags" {
  description = "Теги для AWS-ресурсів модуля"
  type        = map(string)
  default     = {}
}
