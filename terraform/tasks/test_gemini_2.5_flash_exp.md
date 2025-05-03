Отлично, давайте спроектируем и опишем полный гайд по созданию инфраструктуры для мониторинга тестовых контейнеров с использованием стандартных инструментов Debian, Terraform и Ansible, без Docker.

**Рассуждение о выборе контейнеризации**

Выбор стандартной, легковесной контейнеризации, встроенной в Debian по умолчанию (или доступной из стандартных репозиториев без сторонних источников), исключая Docker, сводится к нескольким основным вариантам:

1.  **`chroot`**: Самый простой и базовый метод. Он лишь меняет корневую файловую систему для процесса, но не предоставляет изоляции процессов, сети, PID и т.д. Не подходит для запуска полноценных операционных систем и изоляции служб мониторинга.
2.  **`systemd-nspawn`**: Встроен в systemd (стандартный init-менеджер в современных Debian). Предоставляет изоляцию пространств имен (PID, mount, network, UTS, IPC), изоляцию файловой системы, контроль ресурсов через cgroups. Позволяет запустить практически полноценный дистрибутив Linux внутри. Легковесен, прост в использовании через команду `systemd-nspawn`. Однако управление большим количеством персистентных контейнеров, их сетью и жизненным циклом извне (например, Terraform) может быть менее стандартизированным по сравнению с LXC.
3.  **`LXC (Linux Containers)`**: Более зрелое и функциональное решение по сравнению с `systemd-nspawn`. Также использует пространства имен ядра и cgroups для создания полноценных контейнеров уровня операционной системы. Имеет развитый набор инструментов командной строки (`lxc-create`, `lxc-start`, `lxc-attach`, `lxc-ls`, `lxc-info` и т.д.) и библиотеку liblxc. Поддерживает различные сетевые конфигурации (NAT, мост). Исторически был очень популярен до появления Docker и остается надежным выбором для OS-контейнеризации.

**Выбор для данного проекта:**

Для задачи запуска **20 персистентных контейнеров**, управляемых извне с помощью Terraform и Ansible, **LXC** является наиболее подходящим выбором среди "стандартных" Debian-средств.

* Он предоставляет необходимый уровень изоляции для запуска полноценных ОС и служб (Node Exporter).
* У него есть более стандартизированный API и набор инструментов, облегчающих интеграцию с внешними системами управления.
* Существуют **проверенные сообществом провайдеры Terraform** для управления LXC контейнерами.
* Ansible имеет специальные connection плагины или может использовать `lxc exec` через стандартные плагины для работы внутри контейнеров.

`systemd-nspawn` хорош для простых случаев или интеграции с systemd юнит-файлами, но для массового управления из Terraform, LXC предоставляет более зрелую платформу.

**Провайдер Terraform для LXC:**

Наиболее распространенным провайдером Terraform для LXC является провайдер сообщества **`lxc`** (обычно находится на GitHub как `terraform-provider-lxc`). Хотя он не является официальным провайдером HashiCorp, он широко используется и функционален для базовых операций с контейнерами LXC. Мы будем использовать его.

---

**Полный гайд: Установка и Настройка Мониторинга LXC Контейнеров**

Этот гайд описывает, как использовать Terraform для создания 20 LXC контейнеров (смесь Debian и CentOS-подобных), а затем Ansible для установки Node Exporter в каждый контейнер, а Prometheus и Grafana на хост-машину для их мониторинга.

**Архитектура:**

1.  **Хост-машина:** Виртуальная машина с Debian. На ней установлены Terraform, Ansible, LXC, Prometheus и Grafana.
2.  **LXC Контейнеры:** 20 контейнеров, работающих на хост-машине. Половина - Debian, половина - CentOS-подобные (мы будем использовать образ CentOS Stream). На каждом установлен Node Exporter.
3.  **Сеть:** LXC контейнеры будут использовать мостовую сеть (`lxcbr0` по умолчанию), чтобы получить IP-адреса и быть доступными с хоста.
4.  **Мониторинг:** Prometheus на хосте собирает метрики с Node Exporter в контейнерах. Grafana на хосте визуализирует эти метрики из Prometheus.

**Предварительные требования:**

На вашей Debian хост-машине должно быть установлено следующее:

1.  **Debian 10+**: Современная версия Debian.
2.  **LXC**: `sudo apt update && sudo apt install lxc`
3.  **Terraform**: Следуйте инструкциям на [официальном сайте Terraform](https://developer.hashicorp.com/terraform/downloads).
4.  **Ansible**: `sudo apt update && sudo install ansible`
5.  **Python3 и pip**: Обычно уже установлены, но убедитесь: `sudo apt install python3 python3-pip`.
6.  **Python библиотека для LXC**: `pip install pylxd` (Ansible может ее использовать).

**Шаг 1: Настройка LXC на хосте**

Убедитесь, что LXC установлен и настроена сеть по умолчанию (`lxcbr0`).

* Установка LXC: `sudo apt update && sudo apt install lxc lxd bridge-utils`
* Инициализация LXD (если вы используете его вместо чистого LXC, LXD более современный менеджер): `sudo lxd init`. В большинстве случаев можете выбирать параметры по умолчанию, включая создание моста `lxdbr0`. Если вы используете чистый LXC, мост `lxcbr0` должен создаться автоматически при установке.
* Проверьте мост: `ip a show lxcbr0` или `ip a show lxdbr0`. У него должен быть IP-адрес (например, 10.0.3.1).

**Шаг 2: Структура Проекта**

Создайте следующую структуру каталогов:

```
.
├── ansible/
│   ├── roles/
│   │   ├── node_exporter/
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   ├── prometheus/
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   └── grafana/
│   │       └── tasks/
│   │           └── main.yml
│   ├── inventory.yml          # Ansible Inventory (будет обновляться/генерироваться)
│   └── playbook.yml           # Главный плейбук Ansible
└── terraform/
    ├── versions.tf            # Определение провайдера
    ├── variables.tf           # Переменные
    ├── main.tf                # Описание ресурсов (контейнеры LXC)
    └── outputs.tf             # Вывод данных для Ansible
```

**Шаг 3: Конфигурация Terraform**

Перейдите в каталог `terraform/`.

**`versions.tf`**

```terraform
# Определение требуемой версии Terraform и провайдера LXC
terraform {
  # Требуемая версия Terraform
  required_version = ">= 1.0"

  # Определение провайдеров
  required_providers {
    # Провайдер LXC (сообщество)
    # Источник: https://github.com/terraform-lxc/terraform-provider-lxc
    lxc = {
      source = "terraform-lxc/lxc"
      version = ">= 1.5.0" # Используйте актуальную версию
    }
  }
}

# Конфигурация провайдера LXC
# В данном случае достаточно дефолтной конфигурации для подключения к локальному LXC/LXD демону
provider "lxc" {}
```

**`variables.tf`**

```terraform
# Переменная для количества контейнеров
variable "container_count" {
  # Описание переменной
  description = "Количество LXC контейнеров для создания."
  # Тип переменной (число)
  type        = number
  # Значение по умолчанию
  default     = 20
  # Проверка значения (должно быть больше 0)
  validation {
    condition     = var.container_count > 0
    error_message = "Количество контейнеров должно быть положительным числом."
  }
}

# Список конфигураций контейнеров (для for_each)
# Определяем локальную переменную для генерации списка конфигураций
locals {
  # Генерируем список карт для каждого контейнера
  container_configs = [
    # Создаем цикл от 0 до container_count - 1
    for i in range(var.container_count) :
    {
      # Имя контейнера (форматируем с ведущими нулями)
      name = "node-${format("%02d", i + 1)}"
      # Определяем тип ОС, чередуя debian и centos
      os_type = (i % 2 == 0 ? "debian" : "centos")
      # Определяем версию ОС в зависимости от типа
      os_release = (i % 2 == 0 ? "bookworm" : "stream9") # bookworm для Debian, stream9 для CentOS
    }
  ]
}
```

**`main.tf`**

```terraform
# Создание LXC контейнеров
# Используем for_each для создания множества ресурсов из локальной переменной container_configs
resource "lxc_container" "test_node" {
  # Ключ для каждого ресурса в for_each (имя контейнера)
  for_each = { for config in local.container_configs : config.name => config }

  # Имя контейнера берется из ключа for_each
  name = each.key
  # Описание контейнера
  comment = "Тестовый узел для мониторинга"

  # Конфигурация образа ОС
  #distribution = "debian" # Указывается в each.value.os_type
  #release      = "bookworm" # Указывается в each.value.os_release
  #architecture = "amd64" # Можно указать архитектуру, если нужно

  # Более универсальный способ задания образа через source
  source {
    type        = "image"
    protocol    = "lxd" # Если используется LXD
    certificate = ""    # Пустой сертификат для локального подключения
    mode        = "pull"
    # Имя образа в формате <дистрибутив>/<релиз>/<архитектура>
    # Или более просто: <дистрибутив>/<релиз>
    alias       = "${each.value.os_type}/${each.value.os_release}"
  }


  # Конфигурация сети
  network_device {
    # Тип сетевого устройства (виртуальный Ethernet)
    type    = "bridged"
    # Имя сетевого интерфейса внутри контейнера
    name    = "eth0"
    # Имя моста на хосте, к которому подключается контейнер
    # Обычно это lxcbr0 для чистого LXC или lxdbr0 для LXD
    bridge  = "lxdbr0" # Укажите правильное имя вашего моста (lxcbr0 или lxdbr0)
    # Параметры устройства (например, MAC-адрес, если нужен статический)
    # params = {
    #   "macaddress" = "00:16:3E:XX:XX:XX"
    # }
  }

  # Конфигурация ресурсов (опционально, но полезно для тестов)
  # limits = {
  #   "cpu" = "0.5" # Ограничение CPU
  #   "memory" = "512MB" # Ограничение памяти
  # }

  # Старт контейнера после создания
  start = true

  # Таймаут ожидания старта контейнера
  wait_for_network = true # Ждать получения IP-адреса
  # custom_init_commands = ["apt update", "apt upgrade -y"] # Команды для выполнения после старта (опционально)
}
```

* **Важно:** Замените `"lxdbr0"` в блоке `network_device` на `"lxcbr0"`, если вы используете только чистый LXC без LXD. Узнать имя моста можно командой `ip a`.

**`outputs.tf`**

```terraform
# Вывод имен созданных контейнеров
output "container_names" {
  # Описание вывода
  description = "Список имен созданных LXC контейнеров."
  # Значение: список ключей из for_each ресурса lxc_container.test_node
  value       = keys(lxc_container.test_node)
}

# Вывод IP-адресов контейнеров (если провайдер поддерживает получение IP)
# Примечание: Получение IP-адресов контейнеров через провайдер LXC может быть ненадежным
# или требовать специфической настройки DHCP. Более надежный способ - использовать
# Ansible для получения IP или использовать resolvible имена/добавлять в /etc/hosts.
# Этот вывод может быть пустым или содержать устаревшие данные.
# output "container_ips" {
#   description = "Список IP-адресов созданных LXC контейнеров."
#   value       = [for container in lxc_container.test_node : container.network_device.0.params["ipv4.address"]]
# }

# Вместо получения IP через провайдер, мы можем просто вывести имена для использования в Ansible
# Ansible может использовать connection plugin 'lxc' или получать IP самостоятельно.
# Для простоты, будем полагаться на имена и 'lxc' connection plugin или resolvible имена.
```

**Шаг 4: Конфигурация Ansible**

Перейдите в каталог `ansible/`.

**`inventory.yml`**

Ansible может подключаться к LXC контейнерам несколькими способами. Самый простой для этого случая - использовать connection plugin `community.general.lxc`. Этот плагин выполняет команды на хосте с помощью `lxc exec`.

Следовательно, inventory файл будет простым, просто перечисляя имена контейнеров. Мы будем генерировать этот файл на основе вывода Terraform.

```yaml
# Файл inventory.yml (будет сгенерирован или обновлен)

# Группа для всех контейнеров
[containers]
# Здесь будут перечислены имена контейнеров из вывода Terraform
# Например:
# node-01
# node-02
# ...
# node-20

# Группа для хоста, где работают Prometheus и Grafana
[monitoring_host]
localhost ansible_connection=local # Prometheus и Grafana будут на хосте
```

**Как обновить `inventory.yml`:** После запуска Terraform, вы можете получить список имен контейнеров с помощью `terraform output container_names`. Затем вручную добавить их в раздел `[containers]` файла `inventory.yml`. Или использовать простой скрипт для автоматизации.

**`playbook.yml`**

```yaml
---
# Главный плейбук для настройки мониторинга

# Задача 1: Настройка Node Exporter на контейнерах
- name: Настройка Node Exporter на контейнерах
  # Цель: группа containers из inventory
  hosts: containers
  # Использование connection plugin lxc
  # Требует установки коллекции community.general: ansible-galaxy collection install community.general
  connection: community.general.lxc
  # Переменные для роли Node Exporter (если нужны)
  # vars:
  #   node_exporter_version: "1.7.0"
  # Запуск роли node_exporter
  roles:
    - node_exporter

# Задача 2: Настройка Prometheus на хосте
- name: Настройка Prometheus на хосте
  # Цель: группа monitoring_host из inventory
  hosts: monitoring_host
  # Используем локальное подключение к хосту
  connection: local
  # Запуск роли prometheus
  roles:
    - prometheus

# Задача 3: Настройка Grafana на хосте
- name: Настройка Grafana на хосте
  # Цель: группа monitoring_host из inventory
  hosts: monitoring_host
  # Используем локальное подключение к хосту
  connection: local
  # Запуск роли grafana
  roles:
    - grafana
```

* **Важно:** Для использования `connection: community.general.lxc` установите коллекцию Ansible: `ansible-galaxy collection install community.general`.

**`ansible/roles/node_exporter/tasks/main.yml`**

Этот плейбук будет работать *внутри* контейнеров с помощью `lxc` connection.

```yaml
---
# tasks file for node_exporter role

# Переменные для Node Exporter (можно определить в playbook.yml или в role vars)
# node_exporter_version: "1.7.0"
# node_exporter_url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
# node_exporter_binary_path: "/usr/local/bin/node_exporter"
# node_exporter_user: "node_exporter"
# node_exporter_group: "node_exporter"

# Задача: Обновить кеш пакетов (для Debian и CentOS)
- name: Обновить кеш пакетов
  # Используем разные модули в зависимости от дистрибутива контейнера
  # ansible_distribution - факт, доступный внутри контейнера
  ansible.builtin.apt:
    update_cache: yes
  when: ansible_distribution == 'Debian'

- name: Обновить кеш пакетов (CentOS)
  ansible.builtin.yum:
    state: latest
    name: '*'
  when: ansible_distribution == 'CentOS'

# Задача: Установить необходимые пакеты (например, curl, tar)
- name: Установить зависимости
  ansible.builtin.package:
    name:
      - curl
      - tar
    state: present

# Задача: Создать пользователя и группу для Node Exporter
- name: Создать группу '{{ node_exporter_group | default("node_exporter") }}'
  ansible.builtin.group:
    name: "{{ node_exporter_group | default('node_exporter') }}"
    state: present

- name: Создать пользователя '{{ node_exporter_user | default("node_exporter") }}'
  ansible.builtin.user:
    name: "{{ node_exporter_user | default('node_exporter') }}"
    shell: /sbin/nologin
    system: yes
    createhome: no
    group: "{{ node_exporter_group | default('node_exporter') }}"
    state: present

# Задача: Определить актуальную версию и URL Node Exporter, если не заданы
# Пример, если не заданы переменные node_exporter_version/url
- name: Получить последнюю версию Node Exporter (если не задана)
  ansible.builtin.uri:
    url: https://api.github.com/repos/prometheus/node_exporter/releases/latest
    method: GET
    return_content: yes
  register: latest_release
  when: node_exporter_version is not defined

- name: Установить URL и версию из последней версии
  ansible.builtin.set_fact:
    node_exporter_version: "{{ latest_release.json.tag_name | regex_replace('v','') }}"
    node_exporter_url: "https://github.com/prometheus/node_exporter/releases/download/{{ latest_release.json.tag_name }}/node_exporter-{{ latest_release.json.tag_name | regex_replace('v','') }}.linux-amd64.tar.gz"
  when: node_exporter_version is not defined

# Задача: Скачать архив Node Exporter
- name: Скачать архив Node Exporter
  ansible.builtin.get_url:
    url: "{{ node_exporter_url }}"
    dest: "/tmp/node_exporter-{{ node_exporter_version }}.tar.gz"
    mode: '0644'
    checksum: "" # Можно добавить checksum для безопасности

# Задача: Распаковать архив
- name: Распаковать архив Node Exporter
  ansible.builtin.unarchive:
    src: "/tmp/node_exporter-{{ node_exporter_version }}.tar.gz"
    dest: "/tmp/"
    remote_src: yes # Источник на удаленной машине (контейнере)

# Задача: Скопировать бинарник Node Exporter в /usr/local/bin
- name: Скопировать бинарник Node Exporter
  ansible.builtin.copy:
    src: "/tmp/node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter"
    dest: "{{ node_exporter_binary_path | default('/usr/local/bin/node_exporter') }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: yes

# Задача: Удалить временные файлы
- name: Удалить временные файлы Node Exporter
  ansible.builtin.file:
    path: "/tmp/node_exporter-{{ node_exporter_version }}.linux-amd64"
    state: absent
  ignore_errors: yes # Игнорируем ошибку, если каталог уже удален

- name: Удалить архив Node Exporter
  ansible.builtin.file:
    path: "/tmp/node_exporter-{{ node_exporter_version }}.tar.gz"
    state: absent
  ignore_errors: yes

# Задача: Создать systemd service файл для Node Exporter
- name: Создать systemd service файл для Node Exporter
  ansible.builtin.copy:
    content: |
      [Unit]
      Name=Node Exporter
      Wants=network-online.target
      After=network-online.target

      [Service]
      User={{ node_exporter_user | default("node_exporter") }}
      Group={{ node_exporter_group | default("node_exporter") }}
      Type=simple
      ExecStart={{ node_exporter_binary_path | default('/usr/local/bin/node_exporter') }} --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

      [Install]
      WantedBy=multi-user.target
    dest: /etc/systemd/system/node_exporter.service
    owner: root
    group: root
    mode: '0644'

# Задача: Создать каталог для textfile collector (если используется)
- name: Создать каталог для textfile collector
  ansible.builtin.file:
    path: /var/lib/node_exporter/textfile_collector
    state: directory
    owner: "{{ node_exporter_user | default('node_exporter') }}"
    group: "{{ node_exporter_group | default('node_exporter') }}"
    mode: '0755'

# Задача: Перезагрузить systemd daemon
- name: Перезагрузить systemd daemon
  ansible.builtin.systemd:
    daemon_reload: yes

# Задача: Включить Node Exporter в автозагрузку
- name: Включить Node Exporter в автозагрузку
  ansible.builtin.systemd:
    name: node_exporter
    enabled: yes

# Задача: Запустить службу Node Exporter
- name: Запустить службу Node Exporter
  ansible.builtin.systemd:
    name: node_exporter
    state: started

# Задача: Проверить статус службы (опционально)
- name: Проверить статус Node Exporter
  ansible.builtin.command: systemctl status node_exporter
  changed_when: false
  ignore_errors: yes
```

**`ansible/roles/prometheus/tasks/main.yml`**

Этот плейбук будет работать *на хосте*.

```yaml
---
# tasks file for prometheus role

# Переменные для Prometheus (можно определить в playbook.yml или в role vars)
# prometheus_version: "2.52.0" # Используйте актуальную версию
# prometheus_url: "https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-amd64.tar.gz"
# prometheus_install_dir: "/usr/local/bin"
# prometheus_config_dir: "/etc/prometheus"
# prometheus_data_dir: "/var/lib/prometheus"
# prometheus_user: "prometheus"
# prometheus_group: "prometheus"
# prometheus_port: 9090

# Задача: Создать пользователя и группу для Prometheus
- name: Создать группу '{{ prometheus_group | default("prometheus") }}'
  ansible.builtin.group:
    name: "{{ prometheus_group | default('prometheus') }}"
    system: yes
    state: present

- name: Создать пользователя '{{ prometheus_user | default("prometheus") }}'
  ansible.builtin.user:
    name: "{{ prometheus_user | default('prometheus') }}"
    shell: /sbin/nologin
    system: yes
    createhome: no
    group: "{{ prometheus_group | default('prometheus') }}"
    state: present

# Задача: Создать необходимые каталоги для Prometheus
- name: Создать каталоги для Prometheus
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ prometheus_user | default('prometheus') }}"
    group: "{{ prometheus_group | default('prometheus') }}"
    mode: '0755'
  loop:
    - "{{ prometheus_config_dir | default('/etc/prometheus') }}"
    - "{{ prometheus_data_dir | default('/var/lib/prometheus') }}"

# Задача: Получить последнюю версию Prometheus (если не задана)
- name: Получить последнюю версию Prometheus (если не задана)
  ansible.builtin.uri:
    url: https://api.github.com/repos/prometheus/prometheus/releases/latest
    method: GET
    return_content: yes
  register: latest_release
  when: prometheus_version is not defined

- name: Установить URL и версию из последней версии
  ansible.builtin.set_fact:
    prometheus_version: "{{ latest_release.json.tag_name | regex_replace('v','') }}"
    prometheus_url: "https://github.com/prometheus/prometheus/releases/download/{{ latest_release.json.tag_name }}/prometheus-{{ latest_release.json.tag_name | regex_replace('v','') }}.linux-amd64.tar.gz"
  when: prometheus_version is not defined

# Задача: Скачать архив Prometheus
- name: Скачать архив Prometheus
  ansible.builtin.get_url:
    url: "{{ prometheus_url }}"
    dest: "/tmp/prometheus-{{ prometheus_version }}.tar.gz"
    mode: '0644'
    checksum: "" # Можно добавить checksum

# Задача: Распаковать архив
- name: Распаковать архив Prometheus
  ansible.builtin.unarchive:
    src: "/tmp/prometheus-{{ prometheus_version }}.tar.gz"
    dest: "/tmp/"
    remote_src: yes

# Задача: Скопировать бинарники Prometheus
- name: Скопировать бинарники Prometheus
  ansible.builtin.copy:
    src: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }}"
    dest: "{{ prometheus_install_dir | default('/usr/local/bin') }}/{{ item }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: yes
  loop:
    - prometheus
    - promtool

# Задача: Скопировать консольные файлы
- name: Скопировать консольные файлы Prometheus
  ansible.builtin.copy:
    src: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }}"
    dest: "{{ prometheus_config_dir | default('/etc/prometheus') }}/{{ item }}"
    owner: "{{ prometheus_user | default('prometheus') }}"
    group: "{{ prometheus_group | default('prometheus') }}"
    mode: '0644'
    remote_src: yes
  loop:
    - consoles/
    - console_libraries/

# Задача: Создать основной конфигурационный файл prometheus.yml
# Важно: Здесь нужно определить цели сбора метрик (контейнеры)
- name: Создать prometheus.yml
  ansible.builtin.template:
    # Создадим отдельный шаблонный файл для гибкости
    src: prometheus.yml.j2
    dest: "{{ prometheus_config_dir | default('/etc/prometheus') }}/prometheus.yml"
    owner: "{{ prometheus_user | default('prometheus') }}"
    group: "{{ prometheus_group | default('prometheus') }}"
    mode: '0644'
  # Перезапустить Prometheus при изменении конфига
  notify: Restart prometheus

# Задача: Удалить временные файлы
- name: Удалить временные файлы Prometheus
  ansible.builtin.file:
    path: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64"
    state: absent
  ignore_errors: yes

- name: Удалить архив Prometheus
  ansible.builtin.file:
    path: "/tmp/prometheus-{{ prometheus_version }}.tar.gz"
    state: absent
  ignore_errors: yes

# Задача: Создать systemd service файл для Prometheus
- name: Создать systemd service файл для Prometheus
  ansible.builtin.copy:
    content: |
      [Unit]
      Description=Prometheus Server
      Documentation=https://prometheus.io/docs/
      Wants=network-online.target
      After=network-online.target

      [Service]
      User={{ prometheus_user | default("prometheus") }}
      Group={{ prometheus_group | default("prometheus") }}
      Type=simple
      ExecStart={{ prometheus_install_dir | default('/usr/local/bin') }}/prometheus \
        --config.file {{ prometheus_config_dir | default('/etc/prometheus') }}/prometheus.yml \
        --storage.tsdb.path {{ prometheus_data_dir | default('/var/lib/prometheus') }} \
        --web.listen-address=":{{ prometheus_port | default(9090) }}" \
        --web.enable-lifecycle

      [Install]
      WantedBy=multi-user.target
    dest: /etc/systemd/system/prometheus.service
    owner: root
    group: root
    mode: '0644'
  notify: Reload systemd

# Обработчики (Handlers) для перезагрузки сервисов
handlers:
  - name: Reload systemd
    ansible.builtin.systemd:
      daemon_reload: yes

  - name: Restart prometheus
    ansible.builtin.systemd:
      name: prometheus
      state: restarted

# Задача: Перезагрузить systemd daemon (выполняется через handler)
# - name: Перезагрузить systemd daemon
#   ansible.builtin.systemd:
#     daemon_reload: yes

# Задача: Включить Prometheus в автозагрузку
- name: Включить Prometheus в автозагрузку
  ansible.builtin.systemd:
    name: prometheus
    enabled: yes

# Задача: Запустить службу Prometheus
- name: Запустить службу Prometheus
  ansible.builtin.systemd:
    name: prometheus
    state: started

# Задача: Проверить статус службы (опционально)
- name: Проверить статус Prometheus
  ansible.builtin.command: systemctl status prometheus
  changed_when: false
  ignore_errors: yes
```

**`ansible/roles/prometheus/templates/prometheus.yml.j2`**

Нам нужно добавить цели для сбора метрик. Если контейнеры получают IP-адреса через DHCP на мосту `lxcbr0`/`lxdbr0`, самый надежный способ - добавить эти IP-адреса в `/etc/hosts` на хосте или использовать имена контейнеров, если они разрешаются на мосте. Для простоты, предположим, что имена контейнеров разрешаются на хосте (например, благодаря настройке моста LXC/LXD или добавлению в `/etc/hosts`).

```yaml
# prometheus.yml - Главный конфигурационный файл Prometheus

global:
  # Интервал между сборами метрик
  scrape_interval:     15s # По умолчанию каждые 15 секунд. Можно переопределить на уровне job.
  # Интервал для оценки правил записи/оповещения
  evaluation_interval: 15s # По умолчанию каждые 15 секунд. Можно переопределить на уровне rule.

  # Имя кластера, используемое в метриках
  # external_labels:
  #   monitor: 'my-monitor-system'

# Файлы правил (если используются)
# rule_files:
#   - "first_rules.yml"
#   - "second_rules.yml"

# Конфигурации для сбора метрик (scrape configs)
scrape_configs:
  # Job для сбора метрик с самого Prometheus
  - job_name: 'prometheus'
    # Статическая конфигурация целей
    static_configs:
      # Цель: localhost на порту Prometheus (9090)
      - targets: ['localhost:{{ prometheus_port | default(9090) }}']

  # Job для сбора метрик с Node Exporter в контейнерах
  - job_name: 'node_exporter_containers'
    # Перезаписать интервал сбора для этой job (опционально)
    scrape_interval: 10s
    # Перезаписать таймаут сбора (опционально)
    scrape_timeout: 10s

    # Статическая конфигурация целей для контейнеров
    static_configs:
      # Получаем список имен контейнеров из переменной Ansible
      # Эта переменная должна быть доступна из плейбука,
      # например, передана как extra vars или получена из inventory
      # В данном случае, inventory.yml содержит группу [containers]
      # Мы можем использовать hostvars для получения информации,
      # но для connection=lxc hostvars будут содержать инфу о хосте.
      # Проще всего, если имена контейнеров разрешаются на хосте,
      # или использовать список IP, полученный из Terraform/Ansible фактов.

      # Предполагаем, что имена контейнеров из группы 'containers' резолвятся на хосте
      # или что мы можем использовать их имена для lxc connection.
      # Для static_configs нужны АДРЕСА:ПОРТ.
      # Если имена контейнеров разрешаются на хосте (например, через /etc/hosts),
      # то можно использовать имена. Иначе нужны IP.

      # Вариант 1: Предполагаем резолв имен на хосте
      # targets:
      #   {% for container_name in groups['containers'] %}
      #   - '{{ container_name }}:9100'
      #   {% endfor %}

      # Вариант 2: Если у вас есть список IP (например, из вывода Terraform или Ansible фактов)
      # Передайте этот список как переменную Ansible, например 'container_ips_list'
      #
      # targets:
      #   {% for container_ip in container_ips_list %}
      #   - '{{ container_ip }}:9100'
      #   {% endfor %}

      # Вариант 3 (Самый надежный для этого сетапа):
      # Если контейнеры доступны по имени хоста на bridge сети,
      # и этот bridge доступен с хоста, то имена должны резолвиться.
      # Проверить можно с хоста: ping node-01 (после их запуска).
      # Если резолвится, используем имена.
      # Если нет, нужно настроить DNS или добавлять в /etc/hosts на хосте (через Ansible).
      # Добавление в /etc/hosts на хосте через Ansible - хороший подход.

      # Добавляем задачу в роль prometheus для обновления /etc/hosts на хосте.
      # Тогда здесь можно использовать имена.

      # Вариант 3 (предполагая, что имена контейнеров добавлены в /etc/hosts на хосте)
      targets:
        {% for container_name in groups['containers'] %}
        - '{{ container_name }}:9100'
        {% endfor %}

    # Настройки relabeling (опционально)
    relabel_configs:
      # Добавить метку instance с именем контейнера
      - source_labels: [__address__]
        regex: '([^:]+):9100' # Захватываем имя хоста/IP
        target_label: instance
        replacement: '$1' # Используем захваченное значение

      # Добавить метку job (уже есть из job_name)
      # Добавить метку __metrics_path__ (по умолчанию /metrics)
```

* **Важно:** В роли `prometheus` добавьте задачу для обновления `/etc/hosts` на хосте, чтобы имена контейнеров разрешались в их IP-адреса на мостовой сети. Это можно сделать до создания `prometheus.yml`. Пример задачи:

```yaml
# В ansible/roles/prometheus/tasks/main.yml, перед задачей "Создать prometheus.yml"
- name: Обновить /etc/hosts на хосте с IP контейнеров
  # Эта задача выполняется на хосте
  ansible.builtin.lineinfile:
    path: /etc/hosts
    line: "{{ hostvars[item].ansible_facts.ipv4.address }} {{ item }}" # Предполагаем, что Ansible собрал факты об IP контейнеров
    state: present
  loop: "{{ groups['containers'] }}" # Проходим по именам контейнеров в группе
  # Условие: Эта задача требует, чтобы Ansible мог получить IP-адреса контейнеров.
  # При использовании lxc connection, факты hostvars[item] будут содержать инфу о хосте, а не контейнере item.
  # **Альтернатива:** Использовать команду lxc list и парсить вывод для получения IP.
  # Или использовать динамический inventory скрипт.
  # Или, самый простой путь, если DHCP на lxcbr0/lxdbr0 выдает предсказуемые IP,
  # или если имена контейнеров РЕЗОЛВЯТСЯ на хосте по умолчанию через bridge-utils/lxd.

  # **Упрощенный подход:** Если имена контейнеров разрешаются на хосте через мост,
  # то задача обновления /etc/hosts может быть не нужна, и можно использовать targets: ['{{ container_name }}:9100'].
  # **Проверьте:** После запуска контейнеров, попробуйте с хоста `ping node-01`.
  # Если пинг идет по IP на мостовой сети, значит имена разрешаются.

  # Если имена НЕ разрешаются и IP НЕ статичные, нужно более сложное получение IP.
  # Давайте предположим, что имена разрешаются на хосте через bridge.
  # В этом случае, задача обновления /etc/hosts не нужна для *этого* конкретного плейбука,
  # но это зависит от вашей точной настройки LXC/LXD сети.
  # Оставим шаблон prometheus.yml.j2 с использованием имен `{{ container_name }}:9100`.
```
**Пересмотр `/etc/hosts`:** Если `lxc` connection plugin используется, Ansible факты `hostvars[item]` будут относиться к *хосту*, а не к контейнеру `item`. Чтобы получить IP контейнера, нужно либо использовать другой способ подключения (например, SSH, настроенный внутри контейнеров), либо выполнить команду на хосте `lxc list --format json` и парсить ее, либо полагаться на то, что имена контейнеров разрешаются на хосте в IP-адреса на мостовой сети. **Самый простой путь для этого гайда, полагаясь на lxc connection:** Предположим, что имена контейнеров (`node-01`, `node-02` и т.д.) автоматически становятся разрешимыми на хосте через механизм мостовой сети LXC/LXD. Это часто работает "из коробки" с настройками по умолчанию. **В этом случае, задача обновления `/etc/hosts` в роли prometheus НЕ НУЖНА.** Prometheus сможет собирать метрики, обращаясь по имени контейнера на порт 9100.

**`ansible/roles/grafana/tasks/main.yml`**

Этот плейбук будет работать *на хосте*.

```yaml
---
# tasks file for grafana role

# Переменные для Grafana (можно определить в playbook.yml или в role vars)
# grafana_package: "grafana" # Имя пакета Grafana в репозитории Debian
# grafana_version: "10.4.3" # Можно указать конкретную версию, если репозиторий не используется
# grafana_port: 3000

# Задача: Добавить APT репозиторий Grafana (рекомендуется для получения свежих версий)
- name: Добавить ключ репозитория Grafana
  ansible.builtin.apt_key:
    url: https://apt.grafana.com/gpg.key
    state: present

- name: Добавить репозиторий Grafana в sources.list
  ansible.builtin.apt_repository:
    repo: "deb https://apt.grafana.com/ stable main"
    state: present
    update_cache: yes

# Задача: Установить пакет Grafana
- name: Установить пакет Grafana
  ansible.builtin.apt:
    name: "{{ grafana_package | default('grafana') }}"
    state: present

# Задача: Включить и запустить службу Grafana
- name: Включить и запустить службу Grafana
  ansible.builtin.systemd:
    name: grafana-server
    enabled: yes
    state: started

# Задача: Проверить статус службы (опционально)
- name: Проверить статус Grafana
  ansible.builtin.command: systemctl status grafana-server
  changed_when: false
  ignore_errors: yes

# Задача: Настроить источник данных Prometheus в Grafana (API)
# Это более продвинутая задача, требующая работы с API Grafana.
# Проще настроить вручную через веб-интерфейс первый раз.
# Для автоматизации можно использовать модули community.grafana.* или запрос к API.
# Пока оставим это для ручной настройки.

# Примечание: Чтобы автоматизировать добавление источника данных,
# вам потребуется установить коллекцию community.grafana
# ansible-galaxy collection install community.grafana
# Использовать модуль grafana_datasource:
# - name: Добавить источник данных Prometheus в Grafana
#   community.grafana.grafana_datasource:
#     name: Prometheus
#     type: prometheus
#     url: "http://localhost:{{ prometheus_port | default(9090) }}"
#     access: proxy
#     basic_auth: false
#     is_default: true
#     auth_basic_user: ""
#     auth_basic_password: ""
#     state: present
#     # Учетные данные администратора Grafana (по умолчанию admin/admin)
#     # Это может быть небезопасно, рассмотрите использование API токена
#     grafana_user: admin
#     grafana_password: admin
#     grafana_url: "http://localhost:{{ grafana_port | default(3000) }}"
```

**Шаг 5: Выполнение**

1.  **Инициализация Terraform:** Перейдите в каталог `terraform/`.
    ```bash
    cd terraform/
    terraform init
    ```
    Terraform загрузит провайдер LXC.

2.  **Создание контейнеров:**
    ```bash
    terraform plan -out terraform.plan
    terraform apply "terraform.plan"
    ```
    Terraform создаст 20 LXC контейнеров, распределив Debian и CentOS-подобные в соответствии с логикой в `main.tf`. Подождите, пока все контейнеры запустятся.

3.  **Обновление Ansible Inventory:** Получите список имен контейнеров из вывода Terraform.
    ```bash
    terraform output container_names
    ```
    Вручную скопируйте этот список и вставьте его в файл `ansible/inventory.yml` под секцию `[containers]`.

    ```yaml
    # ansible/inventory.yml
    [containers]
    node-01
    node-02
    ...
    node-20

    [monitoring_host]
    localhost ansible_connection=local
    ```
    * **Примечание:** В реальной среде можно автоматизировать этот шаг с помощью скрипта или использовать динамический inventory, который запрашивает состояние LXC через команду `lxc list`.

4.  **Запуск Ansible плейбуков:** Перейдите в каталог `ansible/`.
    ```bash
    cd ../ansible/
    # Убедитесь, что коллекция community.general установлена
    ansible-galaxy collection install community.general
    # Запустите главный плейбук
    ansible-playbook playbook.yml
    ```
    Ansible подключится к каждому контейнеру с помощью `lxc` connection, установит Node Exporter, затем установит Prometheus и Grafana на хост-машину, настроит Prometheus для сбора метрик с контейнеров.

**Шаг 6: Проверка**

1.  **Проверка контейнеров:** На хост-машине выполните:
    ```bash
    lxc list
    ```
    Вы должны увидеть 20 запущенных контейнеров с именами `node-XX`. Убедитесь, что у них есть IP-адреса в мостовой сети (`lxcbr0`/`lxdbr0`).

2.  **Проверка Node Exporter:** Выберите один из контейнеров (например, `node-01`) и получите его IP-адрес из `lxc list`. С хоста попробуйте получить метрики:
    ```bash
    curl http://<IP_контейнера_node-01>:9100/metrics
    ```
    Вы должны увидеть вывод метрик Node Exporter.

3.  **Проверка Prometheus:** Откройте веб-браузер на хост-машине и перейдите по адресу `http://localhost:9090`.
    * Перейдите в раздел `Status` -> `Targets`.
    * Вы должны увидеть `node_exporter_containers` job и 20 целей (`node-01:9100`, `node-02:9100` и т.д.) со статусом `UP`.

4.  **Проверка Grafana:** Откройте веб-браузер на хост-машине и перейдите по адресу `http://localhost:3000`.
    * Войдите (логин/пароль по умолчанию `admin`/`admin`, вас попросят сменить пароль).
    * Добавьте источник данных (Data Source) типа `Prometheus`, указав URL Prometheus `http://localhost:9090`. Установите его как дефолтный.
    * Импортируйте готовый дашборд для Node Exporter (например, ID 1860 из [Grafana Dashboards](https://grafana.com/grafana/dashboards/)). Выберите ваш Prometheus как источник данных.
    * Вы должны увидеть метрики с ваших контейнеров на дашборде. Используйте фильтр `instance` для выбора конкретного контейнера.

**Шаг 7: Очистка**

Когда тестовая инфраструктура больше не нужна, вы можете удалить ее.

1.  **Остановка и удаление контейнеров с помощью Terraform:** Перейдите в каталог `terraform/`.
    ```bash
    cd terraform/
    terraform destroy
    ```
    Terraform запросит подтверждение и удалит все созданные им LXC контейнеры.

2.  **Удаление Prometheus и Grafana (опционально):** Вы можете удалить установленные пакеты с хоста вручную или с помощью отдельного Ansible плейбука.
    ```bash
    sudo apt remove prometheus grafana-server
    sudo apt purge prometheus grafana-server # Для удаления конфигов
    sudo rm -rf /etc/prometheus /var/lib/prometheus /etc/grafana /var/lib/grafana
    ```

**Важные замечания и потенциальные проблемы:**

* **Сетевая конфигурация LXC/LXD:** Убедитесь, что мостовая сеть (`lxcbr0` или `lxdbr0`) настроена корректно и контейнеры получают IP-адреса, доступные с хоста. В некоторых случаях может потребоваться настройка NAT или правил файрвола на хосте. По умолчанию, LXC/LXD часто настраивает это автоматически.
* **Разрешение имен:** Как упоминалось, для Prometheus важно уметь обращаться к Node Exporter по адресу. Если имена контейнеров (`node-XX`) не разрешаются автоматически на хосте через мостовую сеть, вам нужно либо добавить их в `/etc/hosts` на хосте (вручную или с помощью Ansible), либо настроить DNS в вашей сети, либо использовать IP-адреса контейнеров в конфигурации Prometheus (что сложнее автоматизировать с динамическими IP).
* **Производительность:** Запуск 20 контейнеров (пусть и легковесных) может потребовать значительных ресурсов (RAM, CPU) на хост-машине. Убедитесь, что ваша VM имеет достаточно ресурсов.
* **Стабильность провайдера Terraform LXC:** Провайдер сообщества может иметь свои особенности и быть менее стабильным, чем официальные провайдеры. Следите за его версиями и документацией.
* **Различия между Debian и CentOS-подобными:** Ansible плейбуки используют факты `ansible_distribution` для выполнения дистрибутиво-специфичных задач (например, установка пакетов через `apt` или `yum`). Это важно для совместимости.

Этот гайд предоставляет полную пошаговую инструкцию по созданию тестовой среды мониторинга с использованием инструментов, которые хорошо интегрируются в экосистему Debian без использования Docker.
