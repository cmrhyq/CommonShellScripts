#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: OpenVPN服务管理（启动/停止/重启/状态/日志）
# @Usage: ./manager.sh <start|stop|restart|status|log|help> [config_file]

cd "$(dirname "$0")"
readonly WORK_DIR=$(pwd)
readonly FILE_PATH="${2:-}"
readonly LOG_PATH="${WORK_DIR}/log/openvpn.log"
readonly SERVICE_NAME="OpenVPN"
readonly PID_DIR="${WORK_DIR}/pid"
readonly PID_FILE="${PID_DIR}/${SERVICE_NAME}.pid"

is_exist() {
    pid=$(ps -ef | grep "${SERVICE_NAME}" | grep -v grep | awk '{print $2}')
    if [ -z "${pid}" ]; then
        return 1
    else
        return 0
    fi
}

start() {
    if [ -z "$FILE_PATH" ]; then
        echo "ERROR: Config file required. Usage: $0 start <config_file>"
        exit 1
    fi
    is_exist
    if [ $? -eq 0 ]; then
        echo ">>> ${SERVICE_NAME} already running, PID = ${pid} <<<"
    else
        mkdir -p "$PID_DIR" "$(dirname "$LOG_PATH")"
        openvpn --daemon --cd "${WORK_DIR}/client" --config "${FILE_PATH}" --log-append "${LOG_PATH}"
        echo $! > "${PID_FILE}"
        echo ">>> ${SERVICE_NAME} started, PID = $! <<<"
        echo ">>> Log Path: ${LOG_PATH} <<<"
    fi
}

stop() {
    if [ ! -f "${PID_FILE}" ]; then
        echo ">>> PID file not found, checking process... <<<"
        is_exist
        if [ $? -eq 0 ]; then
            kill "${pid}" 2>/dev/null
            echo ">>> ${SERVICE_NAME} stopped (PID: ${pid}) <<<"
        else
            echo ">>> ${SERVICE_NAME} is not running <<<"
        fi
        return
    fi
    local pidf
    pidf="$(cat "${PID_FILE}")"
    echo ">>> Stopping ${SERVICE_NAME} (PID: ${pidf}) <<<"
    kill "${pidf}" 2>/dev/null
    rm -f "${PID_FILE}"
    sleep 2
    is_exist
    if [ $? -eq 0 ]; then
        echo ">>> Force stopping ${SERVICE_NAME} (PID: ${pid}) <<<"
        kill -9 "${pid}" 2>/dev/null
        sleep 2
    fi
    echo ">>> ${SERVICE_NAME} stopped <<<"
}

restart() {
    stop
    start
}

status() {
    is_exist
    if [ $? -eq 0 ]; then
        echo ">>> ${SERVICE_NAME} is running, PID = ${pid} <<<"
    else
        echo ">>> ${SERVICE_NAME} is not running <<<"
    fi
}

show_log() {
    if [ -f "${LOG_PATH}" ]; then
        tail -f "${LOG_PATH}"
    else
        echo "Log file not found: ${LOG_PATH}"
    fi
}

usage() {
    echo "OpenVPN Service Manager"
    echo "Usage: $0 <command> [config_file]"
    echo ""
    echo "Commands:"
    echo "  start   <config>  Start OpenVPN with specified config"
    echo "  stop              Stop OpenVPN"
    echo "  restart <config>  Restart OpenVPN"
    echo "  status            Show running status"
    echo "  log               Tail the log file"
    echo "  help              Show this help"
}

case "${1:-help}" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    log)     show_log ;;
    help|*)  usage ;;
esac

exit 0
