#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 日志文件切割与归档压缩（按大小或日期切割，自动压缩归档）
# @Usage: ./logRotate.sh <log_file> [options]
#   -s max_size   - 触发切割的文件大小(MB)，默认100
#   -k keep_count - 保留的归档文件数量，默认10
#   -d archive_dir - 归档目录，默认日志文件同目录下的archive子目录
#   -c            - 切割后压缩归档文件

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <log_file> [-s max_size_MB] [-k keep_count] [-d archive_dir] [-c]"
    echo ""
    echo "Examples:"
    echo "  $0 /var/log/myapp/app.log"
    echo "  $0 /var/log/myapp/app.log -s 50 -k 20 -c"
    exit 1
fi

readonly LOG_FILE="${1}"
shift

MAX_SIZE=100
KEEP_COUNT=10
ARCHIVE_DIR=""
COMPRESS=false

while [ $# -gt 0 ]; do
    case "$1" in
        -s) MAX_SIZE="$2"; shift 2 ;;
        -k) KEEP_COUNT="$2"; shift 2 ;;
        -d) ARCHIVE_DIR="$2"; shift 2 ;;
        -c) COMPRESS=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$ARCHIVE_DIR" ]; then
    ARCHIVE_DIR="$(dirname "$LOG_FILE")/archive"
fi

readonly LOG_NAME=$(basename "$LOG_FILE")
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ ! -f "$LOG_FILE" ]; then
    log "ERROR: Log file not found: $LOG_FILE"
    exit 1
fi

file_size_mb=$(du -m "$LOG_FILE" | awk '{print $1}')

if [ "$file_size_mb" -lt "$MAX_SIZE" ]; then
    log "Log file size (${file_size_mb}MB) is below threshold (${MAX_SIZE}MB), skipping"
    exit 0
fi

log "Log file size: ${file_size_mb}MB (threshold: ${MAX_SIZE}MB)"
log "Rotating: ${LOG_FILE}"

mkdir -p "$ARCHIVE_DIR"

archive_file="${ARCHIVE_DIR}/${LOG_NAME}.${TIMESTAMP}"
cp "$LOG_FILE" "$archive_file"
: > "$LOG_FILE"
log "Log truncated, archived to: ${archive_file}"

if [ "$COMPRESS" = true ]; then
    gzip "$archive_file"
    archive_file="${archive_file}.gz"
    log "Compressed: ${archive_file}"
fi

if [ "$COMPRESS" = true ]; then
    pattern="${LOG_NAME}.*.gz"
else
    pattern="${LOG_NAME}.*"
fi

archive_count=$(find "$ARCHIVE_DIR" -name "$pattern" | wc -l)
if [ "$archive_count" -gt "$KEEP_COUNT" ]; then
    excess=$((archive_count - KEEP_COUNT))
    find "$ARCHIVE_DIR" -name "$pattern" -printf '%T@ %p\n' | sort -n | head -"$excess" | awk '{print $2}' | xargs rm -f
    log "Cleaned ${excess} old archive(s), keeping latest ${KEEP_COUNT}"
fi

log "Rotation completed"
