Процесс создания инфраструктуры с использованием Terraform для запуска контейнеров на Debian-основе с установкой Node Exporter, Prometheus и Grafana через Ansible можно разделить на несколько ключевых этапов. Давайте рассмотрим пошагово, как это можно организовать.

### 1. **Подготовка окружения и выбор контейнеризации**

Для начала определимся с контейнеризацией. Учитывая, что нужно работать в Debian-окружении, не использовать Docker, и использовать легковесные решения, я предлагаю два основных варианта:

* **LXC (Linux Containers)**: Это нативное решение для контейнеризации в Linux. Оно работает с использованием системы namespaces, cgroups и других стандартных инструментов ядра Linux. LXC более легковесен, чем Docker, так как не имеет лишних слоев абстракции.

* **Podman**: Это альтернативная к Docker система для работы с контейнерами, которая также поддерживает OCI-совместимые контейнеры и не требует использования демона. Это облегчает настройку и делает решение более легковесным.

Рассмотрим LXC как решение для создания контейнеров, поскольку оно интегрируется в систему, не требует дополнительного демона и является более подходящим для Debian-систем.

### 2. **Структура проекта**

Вот как можно организовать проект:

* **Инфраструктура с Terraform**: С помощью Terraform создадим виртуальные машины (VM), которые будут использовать LXC для создания контейнеров.
* **Конфигурации для Ansible**: Напишем Ansible-игры, которые будут устанавливать на контейнеры Node Exporter, на Prometheus и Grafana.
* **Интеграция с Prometheus и Grafana**: Настроим Prometheus на сбор метрик с каждого контейнера и передадим эти данные в Grafana для визуализации.

### 3. **Как развернуть проект**

#### Структура файлов проекта:

```
terraform/
├── main.tf               # Основной конфиг для Terraform
├── variables.tf          # Переменные
├── outputs.tf            # Выводы
ansible/
├── inventory.ini         # Инвентарный файл
├── playbooks/
│   ├── install_node_exporter.yml   # Установка Node Exporter
│   ├── install_prometheus.yml      # Установка Prometheus
│   └── install_grafana.yml         # Установка Grafana
```

### 4. **Terraform: создание виртуалок и контейнеров LXC**

Для начала, создадим файл `main.tf`, который будет запускать виртуальные машины и настраивать контейнеры через LXC.

```hcl
provider "lxc" {
  endpoint = "unix:///var/lib/lxd/unix.socket"
}

resource "lxc_container" "debian_container" {
  count = 10

  name        = "debian-container-${count.index}"
  image       = "images:debian/11"
  architecture = "x86_64"
  profiles    = ["default"]

  # Монтирование нужных директорий
  rootfs      = "/var/lib/lxd/storage-pools/default/containers/debian-container-${count.index}"
  networks    = ["lxcbr0"]
}

resource "lxc_container" "centos_container" {
  count = 10

  name        = "centos-container-${count.index}"
  image       = "images:centos/8"
  architecture = "x86_64"
  profiles    = ["default"]

  rootfs      = "/var/lib/lxd/storage-pools/default/containers/centos-container-${count.index}"
  networks    = ["lxcbr0"]
}
```

**Комментарии:**

* Мы создаем 10 контейнеров Debian и 10 контейнеров CentOS.
* В качестве образов используем официальные образы Debian 11 и CentOS 8.
* Все контейнеры используют профиль по умолчанию и подключаются к сети `lxcbr0`.

#### Переменные для настройки

Создадим файл `variables.tf` для параметризации:

```hcl
variable "container_count" {
  description = "Number of containers"
  type        = number
  default     = 20
}

variable "container_os" {
  description = "List of operating systems for containers"
  type        = list(string)
  default     = ["debian", "centos"]
}
```

#### Выводы (outputs.tf)

```hcl
output "container_names" {
  value = flatten([
    for os in var.container_os : [
      for i in range(var.container_count) : "${os}-container-${i}"
    ]
  ])
}
```

### 5. **Ansible: Установка ПО (Node Exporter, Prometheus и Grafana)**

#### Установка Node Exporter на контейнеры

В `install_node_exporter.yml` будет такой playbook:

```yaml
---
- name: Install Node Exporter on containers
  hosts: all
  become: true
  tasks:
    - name: Install dependencies
      apt:
        name:
          - curl
          - wget
        state: present
        update_cache: yes

    - name: Download Node Exporter
      get_url:
        url: "https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz"
        dest: "/tmp/node_exporter.tar.gz"

    - name: Extract Node Exporter
      unarchive:
        src: "/tmp/node_exporter.tar.gz"
        dest: "/opt/"
        remote_src: yes

    - name: Create systemd service for Node Exporter
      template:
        src: "node_exporter.service.j2"
        dest: "/etc/systemd/system/node_exporter.service"

    - name: Start Node Exporter
      systemd:
        name: node_exporter
        state: started
        enabled: yes
```

**Комментарии:**

* Playbook устанавливает Node Exporter на каждый контейнер.
* Скачивает архив, распаковывает и создаёт systemd-сервис для автозапуска.

#### Установка Prometheus

Создадим playbook для установки Prometheus `install_prometheus.yml`:

```yaml
---
- name: Install Prometheus
  hosts: all
  become: true
  tasks:
    - name: Download Prometheus
      get_url:
        url: "https://github.com/prometheus/prometheus/releases/download/v2.33.0/prometheus-2.33.0.linux-amd64.tar.gz"
        dest: "/tmp/prometheus.tar.gz"

    - name: Extract Prometheus
      unarchive:
        src: "/tmp/prometheus.tar.gz"
        dest: "/opt/"
        remote_src: yes

    - name: Create systemd service for Prometheus
      template:
        src: "prometheus.service.j2"
        dest: "/etc/systemd/system/prometheus.service"

    - name: Start Prometheus
      systemd:
        name: prometheus
        state: started
        enabled: yes
```

#### Установка Grafana

Для установки Grafana, создадим playbook `install_grafana.yml`:

```yaml
---
- name: Install Grafana
  hosts: all
  become: true
  tasks:
    - name: Add Grafana APT repository
      apt_repository:
        repo: "deb https://packages.grafana.com/oss/deb stable main"
        state: present

    - name: Install Grafana
      apt:
        name: grafana
        state: present
        update_cache: yes

    - name: Start Grafana service
      systemd:
        name: grafana-server
        state: started
        enabled: yes
```

### 6. **Как запускать проект**

1. **Запуск Terraform**:
   Сначала нужно применить Terraform, чтобы создать виртуальные машины и контейнеры:

   ```bash
   terraform init
   terraform apply
   ```

2. **Запуск Ansible**:
   Для каждой группы контейнеров используем Ansible для установки ПО:

   ```bash
   ansible-playbook -i inventory.ini ansible/playbooks/install_node_exporter.yml
   ansible-playbook -i inventory.ini ansible/playbooks/install_prometheus.yml
   ansible-playbook -i inventory.ini ansible/playbooks/install_grafana.yml
   ```

3. **Конфигурация Prometheus и Grafana**:

   * Настроим конфиг Prometheus для сбора метрик с контейнеров.
   * В Grafana добавим источник данных Prometheus и настроим дашборды для отображения метрик.

### Заключение

Этот проект включает настройку контейнеров через LXC, установку Node Exporter, Prometheus и Grafana с помощью Ansible, а также развертывание и управление инфраструктурой через Terraform. Процесс запуска контейнеров, настройки мониторинга и отображения метрик можно автоматизировать через комбинацию этих инструментов.
