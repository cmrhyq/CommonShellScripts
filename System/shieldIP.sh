#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 分析Nginx日志，屏蔽短时间内高频访问的攻击IP
# @Usage: sudo bash shieldIP.sh [log_file] [threshold]
#   log_file  - Nginx访问日志路径，默认 /usr/local/nginx/logs/access.log
#   threshold - 触发封禁的请求次数阈值，默认10次

set -euo pipefail

readonly LOG_FILE="${1:-/usr/local/nginx/logs/access.log}"
readonly THRESHOLD="${2:-10}"
readonly DROP_LOG="/tmp/drop_ip.log"
readonly DATE=$(date +%d/%b/%Y:%H:%M)

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ ! -f "$LOG_FILE" ]; then
    log "ERROR: Log file not found: $LOG_FILE"
    exit 1
fi

ABNORMAL_IP=$(tail -n5000 "$LOG_FILE" | grep "$DATE" | awk -v threshold="$THRESHOLD" '{a[$1]++}END{for(i in a) if(a[i]>threshold) print i}')

if [ -z "$ABNORMAL_IP" ]; then
    log "No abnormal IPs detected"
    exit 0
fi

for IP in $ABNORMAL_IP; do
    if [ "$(iptables -vnL | grep -c "$IP")" -eq 0 ]; then
        iptables -I INPUT -s "$IP" -j DROP
        echo "$(date +'%F_%T') $IP" >> "$DROP_LOG"
        log "Blocked IP: $IP"
    else
        log "IP already blocked: $IP"
    fi
done
