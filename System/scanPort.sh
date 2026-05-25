#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 扫描主机端口状态，检测异常登录IP并用iptables封禁
# @Usage: sudo bash scanPort.sh [threshold]
#   threshold - 登录失败次数阈值，默认10次

set -euo pipefail

readonly THRESHOLD=${1:-10}
readonly DATE=$(date +"%a %b %e %H:%M")

log() {
    echo "[$(date +'%F %T')] $*"
}

if ! command -v lastb &>/dev/null; then
    log "ERROR: lastb command not found"
    exit 1
fi

ABNORMAL_IP=$(lastb | grep "$DATE" | awk -v threshold="$THRESHOLD" '{a[$3]++}END{for(i in a) if(a[i]>threshold) print i}')

if [ -z "$ABNORMAL_IP" ]; then
    log "No abnormal IPs detected"
    exit 0
fi

for IP in $ABNORMAL_IP; do
    if [ "$(iptables -vnL | grep -c "$IP")" -eq 0 ]; then
        iptables -I INPUT -s "$IP" -j DROP
        log "Blocked IP: $IP"
    else
        log "IP already blocked: $IP"
    fi
done
