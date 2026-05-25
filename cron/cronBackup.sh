#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 定时任务配置备份（备份所有用户的crontab和系统级cron配置）
# @Usage: sudo ./cronBackup.sh [backup_dir]
#   backup_dir - 备份目录，默认 /opt/backup/cron

set -euo pipefail

readonly BACKUP_DIR="${1:-/opt/backup/cron}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "WARNING: Running without root - can only backup current user's crontab"
    echo "Use 'sudo $0' to backup all users"
    echo ""
fi

mkdir -p "$BACKUP_PATH"

log "========================================="
log "  Cron Configuration Backup"
log "  Destination: ${BACKUP_PATH}"
log "========================================="
echo ""

log "Backing up user crontabs..."
user_count=0
if [ "$(id -u)" -eq 0 ]; then
    crontab_dir="/var/spool/cron"
    [ -d "/var/spool/cron/crontabs" ] && crontab_dir="/var/spool/cron/crontabs"

    if [ -d "$crontab_dir" ]; then
        mkdir -p "${BACKUP_PATH}/user_crontabs"
        for crontab_file in "$crontab_dir"/*; do
            [ -f "$crontab_file" ] || continue
            username=$(basename "$crontab_file")
            cp "$crontab_file" "${BACKUP_PATH}/user_crontabs/${username}"
            ((user_count++))
            log "  Backed up: ${username}"
        done
    fi
else
    mkdir -p "${BACKUP_PATH}/user_crontabs"
    if crontab -l > "${BACKUP_PATH}/user_crontabs/$(whoami)" 2>/dev/null; then
        ((user_count++))
        log "  Backed up: $(whoami)"
    fi
fi
log "  Total user crontabs: ${user_count}"
echo ""

log "Backing up system cron directories..."
sys_count=0
declare -a CRON_DIRS=(
    "/etc/crontab"
    "/etc/cron.d"
    "/etc/cron.daily"
    "/etc/cron.hourly"
    "/etc/cron.weekly"
    "/etc/cron.monthly"
)

mkdir -p "${BACKUP_PATH}/system"
for item in "${CRON_DIRS[@]}"; do
    if [ -e "$item" ]; then
        cp -a "$item" "${BACKUP_PATH}/system/" 2>/dev/null || true
        ((sys_count++))
        log "  Backed up: ${item}"
    fi
done
log "  Total system items: ${sys_count}"
echo ""

log "Backing up anacron configuration..."
if [ -f "/etc/anacrontab" ]; then
    cp /etc/anacrontab "${BACKUP_PATH}/system/"
    log "  Backed up: /etc/anacrontab"
fi
echo ""

log "Creating backup archive..."
archive_file="${BACKUP_DIR}/cron_backup_${TIMESTAMP}.tar.gz"
tar -czf "$archive_file" -C "$BACKUP_DIR" "$TIMESTAMP"
rm -rf "$BACKUP_PATH"

archive_size=$(du -sh "$archive_file" | awk '{print $1}')
log "Archive created: ${archive_file} (${archive_size})"

log "Cleaning old backups (keeping last 30)..."
backup_count=$(find "$BACKUP_DIR" -name "cron_backup_*.tar.gz" | wc -l)
if [ "$backup_count" -gt 30 ]; then
    find "$BACKUP_DIR" -name "cron_backup_*.tar.gz" -printf '%T@ %p\n' | sort -n | head -$((backup_count - 30)) | awk '{print $2}' | xargs rm -f
    log "  Cleaned $((backup_count - 30)) old backup(s)"
fi

echo ""
log "========================================="
log "  Backup completed: ${archive_file}"
log "========================================="
