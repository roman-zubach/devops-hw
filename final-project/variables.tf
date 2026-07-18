variable "db_password" {
  description = "Пароль master-користувача БД (передається через TF_VAR_db_password або .tfvars)"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Пароль адміністратора Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}
