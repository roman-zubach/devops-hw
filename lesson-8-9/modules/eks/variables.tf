variable "cluster_name" {
  description = "Ім'я EKS-кластера"
  type        = string
}

variable "cluster_version" {
  description = "Версія Kubernetes для кластера"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID VPC, у якій розгортається кластер"
  type        = string
}

variable "subnet_ids" {
  description = "Підмережі (публічні + приватні), доступні control plane кластера"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Приватні підмережі для worker-нод"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Чи доступний публічний endpoint API-сервера"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Чи доступний приватний endpoint API-сервера"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Типи інстансів для node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Бажана кількість worker-нод"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Мінімальна кількість worker-нод"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Максимальна кількість worker-нод"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Теги, застосовані до ресурсів кластера"
  type        = map(string)
  default     = {}
}
