#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 备份文件轮转管理（按天数或份数保留，支持多种清理策略）
# @Usage: ./backupRotate.sh <backup_dir> [options]
#   -d days     - 保留最近N天的备份，默认7
#   -n count    - 保留最近N份备份（优先级高于-d）
#   -p pattern  - 文件匹配模式，默认 "*.tar.gz *.sql.gz *.zip"
#   --dry-run   - 仅显示将被删除的文件，不实际删除

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_dir> [-d days] [-n count] [-p pattern] [--dry-run]"
    echo "Example: $0 /opt/backup -d 30"
    echo "Example: $0 /opt/backup -n 10 -p '*.sql.gz'"
    exit 1
fi

BACKUP_DIR="${1}"
shift

KEEP_DAYS=7
KEEP_COUNT=0
PATTERN="*.tar.gz"
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        -d) KEEP_DAYS="$2"; shift 2 ;;
        -n) KEEP_COUNT="$2"; shift 2 ;;
        -p) PATTERN="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: Directory not found: $BACKUP_DIR"
    exit 1
fi

total_before=$(find "$BACKUP_DIR" -name "$PATTERN" | wc -l)
total_size_before=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')

log "Backup directory: ${BACKUP_DIR}"
log "Current backups: ${total_before} files (${total_size_before})"

if [ "$KEEP_COUNT" -gt 0 ]; then
    log "Strategy: Keep latest ${KEEP_COUNT} files (pattern: ${PATTERN})"

    files_to_delete=$(find "$BACKUP_DIR" -name "$PATTERN" -printf '%T@ %p\n' | sort -rn | tail -n +$((KEEP_COUNT + 1)) | awk '{print $2}')

    if [ -z "$files_to_delete" ]; then
        log "No files to delete"
        exit 0
    fi

    delete_count=0
    while IFS= read -r file; do
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] Would delete: $file"
        else
            rm -f "$file"
        fi
        ((delete_count++))
    done <<< "$files_to_delete"

else
    log "Strategy: Keep files from last ${KEEP_DAYS} days (pattern: ${PATTERN})"

    if [ "$DRY_RUN" = true ]; then
        delete_count=$(find "$BACKUP_DIR" -name "$PATTERN" -mtime +"$KEEP_DAYS" -print | tee /dev/stderr | wc -l)
    else
        delete_count=$(find "$BACKUP_DIR" -name "$PATTERN" -mtime +"$KEEP_DAYS" -print -delete | wc -l)
    fi
fi

total_after=$(find "$BACKUP_DIR" -name "$PATTERN" | wc -l)
total_size_after=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')

if [ "$DRY_RUN" = true ]; then
    log "[DRY-RUN] Would delete ${delete_count} file(s)"
else
    log "Deleted: ${delete_count} file(s)"
    log "Remaining: ${total_after} files (${total_size_after})"
fi
