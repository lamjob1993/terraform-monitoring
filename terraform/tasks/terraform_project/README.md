## Введение в Terraform: Создание инфраструктуры с Docker

Добро пожаловать в ваш первый проект по **Terraform**! Этот учебный курс поможет вам научиться управлять инфраструктурой как кодом, используя **Docker** для создания локальных сред разработки (dev), тестирования (staging) и продакшена (prod). Мы начнём с простого — одной среды с веб-сервером (Nginx) и базой данных (PostgreSQL), а затем шаг за шагом добавим больше сред и оптимизируем код. 

Terraform — это инструмент, который позволяет описывать инфраструктуру (сети, серверы, контейнеры) в виде кода, чтобы её можно было легко создавать, изменять и удалять. Вместо облачных провайдеров, таких как AWS, мы будем использовать Docker, чтобы всё работало на вашем компьютере. Docker создаёт контейнеры — лёгкие "серверы", а Docker-сети изолируют их, как виртуальные сети в облаке.

Наш проект будет простым и понятным:
- Мы используем **один файл `main.tf`** для описания всей инфраструктуры.
- **Один файл `variables.tf`** для всех настроек.
- **Файл `terraform.tfvars`** для задания значений, таких как порты или имена пользователей.
- Никаких сложных конструкций вроде модулей или циклов — только понятный код.
- Мы разобьём обучение на **четыре уровня сложности**, чтобы вы постепенно освоили Terraform.

**VPC** (Virtual Private Cloud) — это виртуальная сеть в облаке, которая изолирует ваши ресурсы (серверы, базы данных) от других, как отдельная сеть в дата-центре. В нашем проекте Docker-сеть (например, `dev-network`) играет роль VPC, изолируя контейнеры одной среды (dev, staging, prod) от других.

К концу курса вы сможете создавать несколько сред, управлять ими через переменные и поймёте, как Terraform помогает автоматизировать инфраструктуру. Всё, что нужно, — это компьютер с **Docker** и **Terraform** (4 ГБ ОЗУ хватит). Давайте начнём!

---

### Структура проекта
```
terraform_project/
├── main.tf
├── variables.tf
└── terraform.tfvars
```
- **`main.tf`**: Описывает Docker-сети (аналог облачных VPC) и контейнеры (Nginx и PostgreSQL).
- **`variables.tf`**: Задаёт переменные, такие как порты или пользователи базы данных.
- **`terraform.tfvars`**: Содержит конкретные значения для переменных.

---

### Уровень 1: Создаём одну среду (dev)

На этом уровне мы создадим одну среду **dev** с Docker-сетью и двумя контейнерами:
- **Nginx** — веб-сервер, доступный через браузер.
- **PostgreSQL** — база данных.

#### Файл: `main.tf`
```hcl
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
```

#### Файл: `variables.tf`
```hcl
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
```

#### Файл: `terraform.tfvars`
```hcl
web_port    = 8080
db_user     = "dev_user"
db_password = "dev_password"
```

#### Что происходит
- **Сеть**: `docker_network.dev_network.name` создаёт сеть `dev-network`, которая изолирует контейнеры, как виртуальная сеть в облаке.
- **Контейнеры**:
  - `dev-web`: Запускает Nginx, доступен на `http://localhost:8080`.
  - `dev-db`: Запускает PostgreSQL с базой `dev_db`.
- **Переменные**: `var.web_port`, `var.db_user`, `var.db_password` задают настройки, которые можно менять в `terraform.tfvars`.

#### Как запустить
1. Убедитесь, что **Docker** и **Terraform** установлены.
2. Инициализация:
   ```bash
   terraform init
   ```
3. Применение:
   ```bash
   terraform apply
   ```
4. Проверка:
   - Откройте `http://localhost:8080` — увидите страницу Nginx.
   - Проверьте базу: `docker exec -it dev-db psql -U dev_user -d dev_db`.
5. Удаление:
   ```bash
   terraform destroy
   ```

#### Дополнительное задание
- Измените `web_port` на 8090 в `terraform.tfvars` и проверьте `http://localhost:8090`.

---

### Уровень 2: Добавляем staging и prod (с дублированием кода)

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

---

### Уровень 3: Упрощаем с помощью переменной `map`

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

### Уровень 4: Автоматизация с модулями и циклами

На этом уровне мы устраняем дублирование кода, внедряя **модули** и **циклы** (`for_each`). Модуль `environment` будет описывать сеть и контейнеры для одной среды, а цикл `for_each` автоматически создаст ресурсы для всех сред, используя переменную `environments`. Это сделает проект компактным, гибким и готовым к масштабированию (например, добавление новой среды `test` потребует только изменения `terraform.tfvars`).

#### Что происходит
- **Модуль `environment`**:
  - Создаётся в папке `modules/environment/` с файлами `main.tf` и `variables.tf`.
  - Описывает сеть (`{env_name}-network`), веб-сервер (`{env_name}-web`) и базу данных (`{env_name}-db`) для одной среды.
  - Принимает параметры: `env_name`, `web_port`, `db_user`, `db_password`, `db_name`.
- **Цикл `for_each`**:
  - В главном `main.tf` используется `for_each` для вызова модуля `environment` для каждой среды из `var.environments`.
  - Например, для `dev` передаётся `env_name = "dev"`, `web_port = 8080` и т.д.
- **Результат**:
  - Код в `main.tf` сокращается до нескольких строк.
  - Добавление новой среды (например, `test`) требует только обновления `terraform.tfvars`.

#### Структура проекта
```
terraform_project/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── modules/
│   └── environment/
│       ├── main.tf
│       └── variables.tf
└── README.md
```
- **`main.tf`**: Определяет провайдер, образ Ubuntu и вызывает модуль `environment` для каждой среды с помощью `for_each`.
- **`variables.tf`**: Содержит переменную `environments` типа `map` (без изменений с Уровня 3).
- **`terraform.tfvars`**: Задаёт значения для `environments` (без изменений).
- **`modules/environment/main.tf`**: Описывает сеть и контейнеры для одной среды.
- **`modules/environment/variables.tf`**: Определяет входные параметры модуля.
- **`README.md`**: Обновлённая документация с инструкциями по запуску и описанием модулей.

#### Файл: `main.tf`
```hcl
# Подключаем провайдер Docker
provider "docker" {}

# Загружаем образ Ubuntu
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}

# Вызываем модуль environment для каждой среды
module "environment" {
  for_each = var.environments
  source   = "./modules/environment"

  env_name    = each.key                    # Например, "dev", "staging", "prod"
  web_port    = each.value.web_port         # Порт из environments
  db_user     = each.value.db_user          # Пользователь БД
  db_password = each.value.db_password      # Пароль БД
  db_name     = "${each.key}_db"            # Имя базы, например, "dev_db"
}
```

#### Файл: `variables.tf`
```hcl
# Настройки всех сред в одной переменной
variable "environments" {
  description = "Configurations for all environments"
  type = map(object({
    web_port    = number # Порт для веб-сервера
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

#### Файл: `terraform.tfvars`
```hcl
environments = {
  dev = {
    web_port    = 8080
    db_user     = "dev_user"
    db_password = "dev_password"
  }
  staking = {
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

#### Файл: `modules/environment/main.tf`
```hcl
# Создаём сеть для среды
resource "docker_network" "network" {
  name = "${var.env_name}-network"
}

# Создаём контейнер для веб-сервера
resource "docker_container" "web" {
  name  = "${var.env_name}-web"
  image = "ubuntu:latest"
  networks_advanced {
    name = docker_network.network.name # Подключаем к сети
    # docker_network.network.name — имя сети, например, "dev-network"
  }
  ports {
    internal = 80
    external = var.web_port
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'"]
}

# Создаём контейнер для базы данных
resource "docker_container" "db" {
  name  = "${var.env_name}-db"
  image = "ubuntu:latest"
  networks_advanced {
    name = docker_network.network.name
  }
  environment = {
    POSTGRES_USER     = var.db_user
    POSTGRES_PASSWORD = var.db_password
    POSTGRES_DB       = var.db_name
  }
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y postgresql && su - postgres -c 'initdb /var/lib/postgresql/data && pg_ctl -D /var/lib/postgresql/data start && psql -c \"CREATE DATABASE ${var.db_name}\"' && tail -f /dev/null"]
}
```

#### Файл: `modules/environment/variables.tf`
```hcl
variable "env_name" {
  description = "Name of the environment (e.g., dev, staging, prod)"
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

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}
```

#### Файл: `README.md`
```markdown
# Terraform Docker Course

Этот проект демонстрирует, как использовать Terraform для создания инфраструктуры с Docker для сред разработки (dev), тестирования (staging) и продакшена (prod). Каждая среда включает сеть (аналог VPC), веб-сервер (Nginx) и базу данных (PostgreSQL).

## Требования
- Docker
- Terraform
- ~4 ГБ ОЗУ

## Структура проекта
- `main.tf`: Определяет провайдер, образ Ubuntu и вызывает модуль `environment` для каждой среды.
- `variables.tf`: Задаёт переменную `environments` для настроек сред.
- `terraform.tfvars`: Содержит значения для `environments`.
- `modules/environment/main.tf`: Описывает сеть и контейнеры для одной среды.
- `modules/environment/variables.tf`: Определяет параметры модуля.
- `README.md`: Это руководство.

## Как запустить
1. Убедитесь, что Docker и Terraform установлены.
2. Инициализируйте проект:
   ```bash
   terraform init
   ```
3. Примените конфигурацию:
   ```bash
   terraform apply
   ```
4. Проверьте:
   - Dev: `http://localhost:8080`
   - Staging: `http://localhost:8081`
   - Prod: `http://localhost:8082`
   - Базы данных:
     ```bash
     docker exec -it dev-db psql -U dev_user -d dev_db
     docker exec -it staging-db psql -U staging_user -d staging_db
     docker exec -it prod-db psql -U prod_user -d prod_db
     ```
5. Удалите ресурсы:
   ```bash
   terraform destroy
   ```

## Задания
- Добавьте среду `test` в `terraform.tfvars` и проверьте, как она автоматически создаётся.
- Измените `db_name` в вызове модуля для staging на `staging_database`.
- Ознакомьтесь с документацией Terraform по модулям и попробуйте добавить новый параметр в модуль (например, `image_tag`).
```

#### Как запустить
1. **Создайте файлы**:
   - Сохраните все файлы из артефакта ниже в соответствующую структуру.
   - Убедитесь, что Docker и Terraform установлены.
2. **Инициализация**:
   ```bash
   terraform init
   ```
3. **Применение**:
   ```bash
   terraform apply
   ```
4. **Проверка**:
   - Откройте в браузере:
     - `http://localhost:8080` (dev).
     - `http://localhost:8081` (staging).
     - `http://localhost:8082` (prod).
   - Проверьте базы данных:
     ```bash
     docker exec -it dev-db psql -U dev_user -d dev_db
     docker exec -it staging-db psql -U staging_user -d staging_db
     docker exec -it prod-db psql -U prod_user -d prod_db
     ```
5. **Удаление**:
   ```bash
   terraform destroy
   ```

#### Что изменилось
- **Компактность**: `main.tf` сократился с ~60 строк (Уровень 3) до ~10 строк, так как дублирующий код вынесен в модуль.
- **Гибкость**: Добавление среды `test` требует только добавления блока в `terraform.tfvars`:
  ```hcl
  test = {
    web_port    = 8083
    db_user     = "test_user"
    db_password = "test_password"
  }
  ```
- **Повторное использование**: Модуль `environment` можно использовать в других проектах, изменив параметры.

#### Задания для студентов
- **Добавьте среду `test`**: Включите `test` в `terraform.tfvars` и проверьте создание `test-network`, `test-web`, `test-db`.
- **Измените имя базы**: В `main.tf` задайте `db_name = "staging_database"` для staging и проверьте.
- **Расширьте модуль**: Добавьте параметр `image_tag` в `modules/environment/variables.tf` и используйте его для выбора версии образа (например, `ubuntu:${var.image_tag}`).
- **Исследование**: Разберитесь, как добавить зависимости между модулями (например, чтобы веб-сервер запускался после базы данных).

#### Рекомендации
- **Закрепите модули**: Убедитесь, что вы понимаете, как параметры передаются в модуль и как `for_each` работает с `map`.
- **Ресурсы**: 4 ГБ ОЗУ достаточно. Если добавляете среды, следите за портами, чтобы избежать конфликтов.
- **Дальнейшие шаги**:
  - Попробуйте заменить Docker на облачный провайдер (например, AWS) с реальными VPC.
  - Изучите Terraform-провайдеры для управления конфигурацией контейнеров (например, Docker Compose через Terraform).

---

### Завершение

Теперь вы умеете:
- Описывать инфраструктуру как код с помощью Terraform.
- Управлять Docker-сетями и контейнерами для изолированных сред.
- Оптимизировать код, используя переменные `map`, модули и `for_each`.
- Планировать масштабируемые проекты, готовые к реальным облачным средам.
