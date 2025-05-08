# Порт, на котором будет доступен веб-сервер (например, http://localhost:8080)
variable "web_port" {
  description = "External port for web server"
  type        = number
  default     = 8080
}

# Имя пользователя для PostgreSQL
variable "db_user" {
  description = "PostgreSQL user"
  type        = string
  default     = "dev_user"
}

# Пароль для PostgreSQL
variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "dev_password"
}
