**Полный гайд: Установка и Настройка Мониторинга Podman Контейнеров**

Этот гайд описывает, как использовать Terraform для создания 20 Podman контейнеров (смесь Debian и CentOS-подобных), а затем Ansible для установки Node Exporter в каждый контейнер, а Prometheus и Grafana на хост-машину для их мониторинга.

**Архитектура:**

1.  **Хост-машина:** Виртуальная машина с Debian. На ней установлен Podman, Terraform, Ansible, Prometheus и Grafana.
2.  **Podman Контейнеры:** 20 контейнеров, работающих на хост-машине под управлением Podman. Половина - Debian, половина - CentOS Stream. На каждом установлен Node Exporter.
3.  **Сеть:** Podman использует свою внутреннюю сеть (по умолчанию `podman0` или пользовательский мост). Контейнеры получат IP-адреса в этой сети, доступные с хоста.
4.  **Мониторинг:** Prometheus на хосте собирает метрики с Node Exporter в контейнерах, обращаясь к ним по их IP-адресам или именам на внутренней сети Podman. Grafana на хосте визуализирует эти метрики из Prometheus.

**Предварительные требования:**

На вашей Debian хост-машине должно быть установлено следующее:

1.  **Debian 11+ (рекомендуется):** Podman лучше всего поддерживается в более новых версиях Debian.
2.  **Podman:** Следуйте инструкциям для Debian на [официальном сайте Podman](https://www.google.com/search?q=https://podman.io/getting-started/installation%23debian-ubuntu-and-derivates). Обычно это `sudo apt update && sudo apt install podman`. Возможно, потребуются дополнительные пакеты типа `podman-plugins`, `netavark` или `cni-plugins`.
3.  **Terraform:** Следуйте инструкциям на [официальном сайте Terraform](https://developer.hashicorp.com/terraform/downloads).
4.  **Ansible:** `sudo apt update && sudo install ansible`.
5.  **Python3 и pip:** Убедитесь, что они установлены: `sudo apt install python3 python3-pip`.
6.  **Python библиотека для работы с Podman (для Ansible):** Возможно, потребуется установить `pip install podman` или `pip install podman-api`. Проверьте требования `community.containers.podman` connection plugin.

**Важное замечание по Podman:**

Podman может работать в двух режимах: "rootful" (от имени root) и "rootless" (от имени обычного пользователя). Режим rootless более безопасен и рекомендуется. Однако настройка сети и других аспектов может быть сложнее в rootless режиме. Для простоты данного гайда и интеграции с системными службами (Prometheus, Grafana), мы будем предполагать использование Podman от имени **root** или пользователя, имеющего необходимые права доступа к сокету Podman. Убедитесь, что Podman демон запущен и доступен.

**Шаг 1: Настройка Podman на хосте**

Установите Podman и убедитесь, что он работает.

  * Установка: `sudo apt update && sudo apt install podman`
  * Проверка версии: `podman --version`
  * Проверка работы (от root или пользователя с правами): `sudo podman info` или `podman info` (для rootless).
  * Убедитесь, что создана сеть по умолчанию: `sudo podman network ls` (должна быть сеть `podman` или `podman0`).

**Шаг 2: Структура Проекта**

Создайте следующую структуру каталогов (аналогично предыдущему гайду):

```
.
├── ansible/
│   ├── roles/
│   │   ├── node_exporter/
│   │   │   └── tasks/
│   │   │       └── main.yml          # Задачи роли Node Exporter (внутри контейнера)
│   │   ├── prometheus/
│   │   │   └── tasks/
│   │   │       └── main.yml          # Задачи роли Prometheus (на хосте)
│   │   │       └── templates/
│   │   │           └── prometheus.yml.j2 # Шаблон конфига Prometheus
│   │   └── grafana/
│   │       └── tasks/
│   │           └── main.yml          # Задачи роли Grafana (на хосте)
│   ├── inventory.yml          # Ansible Inventory (будет обновляться/генерироваться)
│   └── playbook.yml           # Главный плейбук Ansible
└── terraform/
    ├── versions.tf            # Определение провайдера
    ├── variables.tf           # Переменные
    ├── main.tf                # Описание ресурсов (контейнеры Podman)
    └── outputs.tf             # Вывод данных для Ansible
```

**Шаг 3: Конфигурация Terraform**

Перейдите в каталог `terraform/`.

**`versions.tf`**

```terraform
# Определение требуемой версии Terraform и провайдера Podman
terraform {
  # Требуемая версия Terraform
  required_version = ">= 1.0"

  # Определение провайдеров
  required_providers {
    # Провайдер Podman (официальный, от сообщества containers)
    # Источник: registry.terraform.io/containers/podman
    # Документация: https://registry.terraform.io/providers/containers/podman/latest/docs
    podman = {
      source = "containers/podman"
      version = ">= 1.0.0" # Используйте актуальную версию
    }
  }
}

# Конфигурация провайдера Podman
provider "podman" {
  # URL к Podman API сокету.
  # Для rootful обычно "unix:///run/podman/podman.sock"
  # Для rootless может быть "unix:///run/user/$(id -u)/podman/podman.sock"
  # Убедитесь, что путь корректен для вашей установки и режима.
  # Если не указано, провайдер может попытаться определить сам.
  # base_url = "unix:///run/podman/podman.sock"

  # Возможно, потребуется явно указать подключение как root, если запускаете Terraform от обычного пользователя
  # с доступом к rootful сокету через sudo или группы.
  # identity {
  #   kind = "root"
  # }
}
```

  * **Важно:** Укажите правильный `base_url` или убедитесь, что ваш пользователь имеет доступ к сокету Podman. Запуск Terraform от `root` (`sudo terraform apply`) может упростить доступ, но менее предпочтителен с точки зрения безопасности.

**`variables.tf`**

Остается таким же, как и для LXC, определяя количество контейнеров и их типы ОС.

```terraform
# Переменная для количества контейнеров
variable "container_count" {
  # Описание переменной
  description = "Количество Podman контейнеров для создания."
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
      # Определяем тип ОС и тег образа для Podman (Debian и CentOS Stream)
      image = (i % 2 == 0 ? "debian:bookworm" : "centos/stream9:latest") # Используем имена образов из registries
    }
  ]
}
```

**`main.tf`**

Здесь мы заменяем `lxc_container` на `podman_container`.

```terraform
# Создание Podman контейнеров
# Используем for_each для создания множества ресурсов из локальной переменной container_configs
resource "podman_container" "test_node" {
  # Ключ для каждого ресурса в for_each (имя контейнера)
  for_each = { for config in local.container_configs : config.name => config }

  # Имя контейнера берется из ключа for_each
  name = each.key
  # Используемый образ контейнера из registry (например, Docker Hub)
  image = each.value.image

  # Команда, запускаемая в контейнере.
  # Для запуска systemd (необходимо для Node Exporter как службы)
  # обычно используется /sbin/init. Убедитесь, что образ его поддерживает.
  command = ["/sbin/init"]

  # Параметры контейнера (опционально)
  # labels = {
  #   "project" = "monitoring-test"
  # }

  # Конфигурация сети
  # По умолчанию контейнеры подключаются к сети "podman" или "podman0"
  # и получают IP-адреса, доступные с хоста. Явно указывать сеть обычно не нужно,
  # если используется дефолтная.
  # network {
  #  mode = "bridge" # Использует сеть по умолчанию или явно указанный мост
  #  networks = ["podman"] # Явно указать имя сети, если не podman0
  # }

  # Публикация портов (не требуется, т.к. Prometheus на хосте будет обращаться по IP/имени)
  # ports {
  #   host_port = 9100
  #   container_port = 9100
  #   host_ip = "127.0.0.1"
  # }

  # Конфигурация ограничений ресурсов (аналог limits в LXC)
  # Используйте эти лимиты, чтобы ограничить потребление ОЗУ контейнерами
  resource_limits {
     # Ограничение памяти (например, 150 МБ на контейнер)
     # Это очень агрессивно, но может быть необходимо при 4 ГБ ОЗУ всего.
     memory = "150M"
     # Ограничение CPU (опционально, при 8 ядрах можно оставить без явных лимитов)
     # cpus = "0.5" # Эквивалент 50% одного ядра
  }

  # Перезапускать контейнер автоматически при завершении с ошибкой
  # restart = "unless-stopped"

  # Удалить контейнер при завершении
  # remove = true # Не нужно, т.к. Terraform будет управлять жизненным циклом

  # Запустить контейнер сразу после создания
  start = true

  # Таймаут ожидания старта контейнера (опционально)
  # startup_timeout = 60 # в секундах

  # Опционально, для rootless Podman, может потребоваться указать пользователя
  # user = "1000" # UID пользователя на хосте
}
```

**`outputs.tf`**

Остается таким же, как и для LXC, выводя имена созданных контейнеров.

```terraform
# Вывод имен созданных контейнеров
output "container_names" {
  # Описание вывода
  description = "Список имен созданных Podman контейнеров."
  # Значение: список ключей из for_each ресурса podman_container.test_node
  value       = keys(podman_container.test_node)
}

# Примечание: Получение IP-адресов контейнеров через провайдер Podman может быть
# сложным или требовать специфической настройки сети/драйвера.
# Самый надежный способ для Prometheus на хосте - получать IP через ansible
# на этапе настройки или полагаться на разрешение имен (добавив их в /etc/hosts).
```

**Шаг 4: Конфигурация Ansible**

Перейдите в каталог `ansible/`.

**`inventory.yml`**

Структура файла остается прежней. Он будет содержать имена контейнеров (которые мы получим из Terraform) и `localhost` для сервисов мониторинга.

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

  * **Обновление inventory.yml:** После запуска Terraform, получите имена контейнеров командой `terraform output container_names` и вставьте их в секцию `[containers]`.

**`playbook.yml`**

Обновим connection plugin для группы `containers`.

```yaml
---
# Главный плейбук для настройки мониторинга

# Задача 1: Настройка Node Exporter на контейнерах
- name: Настройка Node Exporter на контейнерах
  # Цель: группа containers из inventory
  hosts: containers
  # Использование connection plugin для Podman
  # Требует установки коллекции community.containers: ansible-galaxy collection install community.containers
  connection: community.containers.podman
  # Возможно, потребуется указать пользователя, если Podman работает от root
  # remote_user: root # Используйте root для доступа внутрь контейнера через exec

  # Запуск файла задач роли node_exporter
  roles:
    - node_exporter

# Задача 2: Настройка Prometheus на хосте
- name: Настройка Prometheus на хосте
  # Цель: группа monitoring_host из inventory
  hosts: monitoring_host
  # Используем локальное подключение к хосту
  connection: local
  # Запуск файла задач роли prometheus
  roles:
    - prometheus

# Задача 3: Настройка Grafana на хосте
- name: Настройка Grafana на хосте
  # Цель: группа monitoring_host из inventory
  hosts: monitoring_host
  # Используем локальное подключение к хосту
  connection: local
  # Запуск файла задач роли grafana
  roles:
    - grafana

# Обработчики (Handlers) для перезагрузки служб, определенные в ролях
handlers:
  - name: Reload systemd
    ansible.builtin.systemd:
      daemon_reload: yes

  - name: Restart prometheus
    ansible.builtin.systemd:
      name: prometheus
      state: restarted
```

  * **Важно:** Установите коллекцию Ansible: `ansible-galaxy collection install community.containers`. Возможно, потребуется указать `remote_user: root` в плее для контейнеров, если Podman работает от root и требует root прав для выполнения команд внутри контейнера через `podman exec`.

**`ansible/roles/node_exporter/tasks/main.yml`**

Этот **файл задач роли** будет работать *внутри* Podman контейнеров с помощью `community.containers.podman` connection. Задачи практически идентичны тем, что были для LXC, поскольку они выполняются уже внутри работающей ОС контейнера.

```yaml
---
# Задачи для роли node_exporter

# Задача: Обновить кеш пакетов (для Debian и CentOS)
- name: Обновить кеш пакетов (Debian)
  ansible.builtin.apt:
    update_cache: yes
  when: ansible_distribution == 'Debian'
  # Запустится внутри контейнеров Debian

- name: Обновить кеш пакетов (CentOS)
  ansible.builtin.yum: # Или dnf для CentOS Stream 8/9+
    state: latest
    name: '*'
  when: ansible_distribution == 'CentOS'
  # Запустится внутри контейнеров CentOS Stream

# Задача: Установить необходимые пакеты (curl, tar)
- name: Установить зависимости
  ansible.builtin.package:
    name:
      - curl
      - tar
    state: present

# ... (Остальные задачи на скачивание, установку бинарника Node Exporter,
# создание пользователя/группы, service файла, каталога для textfile collector,
# включение и запуск службы systemd) ...
# Эти задачи идентичны тем, что были в предыдущем гайде для LXC,
# так как они стандартны для установки Node Exporter в Linux.
# Используются стандартные модули Ansible (get_url, copy, file, systemd),
# которые работают внутри контейнера через Podman connection.

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

# (Задачи на получение URL/версии, скачивание, распаковку, копирование бинарника, удаление временных файлов - аналогично LXC гайду)

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
      ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

      [Install]
      WantedBy=multi-user.target
    dest: /etc/systemd/system/node_exporter.service
    owner: root
    group: root
    mode: '0644'

# Задача: Создать каталог для textfile collector
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

Этот **файл задач роли** будет работать *на хосте*. Главное изменение – задача по получению IP-адресов контейнеров Podman и обновлению `/etc/hosts` на хосте.

```yaml
---
# Задачи для роли prometheus

# ... (Задачи на создание пользователя/группы, каталогов,
# скачивание/установку бинарников Prometheus - аналогично LXC гайду) ...

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

# (Задачи на получение URL/версии, скачивание, распаковку, копирование бинарников/консолей, удаление временных файлов - аналогично LXC гайду)

# Задача: Получить IP-адреса Podman контейнеров и обновить /etc/hosts на хосте
# Это необходимо, чтобы Prometheus на хосте мог обращаться к Node Exporter в контейнерах по имени.
- name: Получить IP Podman контейнера '{{ item }}'
  # Выполняем команду podman inspect на хосте (delegate_to: localhost)
  ansible.builtin.command: "podman inspect -f '{{ '{{' }} .NetworkSettings.IPAddress {{ '}}' }}' {{ item }}"
  args:
    # Устанавливаем рабочую директорию, где может быть доступен сокет Podman (если не в стандартном месте)
    chdir: / # Или путь к сокету, если нужно
  register: podman_ip_result
  delegate_to: localhost # Выполнить эту задачу на хосте
  delegate_facts: yes # Сохранить полученные факты (IP) для использования в других задачах

- name: Добавить/обновить запись для '{{ item }}' в /etc/hosts на хосте
  ansible.builtin.lineinfile:
    path: /etc/hosts
    # Формат: IP Имя_контейнера
    line: "{{ podman_ip_result.stdout | trim }} {{ item }}"
    state: present
    create: yes # Создать файл, если не существует
  # Выполняем эту задачу на хосте
  delegate_to: localhost
  # Применяем эту задачу для каждого контейнера из группы 'containers'
  loop: "{{ groups['containers'] }}"
  loop_control:
    loop_var: item # Используем 'item' как имя контейнера в этом цикле

# Задача: Создать основной конфигурационный файл prometheus.yml
# Теперь имена контейнеров должны быть разрешимы на хосте благодаря предыдущей задаче.
- name: Создать prometheus.yml
  ansible.builtin.template:
    src: prometheus.yml.j2 # Шаблонный файл
    dest: "{{ prometheus_config_dir | default('/etc/prometheus') }}/prometheus.yml"
    owner: "{{ prometheus_user | default('prometheus') }}"
    group: "{{ prometheus_group | default('prometheus') }}"
    mode: '0644'
  # Перезапустить Prometheus при изменении конфига (через handler)
  notify: Restart prometheus

# (Задачи на создание systemd service файла, включение в автозагрузку, запуск службы, проверку статуса - аналогично LXC гайду, используют handlers)

# Обработчики (Handlers) - определены в playbook.yml
# - name: Reload systemd
#   ansible.builtin.systemd:
#     daemon_reload: yes
#
# - name: Restart prometheus
#   ansible.builtin.systemd:
#     name: prometheus
#     state: restarted
```

**`ansible/roles/prometheus/templates/prometheus.yml.j2`**

Этот шаблон конфига Prometheus остается таким же, как и для LXC, поскольку он полагается на то, что имена контейнеров разрешаются на хосте (что мы обеспечили задачей обновления `/etc/hosts`).

```yaml
# prometheus.yml - Главный конфигурационный файл Prometheus

global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:{{ prometheus_port | default(9090) }}']

  # Job для сбора метрик с Node Exporter в контейнерах
  - job_name: 'node_exporter_containers'
    scrape_interval: 10s
    scrape_timeout: 10s

    # Статическая конфигурация целей для контейнеров.
    # Используем имена контейнеров, которые мы добавили в /etc/hosts на хосте.
    static_configs:
      targets:
        {% for container_name in groups['containers'] %}
        - '{{ container_name }}:9100'
        {% endfor %}

    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):9100'
        target_label: instance
        replacement: '$1'
```

**`ansible/roles/grafana/tasks/main.yml`**

Этот **файл задач роли** работает *на хосте* и остается практически идентичным версии для LXC.

```yaml
---
# Задачи для роли grafana

# (Задачи на добавление репозитория Grafana, установку пакета,
# включение/запуск службы systemd, проверку статуса - аналогично LXC гайду)

# Задача: Добавить APT репозиторий Grafana
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

# Задача: Настроить источник данных Prometheus в Grafana (через API - опционально, не входит в базовый гайд)
# ... (можно добавить задачи для автоматической настройки источника данных, если используете коллекцию community.grafana)
```

**Шаг 5: Выполнение**

1.  **Инициализация Terraform:** Перейдите в каталог `terraform/`.

    ```bash
    cd terraform/
    # Убедитесь, что у вашего пользователя есть права на работу с Podman
    # Возможно, потребуется выполнить с sudo: sudo terraform init
    terraform init
    ```

    Terraform загрузит провайдер Podman.

2.  **Создание контейнеров:**

    ```bash
    # Возможно, потребуется выполнить с sudo: sudo terraform plan -out terraform.plan
    terraform plan -out terraform.plan
    # Возможно, потребуется выполнить с sudo: sudo terraform apply "terraform.plan"
    terraform apply "terraform.plan"
    ```

    Terraform создаст 20 Podman контейнеров на основе указанных образов. Podman скачает образы, если их нет локально. Подождите, пока все контейнеры запустятся.

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

4.  **Запуск Ansible плейбуков:** Перейдите в каталог `ansible/`.

    ```bash
    cd ../ansible/
    # Установите необходимые коллекции Ansible
    ansible-galaxy collection install community.containers
    ansible-galaxy collection install community.general # Нужна для lxc connection plugin, но может содержать другие полезные модули
    # Запустите главный плейбук
    # Возможно, потребуется выполнить с sudo для доступа к Podman сокету или root прав внутри контейнеров
    # sudo ansible-playbook playbook.yml
    ansible-playbook playbook.yml
    ```

    Ansible выполнит задачи:

      * Подключится к каждому контейнеру Podman с помощью `community.containers.podman` connection plugin.
      * Установит Node Exporter внутри каждого контейнера.
      * Запустит задачи на хосте: получит IP каждого Podman контейнера с помощью `podman inspect` и обновит `/etc/hosts` на хосте, чтобы имена контейнеров разрешались в их IP.
      * Установит Prometheus на хосте и настроит его для сбора метрик с контейнеров по их именам.
      * Установит Grafana на хосте и настроит ее (только установка, источник данных нужно добавить вручную или через API).

**Шаг 6: Проверка**

1.  **Проверка контейнеров:** На хост-машине выполните:

    ```bash
    # Возможно, с sudo: sudo podman ps
    podman ps
    ```

    Вы должны увидеть 20 запущенных контейнеров с именами `node-XX`.

2.  **Проверка разрешения имен и Node Exporter:** Выберите один из контейнеров (например, `node-01`). Попробуйте пропинговать его имя с хоста:

    ```bash
    ping -c 4 node-01
    ```

    Пинг должен идти на IP-адрес контейнера в сети Podman. Затем попробуйте получить метрики:

    ```bash
    curl http://node-01:9100/metrics
    ```

    Вы должны увидеть вывод метрик Node Exporter из контейнера `node-01`. Проверьте несколько контейнеров.

3.  **Проверка Prometheus:** Откройте веб-браузер на хост-машине и перейдите по адресу `http://localhost:9090`.

      * Перейдите в раздел `Status` -\> `Targets`.
      * Вы должны увидеть `node_exporter_containers` job и 20 целей (`node-01:9100`, `node-02:9100` и т.д.) со статусом `UP`.

4.  **Проверка Grafana:** Откройте веб-браузер на хост-машине и перейдите по адресу `http://localhost:3000`.

      * Войдите (логин/пароль по умолчанию `admin`/`admin`, вас попросят сменить пароль).
      * Добавьте источник данных (Data Source) типа `Prometheus`, указав URL Prometheus `http://localhost:9090`. Установите его как дефолтный.
      * Импортируйте готовый дашборд для Node Exporter (например, ID 1860). Выберите ваш Prometheus как источник данных.
      * Вы должны увидеть метрики с ваших контейнеров на дашборде.

**Шаг 7: Очистка**

Когда тестовая инфраструктура больше не нужна, вы можете удалить ее.

1.  **Остановка и удаление контейнеров с помощью Terraform:** Перейдите в каталог `terraform/`.

    ```bash
    cd terraform/
    # Возможно, с sudo: sudo terraform destroy
    terraform destroy
    ```

    Terraform запросит подтверждение и удалит все созданные им Podman контейнеры.

2.  **Очистка записей в /etc/hosts:** Удалите записи, которые были добавлены для контейнеров (`node-XX`). Это можно сделать вручную, отредактировав `/etc/hosts` на хосте.

3.  **Удаление Prometheus и Grafana (опционально):** Удалите установленные пакеты с хоста.

    ```bash
    sudo apt remove prometheus grafana-server
    sudo apt purge prometheus grafana-server # Для удаления конфигов
    sudo rm -rf /etc/prometheus /var/lib/prometheus /etc/grafana /var/lib/grafana
    ```

**Важные замечания и потенциальные проблемы с Podman:**

  * **Режим Rootful vs Rootless:** Если вы используете rootless Podman, настройка доступа Terraform и Ansible к нему требует дополнительных шагов (например, переменные окружения, путь к сокету). Rootful проще для интеграции с системными инструментами, но менее безопасен.
  * **Доступ к Podman API:** Убедитесь, что пользователь, от имени которого запускаются Terraform и Ansible, имеет необходимые права для взаимодействия с Podman (доступ к сокету, членство в группе `podman` и т.д.).
  * **Сеть Podman:** Поведение сети по умолчанию (`podman0`) может различаться. Убедитесь, что контейнеры получают IP, доступные с хоста, и что разрешение имен через `/etc/hosts` работает корректно.
  * **`/sbin/init` в образах:** Не все минимальные образы контейнеров могут корректно работать с `/sbin/init` как PID 1. Если контейнер падает сразу после старта с этой командой, возможно, придется использовать другую команду-заглушку (например, `sleep infinity`), но тогда Node Exporter придется запускать не как systemd службу, а другим способом (например, как процесс под управлением supervisor или запуская его напрямую из ENTRYPOINT/CMD образа, но это уже выходит за рамки данного гайда). Для большинства стандартных образов Debian/CentOS `/sbin/init` работает.
  * **Потребление ресурсов:** Как обсуждалось ранее, 4 ГБ ОЗУ - это очень мало. Установленные лимиты памяти (`resource_limits` в Terraform) критически важны, но могут сделать контейнеры нестабильными. Swap будет активно использоваться.
