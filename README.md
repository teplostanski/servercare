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

## omz-plugins-install.sh

Установите `oh-my-zsh`, если не установлен
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
или
```bash
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
```

Скачайте и запустите скрипт
```bash
wget -O ./omz-plugins-install.sh https://raw.githubusercontent.com/teplostanski/servercare/main/omz-plugins-install.sh && chmod +x ./omz-plugins-install.sh && ./omz-plugins-install.sh
```

В конфиге `.zshrc` добавьте плагины
```zsh
plugins=(git zsh-completions zsh-syntax-highlighting zsh-autosuggestions)
```
## ssh_connect_monitor.sh
Скрипт позволяет удобно мониторить SSH соединения

1. Скачать скрипт
```bash
wget -O ./ssh_connect_monitor.sh https://raw.githubusercontent.com/teplostanski/servercare/main/ssh_connect_monitor.sh && chmod +x ./ssh_connect_monitor.sh
```
2. Создать список доверенных IP адресов, для этого необходимо создать файл `white_list_ip.conf` в той же директории что и скрипт

Формат списка: IP_ADDRESS=NAME

Пример: 
```bash
# white_list_ip.conf

101.42.101.42=My_Office
203.73.111.17=Home_WiFi
```

Или скачать и отредактировать [`white_list_ip.conf`](./white_list_ip.conf)

```bash
wget -O ./white_list_ip.conf https://raw.githubusercontent.com/teplostanski/servercare/main/white_list_ip.conf
```

3. Запустить
```bash
./ssh_connect_monitor.sh
```

**Использование**
```bash
./ssh_connect_monitor.sh [1h|today|24h|week|current|realtime]
  1h       - за последний час
  today    - за сегодня (по умолчанию)
  24h      - за последние 24 часа
  week     - за неделю
  current  - только активные соединения
  realtime - мониторинг в реальном времени
```
