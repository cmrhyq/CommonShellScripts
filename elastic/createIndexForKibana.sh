#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 每月自动创建/删除Kibana索引
# @Usage: ./createIndexForKibana.sh [add|del] [date]
#   action - 操作类型: add(创建) 或 del(删除)，默认 add
#   date   - 目标月份，格式 YYYY-MM，默认当前月份
# @Note: 索引名从 type_log.txt 文件中读取，每行一个索引类型名

set -euo pipefail

readonly ACTION="${1:-add}"
readonly DATE="${2:-$(date +%Y-%m)}"
readonly SCRIPT_DIR="${3:-/mnt/remote/data/elastic/logstash_02/script}"
readonly KIBANA_URL="http://localhost:5601"
readonly DOMAIN_FILE="${SCRIPT_DIR}/type_log.txt"
readonly LOG_FILE="${SCRIPT_DIR}/update_index.log"
readonly MIDDLE_FILE="${SCRIPT_DIR}/middle.txt"

if [ ! -f "$DOMAIN_FILE" ]; then
    echo "ERROR: Domain name file not found: $DOMAIN_FILE"
    exit 1
fi

echo "[$(date +'%F %T')] Action: ${ACTION}, Date: ${DATE}" >> "$LOG_FILE"

grep -E -n '^[[:alnum:]]' "$DOMAIN_FILE" > "$MIDDLE_FILE"
readonly TOTAL=$(wc -l < "$MIDDLE_FILE")

if [ "$TOTAL" -eq 0 ]; then
    echo "No index types found in $DOMAIN_FILE"
    exit 0
fi

success_count=0
error_count=0

for ((i = 1; i <= TOTAL; i++)); do
    domain_type=$(sed -n "${i}p" "$MIDDLE_FILE" | awk -F':' '{print $2}')

    if [ "$ACTION" == "add" ]; then
        if curl -sf -XPOST -H 'Content-Type: application/json' -H 'kbn-xsrf: anything' \
            "${KIBANA_URL}/api/saved_objects/index-pattern/logstash-app_${domain_type}_${DATE}" \
            -d "{\"attributes\":{\"title\":\"logstash-app_${domain_type}_${DATE}\",\"timeFieldName\":\"@timestamp\"}}" >> "$LOG_FILE" 2>&1; then
            ((success_count++))
        else
            ((error_count++))
            echo "error ${domain_type}" >> "$LOG_FILE"
        fi
    elif [ "$ACTION" == "del" ]; then
        if curl -sf -XDELETE "${KIBANA_URL}/api/saved_objects/index-pattern/logstash-app_${domain_type}_${DATE}" \
            -H 'kbn-xsrf: true' >> "$LOG_FILE" 2>&1; then
            ((success_count++))
        else
            ((error_count++))
            echo "error ${domain_type}" >> "$LOG_FILE"
        fi
    else
        echo "ERROR: Invalid action '${ACTION}'. Use 'add' or 'del'" | tee -a "$LOG_FILE"
        exit 1
    fi
done

if [ "$ACTION" == "add" ]; then
    curl -sf -XPOST -H 'Content-Type: application/json' -H 'kbn-xsrf: anything' \
        "${KIBANA_URL}/api/kibana/settings/defaultIndex" \
        -d "{\"value\":\"logstash-app_www_${DATE}\"}" >> "$LOG_FILE" 2>&1
fi

rm -f "$MIDDLE_FILE"

echo "[$(date +'%F %T')] Completed: ${success_count} success, ${error_count} errors" | tee -a "$LOG_FILE"
