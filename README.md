## Sudo No Password

Скрипт позволяет включать или отключать выполнение sudo без запроса пароля для выбранных пользователей, создавая или удаляя соответствующие файлы в `/etc/sudoers.d/` через меню.

1. Скачать скрипт
```bash
wget -O ./sudo_nopasswd_toggle.sh https://raw.githubusercontent.com/teplostanski/servercare/main/sudo_nopasswd_toggle.sh && chmod +x ./sudo_nopasswd_toggle.sh
```
2. Запустить
```bash
sudo ./sudo_nopasswd_toggle.sh
```
