provider "docker" {}

# Создание Docker-сети (аналог VPC)
resource "docker_network" "env_network" {
  name = "${var.env_name}-network"
}

# Образ для контейнеров
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}

# Контейнер для веб-сервера (Nginx)
resource "docker_container" "web_server" {
  name  = "${var.env_name}-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.env_network.name
  }
  ports {
    internal = 80
    external = var.web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}

# Контейнер для базы данных (PostgreSQL)
resource "docker_container" "database" {
  name  = "${var.env_name}-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.env_network.name
  }
  environment = {
    POSTGRES_USER     = var.db_user
    POSTGRES_PASSWORD = var.db_password
    POSTGRES_DB       = "${var.env_name}_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE ${var.env_name}_db\"' && tail -f /dev/null"]
}
