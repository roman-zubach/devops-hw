output "is_aurora" {
  description = "Чи розгорнуто Aurora Cluster (true) або звичайну RDS (false)"
  value       = var.use_aurora
}

output "endpoint" {
  description = "Основний endpoint для запису (writer)"
  value       = var.use_aurora ? one(aws_rds_cluster.this[*].endpoint) : one(aws_db_instance.this[*].address)
}

output "reader_endpoint" {
  description = "Reader endpoint (тільки для Aurora, інакше null)"
  value       = var.use_aurora ? one(aws_rds_cluster.this[*].reader_endpoint) : null
}

output "port" {
  description = "Порт підключення до БД"
  value       = var.port
}

output "db_name" {
  description = "Ім'я початкової бази даних"
  value       = var.db_name
}

output "username" {
  description = "Ім'я master-користувача"
  value       = var.username
}

output "security_group_id" {
  description = "ID Security Group, створеної для БД"
  value       = aws_security_group.this.id
}

output "db_subnet_group_name" {
  description = "Ім'я створеної DB Subnet Group"
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Ім'я створеного Parameter Group"
  value       = var.use_aurora ? one(aws_rds_cluster_parameter_group.this[*].name) : one(aws_db_parameter_group.this[*].name)
}
