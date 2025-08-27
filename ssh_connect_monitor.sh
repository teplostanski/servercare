#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG_FILE="$(dirname "$0")/white_list_ip.conf"

declare -A WHITELIST_NAMES
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r ip name; do
        [[ "$ip" =~ ^#.*$ ]] || [[ -z "$ip" ]] && continue
        WHITELIST_NAMES["$ip"]="$name"
    done < "$CONFIG_FILE"
fi

get_ip_info() {
    local ip="$1"
    local color=""
    local name=""

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

show_current_connections() {
    echo -e "${BOLD}=== АКТИВНЫЕ SSH СОЕДИНЕНИЯ ===${NC}"

    who | grep pts | while read user tty date time ip_raw; do
        if [[ "$ip_raw" =~ ^\( ]]; then
            clean_ip=$(echo "$ip_raw" | sed 's/[()]//g')
            ip_info=$(get_ip_info "$clean_ip")
            echo -e "${BOLD}$user${NC} на $tty с $ip_info ($date $time)"
        else
            echo -e "${BOLD}$user${NC} на $tty локально ($date $time)"
        fi
    done
    echo ""
}

show_history() {
    local period="$1"
    echo -e "${BOLD}=== SSH АКТИВНОСТЬ ($period) ===${NC}"

    echo -e "\n${GREEN}УСПЕШНЫЕ ВХОДЫ:${NC}"
    sudo journalctl --since "$period" -u ssh -u sshd --no-pager -q | grep "Accepted" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Accepted [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')
        key_type=$(echo "$line" | grep -o "ED25519\|RSA\|ECDSA\|DSA")
        key_hash=$(echo "$line" | grep -o "SHA256:[A-Za-z0-9+/]*")

        if [[ -n "$user" && -n "$ip" ]]; then
            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port $key_type $key_hash"
        fi
    done

    echo -e "\n${RED}ПОДОЗРИТЕЛЬНЫЕ ПОДКЛЮЧЕНИЯ:${NC}"
    sudo journalctl --since "$period" -u ssh -u sshd --no-pager -q | grep "invalid format" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\).*/\1/p')

        if [[ -n "$ip" ]]; then
            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp $ip_info:$port INVALID FORMAT"
        fi
    done

    echo -e "\n${RED}НЕУДАЧНЫЕ ПОПЫТКИ:${NC}"
    sudo journalctl --since "$period" -u ssh -u sshd --no-pager -q | grep "Failed" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Failed [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

        if [[ -n "$user" && -n "$ip" ]]; then
            ip_info=$(get_ip_info "$ip")
            echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port FAILED"
        fi
    done

    echo -e "\n${YELLOW}ОТЛОЖЕННЫЕ КЛЮЧИ (Postponed):${NC}"
    sudo journalctl --since "$period" -u ssh -u sshd --no-pager -q | grep "Postponed" | while read -r line; do
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        user=$(echo "$line" | sed -n 's/.*Postponed [^ ]* for \([^ ]*\) from.*/\1/p')
        ip=$(echo "$line" | sed -n 's/.*from \([0-9.]*\) port.*/\1/p')
        port=$(echo "$line" | sed -n 's/.*port \([0-9]*\) .*/\1/p')

        if [[ -n "$user" && -n "$ip" ]]; then
            ip_info=$(get ip_info "$ip")
            echo -e "$timestamp ${BOLD}$user${NC} $ip_info:$port POSTPONED"
        fi
    done

    echo -e "\n${BOLD}СТАТИСТИКА ПО IP ($period):${NC}"
    sudo journalctl --since "$period" -u ssh -u sshd --no-pager -q | grep "from [0-9]" | \
    grep -o "from [0-9.]*" | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -20 | while read count ip; do
        ip_info=$(get_ip_info "$ip")
        echo -e "  $ip_info: $count событий"
    done
}

realtime_monitor() {
    echo -e "${BOLD}=== МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ ===${NC}"
    echo -e "Нажмите Ctrl+C для выхода\n"

    sudo journalctl -u ssh -u sshd -f --no-pager | while read -r line; do
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

show_legend() {
    echo -e "\n${BOLD}Легенда цветов:${NC}"
    echo -e "  ${GREEN}■${NC} Белый список (доверенные IP)"
    echo -e "  ${BLUE}■${NC} Частные IP адреса"
    echo -e "  ${RED}■${NC} Подозрительные/неизвестные IP"
    echo ""
}

case "${1:-today}" in
    "current"|"now")
        show_current_connections
        show_legend
        ;;
    "realtime"|"live"|"monitor")
        realtime_monitor
        ;;
    "1h"|"hour")
        show_current_connections
        show_history "1 hour ago"
        show_legend
        ;;
    "today")
        show_current_connections
        show_history "today"
        show_legend
        ;;
    "24h")
        show_current_connections
        show_history "24 hours ago"
        show_legend
        ;;
    "week")
        show_current_connections
        show_history "1 week ago"
        show_legend
        ;;
    *)
        echo "Использование: $0 [1h|today|24h|week|current|realtime]"
        echo "  1h       - за последний час"
        echo "  today    - за сегодня (по умолчанию)"
        echo "  24h      - за последние 24 часа"
        echo "  week     - за неделю"
        echo "  current  - только активные соединения"
        echo "  realtime - мониторинг в реальном времени"
        ;;
esac
