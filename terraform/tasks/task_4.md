# Terraform

_Для подобного рода задач заводится таска в Jira (вкратце в описании описывается план проведения работ, выставляется время проведения работ, указывается исполнитель и ответственный), прикладывается документация в формате `.docx`, где прописано построчно, что будет происходить, и что делать в случае сбоя (откат). То есть вот вам еще одна строчка в резюме - придумайте, как её красиво расписать._

## **Task 4**

### Подготовка к плавному переходу в репозиторий Ansible. Разворачивание инфраструктуры мониторинга на три контура: DEV, STAGING и PROD

1. Нужно подготовить каждый контур для деплоя мониторинга:
  - Это **Ansible** плейбук с [нужными ролями](https://github.com/lamjob1993/ansible-monitoring/blob/main/ansible/tasks/monitoring_project/playbook.yml).
  - Плейбук представлен, как будущий проект, где нужно развернуть по 8 контейнеров на каждом контуре [Ansible: Task_3](https://github.com/lamjob1993/ansible-monitoring/blob/main/ansible/tasks/task_3.md)).
2. Далее нужно самостоятельно написать структуру **Terraform** проекта (почти тоже самое, что и в проекте по заданию 3).
3. В данном проекте на каждом контуре должно быть по 8 пустых контейнеров **Debian**, в которые может ходить Ansible:
  - Нужно жестко прописать на каждый контейнер: `openssh` + `systemd`.
  - Завязать на каждый контейнер уникальный IP.
  - Каждый контур должен быть в своей сети Docker.
4. Инфраструктура подготовлена:
  - Не забываем, что на работе мы используем облако на базе OpenStack (SberInfra, Альфа Cloud, ВТБ Cloud и т.д) через провайдер [Terraform OpenStack](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest) и что для нас контейнеры - это VM-ки либо в облачной терминологии - инстансы).
5. Тем самым **Terraform** раскрывается, как IaC по прямому назначению, то есть разворачивает только инфраструктуру (на 3 контура разработки по 8 подготовленных инстансов) описанную кодом (декларативно).
  - К дальнейшей автоматизации развернутой инфры подключается **Ansible**, как IaC по прямому назначению для работы с конфигурациями (императивно-декларативно). 
5. Сохраняем эту Ubuntu VM-ку и не трогаем.
6. Переходим в репозиторий Ansible (текущее задание, как подготовка к [Ansible: Task_3](https://github.com/lamjob1993/ansible-monitoring/blob/main/ansible/tasks/task_3.md)).

---

# Если **Terraform — декларативный**, то **Ansible — императивно-декларативный** (смешанный), с сильным уклоном в **императивный стиль**.


##  В чём разница:

| Характеристика       | **Terraform (декларативный)**                                    | **Ansible (императивный/декларативный)**          |
| -------------------- | ---------------------------------------------------------------- | ------------------------------------------------- |
| **Что описываем**    | *Какое состояние мы хотим получить*                              | *Что нужно сделать, чтобы прийти к цели*          |
| **Как работает**     | Планирует изменения → приводит инфраструктуру в нужное состояние | Выполняет шаги один за другим, как в сценарии     |
| **Пример мышления**  | "Хочу 3 VM с такими параметрами"                                 | "Создай 3 VM вот так: сначала это, потом то..."   |
| **Идемпотентность**  | Встроена (сравнивает текущее и желаемое состояние)               | Зависит от конкретных модулей и задач             |
| **Сфера применения** | Управление инфраструктурой (VM, сети, облака)                    | Настройка конфигурации, установка ПО, оркестрация |

---

###  Аналогия:

* **Terraform** — это архитектор: "Я хочу вот такой дом", и он организует строительство.
* **Ansible** — это прораб: "Сначала закладываем фундамент, потом стены, потом крышу".

---

###  Примеры:

**Terraform (декларативно):**

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-xyz"
  instance_type = "t2.micro"
}
```

**Ansible (императивно-декларативно):**

```yaml
- name: Установка nginx
  hosts: web
  tasks:
    - name: Установить nginx
      apt:
        name: nginx
        state: present
```

---

###  Вывод:

* **Terraform** — декларативен: ты описываешь состояние инфраструктуры.
* **Ansible** — гибрид: ты управляешь процессом пошагово, но можешь использовать декларативные модули (`apt`, `copy`, `template` и др.).


---

# **Полноценный пример пайплайна для OpenStack**, где:

* **Terraform** создаёт виртуальную машину в облаке OpenStack;
* **Ansible** подключается к ней и настраивает nginx.

---

## Предпосылки:

* У тебя есть доступ к OpenStack (auth URL, проект, логин/пароль).
* Есть SSH-ключ, зарегистрированный в OpenStack (например, `my-key`).
* В OpenStack есть образ Ubuntu (например, `Ubuntu-22.04`).

---

## Шаг 1: Terraform — создаёт VM

```hcl
# main.tf
provider "openstack" {
  auth_url    = "https://openstack.example.ru:5000/v3"
  region      = "RegionOne"
  domain_name = "Default"
  tenant_name = "my-project"
  user_name   = "your_user"
  password    = "your_password"
}

resource "openstack_compute_instance_v2" "web" {
  name            = "web-vm"
  image_name      = "Ubuntu-22.04"
  flavor_name     = "m1.small"
  key_pair        = "my-key"
  security_groups = ["default"]

  network {
    name = "private"
  }

  provisioner "local-exec" {
    command = "echo ${self.access_ip_v4} > inventory.txt"
  }
}
```

Обрати внимание:

* `image_name`, `flavor_name`, `network.name` и т.д. должны существовать в твоём OpenStack.
* Созданный IP записывается в `inventory.txt`.

---

## Шаг 2: Ansible — настраивает VM

Создаём Ansible-файлы:

### `inventory.ini` (вручную или из `inventory.txt`):

```
[web]
<ip-из-terraform> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### `nginx.yml`:

```yaml
- name: Установить и запустить nginx
  hosts: web
  become: true
  tasks:
    - name: Обновить apt
      apt:
        update_cache: yes

    - name: Установить nginx
      apt:
        name: nginx
        state: present
```

---

## Порядок запуска

```bash
terraform init
terraform apply
```

Затем (если IP в `inventory.txt`):

```bash
ansible-playbook -i inventory.txt nginx.yml
```

*или вручную подставь IP в `inventory.ini` и запускай:*

```bash
ansible-playbook -i inventory.ini nginx.yml
```

---

## Моно добавить запуск Ansible прямо из Terraform:

```hcl
provisioner "local-exec" {
  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.access_ip_v4},' -u ubuntu --private-key ~/.ssh/id_rsa nginx.yml"
}
```

---
