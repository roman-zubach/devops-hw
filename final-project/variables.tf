variable "db_password" {
  description = "Пароль master-користувача БД (передається через TF_VAR_db_password або .tfvars)"
  type        = string
  sensitive   = true
}
