### Введение в Terraform: Создание инфраструктуры с Docker для учебного курса

Добро пожаловать в ваш первый проект по **Terraform**! Этот учебный курс поможет вам научиться управлять инфраструктурой как кодом, используя **Docker** для создания локальных сред разработки (dev), тестирования (staging) и продакшена (prod). Мы начнём с простого — одной среды с веб-сервером (Nginx) и базой данных (PostgreSQL), а затем шаг за шагом добавим больше сред и оптимизируем код. 

Terraform — это инструмент, который позволяет описывать инфраструктуру (сети, серверы, контейнеры) в виде кода, чтобы её можно было легко создавать, изменять и удалять. Вместо облачных провайдеров, таких как AWS, мы будем использовать Docker, чтобы всё работало на вашем компьютере. Docker создаёт контейнеры — лёгкие "серверы", а Docker-сети изолируют их, как виртуальные сети в облаке.

Наш проект будет простым и понятным:
- Мы используем **один файл `main.tf`** для описания всей инфраструктуры.
- **Один файл `variables.tf`** для всех настроек.
- **Файл `terraform.tfvars`** для задания значений, таких как порты или имена пользователей.
- Никаких сложных конструкций вроде модулей или циклов — только понятный код.
- Мы разобьём обучение на **четыре уровня сложности**, чтобы вы постепенно освоили Terraform.

К концу курса вы сможете создавать несколько сред, управлять ими через переменные и поймёте, как Terraform помогает автоматизировать инфраструктуру. Всё, что нужно, — это компьютер с **Docker** и **Terraform** (4 ГБ ОЗУ хватит). Давайте начнём!

---

### Структура проекта
```
terraform-docker-course/
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

#### Задания для студентов
- Измените `web_port` на 8090 в `terraform.tfvars` и проверьте `http://localhost:8090`.
- Добавьте `curl` в контейнер `dev-web`, изменив `command`:
  ```hcl
  command = ["/bin/bash", "-c", "apt-get update && apt-get install -y nginx curl && nginx -g 'daemon off;'"]
  ```

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

#### Задания для студентов
- Измените `staging_web_port` на 8090 в `terraform.tfvars`.
- Добавьте `curl` в контейнер `prod-web`.

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

#### Задания для студентов
- Добавьте среду `test` в `terraform.tfvars` и скопируйте код в `main.tf` для неё.
- Измените имя базы для `staging` на `staging_database`.

---

### Уровень 4: Подведение итогов и следующий шаг

Вы научились:
- Создавать одну среду (Уровень 1).
- Работать с несколькими средами, даже если код повторяется (Уровень 2).
- Упрощать настройки с помощью `map` (Уровень 3).

Проблема: в `main.tf` всё ещё много одинакового кода. Следующий шаг (для продвинутых) — использовать **модули** и **циклы** (`for_each`), чтобы автоматизировать создание сред. Это сделает код короче и гибче, но мы оставим это для будущего урока, чтобы не усложнять.

---

### Рекомендации для курса
1. **Начинайте с Уровня 1**: Он простой и подходит для новичков.
2. **Продвигайтесь к Уровню 3**: Студенты увидят, как улучшить код с помощью переменных.
3. **Сохраняйте простоту**:
   - Один `main.tf` и один `variables.tf` делают проект понятным.
   - Комментарии вроде `docker_network.staging_network.name` объясняют, что означают точки.
4. **Задания**:
   - Уровень 1: Изменить порт или добавить `curl`.
   - Уровень 2: Добавить среду вручную.
   - Уровень 3: Добавить `test` в `terraform.tfvars`.
5. **Ресурсы**: 4 ГБ ОЗУ достаточно для 6 контейнеров.
6. **Документация**:
   - Опишите каждый уровень.
   - Дайте команды: `terraform init`, `apply`, `destroy`.

---

### Ответ
Мы создали простой Terraform-проект для управления Docker-инфраструктурой:
- **Один `main.tf`** описывает сети и контейнеры.
- **Один `variables.tf`** задаёт переменные.
- **Четыре уровня сложности**:
  1. Одна среда (dev) — основы Terraform.
  2. Три среды (dev, staging, prod) — дублирование кода.
  3. Оптимизация с `map` — меньше переменных.
  4. Итоги и план на будущее (модули).
