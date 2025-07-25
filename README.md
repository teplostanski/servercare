## No Sudo Password

Скрипт позволяет включать или отключать выполнение sudo без запроса пароля для выбранных пользователей, создавая или удаляя соответствующие файлы в `/etc/sudoers.d/` через меню.

1. Скачать скрипт
```bash
wget -O ./nosudopass.sh https://raw.githubusercontent.com/teplostanski/servercare/main/nosudopass.sh && chmod +x ./nosudopass.sh
```
2. Запустить
```bash
sudo ./nosudopass.sh
```
