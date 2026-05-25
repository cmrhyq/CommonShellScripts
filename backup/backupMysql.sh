#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: MySQL数据库全量备份（支持单库/全库，带压缩和轮转）
# @Usage: ./backupMysql.sh [options]
#   -u username  - MySQL用户名，默认 root
#   -p password  - MySQL密码（或使用 ~/.my.cnf）
#   -H host      - MySQL主机，默认 localhost
#   -P port      - MySQL端口，默认 3306
#   -d database  - 指定数据库（不指定则备份全部）
#   -o output    - 备份输出目录，默认 /opt/backup/mysql
#   -k days      - 保留天数，默认7天

set -euo pipefail

DB_USER="root"
DB_PASS=""
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME=""
BACKUP_DIR="/opt/backup/mysql"
KEEP_DAYS=7

while getopts "u:p:H:P:d:o:k:" opt; do
    case $opt in
        u) DB_USER="$OPTARG" ;;
        p) DB_PASS="$OPTARG" ;;
        H) DB_HOST="$OPTARG" ;;
        P) DB_PORT="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        o) BACKUP_DIR="$OPTARG" ;;
        k) KEEP_DAYS="$OPTARG" ;;
        *)
            echo "Usage: $0 [-u user] [-p pass] [-H host] [-P port] [-d db] [-o dir] [-k days]"
            exit 1
            ;;
    esac
done

readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo "[$(date +'%F %T')] $*"
}

mkdir -p "$BACKUP_DIR"

MYSQL_OPTS="-h${DB_HOST} -P${DB_PORT} -u${DB_USER}"
if [ -n "$DB_PASS" ]; then
    MYSQL_OPTS="${MYSQL_OPTS} -p${DB_PASS}"
fi

if [ -n "$DB_NAME" ]; then
    backup_file="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
    log "Backing up database: ${DB_NAME}"
    if mysqldump $MYSQL_OPTS --single-transaction --routines --triggers --databases "$DB_NAME" | gzip > "$backup_file"; then
        file_size=$(du -sh "$backup_file" | awk '{print $1}')
        log "Success: ${backup_file} (${file_size})"
    else
        log "ERROR: Failed to backup ${DB_NAME}"
        exit 1
    fi
else
    backup_file="${BACKUP_DIR}/all_databases_${TIMESTAMP}.sql.gz"
    log "Backing up all databases"
    if mysqldump $MYSQL_OPTS --single-transaction --routines --triggers --all-databases | gzip > "$backup_file"; then
        file_size=$(du -sh "$backup_file" | awk '{print $1}')
        log "Success: ${backup_file} (${file_size})"
    else
        log "ERROR: Failed to backup all databases"
        exit 1
    fi
fi

log "Cleaning backups older than ${KEEP_DAYS} days..."
deleted_count=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$KEEP_DAYS" -print -delete | wc -l)
log "Cleaned ${deleted_count} old backup(s)"

log "MySQL backup completed"
