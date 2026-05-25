#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 用户安全审计（检测空密码、密码过期、未登录、无用账户等安全风险）
# @Usage: sudo ./userAudit.sh [options]
#   -d inactive_days  - 未登录天数阈值，默认90
#   -o output         - 输出报告文件
#   -m email          - 发送报告到邮箱
# @Note: 需要root权限执行

set -euo pipefail

INACTIVE_DAYS=90
OUTPUT_FILE=""
ALERT_EMAIL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -d) INACTIVE_DAYS="$2"; shift 2 ;;
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        -m) ALERT_EMAIL="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo $0 [-d inactive_days] [-o output] [-m email]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

readonly HOSTNAME=$(hostname)

output() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$*" | tee -a "$OUTPUT_FILE"
    else
        echo "$*"
    fi
}

[ -n "$OUTPUT_FILE" ] && : > "$OUTPUT_FILE"

output "============================================="
output "  User Security Audit Report"
output "============================================="
output "  Host:   ${HOSTNAME}"
output "  Time:   $(date +'%F %T')"
output "  Inactive threshold: ${INACTIVE_DAYS} days"
output "============================================="
output ""

issue_count=0

output "--- [CRITICAL] Users with Empty Password ---"
empty_pw_users=$(awk -F: '($2 == "" || $2 == "!!" || $2 == "!") && $1 != "root" {print $1}' /etc/shadow 2>/dev/null || true)
if [ -n "$empty_pw_users" ]; then
    while IFS= read -r user; do
        output "  [!] ${user} - NO PASSWORD SET"
        ((issue_count++))
    done <<< "$empty_pw_users"
else
    output "  (none)"
fi
output ""

output "--- [HIGH] Users with UID 0 (Root Equivalent) ---"
uid0_users=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd || true)
if [ -n "$uid0_users" ]; then
    while IFS= read -r user; do
        output "  [!] ${user} - UID 0 (root equivalent)"
        ((issue_count++))
    done <<< "$uid0_users"
else
    output "  (none - only root has UID 0)"
fi
output ""

output "--- [MEDIUM] Users with Expired Passwords ---"
today_days=$(( $(date +%s) / 86400 ))
while IFS=: read -r user pw lastchg minage maxage warn inactive expire _; do
    [ -z "$maxage" ] || [ "$maxage" = "99999" ] || [ "$maxage" = "-1" ] && continue
    [ -z "$lastchg" ] || [ "$lastchg" = "0" ] && continue
    [ "$user" = "root" ] && continue

    expire_day=$((lastchg + maxage))
    if [ "$today_days" -gt "$expire_day" ]; then
        days_expired=$((today_days - expire_day))
        output "  [!] ${user} - Password expired ${days_expired} days ago"
        ((issue_count++))
    fi
done < /etc/shadow
output ""

output "--- [MEDIUM] Users Never Logged In ---"
while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -lt 1000 ] && continue
    [[ "$shell" == */nologin ]] && continue
    [[ "$shell" == */false ]] && continue

    last_login=$(lastlog -u "$user" 2>/dev/null | tail -1 | awk '{print $4, $5, $6, $7, $9}')
    if echo "$last_login" | grep -q "Never logged in"; then
        output "  [?] ${user} - Never logged in"
        ((issue_count++))
    fi
done < /etc/passwd
output ""

output "--- [LOW] Users Inactive > ${INACTIVE_DAYS} Days ---"
while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -lt 1000 ] && continue
    [[ "$shell" == */nologin ]] && continue
    [[ "$shell" == */false ]] && continue

    last_login_line=$(lastlog -u "$user" 2>/dev/null | tail -1)
    if ! echo "$last_login_line" | grep -q "Never"; then
        login_date=$(echo "$last_login_line" | awk '{print $4, $5, $6, $9}')
        if [ -n "$login_date" ]; then
            login_ts=$(date -d "$login_date" +%s 2>/dev/null || echo "0")
            if [ "$login_ts" -gt 0 ]; then
                days_since=$(( ($(date +%s) - login_ts) / 86400 ))
                if [ "$days_since" -gt "$INACTIVE_DAYS" ]; then
                    output "  [i] ${user} - Last login ${days_since} days ago"
                    ((issue_count++))
                fi
            fi
        fi
    fi
done < /etc/passwd
output ""

output "--- [INFO] Summary ---"
total_users=$(awk -F: '$3 >= 1000 {count++} END {print count}' /etc/passwd)
output "  Total system users (UID >= 1000): ${total_users:-0}"
output "  Security issues found: ${issue_count}"
output ""
output "============================================="
output "  Audit completed: $(date +'%F %T')"
output "============================================="

if [ -n "$ALERT_EMAIL" ] && [ "$issue_count" -gt 0 ]; then
    if [ -n "$OUTPUT_FILE" ]; then
        mail -s "[Audit] User Security Issues on ${HOSTNAME}" "$ALERT_EMAIL" < "$OUTPUT_FILE"
    fi
    echo "Report sent to: ${ALERT_EMAIL}"
fi

[ "$issue_count" -gt 0 ] && exit 1 || exit 0
