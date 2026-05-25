#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 日志关键字分析与统计（按时间段统计错误、警告等关键字出现频次）
# @Usage: ./logAnalyze.sh <log_file> [options]
#   -k keywords  - 关键字列表（逗号分隔），默认 ERROR,WARN,Exception
#   -s since     - 起始时间（支持格式: YYYY-MM-DD 或 "1 hour ago"）
#   -n top_n     - 显示Top N条匹配行，默认20
#   -o output    - 输出报告文件

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <log_file> [-k keywords] [-s since] [-n top_n] [-o output]"
    echo ""
    echo "Examples:"
    echo "  $0 /var/log/myapp/app.log"
    echo "  $0 /var/log/myapp/app.log -k 'ERROR,FATAL,OutOfMemory' -n 50"
    echo "  $0 /var/log/messages -s '2023-12-01' -k 'error,failed,denied'"
    exit 1
fi

readonly LOG_FILE="${1}"
shift

KEYWORDS="ERROR,WARN,Exception,FATAL"
SINCE=""
TOP_N=20
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -k) KEYWORDS="$2"; shift 2 ;;
        -s) SINCE="$2"; shift 2 ;;
        -n) TOP_N="$2"; shift 2 ;;
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Log file not found: $LOG_FILE"
    exit 1
fi

output() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$*" | tee -a "$OUTPUT_FILE"
    else
        echo "$*"
    fi
}

[ -n "$OUTPUT_FILE" ] && : > "$OUTPUT_FILE"

readonly FILE_SIZE=$(du -sh "$LOG_FILE" | awk '{print $1}')
readonly TOTAL_LINES=$(wc -l < "$LOG_FILE")

output "============================================="
output "  Log Analysis Report"
output "============================================="
output "  File:   ${LOG_FILE}"
output "  Size:   ${FILE_SIZE}"
output "  Lines:  ${TOTAL_LINES}"
output "  Time:   $(date +'%F %T')"
if [ -n "$SINCE" ]; then
    output "  Since:  ${SINCE}"
fi
output "============================================="
output ""

log_content="$LOG_FILE"
if [ -n "$SINCE" ]; then
    since_ts=$(date -d "$SINCE" +%s 2>/dev/null || echo "0")
    if [ "$since_ts" != "0" ]; then
        log_content=$(mktemp)
        while IFS= read -r line; do
            line_date=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}' | head -1)
            if [ -n "$line_date" ]; then
                line_ts=$(date -d "$line_date" +%s 2>/dev/null || echo "0")
                [ "$line_ts" -ge "$since_ts" ] && echo "$line"
            fi
        done < "$LOG_FILE" > "$log_content"
    fi
fi

output "--- Keyword Frequency ---"
output ""
IFS=',' read -ra KW_LIST <<< "$KEYWORDS"
for keyword in "${KW_LIST[@]}"; do
    keyword=$(echo "$keyword" | tr -d ' ')
    count=$(grep -ci "$keyword" "$log_content" 2>/dev/null || echo "0")
    output "  $(printf '%-20s : %d occurrences' "$keyword" "$count")"
done
output ""

output "--- Hourly Distribution (Last Keyword: ${KW_LIST[0]}) ---"
output ""
first_keyword="${KW_LIST[0]}"
grep -i "$first_keyword" "$log_content" 2>/dev/null | \
    grep -oP '\d{2}(?=:\d{2}:\d{2})' | \
    sort | uniq -c | sort -rn | \
    while read -r count hour; do
        bar=$(printf '%*s' "$((count > 50 ? 50 : count))" '' | tr ' ' '#')
        output "  $(printf '%s:00  %4d  %s' "$hour" "$count" "$bar")"
    done
output ""

output "--- Top ${TOP_N} Error Lines ---"
output ""
grep_pattern=$(echo "${KEYWORDS}" | tr ',' '|')
grep -iE "$grep_pattern" "$log_content" 2>/dev/null | tail -"$TOP_N" | while IFS= read -r line; do
    output "  ${line:0:200}"
done
output ""

output "============================================="
output "  Analysis completed: $(date +'%F %T')"
output "============================================="

[ -n "$SINCE" ] && [ "$log_content" != "$LOG_FILE" ] && rm -f "$log_content"
