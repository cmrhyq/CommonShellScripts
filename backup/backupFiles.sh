#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 文件/目录定时备份（tar.gz压缩 + 自动轮转清理旧备份）
# @Usage: ./backupFiles.sh <source_path> [backup_dir] [keep_days]
#   source_path - 要备份的文件或目录
#   backup_dir  - 备份存储目录，默认 /opt/backup/files
#   keep_days   - 保留天数，默认7天

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <source_path> [backup_dir] [keep_days]"
    echo "Example: $0 /etc/nginx /opt/backup/nginx 30"
    exit 1
fi

readonly SOURCE_PATH="${1}"
readonly BACKUP_DIR="${2:-/opt/backup/files}"
readonly KEEP_DAYS="${3:-7}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly SOURCE_NAME=$(basename "$SOURCE_PATH")
readonly BACKUP_FILE="${BACKUP_DIR}/${SOURCE_NAME}_${TIMESTAMP}.tar.gz"

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ ! -e "$SOURCE_PATH" ]; then
    log "ERROR: Source not found: $SOURCE_PATH"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

log "Starting backup: ${SOURCE_PATH}"
if tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_PATH")" "$SOURCE_NAME"; then
    file_size=$(du -sh "$BACKUP_FILE" | awk '{print $1}')
    log "Backup created: ${BACKUP_FILE} (${file_size})"
else
    log "ERROR: Backup failed"
    exit 1
fi

log "Cleaning backups older than ${KEEP_DAYS} days..."
deleted_count=$(find "$BACKUP_DIR" -name "${SOURCE_NAME}_*.tar.gz" -mtime +"$KEEP_DAYS" -print -delete | wc -l)
log "Cleaned ${deleted_count} old backup(s)"

log "Backup completed successfully"
