#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG_FILE="$(dirname "$0")/white_list_ip.conf"

# Парсинг конфига
declare -A WHITELIST_NAMES
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r ip name; do
        [[ "$ip" =~ ^#.*$ ]] || [[ -z "$ip" ]] && continue
        WHITELIST_NAMES["$ip"]="$name"
    done < "$CONFIG_FILE"
else
    echo -e "${RED}Конфиг файл $CONFIG_FILE не найден!${NC}"
    exit 1
fi

get_ip_info() {
    local ip="$1"
    local color=""
    local name=""

    # Проверка белого списка
    if [[ -n "${WHITELIST_NAMES[$ip]}" ]]; then
        color="${GREEN}"
        name=" (${WHITELIST_NAMES[$ip]})"
    elif [[ "$ip" =~ ^10\. ]] || [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "$ip" =~ ^192\.168\. ]]; then
        color="${BLUE}"
        name=" (Private)"
    else
        color="${RED}"
        name=" (Suspicious)"
    fi

    echo "${color}${ip}${name}${NC}"
}

show_legend() {
    echo -e "\n${BOLD}Легенда цветов:${NC}"
    echo -e "  ${GREEN}■${NC} Белый список (доверенные IP)"
    echo -e "  ${BLUE}■${NC} Частные IP адреса"
    echo -e "  ${RED}■${NC} Подозрительные/неизвестные IP"
    echo ""
}

show_current_connections() {
    echo -e "${BOLD}=== АКТИВНЫЕ SSH СОЕДИНЕНИЯ ===${NC}"

    # Активные SSH сессии
    who | grep pts | while read user tty date time ip_raw; do
        if [[ "$ip_raw" =~ ^\( ]]; then
            clean_ip=$(echo "$ip_raw" | sed 's/[()]//g')
            ip_info=$(get_ip_info "$clean_ip")
            echo -e "${BOLD}$user${NC} на $tty с $ip_info ($date $time)"
        else
            echo -e "${BOLD}$user${NC} на $tty локально ($date $time)"
        fi
    done

    # SSH процессы
    echo -e "\n${BOLD}SSH процессы:${NC}"
    ps aux | grep "sshd.*@" | grep -v grep | while read user pid cpu mem vsz rss tty stat start time cmd; do
        session_info=$(echo "$cmd" | grep -o "@pts/[0-9]*")
        echo -e "PID: $pid, пользователь: $user, сессия: $session_info"
    done

    echo ""
}

show_history() {
    echo -e "${BOLD}=== SSH АКТИВНОСТЬ ЗА 24 ЧАСА ===${NC}"

    echo -e "\n${GREEN}УСПЕШНЫЕ ВХОДЫ:${NC}"
    sudo journalctl --since "24 hours ago" | grep "sshd.*Accepted" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Accepted [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')
        key_type=$(echo "$line" | grep -o "ED25519\|RSA\|ECDSA\|DSA")
        key_hash=$(echo "$line" | grep -o "SHA256:[A-Za-z0-9+/]*")

        ip_info=$(get_ip_info "$ip")
        echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port $key_type $key_hash"
    done

    echo -e "\n${RED}ПОДОЗРИТЕЛЬНЫЕ ПОДКЛЮЧЕНИЯ:${NC}"
    sudo journalctl --since "24 hours ago" | grep "sshd.*banner exchange.*invalid format" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\).*/\1/p')

        ip_info=$(get_ip_info "$ip")
        echo -e "$timestamp $ip_info:$port INVALID FORMAT"
    done

    echo -e "\n${RED}НЕУДАЧНЫЕ ПОПЫТКИ:${NC}"
    sudo journalctl --since "24 hours ago" | grep "sshd.*Failed" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Failed [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

        ip_info=$(get_ip_info "$ip")
        echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port FAILED"
    done

    echo -e "\n${YELLOW}ОТЛОЖЕННЫЕ КЛЮЧИ (Postponed):${NC}"
    sudo journalctl --since "24 hours ago" | grep "sshd.*Postponed" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Postponed [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

        ip_info=$(get_ip_info "$ip")
        echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port POSTPONED"
    done

    echo -e "\n${BOLD}СТАТИСТИКА ПО IP:${NC}"
    sudo journalctl --since "24 hours ago" | grep "sshd.*from [0-9]" | \
    grep -o "from [0-9.]*" | cut -d' ' -f2 | sort | uniq -c | sort -nr | while read count ip; do
        ip_info=$(get_ip_info "$ip")
        echo -e "  $ip_info: $count событий"
    done

    echo -e "\n${BOLD}УНИКАЛЬНЫЕ SSH КЛЮЧИ:${NC}"
    sudo journalctl --since "24 hours ago" | grep "SHA256:" | \
    grep -o "SHA256:[A-Za-z0-9+/]*" | sort | uniq | while read key; do
        user_count=$(sudo journalctl --since "24 hours ago" | grep "$key" | \
                    grep -o "for [a-zA-Z0-9_-]*" | cut -d' ' -f2 | sort | uniq | wc -l)
        echo -e "  $key (используется $user_count пользователями)"
    done
}

realtime_monitor() {
    echo -e "${BOLD}=== МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ ===${NC}"
    echo -e "Нажмите Ctrl+C для выхода\n"

    sudo journalctl -u ssh -f --no-pager | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')

        if echo "$line" | grep -q "Accepted"; then
            user=$(echo "$line" | sed -n 's/.*Accepted [^ ]* for \([^ ]*\) from.*/\1/p')
            ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
            port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')
            key_type=$(echo "$line" | grep -o "ED25519\|RSA\|ECDSA\|DSA")
            key_hash=$(echo "$line" | grep -o "SHA256:[A-Za-z0-9+/]*")

            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${GREEN}[SUCCESS]${NC} ${BOLD}$user${NC} $ip_info:$port $key_type $key_hash"

        elif echo "$line" | grep -q "Failed"; then
            user=$(echo "$line" | sed -n 's/.*Failed [^ ]* for \([^ ]*\) from.*/\1/p')
            ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
            port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${RED}[FAILED]${NC} ${BOLD}$user${NC} $ip_info:$port"

        elif echo "$line" | grep -q "invalid format"; then
            ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
            port=$(echo "$line" | sed -n 's/.*port \([0-9]*\).*/\1/p')

            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${RED}[SUSPICIOUS]${NC} $ip_info:$port invalid format"

        elif echo "$line" | grep -q "Postponed"; then
            user=$(echo "$line" | sed -n 's/.*Postponed [^ ]* for \([^ ]*\) from.*/\1/p')
            ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
            port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${YELLOW}[POSTPONED]${NC} ${BOLD}$user${NC} $ip_info:$port"
        fi
    done
}

show_config() {
    echo -e "${BOLD}=== КОНФИГУРАЦИЯ БЕЛОГО СПИСКА ===${NC}"
    echo "Файл конфигурации: $CONFIG_FILE"
    echo ""

    if [[ ${#WHITELIST_NAMES[@]} -eq 0 ]]; then
        echo "Белый список пуст"
    else
        for ip in "${!WHITELIST_NAMES[@]}"; do
            echo -e "  ${GREEN}$ip${NC} = ${WHITELIST_NAMES[$ip]}"
        done
    fi
    echo ""
}

case "${1:-history}" in
    "current"|"now")
        show_current_connections
        show_legend
        ;;
    "realtime"|"live"|"monitor")
        realtime_monitor
        ;;
    "config"|"conf")
        show_config
        ;;
    "history"|"")
        show_current_connections
        show_history
        show_legend
        ;;
    *)
        echo "Использование: $0 [current|realtime|history|config]"
        echo "  current  - показать активные соединения"
        echo "  realtime - мониторинг в реальном времени"
        echo "  history  - показать историю (по умолчанию)"
        echo "  config   - показать конфигурацию белого списка"
        ;;
esac
