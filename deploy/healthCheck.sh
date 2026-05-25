#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 服务健康检查（支持HTTP状态码、TCP端口、进程存活三种检查方式）
# @Usage: ./healthCheck.sh <check_type> <target> [options]
#   check_type: http | tcp | process
#   target: URL / host:port / process_name
#   -t timeout   - 超时时间(秒)，默认5
#   -r retries   - 重试次数，默认3
#   -i interval  - 重试间隔(秒)，默认2

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <http|tcp|process> <target> [-t timeout] [-r retries] [-i interval]"
    echo ""
    echo "Examples:"
    echo "  $0 http http://localhost:8080/health"
    echo "  $0 tcp 192.168.1.100:3306"
    echo "  $0 process nginx"
    exit 1
fi

readonly CHECK_TYPE="${1}"
readonly TARGET="${2}"
shift 2

TIMEOUT=5
RETRIES=3
INTERVAL=2

while [ $# -gt 0 ]; do
    case "$1" in
        -t) TIMEOUT="$2"; shift 2 ;;
        -r) RETRIES="$2"; shift 2 ;;
        -i) INTERVAL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() {
    echo "[$(date +'%F %T')] $*"
}

check_http() {
    local url="$1"
    local status_code
    status_code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
        return 0
    else
        log "HTTP check failed: status=${status_code}, url=${url}"
        return 1
    fi
}

check_tcp() {
    local host="${1%:*}"
    local port="${1#*:}"
    if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        return 0
    else
        log "TCP check failed: ${host}:${port}"
        return 1
    fi
}

check_process() {
    local proc_name="$1"
    if pgrep -x "$proc_name" &>/dev/null; then
        return 0
    else
        log "Process check failed: ${proc_name} not running"
        return 1
    fi
}

attempt=0
while [ $attempt -lt "$RETRIES" ]; do
    ((attempt++))

    case "$CHECK_TYPE" in
        http)    check_http "$TARGET" && { log "HEALTHY: ${TARGET} (attempt ${attempt})"; exit 0; } ;;
        tcp)     check_tcp "$TARGET" && { log "HEALTHY: ${TARGET} (attempt ${attempt})"; exit 0; } ;;
        process) check_process "$TARGET" && { log "HEALTHY: ${TARGET} (attempt ${attempt})"; exit 0; } ;;
        *)
            echo "ERROR: Unknown check type: ${CHECK_TYPE}"
            exit 1
            ;;
    esac

    if [ $attempt -lt "$RETRIES" ]; then
        log "Retry ${attempt}/${RETRIES}, waiting ${INTERVAL}s..."
        sleep "$INTERVAL"
    fi
done

log "UNHEALTHY: ${TARGET} (failed after ${RETRIES} attempts)"
exit 1
