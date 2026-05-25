#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量端口扫描（检测目标主机的多个端口开放状态）
# @Usage: ./portScan.sh <host> [options]
#   -p ports    - 端口列表（逗号分隔或范围如1-1024），默认常用端口
#   -t timeout  - 超时时间(秒)，默认2
#   -o output   - 输出文件路径

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <host> [-p ports] [-t timeout] [-o output]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.1"
    echo "  $0 example.com -p 80,443,8080,3306"
    echo "  $0 10.0.0.1 -p 1-1024 -t 1"
    exit 1
fi

readonly HOST="${1}"
shift

PORTS=""
TIMEOUT=2
OUTPUT_FILE=""
readonly COMMON_PORTS="21,22,23,25,53,80,110,111,135,139,143,443,465,587,993,995,1433,1521,2049,3306,3389,5432,5900,6379,8080,8443,9090,27017"

while [ $# -gt 0 ]; do
    case "$1" in
        -p) PORTS="$2"; shift 2 ;;
        -t) TIMEOUT="$2"; shift 2 ;;
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

[ -z "$PORTS" ] && PORTS="$COMMON_PORTS"

expand_ports() {
    local input="$1"
    local result=""
    IFS=',' read -ra PARTS <<< "$input"
    for part in "${PARTS[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            for ((p=${BASH_REMATCH[1]}; p<=${BASH_REMATCH[2]}; p++)); do
                result="${result}${p} "
            done
        else
            result="${result}${part} "
        fi
    done
    echo "$result"
}

readonly PORT_LIST=$(expand_ports "$PORTS")
open_count=0
closed_count=0

output() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$*" | tee -a "$OUTPUT_FILE"
    else
        echo "$*"
    fi
}

[ -n "$OUTPUT_FILE" ] && : > "$OUTPUT_FILE"

output "========================================="
output "  Port Scan: ${HOST}"
output "  Time: $(date +'%F %T')"
output "  Timeout: ${TIMEOUT}s"
output "========================================="
output ""
output "  $(printf '%-8s %-10s %s' 'PORT' 'STATE' 'SERVICE')"
output "  $(printf '%-8s %-10s %s' '----' '-----' '-------')"

get_service_name() {
    local port="$1"
    case "$port" in
        21) echo "ftp" ;; 22) echo "ssh" ;; 23) echo "telnet" ;;
        25) echo "smtp" ;; 53) echo "dns" ;; 80) echo "http" ;;
        110) echo "pop3" ;; 143) echo "imap" ;; 443) echo "https" ;;
        993) echo "imaps" ;; 995) echo "pop3s" ;; 1433) echo "mssql" ;;
        1521) echo "oracle" ;; 3306) echo "mysql" ;; 3389) echo "rdp" ;;
        5432) echo "postgresql" ;; 5900) echo "vnc" ;; 6379) echo "redis" ;;
        8080) echo "http-alt" ;; 8443) echo "https-alt" ;; 9090) echo "web-proxy" ;;
        27017) echo "mongodb" ;; *) echo "" ;;
    esac
}

for port in $PORT_LIST; do
    if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${HOST}/${port}" 2>/dev/null; then
        service=$(get_service_name "$port")
        output "  $(printf '%-8s %-10s %s' "$port" "OPEN" "$service")"
        ((open_count++))
    else
        ((closed_count++))
    fi
done

output ""
output "========================================="
output "  Open: ${open_count} | Closed/Filtered: ${closed_count}"
output "========================================="
