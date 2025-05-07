# Terraform

_Для подобного рода задач заводится таска в Jira (вкратце в описании описывается план проведения работ, выставляется время проведения работ, указывается исполнитель и ответственный), прикладывается документация в формате `.docx`, где прописано построчно, что будет происходить, и что делать в случае сбоя (откат). То есть вот вам еще одна строчка в резюме - придумайте, как её красиво расписать._

## **Task 2**

### Разворачивание пустых контейнеров (далее объясняю почему)

Условно у вас по рабочей задаче нужно на платформу TEST задеплоить пустые VM-ки (их заказали тестировщики), протестировать работоспособность, обновить и внедрить:

- Нужно написать Terraform IaC темплейт для раворачивания x14 пустых контейнеров Docker с ОС Debian.
  - Почему не используем Docker Compose, ведь это гораздо проще? Потому что вспоминаем, что у нас в реальности по рабочим задачам будут VM-ки от x20 до x50 или больше для чего Terraform и предназначен - разворачивание инфраструктуры (разворачивание условных виртуалок и прочих провайдеров), которые будут изолированы друг от друга на уровне гипервизора.
  - **То есть с этого этапа держим мысленно в голове контейнеры за VM-ки** (мы это делаем для экономии ресурсов и скорости, потому что ждать на домашнем ноутбуке или ПК, пока Terraform задеплоит x5-10 VM, у которых по 5-10Gb SSD - это очень долго).
- Пока что учимся разворачивать пустые контейнеры в вакууме, но в следующем репозитории Ansible мы накатим на контейнеры (VM-ки) инфру мониторинга.
  - Для того чтобы поддерживать работу контейнера в фоне пробрасываем в аргумент CMD каждого контейнера `tail -f /dev/null`.

### Успешное выполнение задачи:

```bash
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

docker_image.debian: Creating...
docker_image.debian: Creation complete after 0s [id=sha256:b2ab84c007feae81d95c5350d44ad7a54ea4693a79cb40fb05bd3fe00cbd4d26debian:latest]
docker_container.empty_debian_container[5]: Creating...
docker_container.empty_debian_container[3]: Creating...
docker_container.empty_debian_container[8]: Creating...
docker_container.empty_debian_container[12]: Creating...
docker_container.empty_debian_container[10]: Creating...
docker_container.empty_debian_container[2]: Creating...
docker_container.empty_debian_container[4]: Creating...
docker_container.empty_debian_container[9]: Creating...
docker_container.empty_debian_container[7]: Creating...
docker_container.empty_debian_container[13]: Creating...
docker_container.empty_debian_container[10]: Creation complete after 1s [id=c2ec60aa763177ef4fe2269fa08bbfd241489a4fbe19654b1dbe9a77c5aef694]
docker_container.empty_debian_container[1]: Creating...
docker_container.empty_debian_container[3]: Creation complete after 2s [id=a21dd048ccd8bd6f5e1f42f9b7fabe2e05cd5e3790e87d709f9f080e856d2192]
docker_container.empty_debian_container[6]: Creating...
docker_container.empty_debian_container[12]: Creation complete after 2s [id=bcc5a64a5e3eca56249d704525d5408c0e9ec141efdc81adea452d5a49cd68ae]
docker_container.empty_debian_container[0]: Creating...
docker_container.empty_debian_container[4]: Creation complete after 2s [id=584029b46257118b153bfbb19931988309f2163b555b5eed256a0513057400be]
docker_container.empty_debian_container[11]: Creating...
docker_container.empty_debian_container[2]: Creation complete after 2s [id=289a6277f8232b4fb0200fcf690cd4a79d73b86e235a8b8ae7fd846a4278f541]
docker_container.empty_debian_container[13]: Creation complete after 1s [id=598bf1e02566b13b64237083ac67919ac93c3d6949971a6f0710c66df8d91838]
docker_container.empty_debian_container[8]: Creation complete after 2s [id=6db1a39ff1f9d56ecd6416067034c5d4fc68919583fa31fb7788da952dcd3ad2]
docker_container.empty_debian_container[5]: Creation complete after 2s [id=ccbda374860d28949e9f7254b01455a572fe40ac3708a0ccdfd67deb0138855f]
docker_container.empty_debian_container[9]: Creation complete after 1s [id=b73d40a94bcab49189238268566199b21868b97b1a88a75bcc8e9110b775b454]
docker_container.empty_debian_container[7]: Creation complete after 1s [id=72070f6a82d73b71a114a1dac7ada2870f246be31bc5b97dfb22c602cd978490]
docker_container.empty_debian_container[1]: Creation complete after 1s [id=4036b8a31de87b369adcc33d4d501577d348f72d4f38496302be80f5960b1775]
docker_container.empty_debian_container[11]: Creation complete after 0s [id=f99e253667b368c07039645772cf39b7d60ccc571dcbe0895462c6c0ca27e5c7]
docker_container.empty_debian_container[0]: Creation complete after 0s [id=f46b8b3c5381a24d005dcb8657a373bd375ea80fcba6849109700dc3d5688a80]
docker_container.empty_debian_container[6]: Creation complete after 0s [id=ea60e9854ba269bd2372cdb5542128319e891d9f5e7d37a33321ee9bcd33898d]

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
lamjob@lamjob-VirtualBox:~/Documents/terraform/arch_mon$ dockerps
dockerps: command not found
lamjob@lamjob-VirtualBox:~/Documents/terraform/arch_mon$ docker ps
CONTAINER ID   IMAGE          COMMAND               CREATED         STATUS         PORTS     NAMES
f99e253667b3   b2ab84c007fe   "tail -f /dev/null"   8 seconds ago   Up 7 seconds             debian-container-11
f46b8b3c5381   b2ab84c007fe   "tail -f /dev/null"   8 seconds ago   Up 7 seconds             debian-container-0
ea60e9854ba2   b2ab84c007fe   "tail -f /dev/null"   8 seconds ago   Up 7 seconds             debian-container-6
4036b8a31de8   b2ab84c007fe   "tail -f /dev/null"   8 seconds ago   Up 8 seconds             debian-container-1
598bf1e02566   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-13
72070f6a82d7   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-7
b73d40a94bca   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-9
584029b46257   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-4
ccbda374860d   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-5
a21dd048ccd8   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-3
bcc5a64a5e3e   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-12
c2ec60aa7631   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-10
6db1a39ff1f9   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-8
289a6277f823   b2ab84c007fe   "tail -f /dev/null"   9 seconds ago   Up 8 seconds             debian-container-2
```

---

- После успешного запуска контейнеров сохраните изменения в GitHub репозиторий.
