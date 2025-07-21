#!/bin/bash

# Проверка, что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
  echo "Этот скрипт нужно запускать с правами root или через sudo."
  exit 1
fi

# Функция проверки списка пользователей с домашними каталогами
get_users() {
  mapfile -t users < <(awk -F: '$6 ~ /^\/home\// {print $1}' /etc/passwd)
}

# Функция отображения меню
show_menu() {
  echo "Выберите действие:"
  echo "1) Разрешить sudo без пароля для пользователя"
  echo "2) Отключить sudo без пароля (удалить файл)"
  echo "3) Выход"
}

# Функция создания файла sudoers.d для выбранного пользователя
create_sudoers_file() {
  get_users
  if [ ${#users[@]} -eq 0 ]; then
    echo "Пользователи с домашними каталогами не найдены."
    return
  fi

  echo "Выберите пользователя для разрешения sudo без пароля:"
  for i in "${!users[@]}"; do
    echo "$((i+1))) ${users[$i]}"
  done

  read -rp "Введите номер пользователя: " user_num

  if ! [[ "$user_num" =~ ^[0-9]+$ ]] || (( user_num < 1 || user_num > ${#users[@]} )); then
    echo "Неверный номер пользователя."
    return
  fi

  local selected_user="${users[$((user_num-1))]}"
  local file_path="/etc/sudoers.d/nopasswd_${selected_user}"

  if [ -e "$file_path" ]; then
    echo "Файл $file_path уже существует. Перезаписать? (y/n)"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      echo "Отмена."
      return
    fi
  fi

  echo "$selected_user ALL=(ALL) NOPASSWD: ALL" > "$file_path"
  chmod 440 "$file_path"

  # Проверка синтаксиса sudoers
  if visudo -cf "$file_path"; then
    echo "Файл $file_path успешно создан."
    echo "Пользователь $selected_user теперь может выполнять sudo без пароля."
  else
    echo "Ошибка в файле sudoers. Удаляю файл."
    rm -f "$file_path"
  fi
}

# Функция удаления файла sudoers.d для выбранного пользователя
remove_sudoers_file() {
  local files=(/etc/sudoers.d/nopasswd_*)
  # Проверка, есть ли такие файлы (проверка, что массив не содержит именно "/etc/sudoers.d/nopasswd_*")
  if [[ ${files[0]} == "/etc/sudoers.d/nopasswd_*" ]]; then
    echo "Файлы для отключения sudo без пароля не найдены."
    return
  fi

  echo "Выберите файл для удаления:"
  for i in "${!files[@]}"; do
    file_name=$(basename "${files[$i]}")
    echo "$((i+1))) $file_name"
  done

  read -rp "Введите номер файла: " file_num

  if ! [[ "$file_num" =~ ^[0-9]+$ ]] || (( file_num < 1 || file_num > ${#files[@]} )); then
    echo "Неверный номер."
    return
  fi

  local to_delete="${files[$((file_num-1))]}"
  echo "Удалить файл $to_delete? (y/n)"
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -f "$to_delete"
    echo "Файл удалён."
  else
    echo "Отмена."
  fi
}

# Основной цикл
while true; do
  show_menu
  read -rp "Введите номер действия: " choice
  case $choice in
    1)
      create_sudoers_file
      ;;
    2)
      remove_sudoers_file
      ;;
    3)
      echo "Выход."
      exit 0
      ;;
    *)
      echo "Неверный выбор."
      ;;
  esac
  echo
done
