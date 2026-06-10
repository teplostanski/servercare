#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Скрипт необходимо запускать от имени root (или через sudo)."
  exit 1
fi

if [ -z "$1" ]; then
  echo "Использование: sudo $0 <имя_пользователя>"
  exit 1
fi

USERNAME=$1

echo "Создание пользователя $USERNAME..."
adduser "$USERNAME"

echo "Добавление $USERNAME в группу sudo..."
usermod -aG sudo "$USERNAME"

echo "Проверка групп пользователя $USERNAME:"
groups "$USERNAME"
