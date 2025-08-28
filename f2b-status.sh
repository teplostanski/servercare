#!/bin/bash
# Статистика Fail2ban

# Функция для вывода ошибок
error_exit() {
    echo "❌ Ошибка: $1" >&2
    exit 1
}

# Функция для проверки команды
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Проверка наличия fail2ban
if ! check_command fail2ban-client; then
    error_exit "fail2ban не установлен."
fi

# Проверка службы fail2ban
if ! systemctl is-active --quiet fail2ban; then
    error_exit "Служба fail2ban не запущена. Запустите её: sudo systemctl start fail2ban"
fi

# Проверка прав sudo
if ! sudo -n true 2>/dev/null; then
    echo "Введите пароль для выполнения команд sudo:"
    sudo -v || error_exit "Не удалось получить права sudo"
fi

# Проверка доступности fail2ban-client
if ! sudo fail2ban-client ping >/dev/null 2>&1; then
    error_exit "fail2ban-server недоступен. Проверьте статус службы: systemctl status fail2ban"
fi

echo ""
echo "   🛡️  FAIL2BAN STATUS REPORT"
echo "════════════════════════════════════════"

# Проверкп активных jail
jail_count=$(sudo fail2ban-client status 2>/dev/null | grep "Number of jail" | grep -o '[0-9]*' || echo "0")
if [ "$jail_count" -eq 0 ]; then
    echo "⚠️  Предупреждение: Не настроено ни одного jail"
    echo "📖 Настройте защиту в файле /etc/fail2ban/jail.local"
    exit 0
fi

# Общий статус
echo "📋 Активные jail-ы:"
jail_list=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[ \t]*//')
if [ -z "$jail_list" ]; then
    echo "  ❌ Нет активных jail-ов"
else
    echo "$jail_list" | tr ',' '\n' | sed 's/^[[:space:]]*/  • /'
fi

echo ""
echo "🚫 Статистика блокировок:"
echo "────────────────────────────────────────"

# Парсинг jail
total_banned_all=0
for jail in $(echo "$jail_list" | tr ',' ' '); do
    jail=$(echo $jail | xargs)

    if [ -z "$jail" ]; then
        continue
    fi

    # Статистика jail с обработкой ошибок
    status=$(sudo fail2ban-client status "$jail" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "🔒 ${jail^^}: ❌ Ошибка получения статуса"
        continue
    fi

    currently_failed=$(echo "$status" | grep "Currently failed" | sed 's/.*Currently failed:[ \t]*//' || echo "0")
    total_failed=$(echo "$status" | grep "Total failed" | sed 's/.*Total failed:[ \t]*//' || echo "0")
    currently_banned=$(echo "$status" | grep "Currently banned" | sed 's/.*Currently banned:[ \t]*//' || echo "0")
    total_banned=$(echo "$status" | grep "Total banned" | sed 's/.*Total banned:[ \t]*//' || echo "0")

    currently_failed=${currently_failed:-0}
    total_failed=${total_failed:-0}
    currently_banned=${currently_banned:-0}
    total_banned=${total_banned:-0}

    total_banned_all=$((total_banned_all + currently_banned))

    echo "🔒 ${jail^^}:"
    echo "   Сейчас заблокировано: $currently_banned IP"
    echo "   Всего заблокировано: $total_banned IP"
    echo "   Подозрительная активность: $currently_failed IP"
    echo "   Всего атак отражено: $total_failed"

    # Заблокированные IP
    banned_ips=$(echo "$status" | grep "Banned IP list" | sed 's/.*Banned IP list:[ \t]*//')
    if [ ! -z "$banned_ips" ] && [ "$banned_ips" != "" ] && [ "$banned_ips" != " " ]; then
        echo "   Заблокированные адреса:"
        echo "$banned_ips" | tr ' ' '\n' | grep -v '^$' | sed 's/^/      • /'
    fi
    echo ""
done

echo "📊 ОБЩАЯ СВОДКА:"
echo "────────────────"
echo "Всего IP в блокировке: $total_banned_all"
echo "Отчёт сгенерирован: $(date '+%d.%m.%Y в %H:%M')"

# Показываем статус службы
service_status=$(systemctl is-active fail2ban)
uptime=$(systemctl show fail2ban --property=ActiveEnterTimestamp --value | xargs -I {} date -d "{}" "+%d.%m.%Y %H:%M" 2>/dev/null || echo "неизвестно")

echo ""
echo "🔧 СТАТУС СЛУЖБЫ:"
echo "────────────────"
echo "Статус: $service_status"
echo "Запущена с: $uptime"
