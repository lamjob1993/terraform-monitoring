# Terraform

## Task 1

**Как установить и запустить Terraform на Debian?**

1. Качаем бинарь Terraform из [официального репозитория](https://releases.hashicorp.com/terraform)
    - Или качаем [OpenTofu отсюда](https://github.com/opentofu/opentofu/releases) в виде пакета [tofu_1.9.1_amd64.deb](https://github.com/opentofu/opentofu/releases/download/v1.9.1/tofu_1.9.1_amd64.deb)
    - `wget https://github.com/opentofu/opentofu/releases/download/v1.9.1/tofu_1.9.1_amd64.deb`
    - Если сайт не открывается, то используем VPN
    - Почему-то с разной периодичностью архивы скачиваются битыми или не скачиваются вообще (официальный сайт Terraform)
    - Поэтому качаем архив напрямую в Windows и кладем через проводник MobaXterm в нужную директорию в Linux (либо качаем сразу рабочий `.deb` пакет OpenTofu)
    - Установка `sudo dpkg -i tofu_1.9.1_amd64.deb`
2. Ставим архиватор unzip - `sudo apt install unzip`
    - `unzip terraform_x.x.x_linux_amd64.zip`
    - Для пакета `.deb` этот раздел пропускаем
2. Кладем бинарь в `/usr/local/bin` и назначаем права `+x`, если не назначены
    - `sudo cp terraform /usr/local/bin/`
    - Для пакета `.deb` этот раздел пропускаем
3. Проверяем в консоли (terraform автоматом будет доступен в системе)
    - `terraform version`
    - `tofu version`
    - И выведет версию (качаем последнюю, не RC, не Alpha, не Beta)

**Теперь Terraform установлен и готов к работе!**

**Первые шаги:**

Чтобы начать, создай новую папку для своего проекта, например `terraform-hello`. Внутри создай файл с именем `main.tf` (или любым другим именем с расширением `.tf`).

**Пример простого `main.tf` (создание локального файла):**

```hcl
# Указываем, что будем использовать провайдер "local"
# для работы с локальными файлами.
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "2.5.2" # Укажите актуальную версию провайдера, если нужно
    }
  }
}

# Описываем ресурс: локальный файл
resource "local_file" "hello" {
  # Имя файла, который будет создан
  filename = "${path.module}/hello.txt" # Эта строка говорит Terraform: "Создай файл с именем hello.txt в том же каталоге"
  # Содержимое файла
  content  = "Привет от Terraform!"
}

# Опционально: выводим путь к созданному файлу после применения
output "file_path" {
  value = local_file.hello.filename
}
```

**Как запустить этот пример:**

1.  Перейди в папку `terraform-hello` в терминале.
2.  Выполни `terraform init`. Terraform скачает провайдер `local`.
    - Если Terraform не скачивает провайдер и выдает ошибку, то [кладем локальный провайдер вручную](https://hc-releases.website.cloud.croc.ru/terraform-provider-local/) по адресу: `~/.terraform.d/plugins/registry.terraform.io/hashicorp/local/2.5.2/linux_amd64/`
    - А также вы можете столкнуться с проблемой с VPN и снова с проблемой битых архивов, значит нужно проделать путь, как в п.1
    - Или же можете воспользоваться зеркалами репозиториев [из раздела](https://github.com/lamjob1993/terraform-monitoring/blob/main/terraform/README.md)
3.  Выполните `terraform plan`. Вы увидите, что Terraform планирует создать один ресурс (`local_file.hello`).
4.  Выполните `terraform apply`. Подтвердите действие, введя `yes`. Terraform создаст файл `hello.txt` в текущей папке (filename = "${path.module}/hello.txt") с указанным содержимым. Вы также увидите вывод `file_path`.
5.  Чтобы удалить созданный файл, выполните `terraform destroy`. Подтвердите действие.

Это очень простой пример, но он показывает основной цикл работы с Terraform. Обычно вы будете описывать гораздо более сложные вещи: серверы в облаке, сети, базы данных и т.д., используя соответствующие провайдеры (AWS, GCP, Azure и т.д.).
