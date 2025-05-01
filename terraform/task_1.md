# Terraform

## Task 1

_От меня сразу рекомендация использовать только OpenTofu - это официальный форк от Terraform и синтаксис у них одинаковый. Причем оба ПО заблокированы на территории РФ, но с OpenTofu всё гораздо проще. Компания [HashCorp](https://en.wikipedia.org/wiki/HashiCorp) сделала всё, чтобы Terraform не работал на территории РФ._

### **Как установить и запустить Terraform на Debian?**

#### 1. Качаем [OpenTofu отсюда](https://github.com/opentofu/opentofu/releases) в виде пакета [tofu_1.9.1_amd64.deb](https://github.com/opentofu/opentofu/releases/download/v1.9.1/tofu_1.9.1_amd64.deb)
- `wget https://github.com/opentofu/opentofu/releases/download/v1.9.1/tofu_1.9.1_amd64.deb`
- Если сайт не открывается, то используем VPN
- Почему-то с разной периодичностью архивы скачиваются битыми или не скачиваются вообще (официальный сайт Terraform)
- Поэтому в случае сбоев качаем напрямую в Windows и кладем `.deb` через проводник MobaXterm в нужную директорию в Linux
- Установка `sudo dpkg -i tofu_1.9.1_amd64.deb`

#### 2. Проверяем в консоли (OpenTofu автоматом будет доступен в системе)
- `tofu version`
- И выведет версию (качаем последнюю, не RC, не Alpha, не Beta)

#### 3. Включаем обязательно автодополнение в консоли
- `tofu -install-autocomplete`
- Применяем изменения `source ~/.bashrc`
- Готово, пробуем `tofu ver...` + `tab`

#### 4. Ручная загрузка провайдеров (так как скорее всего зеркала будут недоступны)
- Найдите нужный провайдер (например, hashicorp/local) на сайте [GitHub Releases](https://github.com/opentofu/terraform-provider-local/releases)
- Скачайте и распакуйте в папку плагинов:

```bash
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.5.2/linux_amd64
wget https://releases.hashicorp.com/terraform-provider-local/2.5.2/terraform-provider-local_2.5.2_linux_amd64.zip
unzip terraform-provider-local_2.5.2_linux_amd64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.5.2/linux_amd64
```

- Предварительно должна быть создана директория в домашнем каталоге `~/.terraform.d/plugins`
- Предварительно рядом должен быть создан одноименный файл в домашнем каталоге `touch ~/.terraformrc`

#### 5. В файл `.tofurc` вписываем следующий конфиг (долгий способ, но работает железобетонно, таким образом OpenTofu будет смотреть в скачанные вами провайдеры локально):

```hcl
provider_installation {
  filesystem_mirror {
    path = "~/.terraform.d/plugins"
  }
}
```

#### 6. Способ с альтернативными зеркалами. В файл `.tofurc` вписываем следующий конфиг (для загрузки провайдеров [с вашего зеркала](https://terraform-registry-mirror.ru/) - способ быстрый и работает на территории РФ):

```hcl
provider_installation {
  network_mirror {
    url = "https://terraform-registry-mirror.ru/"
  }
  direct {
    exclude = ["registry.terraform.io/*/*", "releases.hashicorp.com/*/*"]
  }
}
```

- А также для этого способа необходимо поднять [docker + docker compose по ссылке](https://terraform-registry-mirror.ru/):
  - Это неофициальное, но рабочее зеркало на территории РФ, которое завязано на контейнер

```yaml
services:
  terraform-registry-mirror:
    image: ghcr.io/jonasasx/terraform-registry-mirror:0.0.9
    ports:
      - "8080:8080"
```

### **Теперь Terraform установлен и готов к работе!**

**Первые шаги:**

Чтобы начать, создайте новую папку для своего проекта, например `terraform-project`. Внутри создайте файл с именем `main.tf` (или любым другим именем с расширением `.tf`).

1. **Пример простого `main.tf`:**
_Terraform смотрит в директорию `plugins` локальных провайдеров - способ рекомендуется!_

```hcl
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

resource "local_file" "example" {
  filename = "hello.txt"
  content  = "Hello, Terraform-OpenTofu!"
}
```

2. **Как запустить этот пример:**

1.  Перейдите в папку `вашего_проекта` в терминале.
2.  Выполните `tofu init`. Terraform запустит провайдер `local`.
3.  Выполните `tofu plan`. Вы увидите, что Terraform планирует создать один ресурс (`local_file`).
4.  Выполните `tofu apply`. Подтвердите действие, введя `yes`. Terraform создаст файл `hello.txt` в текущей папке с указанным содержимым. Вы также увидите вывод `file_path`.
5.  Чтобы удалить созданный файл, выполните `tofu destroy`. Подтвердите действие.

---

_Это очень простой пример, но он показывает основной цикл работы с Terraform. Обычно вы будете описывать гораздо более сложные вещи: серверы в облаке, сети, базы данных и т.д., используя соответствующие провайдеры (AWS, GCP, Azure и т.д.)._
