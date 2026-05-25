#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 磁盘空间监控告警（超过阈值发送告警邮件或执行自定义命令）
# @Usage: ./diskAlert.sh [options]
#   -t threshold  - 告警阈值百分比，默认80
#   -m email      - 告警邮件接收地址
#   -e exclude    - 排除的挂载点（逗号分隔）

set -euo pipefail

THRESHOLD=80
ALERT_EMAIL=""
EXCLUDE_MOUNTS="/dev,/run,/sys,tmpfs"

while [ $# -gt 0 ]; do
    case "$1" in
        -t) THRESHOLD="$2"; shift 2 ;;
        -m) ALERT_EMAIL="$2"; shift 2 ;;
        -e) EXCLUDE_MOUNTS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-t threshold] [-m email] [-e exclude_mounts]"
            echo "Example: $0 -t 85 -m admin@example.com"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

readonly HOSTNAME=$(hostname)

log() {
    echo "[$(date +'%F %T')] $*"
}

alert_message=""
alert_count=0

while IFS= read -r line; do
    usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')
    filesystem=$(echo "$line" | awk '{print $1}')
    available=$(echo "$line" | awk '{print $4}')

    skip=false
    IFS=',' read -ra EXCL <<< "$EXCLUDE_MOUNTS"
    for excl in "${EXCL[@]}"; do
        if [[ "$mount" == "$excl"* ]] || [[ "$filesystem" == "$excl"* ]]; then
            skip=true
            break
        fi
    done
    [ "$skip" = true ] && continue

    if [ "$usage" -ge "$THRESHOLD" ]; then
        ((alert_count++))
        msg="  WARNING: ${mount} (${filesystem}) usage: ${usage}% | available: ${available}"
        alert_message="${alert_message}${msg}\n"
        log "$msg"
    fi
done < <(df -h | tail -n +2)

if [ "$alert_count" -gt 0 ]; then
    log "========== DISK SPACE ALERT =========="
    log "Host: ${HOSTNAME}"
    log "Threshold: ${THRESHOLD}%"
    log "Alerts: ${alert_count}"
    echo -e "$alert_message"

    if [ -n "$ALERT_EMAIL" ]; then
        subject="[ALERT] Disk Space Warning on ${HOSTNAME}"
        body="Disk space alert on ${HOSTNAME}\nThreshold: ${THRESHOLD}%\n\n${alert_message}\n\nTime: $(date +'%F %T')"
        echo -e "$body" | mail -s "$subject" "$ALERT_EMAIL"
        log "Alert email sent to: ${ALERT_EMAIL}"
    fi

    exit 1
else
    log "All disk usage below ${THRESHOLD}% threshold"
    exit 0
fi
