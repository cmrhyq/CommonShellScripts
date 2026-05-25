#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 清理N天前的日志文件（支持多目录、多文件模式）
# @Usage: ./logClean.sh [options]
#   -d dirs     - 日志目录列表（逗号分隔），默认 /var/log
#   -k days     - 保留天数，默认30
#   -p pattern  - 文件匹配模式，默认 "*.log *.log.* *.gz"
#   --dry-run   - 仅预览不实际删除

set -euo pipefail

LOG_DIRS="/var/log"
KEEP_DAYS=30
PATTERNS="*.log"
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        -d) LOG_DIRS="$2"; shift 2 ;;
        -k) KEEP_DAYS="$2"; shift 2 ;;
        -p) PATTERNS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-d dirs] [-k days] [-p pattern] [--dry-run]"
            echo ""
            echo "Examples:"
            echo "  $0 -d /var/log/myapp,/opt/logs -k 7"
            echo "  $0 -d /var/log -k 30 -p '*.log.gz' --dry-run"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() {
    echo "[$(date +'%F %T')] $*"
}

total_files=0
total_size=0

log "========================================="
log "  Log Cleanup"
log "  Directories: ${LOG_DIRS}"
log "  Keep days:   ${KEEP_DAYS}"
log "  Pattern:     ${PATTERNS}"
[ "$DRY_RUN" = true ] && log "  Mode: DRY-RUN"
log "========================================="
echo ""

IFS=',' read -ra DIRS <<< "$LOG_DIRS"
for dir in "${DIRS[@]}"; do
    dir=$(echo "$dir" | tr -d ' ')
    if [ ! -d "$dir" ]; then
        log "WARNING: Directory not found: $dir"
        continue
    fi

    log "Scanning: ${dir}"

    IFS=' ' read -ra PAT_LIST <<< "$PATTERNS"
    for pattern in "${PAT_LIST[@]}"; do
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            file_size=$(du -k "$file" 2>/dev/null | awk '{print $1}')
            total_size=$((total_size + file_size))
            ((total_files++))

            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY-RUN] Would delete: ${file} (${file_size}KB)"
            else
                rm -f "$file"
                echo "  Deleted: ${file} (${file_size}KB)"
            fi
        done < <(find "$dir" -name "$pattern" -mtime +"$KEEP_DAYS" -type f 2>/dev/null)
    done
done

echo ""
total_size_mb=$((total_size / 1024))
if [ "$DRY_RUN" = true ]; then
    log "Summary: Would delete ${total_files} file(s), freeing ~${total_size_mb}MB"
else
    log "Summary: Deleted ${total_files} file(s), freed ~${total_size_mb}MB"
fi
