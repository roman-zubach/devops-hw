variable "name" {
  description = "Базове ім'я (префікс) для всіх ресурсів RDS-модуля"
  type        = string
}

variable "use_aurora" {
  description = "true → створюється Aurora Cluster + інстанси; false → одна звичайна aws_db_instance"
  type        = bool
  default     = false
}


variable "engine" {
  description = "Тип рушія БД. Для звичайної RDS: postgres, mysql, mariadb. Для Aurora: aurora-postgresql, aurora-mysql"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Версія рушія БД (наприклад 16.4 для postgres або 8.0 для mysql)"
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "Клас інстансу БД (наприклад db.t3.micro, db.r6g.large для Aurora)"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Увімкнути Multi-AZ для звичайної RDS (для Aurora відмовостійкість забезпечується кількістю інстансів)"
  type        = bool
  default     = false
}


variable "allocated_storage" {
  description = "Розмір сховища у ГБ (тільки для звичайної RDS, Aurora масштабується автоматично)"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Тип сховища для звичайної RDS (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}


variable "aurora_instance_count" {
  description = "Кількість інстансів у Aurora-кластері (перший — writer, решта — reader)"
  type        = number
  default     = 1
}


variable "db_name" {
  description = "Ім'я початкової бази даних"
  type        = string
  default     = "appdb"
}

variable "username" {
  description = "Ім'я master-користувача БД"
  type        = string
  default     = "dbadmin"
}

variable "password" {
  description = "Пароль master-користувача БД"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Порт БД (5432 для postgres, 3306 для mysql/mariadb)"
  type        = number
  default     = 5432
}


variable "vpc_id" {
  description = "ID VPC, у якій розгортається БД"
  type        = string
}

variable "subnet_ids" {
  description = "Список ID підмереж для DB Subnet Group (зазвичай приватні підмережі)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR-блоки, яким дозволено доступ до порту БД"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "ID Security Group, яким дозволено доступ до порту БД (наприклад SG нод EKS)"
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Чи має БД публічну адресу"
  type        = bool
  default     = false
}


variable "db_parameter_group_family" {
  description = "Family для aws_db_parameter_group звичайної RDS (наприклад postgres16, mysql8.0)"
  type        = string
  default     = "postgres16"
}

variable "aurora_cluster_parameter_group_family" {
  description = "Family для aws_rds_cluster_parameter_group Aurora (наприклад aurora-postgresql16, aurora-mysql8.0)"
  type        = string
  default     = "aurora-postgresql16"
}

variable "parameters" {
  description = "Список параметрів для Parameter Group. За замовчуванням базові параметри для PostgreSQL"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = [
    { name = "max_connections", value = "100", apply_method = "pending-reboot" },
    { name = "log_statement", value = "all" },
    { name = "work_mem", value = "4096" },
  ]
}


variable "backup_retention_period" {
  description = "Кількість днів зберігання резервних копій"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Пропустити фінальний snapshot при видаленні БД"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Шифрувати сховище БД"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Теги, застосовані до всіх ресурсів модуля"
  type        = map(string)
  default     = {}
}
