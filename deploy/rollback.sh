#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 快速回滚应用到上一版本（从备份目录恢复）
# @Usage: ./rollback.sh <app_name> [options]
#   -t target_dir  - 部署目标目录
#   -b backup_dir  - 备份存储目录
#   -s service     - systemd服务名称
#   -v version     - 指定回滚版本（备份文件名），不指定则回滚到最近一次

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <app_name> [-t target_dir] [-b backup_dir] [-s service] [-v version]"
    echo "Example: $0 myapp"
    echo "Example: $0 myapp -v myapp_20231201_120000.tar.gz"
    exit 1
fi

readonly APP_NAME="${1}"
shift

TARGET_DIR="/opt/apps/${APP_NAME}"
BACKUP_DIR="/opt/backup/deploy/${APP_NAME}"
SERVICE_NAME="${APP_NAME}"
SPECIFIC_VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        -t) TARGET_DIR="$2"; shift 2 ;;
        -b) BACKUP_DIR="$2"; shift 2 ;;
        -s) SERVICE_NAME="$2"; shift 2 ;;
        -v) SPECIFIC_VERSION="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() {
    echo "[$(date +'%F %T')] [ROLLBACK] $*"
}

if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

if [ -n "$SPECIFIC_VERSION" ]; then
    BACKUP_FILE="${BACKUP_DIR}/${SPECIFIC_VERSION}"
else
    BACKUP_FILE=$(find "$BACKUP_DIR" -name "${APP_NAME}_*.tar.gz" -printf '%T@ %p\n' | sort -rn | head -1 | awk '{print $2}')
fi

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    log "ERROR: No backup found to restore"
    echo ""
    echo "Available backups:"
    find "$BACKUP_DIR" -name "${APP_NAME}_*.tar.gz" -printf '  %f (%TY-%Tm-%Td %TH:%TM)\n' | sort -r | head -10
    exit 1
fi

log "========== Rolling back ${APP_NAME} =========="
log "Backup: $(basename "$BACKUP_FILE")"
log "Target: ${TARGET_DIR}"

log "Step 1: Stopping service..."
if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    log "Service stopped"
fi

log "Step 2: Restoring from backup..."
if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
fi
mkdir -p "$(dirname "$TARGET_DIR")"
tar -xzf "$BACKUP_FILE" -C "$(dirname "$TARGET_DIR")"
log "Files restored"

log "Step 3: Restarting service..."
if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl start "$SERVICE_NAME"
    sleep 3
    if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
        log "Service ${SERVICE_NAME} started successfully"
    else
        log "ERROR: Service failed to start after rollback"
        exit 1
    fi
fi

log "========== Rollback completed =========="
