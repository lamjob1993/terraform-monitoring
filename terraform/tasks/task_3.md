# Разворачиваем: Dev, Staging и Prod контуры (среды) разработки (данное задание разбивается на 5 подзаданий)

_Для подобного рода задач заводится таска в Jira (вкратце в описании описывается план проведения работ, выставляется время проведения работ, указывается исполнитель и ответственный), прикладывается документация в формате `.docx`, где прописано построчно, что будет происходить, и что делать в случае сбоя (откат). То есть вот вам еще одна строчка в резюме - придумайте, как её красиво расписать._

## Создание инфраструктуры с Docker (для нас эта инфра будет в рабочем облаке)

Мы будем использовать **Docker** для создания локальных сред разработки (dev), тестирования (staging) и продакшена (prod). Мы начнём с простого — одной среды с веб-сервером (Nginx) и базой данных (PostgreSQL), а затем шаг за шагом добавим больше сред и оптимизируем код. 

**Наш первый проект:**
- Мы используем **один файл `main.tf`** для описания всей инфраструктуры.
- **Один файл `variables.tf`** для всех настроек.
- **Файл `terraform.tfvars`** для задания значений, таких как порты или имена пользователей.
- Никаких сложных конструкций вроде модулей или циклов — только понятный код.
- Мы разобьём обучение на **уровни сложности**, чтобы вы постепенно освоили Terraform.

**VPC** (Virtual Private Cloud) — это виртуальная сеть в облаке, которая изолирует ваши ресурсы (серверы, базы данных) от других, как отдельная сеть в дата-центре. В нашем проекте Docker-сеть (например, `dev-network`) играет роль VPC, изолируя контейнеры одной среды (dev, staging, prod) от других.

К концу курса вы сможете создавать несколько сред, управлять ими через переменные и поймёте, как Terraform помогает автоматизировать инфраструктуру. Всё, что нужно, — это компьютер с **Docker** и **Terraform** (4 ГБ ОЗУ + 4 CPU).

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

**Пояснения:**

```hcl
resource "docker_network" "dev_network" {
  name = "dev-network"
}
```

1. **`resource`**:
   - Ключевое слово Terraform, указывающее, что мы определяем ресурс — объект инфраструктуры, которым будет управлять Terraform.

2. **`"docker_network"`**:
   - Тип ресурса, предоставляемый провайдером Docker. Указывает, что мы создаём сеть в Docker, которая изолирует контейнеры (аналог VPC в облаке).

3. **`"dev_network"`**:
   - Логическое имя ресурса в Terraform. Это внутреннее имя, используемое в коде Terraform для ссылки на этот ресурс (например, `docker_network.dev_network.name`). Оно не влияет на имя сети в Docker.

4. **`{`**:
   - Открывает блок конфигурации ресурса, где задаются его параметры.

5. **`name = "dev-network"`**:
   - Атрибут ресурса, задающий имя сети в Docker. В данном случае сеть будет называться `dev-network` в Docker. Это имя используется контейнерами для подключения к сети.

6. **`}`**:
   - Закрывает блок конфигурации ресурса.

**Кратко**: Код создаёт Docker-сеть с именем `dev-network`, которая изолирует контейнеры среды `dev`. Логическое имя `dev_network` позволяет ссылаться на сеть в Terraform, например, для подключения контейнеров.

---

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
