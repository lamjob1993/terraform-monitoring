# Подключаем провайдер Docker, чтобы Terraform мог управлять контейнерами
provider "docker" {}

# Создаём Docker-сеть для изоляции контейнеров (как VPC в облаке)
resource "docker_network" "dev_network" {
  name = "dev-network"
}

# Загружаем образ Ubuntu для контейнеров
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}

# Создаём контейнер для веб-сервера (Nginx)
resource "docker_container" "dev_web" {
  name  = "dev-web" # Имя контейнера
  image = docker_image.ubuntu.name # Используем образ Ubuntu
  networks_advanced {
    name = docker_network.dev_network.name # Подключаем к сети dev-network
    # docker_network.dev_network.name — это имя сети, созданной выше ("dev-network")
  }
  ports {
    internal = 80 # Nginx внутри контейнера работает на порту 80
    external = var.web_port # Внешний порт, задаётся в terraform.tfvars
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
  # Устанавливаем Nginx и запускаем его
}

# Создаём контейнер для базы данных (PostgreSQL)
resource "docker_container" "dev_db" {
  name  = "dev-db" # Имя контейнера
  image = docker_image.ubuntu.name # Используем образ Ubuntu
  networks_advanced {
    name = docker_network.dev_network.name # Подключаем к сети dev-network
  }
  environment = {
    POSTGRES_USER     = var.db_user # Имя пользователя PostgreSQL
    POSTGRES_PASSWORD = var.db_password # Пароль PostgreSQL
    POSTGRES_DB       = "dev_db" # Имя базы данных
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE dev_db\"' && tail -f /dev/null"]
  # Устанавливаем PostgreSQL, создаём базу и держим контейнер активным
}
