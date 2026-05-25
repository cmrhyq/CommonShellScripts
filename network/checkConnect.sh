#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量连通性检测（支持ping和TCP端口检测）
# @Usage: ./checkConnect.sh <hosts_file|host_list> [options]
#   hosts_file - 主机列表文件（每行一个IP或host:port）
#   -t timeout - 超时时间(秒)，默认3
#   -c count   - ping次数，默认3
#   -p port    - 统一检测的端口（与ping二选一）

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <hosts_file|host1,host2,...> [-t timeout] [-c count] [-p port]"
    echo ""
    echo "Examples:"
    echo "  $0 hosts.txt"
    echo "  $0 192.168.1.1,192.168.1.2,192.168.1.3"
    echo "  $0 hosts.txt -p 22 -t 5"
    echo ""
    echo "hosts_file format (one per line):"
    echo "  192.168.1.1"
    echo "  10.0.0.1:3306"
    echo "  example.com:80"
    exit 1
fi

readonly INPUT="${1}"
shift

TIMEOUT=3
PING_COUNT=3
PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -t) TIMEOUT="$2"; shift 2 ;;
        -c) PING_COUNT="$2"; shift 2 ;;
        -p) PORT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

success_count=0
fail_count=0
total_count=0

check_ping() {
    local host="$1"
    if ping -c "$PING_COUNT" -W "$TIMEOUT" "$host" &>/dev/null; then
        printf "  %-40s [ OK ]\n" "$host"
        ((success_count++))
    else
        printf "  %-40s [FAIL]\n" "$host"
        ((fail_count++))
    fi
    ((total_count++))
}

check_tcp() {
    local host="$1"
    local port="$2"
    if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        printf "  %-40s [ OK ] port %s\n" "$host" "$port"
        ((success_count++))
    else
        printf "  %-40s [FAIL] port %s\n" "$host" "$port"
        ((fail_count++))
    fi
    ((total_count++))
}

process_host() {
    local entry="$1"
    local host="${entry%:*}"
    local entry_port="${entry#*:}"

    if [ "$entry_port" = "$entry" ]; then
        entry_port=""
    fi

    local target_port="${PORT:-$entry_port}"

    if [ -n "$target_port" ]; then
        check_tcp "$host" "$target_port"
    else
        check_ping "$host"
    fi
}

echo "========================================="
echo "  Connectivity Check"
echo "========================================="
echo ""

if [ -f "$INPUT" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^# ]] && continue
        process_host "$line"
    done < "$INPUT"
else
    IFS=',' read -ra HOSTS <<< "$INPUT"
    for host in "${HOSTS[@]}"; do
        process_host "$(echo "$host" | tr -d ' ')"
    done
fi

echo ""
echo "========================================="
echo "  Results: ${success_count} OK / ${fail_count} FAIL / ${total_count} Total"
echo "========================================="

[ "$fail_count" -gt 0 ] && exit 1 || exit 0
