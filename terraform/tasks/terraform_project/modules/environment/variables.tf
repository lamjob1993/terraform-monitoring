variable "env_name" {
  description = "Name of the environment (dev, staging, prod)"
  type        = string
}

variable "web_port" {
  description = "External port for web server"
  type        = number
}

variable "db_user" {
  description = "PostgreSQL user"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
}
