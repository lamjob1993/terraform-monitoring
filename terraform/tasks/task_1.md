# Terraform

## Task 1

- По данному репозиторию и таскам переходим на Ubuntu 22.04 + 25Gb SSD + 4 Cores CPU + 4Gb RAM.
- Для стабильной работы Terraform используем виртуалку в режиме NAT + VPN (на хосте), желательно Amnezia VPN (проверено), можно и любой другой работающий стабильно.

### **Как установить и запустить Terraform?**

- Переходим на [официальную страницу для загрузки](https://developer.hashicorp.com/terraform/install#linux) бинаря AMD64.
- Переходим в [официальный гайд по установке](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) и запуску первого провайдера.
- Ставим обязательно автодополнение по `tab`:
  - `terraform -install-autocomplete`
  - `touch ~/.bashrc`
  - `source ~/.bashrc`

### **Теперь Terraform установлен и готов к работе!**

**Первые шаги:**

- Чтобы начать, создайте новый каталог для своего проекта, например `terraform-project`. Внутри создайте файл с именем `main.tf`.
- Чтобы начать, установите Docker и добавьте пользователя Docker в группу sudo после первой установки Docker в систему. Далее `logout`.

1. **Пример простого `main.tf`:**

```hcl
terraform {
  required_providers {
    docker = {                          # terraform подгружает из репозитория провайдер docker
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}                    # terraform инициализирует провайдер docker

resource "docker_image" "nginx" {       # выбор nginx в качестве image
  name         = "nginx"
  keep_locally = false
}

resource "docker_container" "nginx" {   # создание ресурса (контейнера nginx)
  image = docker_image.nginx.image_id
  name  = "tutorial"                    # создание контейнера с именем tutorial

  ports {                               # пробпрос портов из контейнера на хост
    internal = 80
    external = 8000
  }
}
```

2. **Как запустить этот пример:**

  1.  Перейдите в каталог `вашего_проекта` в терминале.
  2.  Выполните `terraform init`. Terraform скачает и выберет провайдер `docker`.
  3.  Выполните `terraform plan`. Вы увидите, что Terraform планирует создать ресурс (показывает какие изменения terraform собирается внести в инфраструктуру).
  4.  Выполните `terraform apply`. Подтвердите действие, введя `yes`. Terraform создаст контейнер с указанным содержимым. Вы также увидите вывод.
  5.  Чтобы удалить созданный проект, выполните `terraform destroy`. Подтвердите действие, `yes`.

---

_Это очень простой пример, но он показывает основной цикл работы с Terraform. Обычно вы будете описывать гораздо более сложные вещи: серверы в облаке, сети, базы данных и т.д., используя соответствующие провайдеры (AWS, GCP, Azure и т.д.)._
