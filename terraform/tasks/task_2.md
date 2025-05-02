
### Практика

#### Создание конфигурации

Создайте файл `main.tf` со следующим содержимым:

```hcl
provider "docker" {}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx" {
  name  = "nginx-container"
  image = docker_image.nginx.latest
  ports {
    internal = 80
    external = 8080
  }
}
```

#### Инициализация и применение конфигурации

1. Инициализируйте рабочий каталог:

   ```bash
   terraform init
   ```
2. Создайте план изменений:

   ```bash
   terraform plan
   ```
3. Примените изменения:

   ```bash
   terraform apply
   ```

После выполнения этих шагов, Nginx будет доступен по адресу [http://localhost:8080](http://localhost:8080).

---
