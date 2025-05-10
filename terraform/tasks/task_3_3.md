### Уровень 4: Автоматизация с модулями и циклами

_Для этого задания возьмите 5 листов формата A4 и распишите код каждого файла. Далее разложите листки бумаги на столе и нарисуйте фломастером логику взаимодействия переменных в каждом файле (далее можно сделать фотку на телефон). Делайте это упражнение до тех пор, пока не запомните механику. Делайте упражнение с A4, как минимум 3 дня, а далее воспроизведите на бумаге логику самостоятельно. С Ansible будет также, но уже сильно проще._

На этом уровне мы устраняем дублирование кода, внедряя **модули** и **циклы** (`for_each`). Модуль `environment` будет описывать сеть и контейнеры для одной среды, а цикл `for_each` автоматически создаст ресурсы для всех сред, используя переменную `environments`. Это сделает проект компактным, гибким и готовым к масштабированию (например, добавление новой среды `test` потребует только изменения `terraform.tfvars`).

#### Что происходит
- **Модуль [environment](https://developer.hashicorp.com/terraform/language/modules/syntax)**:
  - Создаётся в папке `modules/environment/` с файлами `main.tf` и `variables.tf`.
  - Описывает сеть (`{env_name}-network`), веб-сервер (`{env_name}-web`) и базу данных (`{env_name}-db`) для одной среды.
  - Принимает параметры: `env_name`, `web_port`, `db_user`, `db_password`, `db_name`.
- **Цикл [for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) (аргумент)**:
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

#### Как запустить
1. **Создайте файлы**:
   - Сохраните все файлы в соответствующую структуру.
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
- **Компактность**: `main.tf` сократился с ~60 строк (предыдущий уровень) до ~10 строк, так как дублирующий код вынесен в модуль.
- **Гибкость**: Добавление среды `test` требует только добавления блока в `terraform.tfvars`:
  ```hcl
  test = {
    web_port    = 8083
    db_user     = "test_user"
    db_password = "test_password"
  }
  ```
- **Повторное использование**: Модуль `environment` можно использовать в других проектах, изменив параметры.

---

**Задание завершено**
