# Terraform

## Task 1

**Как установить и запустить Terraform на Debian?**

1. Качаем бинарь Terraform с [официального сайта](https://developer.hashicorp.com/terraform/install#linux) 
    - `curl -O https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_linux_amd64.zip`
2. Ставим архиватор unzip - `sudo apt install unzip`
    - `unzip terraform_YOUR_VERSION_linux_amd64.zip`
2. Кладем в `/usr/local/bin` и назначаем права `+x`, если не назначены
    - `sudo cp terraform /usr/local/bin/`
3. Проверяем в консоли (terraform автоматом будет доступен в системе)
    - `terraform version`
4. Если не качает, если не можете разархивировать, то скачайте Linux AMD64 сначала на Windows, а потом перетащите в свою файловую систему Debian файл `terraform` с помощью MobaXterm и проделайте процедуры указанные с пункта №2

Теперь Terraform установлен и готов к работе!

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
      version = "2.1.0" # Укажите актуальную версию, если нужно
    }
  }
}

# Описываем ресурс: локальный файл
resource "local_file" "hello" {
  # Имя файла, который будет создан
  filename = "${path.module}/hello.txt" # Эта строка говорит Terraform: "Создай файл с именем hello.txt в том же каталоге, где находится этот конфигурационный файл (main.tf), который я сейчас выполняю".
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
3.  Выполни `terraform plan`. Ты увидишь, что Terraform планирует создать один ресурс (`local_file.hello`).
4.  Выполни `terraform apply`. Подтверди действие, введя `yes`. Terraform создаст файл `hello.txt` в текущей папке (filename = "${path.module}/hello.txt") с указанным содержимым. Ты также увидишь вывод `file_path`.
5.  Чтобы удалить созданный файл, выполни `terraform destroy`. Подтверди действие.

Это очень простой пример, но он показывает основной цикл работы с Terraform. Обычно ты будешь описывать гораздо более сложные вещи: серверы в облаке, сети, базы данных и т.д., используя соответствующие провайдеры (AWS, GCP, Azure и т.д.).
