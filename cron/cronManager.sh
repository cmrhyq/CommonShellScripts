#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 定时任务管理工具（列表查看/添加/删除/备份/恢复crontab）
# @Usage: ./cronManager.sh <command> [options]
#   list                   - 列出当前用户的所有定时任务
#   add <schedule> <cmd>   - 添加定时任务
#   remove <pattern>       - 删除匹配的定时任务
#   backup [file]          - 备份当前crontab
#   restore <file>         - 从备份文件恢复crontab
#   enable <pattern>       - 启用被注释的任务
#   disable <pattern>      - 注释禁用任务

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list                      List all cron jobs"
    echo "  add <schedule> <command>  Add a cron job"
    echo "  remove <pattern>          Remove matching cron jobs"
    echo "  backup [file]             Backup crontab to file"
    echo "  restore <file>            Restore crontab from file"
    echo "  enable <pattern>          Enable commented jobs"
    echo "  disable <pattern>         Disable (comment out) jobs"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 add '0 2 * * *' '/opt/scripts/backup.sh'"
    echo "  $0 remove 'backup.sh'"
    echo "  $0 backup /tmp/my_crontab.bak"
    echo "  $0 disable 'old_script'"
    exit 1
fi

readonly COMMAND="${1}"
shift

readonly BACKUP_DIR="/opt/backup/cron"

log() {
    echo "[$(date +'%F %T')] $*"
}

cmd_list() {
    echo "--- Crontab for $(whoami) ---"
    echo ""
    local jobs
    jobs=$(crontab -l 2>/dev/null || true)
    if [ -z "$jobs" ]; then
        echo "(empty - no cron jobs configured)"
    else
        local line_num=0
        while IFS= read -r line; do
            ((line_num++))
            if [[ "$line" =~ ^# ]]; then
                echo "  ${line_num}. [DISABLED] ${line}"
            elif [ -n "$line" ]; then
                echo "  ${line_num}. [ACTIVE]   ${line}"
            fi
        done <<< "$jobs"
    fi
    echo ""
    active=$(echo "$jobs" | grep -v '^#' | grep -v '^$' | wc -l)
    disabled=$(echo "$jobs" | grep '^#' | grep -v '^#[[:space:]]*$' | wc -l)
    echo "Total: ${active} active, ${disabled} disabled"
}

cmd_add() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 add <schedule> <command>"
        echo "Example: $0 add '0 2 * * *' '/opt/scripts/backup.sh'"
        exit 1
    fi
    local schedule="$1"
    local cmd="$2"
    local entry="${schedule} ${cmd}"

    if crontab -l 2>/dev/null | grep -qF "$cmd"; then
        log "WARNING: Similar job already exists"
        crontab -l 2>/dev/null | grep -F "$cmd"
        read -p "Add anyway? [y/N]: " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 0
    fi

    (crontab -l 2>/dev/null; echo "$entry") | crontab -
    log "Added: ${entry}"
}

cmd_remove() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 remove <pattern>"
        exit 1
    fi
    local pattern="$1"

    local matches
    matches=$(crontab -l 2>/dev/null | grep -n "$pattern" || true)
    if [ -z "$matches" ]; then
        log "No matching jobs found for: ${pattern}"
        exit 0
    fi

    echo "Matching jobs:"
    echo "$matches"
    echo ""
    read -p "Remove these jobs? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        crontab -l 2>/dev/null | grep -v "$pattern" | crontab -
        log "Removed jobs matching: ${pattern}"
    else
        log "Cancelled"
    fi
}

cmd_backup() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="${1:-${BACKUP_DIR}/crontab_$(whoami)_$(date +%Y%m%d_%H%M%S).bak}"

    if crontab -l > "$backup_file" 2>/dev/null; then
        log "Crontab backed up to: ${backup_file}"
    else
        log "No crontab to backup"
    fi
}

cmd_restore() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 restore <file>"
        exit 1
    fi
    local restore_file="$1"

    if [ ! -f "$restore_file" ]; then
        log "ERROR: File not found: $restore_file"
        exit 1
    fi

    echo "Will restore from: ${restore_file}"
    echo "Content:"
    cat "$restore_file"
    echo ""
    read -p "Restore this crontab? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        crontab "$restore_file"
        log "Crontab restored from: ${restore_file}"
    else
        log "Cancelled"
    fi
}

cmd_enable() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 enable <pattern>"
        exit 1
    fi
    local pattern="$1"
    crontab -l 2>/dev/null | sed "s/^#\(.*${pattern}.*\)/\1/" | crontab -
    log "Enabled jobs matching: ${pattern}"
}

cmd_disable() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 disable <pattern>"
        exit 1
    fi
    local pattern="$1"
    crontab -l 2>/dev/null | sed "/^#/!s/\(.*${pattern}.*\)/#\1/" | crontab -
    log "Disabled jobs matching: ${pattern}"
}

case "$COMMAND" in
    list)    cmd_list ;;
    add)     cmd_add "$@" ;;
    remove)  cmd_remove "$@" ;;
    backup)  cmd_backup "$@" ;;
    restore) cmd_restore "$@" ;;
    enable)  cmd_enable "$@" ;;
    disable) cmd_disable "$@" ;;
    *)
        echo "ERROR: Unknown command: $COMMAND"
        echo "Run '$0' without arguments for help"
        exit 1
        ;;
esac
