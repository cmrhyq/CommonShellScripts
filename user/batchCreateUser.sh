#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 从CSV文件批量创建系统用户（支持设置密码、组、shell等）
# @Usage: sudo ./batchCreateUser.sh <csv_file>
#   CSV格式: username,password,group,shell,comment
#   示例CSV:
#     zhangsan,Pass123!,developers,/bin/bash,Zhang San
#     lisi,Pass456!,operations,/bin/bash,Li Si
# @Note: 需要root权限执行

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: sudo $0 <csv_file>"
    echo ""
    echo "CSV format: username,password,group,shell,comment"
    echo ""
    echo "Example CSV content:"
    echo "  zhangsan,Pass123!,developers,/bin/bash,Zhang San"
    echo "  lisi,Pass456!,operations,/bin/bash,Li Si"
    exit 1
fi

readonly CSV_FILE="${1}"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo "ERROR: CSV file not found: $CSV_FILE"
    exit 1
fi

log() {
    echo "[$(date +'%F %T')] $*"
}

success_count=0
fail_count=0
skip_count=0
line_num=0

log "========================================="
log "  Batch User Creation"
log "  Source: ${CSV_FILE}"
log "========================================="
echo ""

while IFS=',' read -r username password group shell comment; do
    ((line_num++))

    [ -z "$username" ] && continue
    [[ "$username" =~ ^# ]] && continue
    [ "$username" = "username" ] && continue

    username=$(echo "$username" | tr -d ' ')
    group=$(echo "${group:-users}" | tr -d ' ')
    shell=$(echo "${shell:-/bin/bash}" | tr -d ' ')
    comment=$(echo "${comment:-}" | sed 's/^ *//;s/ *$//')

    if id "$username" &>/dev/null; then
        log "SKIP: User '${username}' already exists (line ${line_num})"
        ((skip_count++))
        continue
    fi

    if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        log "Created group: ${group}"
    fi

    if useradd -m -g "$group" -s "$shell" -c "$comment" "$username" 2>/dev/null; then
        if [ -n "$password" ]; then
            echo "${username}:${password}" | chpasswd
            chage -d 0 "$username"
        fi
        log "CREATED: ${username} (group: ${group}, shell: ${shell})"
        ((success_count++))
    else
        log "FAILED: Could not create user '${username}' (line ${line_num})"
        ((fail_count++))
    fi
done < "$CSV_FILE"

echo ""
log "========================================="
log "  Results: ${success_count} created, ${skip_count} skipped, ${fail_count} failed"
log "========================================="
