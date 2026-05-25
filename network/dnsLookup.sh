#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: DNS批量查询与对比（检测域名解析结果，对比多DNS服务器）
# @Usage: ./dnsLookup.sh <domains_file|domain_list> [options]
#   domains_file - 域名列表文件（每行一个域名）
#   -s servers   - DNS服务器列表（逗号分隔），默认8.8.8.8,114.114.114.114
#   -t type      - 查询类型(A/AAAA/MX/NS/CNAME)，默认A
#   -o output    - 输出文件

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <domains_file|domain1,domain2,...> [-s dns_servers] [-t type] [-o output]"
    echo ""
    echo "Examples:"
    echo "  $0 domains.txt"
    echo "  $0 example.com,google.com -s 8.8.8.8,1.1.1.1"
    echo "  $0 domains.txt -t MX -o results.txt"
    exit 1
fi

readonly INPUT="${1}"
shift

DNS_SERVERS="8.8.8.8,114.114.114.114"
QUERY_TYPE="A"
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -s) DNS_SERVERS="$2"; shift 2 ;;
        -t) QUERY_TYPE="$2"; shift 2 ;;
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v dig &>/dev/null; then
    echo "ERROR: 'dig' command not found. Install: yum install bind-utils"
    exit 1
fi

output() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$*" | tee -a "$OUTPUT_FILE"
    else
        echo "$*"
    fi
}

[ -n "$OUTPUT_FILE" ] && : > "$OUTPUT_FILE"

output "============================================="
output "  DNS Lookup Report"
output "  Time: $(date +'%F %T')"
output "  Type: ${QUERY_TYPE}"
output "  DNS Servers: ${DNS_SERVERS}"
output "============================================="
output ""

IFS=',' read -ra SERVERS <<< "$DNS_SERVERS"

resolve_domain() {
    local domain="$1"
    output "--- ${domain} ---"

    local results=()
    for server in "${SERVERS[@]}"; do
        local result
        result=$(dig +short "$domain" "$QUERY_TYPE" "@${server}" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
        if [ -z "$result" ]; then
            result="(no record)"
        fi
        results+=("$result")
        output "  $(printf '%-18s -> %s' "$server" "$result")"
    done

    if [ ${#results[@]} -gt 1 ]; then
        local first="${results[0]}"
        local mismatch=false
        for r in "${results[@]}"; do
            if [ "$r" != "$first" ]; then
                mismatch=true
                break
            fi
        done
        if [ "$mismatch" = true ]; then
            output "  ** MISMATCH detected **"
        fi
    fi
    output ""
}

if [ -f "$INPUT" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^# ]] && continue
        resolve_domain "$line"
    done < "$INPUT"
else
    IFS=',' read -ra DOMAINS <<< "$INPUT"
    for domain in "${DOMAINS[@]}"; do
        resolve_domain "$(echo "$domain" | tr -d ' ')"
    done
fi

output "============================================="
output "  Query completed: $(date +'%F %T')"
output "============================================="
