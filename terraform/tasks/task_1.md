# Terraform

## Task 1

- По данному репозиторию и таскам переходим на Ubuntu 22.04 + 25Gb SSD + 4 Cores CPU + 4Gb RAM.
- Для стабильной работы Terraform используем NAT + VPN, желательно Amnezia, можно и любой другой работающий стабильно. 

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

#### 4. Используем способ с альтернативными зеркалами

- В предварительно созданный вами файл в корне домашней директории `~/.tofurc` вписываем следующий конфиг для загрузки провайдеров [с зеркала](https://terraform-registry-mirror.ru/) - способ относительно быстрый и работает на территории РФ:

```hcl
provider_installation {
  network_mirror {
    url = "https://terraform-registry-mirror.ru/"
  }
}
```

- А также для этого способа необходимо поднять [docker + docker compose по ссылке](https://terraform-registry-mirror.ru/):
  - Это неофициальное, но рабочее зеркало на территории РФ, которое завязано на контейнер (в `hcl` конфиге выше мы прописывали для него зеркало: `https://terraform-registry-mirror.ru/`), Docker Compose:

```yaml
services:
  terraform-registry-mirror:
    image: ghcr.io/jonasasx/terraform-registry-mirror:0.0.9
    ports:
      - "8080:8080"
```

- [И переходим ниже к практике](https://github.com/lamjob1993/terraform-monitoring/blob/main/terraform/tasks/task_1.md#%D1%82%D0%B5%D0%BF%D0%B5%D1%80%D1%8C-terraform-%D1%83%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BB%D0%B5%D0%BD-%D0%B8-%D0%B3%D0%BE%D1%82%D0%BE%D0%B2-%D0%BA-%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D0%B5)
- Если способ с зеркалом не работает, то продолжаем следующие пункты

#### 5. Ручная загрузка провайдеров (выполняем только если зеркало не доступно)
- Найдите нужный провайдер (например, hashicorp/local для нашего примера) на сайте [GitHub Releases](https://github.com/orgs/opentofu/repositories?type=all)
- Скачайте и распакуйте в директорию плагинов:

```bash
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.5.2/linux_amd64
wget https://releases.hashicorp.com/terraform-provider-local/2.5.2/terraform-provider-local_2.5.2_linux_amd64.zip
unzip terraform-provider-local_2.5.2_linux_amd64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.5.2/linux_amd64
```

- Предварительно должна быть создана директория `mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.5.2/linux_amd64` в домашнем каталоге

- Предварительно рядом должен быть создан файл `touch ~/.tofurc` в домашнем каталоге

#### 6. В файл `nano ~/.tofurc` вписываем следующий конфиг, долгий способ, но работает точно, таким образом OpenTofu будет смотреть в скачанные вами провайдеры локально (выполняем только если зеркало не доступно):

```hcl
provider_installation {
  filesystem_mirror {
    path = "~/.terraform.d/plugins"
  }
}
```

### **Теперь Terraform установлен и готов к работе!**

**Первые шаги:**

Чтобы начать, создайте новый каталог для своего проекта, например `terraform-project`. Внутри создайте файл с именем `main.tf`.

1. **Пример простого `main.tf`:**

```hcl
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"  # Terraform выбирает нужный провайдер для работы
      version = "2.5.2"
    }
  }
}

resource "local_file" "example" {
  filename = "hello.txt"  # Terraform создает файл hello.txt
  content  = "Hello, Terraform-OpenTofu!"  # Terraform наполняет файл hello.txt содержимым
}
```

2. **Как запустить этот пример:**

1.  Перейдите в каталог `вашего_проекта` в терминале.
2.  Выполните `tofu init`. Terraform скачает и выберет провайдер `local`.
3.  Выполните `tofu plan`. Вы увидите, что Terraform планирует создать один ресурс (`local_file`).
4.  Выполните `tofu apply`. Подтвердите действие, введя `yes`. Terraform создаст файл `hello.txt` в текущей папке с указанным содержимым. Вы также увидите вывод `file_path`.
5.  Чтобы удалить созданный файл, выполните `tofu destroy`. Подтвердите действие.

---

_Это очень простой пример, но он показывает основной цикл работы с Terraform. Обычно вы будете описывать гораздо более сложные вещи: серверы в облаке, сети, базы данных и т.д., используя соответствующие провайдеры (AWS, GCP, Azure и т.д.)._
