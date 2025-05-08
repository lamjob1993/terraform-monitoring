### Уровень 3: Упрощаем проект с помощью переменной `map`

Чтобы уменьшить повторение кода, используем одну переменную `environments` типа `map`, которая хранит настройки всех сред.

#### Файл: `main.tf`
```hcl
# Подключаем провайдер Docker
provider "docker" {}

# Загружаем образ Ubuntu
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}

# --- Dev ---
resource "docker_network" "dev_network" {
  name = "dev-network"
}
resource "docker_container" "dev_web" {
  name  = "dev-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.dev_network.name # Подключаем к dev-network
  }
  ports {
    internal = 80
    external = var.environments["dev"].web_port # Порт из переменной environments
    # var.environments["dev"].web_port — это web_port для dev из terraform.tfvars
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
resource "docker_container" "dev_db" {
  name  = "dev-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.dev_network.name
  }
  environment = {
    POSTGRES_USER     = var.environments["dev"].db_user
    POSTGRES_PASSWORD = var.environments["dev"].db_password
    POSTGRES_DB       = "dev_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE dev_db\"' && tail -f /dev/null"]
}

# --- Staging ---
resource "docker_network" "staging_network" {
  name = "staging-network"
}
resource "docker_container" "staging_web" {
  name  = "staging-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.staging_network.name # Подключаем к staging-network
  }
  ports {
    internal = 80
    external = var.environments["staging"].web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
resource "docker_container" "staging_db" {
  name  = "staging-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.staging_network.name
  }
  environment = {
    POSTGRES_USER     = var.environments["staging"].db_user
    POSTGRES_PASSWORD = var.environments["staging"].db_password
    POSTGRES_DB       = "staging_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE staging_db\"' && tail -f /dev/null"]
}

# --- Prod ---
resource "docker_network" "prod_network" {
  name = "prod-network"
}
resource "docker_container" "prod_web" {
  name  = "prod-web"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.prod_network.name # Подключаем к prod-network
  }
  ports {
    internal = 80
    external = var.environments["prod"].web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}
resource "docker_container" "prod_db" {
  name  = "prod-db"
  image = docker_image.ubuntu.name
  networks_advanced {
    name = docker_network.prod_network.name
  }
  environment = {
    POSTGRES_USER     = var.environments["prod"].db_user
    POSTGRES_PASSWORD = var.environments["prod"].db_password
    POSTGRES_DB       = "prod_db"
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE prod_db\"' && tail -f /dev/null"]
}
```

#### Файл: `variables.tf`
```hcl
# Настройки всех сред (dev, staging, prod) в одной переменной
variable "environments" {
  description = "Configurations for all environments"
  type = map(object({
    web_port    = number # Порт для веб-сервера (например, 8080)
    db_user     = string # Пользователь PostgreSQL
    db_password = string # Пароль PostgreSQL
  }))
  default = {
    dev = {
      web_port    = 8080
      db_user     = "dev_user"
      db_password = "dev_password"
    }
    staging = {
      web_port    = 8081
      db_user     = "staging_user"
      db_password = "staging_password"
    }
    prod = {
      web_port    = 8082
      db_user     = "prod_user"
      db_password = "prod_password"
    }
  }
}
```

#### **Пояснения:**

```hcl
variable "environments" {
  description = "Configurations for all environments"
  type = map(object({
    web_port    = number # Порт для веб-сервера (например, 8080)
    db_user     = string # Пользователь PostgreSQL
    db_password = string # Пароль PostgreSQL
  }))
}
```

### Разбор

1. **`variable "environments" {`**:
   - Определяет переменную в Terraform с именем `environments`. Переменные используются для хранения настроек, которые можно задавать в коде или в файле `terraform.tfvars`.

2. **`description = "Configurations for all environments"`**:
   - Описание переменной, поясняющее её назначение. Это комментарий для документации, который помогает понять, что переменная хранит настройки для всех сред (dev, staging, prod).

3. **`type = map(object({`**:
   - Задаёт тип переменной. Здесь используется `map`, который содержит объекты (`object`). Это означает, что переменная будет словарем (ключ-значение), где каждый ключ (например, `dev`, `staging`) связан с объектом, содержащим определённые поля.
   - `map` — это структура данных в Terraform, где ключи — строки, а значения — данные определённого типа (в данном случае объекты).

4. **`}))`**:
   - Закрывает определение объекта (`object`) и карты (`map`). Указывает, что каждый элемент `map` — это объект с тремя полями: `web_port`, `db_user`, `db_password`.

- **Зачем нужен `map`?**:
  - Позволяет хранить настройки для нескольких сред в одной переменной, упрощая доступ к ним через ключи, например, `var.environments["dev"].web_port` возвращает `8080`.
  - Удобен для масштабирования: добавление новой среды (например, `test`) требует только нового ключа в `map`.

---

#### Файл: `terraform.tfvars`
```hcl
environments = {
  dev = {
    web_port    = 8080
    db_user     = "dev_user"
    db_password = "dev_password"
  }
  staging = {
    web_port    = 8081
    db_user     = "staging_user"
    db_password = "staging_password"
  }
  prod = {
    web_port    = 8082
    db_user     = "prod_user"
    db_password = "prod_password"
  }
}
```

#### Что происходит
- Переменная `environments` хранит настройки всех сред в одном месте.
- Например, `var.environments["dev"].web_port` — это порт 8080 для dev, взятый из `terraform.tfvars`.
- Код в `main.tf` всё ещё повторяется, но переменные упрощены.

#### Дополнительные задания
- Добавьте среду `test` в `terraform.tfvars` и скопируйте код в `main.tf` для неё.

---

