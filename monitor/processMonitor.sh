#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 进程存活监控（检测指定进程，挂了自动拉起并告警）
# @Usage: ./processMonitor.sh <process_name> [options]
#   -c command    - 拉起进程的命令
#   -s service    - systemd服务名（优先于-c）
#   -m email      - 告警邮件
#   -r max_retry  - 最大重试次数，默认3
#   -i interval   - 检查间隔(秒)，默认0（单次检查）

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <process_name> [-c command] [-s service] [-m email] [-r max_retry] [-i interval]"
    echo ""
    echo "Examples:"
    echo "  $0 nginx -s nginx -m admin@example.com"
    echo "  $0 myapp -c '/opt/myapp/start.sh' -r 5"
    echo "  $0 redis-server -s redis -i 30"
    exit 1
fi

readonly PROC_NAME="${1}"
shift

START_CMD=""
SERVICE_NAME=""
ALERT_EMAIL=""
MAX_RETRY=3
CHECK_INTERVAL=0

while [ $# -gt 0 ]; do
    case "$1" in
        -c) START_CMD="$2"; shift 2 ;;
        -s) SERVICE_NAME="$2"; shift 2 ;;
        -m) ALERT_EMAIL="$2"; shift 2 ;;
        -r) MAX_RETRY="$2"; shift 2 ;;
        -i) CHECK_INTERVAL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

readonly HOSTNAME=$(hostname)
readonly LOG_FILE="/var/log/process_monitor.log"

log() {
    local msg="[$(date +'%F %T')] [${PROC_NAME}] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

send_alert() {
    local subject="$1"
    local body="$2"
    if [ -n "$ALERT_EMAIL" ]; then
        echo -e "$body" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

restart_process() {
    if [ -n "$SERVICE_NAME" ]; then
        systemctl restart "$SERVICE_NAME" 2>/dev/null
        return $?
    elif [ -n "$START_CMD" ]; then
        eval "$START_CMD" 2>/dev/null &
        return $?
    else
        log "ERROR: No restart method configured (use -s or -c)"
        return 1
    fi
}

check_and_recover() {
    if pgrep -x "$PROC_NAME" &>/dev/null || pgrep -f "$PROC_NAME" &>/dev/null; then
        return 0
    fi

    log "Process DOWN! Attempting recovery..."
    send_alert "[ALERT] Process Down: ${PROC_NAME}@${HOSTNAME}" \
        "Process ${PROC_NAME} is not running on ${HOSTNAME}\nTime: $(date +'%F %T')\nAttempting auto-recovery..."

    local attempt=0
    while [ $attempt -lt "$MAX_RETRY" ]; do
        ((attempt++))
        log "Recovery attempt ${attempt}/${MAX_RETRY}..."

        if restart_process; then
            sleep 3
            if pgrep -x "$PROC_NAME" &>/dev/null || pgrep -f "$PROC_NAME" &>/dev/null; then
                log "Process recovered successfully (attempt ${attempt})"
                send_alert "[RECOVERED] Process: ${PROC_NAME}@${HOSTNAME}" \
                    "Process ${PROC_NAME} recovered on ${HOSTNAME}\nAttempt: ${attempt}\nTime: $(date +'%F %T')"
                return 0
            fi
        fi

        [ $attempt -lt "$MAX_RETRY" ] && sleep 5
    done

    log "CRITICAL: Failed to recover after ${MAX_RETRY} attempts"
    send_alert "[CRITICAL] Recovery Failed: ${PROC_NAME}@${HOSTNAME}" \
        "CRITICAL: Process ${PROC_NAME} could not be recovered on ${HOSTNAME}\nAttempts: ${MAX_RETRY}\nTime: $(date +'%F %T')\nManual intervention required!"
    return 1
}

if [ "$CHECK_INTERVAL" -gt 0 ]; then
    log "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    while true; do
        check_and_recover
        sleep "$CHECK_INTERVAL"
    done
else
    check_and_recover
fi
