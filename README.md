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
