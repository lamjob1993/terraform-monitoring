### Уровень 2: Добавляем в проект staging и prod (с дублированием кода)

Теперь добавим среды **staging** и **prod**, просто копируя код для `dev`. Это покажет, почему повторение кода — неудобно.

#### Файл: `main.tf`
```hcl
# Подключаем провайдер Docker
provider "docker" {}

# Загружаем образ Ubuntu
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}

# --- Dev ---
# Сеть для dev
resource "docker_network" "dev_network" {
  name = "dev-network"
}
# Веб-сервер для dev
resource "docker_container" "dev_web" {
  name  = "dev-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.dev_network.name # Подключаем к dev-network
  }
  ports {
    internal = 80
    external = var.dev_web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
# База данных для dev
resource "docker_container" "dev_db" {
  name  = "dev-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.dev_network.name
  }
  environment = {
    POSTGRES_USER     = var.dev_db_user
    POSTGRES_PASSWORD = var.dev_db_password
    POSTGRES_DB       = "dev_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE dev_db\"' && tail -f /dev/null"]
}

# --- Staging ---
# Сеть для staging
resource "docker_network" "staging_network" {
  name = "staging-network"
}
# Веб-сервер для staging
resource "docker_container" "staging_web" {
  name  = "staging-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.staging_network.name # Подключаем к staging-network
    # docker_network.staging_network.name — это имя сети "staging-network"
  }
  ports {
    internal = 80
    external = var.staging_web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
# База данных для staging
resource "docker_container" "staging_db" {
  name  = "staging-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.staging_network.name
  }
  environment = {
    POSTGRES_USER     = var.staging_db_user
    POSTGRES_PASSWORD = var.staging_db_password
    POSTGRES_DB       = "staging_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE staging_db\"' && tail -f /dev/null"]
}

# --- Prod ---
# Сеть для prod
resource "docker_network" "prod_network" {
  name = "prod-network"
}
# Веб-сервер для prod
resource "docker_container" "prod_web" {
  name  = "prod-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.prod_network.name # Подключаем к prod-network
  }
  ports {
    internal = 80
    external = var.prod_web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
# База данных для prod
resource "docker_container" "prod_db" {
  name  = "prod-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.prod_network.name
  }
  environment = {
    POSTGRES_USER     = var.prod_db_user
    POSTGRES_PASSWORD = var.prod_db_password
    POSTGRES_DB       = "prod_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE prod_db\"' && tail -f /dev/null"]
}
```

#### Файл: `variables.tf`
```hcl
# Порт для веб-сервера dev
variable "dev_web_port" {
  description = "External port for dev web server"
  type        = number
  default     = 8080
}
# Пользователь PostgreSQL для dev
variable "dev_db_user" {
  description = "PostgreSQL user for dev"
  type        = string
  default     = "dev_user"
}
# Пароль PostgreSQL для dev
variable "dev_db_password" {
  description = "PostgreSQL password for dev"
  type        = string
  default     = "dev_password"
}

# Порт для веб-сервера staging
variable "staging_web_port" {
  description = "External port for staging web server"
  type        = number
  default     = 8081
}
# Пользователь PostgreSQL для staging
variable "staging_db_user" {
  description = "PostgreSQL user for staging"
  type        = string
  default     = "staging_user"
}
# Пароль PostgreSQL для staging
variable "staging_db_password" {
  description = "PostgreSQL password for staging"
  type        = string
  default     = "staging_password"
}

# Порт для веб-сервера prod
variable "prod_web_port" {
  description = "External port for prod web server"
  type        = number
  default     = 8082
}
# Пользователь PostgreSQL для prod
variable "prod_db_user" {
  description = "PostgreSQL user for prod"
  type        = string
  default     = "prod_user"
}
# Пароль PostgreSQL для prod
variable "prod_db_password" {
  description = "PostgreSQL password for prod"
  type        = string
  default     = "prod_password"
}
```

#### Файл: `terraform.tfvars`
```hcl
dev_web_port    = 8080
dev_db_user     = "dev_user"
dev_db_password = "dev_password"

staging_web_port    = 8081
staging_db_user     = "staging_user"
staging_db_password = "staging_password"

prod_web_port    = 8082
prod_db_user     = "prod_user"
prod_db_password = "prod_password"
```

#### Что происходит
- Создаются три сети: `dev-network`, `staging-network`, `prod-network`.
- Для каждой среды — два контейнера: `*-web` (Nginx) и `*-db` (PostgreSQL).
- Код повторяется, что делает `main.tf` длинным и сложным для изменений.

#### Как запустить
- Применение: `terraform apply`.
- Проверка:
  - `http://localhost:8080` (dev), `8081` (staging), `8082` (prod).
  - База: `docker exec -it prod-db psql -U prod_user -d prod_db`.

#### Удаление проекта
- `terraform destroy`

---
