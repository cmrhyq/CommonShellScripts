#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 系统资源使用报告（CPU/内存/磁盘IO/网络/Top进程）
# @Usage: ./resourceReport.sh [options]
#   -o output  - 报告输出文件路径（不指定则输出到终端）
#   -m email   - 发送报告到邮箱
#   -n top_n   - 显示Top N进程，默认10

set -euo pipefail

OUTPUT_FILE=""
ALERT_EMAIL=""
TOP_N=10

while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUTPUT_FILE="$2"; shift 2 ;;
        -m) ALERT_EMAIL="$2"; shift 2 ;;
        -n) TOP_N="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-o output_file] [-m email] [-n top_n]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

readonly HOSTNAME=$(hostname)
readonly REPORT_TIME=$(date +'%F %T')

generate_report() {
    echo "============================================="
    echo "  System Resource Report"
    echo "============================================="
    echo "  Host:    ${HOSTNAME}"
    echo "  Time:    ${REPORT_TIME}"
    echo "  Uptime:  $(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}' | awk -F'up' '{print $2}')"
    echo "============================================="
    echo ""

    echo "--- CPU Usage ---"
    echo "  Load Average: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    echo "  CPU Cores:    $(nproc)"
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' 2>/dev/null || echo "N/A")
    echo "  CPU Idle:     ${cpu_idle}%"
    echo ""

    echo "--- Memory Usage ---"
    free -h | awk '
        /Mem:/ { printf "  Total: %s | Used: %s | Free: %s | Available: %s\n", $2, $3, $4, $7 }
        /Swap:/ { printf "  Swap:  %s | Used: %s | Free: %s\n", $2, $3, $4 }
    '
    mem_percent=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')
    echo "  Usage:   ${mem_percent}%"
    echo ""

    echo "--- Disk Usage ---"
    df -h | grep -vE '^(tmpfs|devtmpfs|Filesystem)' | awk '{printf "  %-20s %6s used of %6s (%s) on %s\n", $1, $3, $2, $5, $6}'
    echo ""

    echo "--- Disk IO ---"
    if command -v iostat &>/dev/null; then
        iostat -d -x 1 1 | tail -n +4 | head -10
    else
        echo "  (iostat not available - install sysstat)"
    fi
    echo ""

    echo "--- Network Connections ---"
    echo "  ESTABLISHED: $(ss -tn state established | wc -l)"
    echo "  TIME_WAIT:   $(ss -tn state time-wait | wc -l)"
    echo "  LISTEN:      $(ss -tln | tail -n +2 | wc -l)"
    echo ""

    echo "--- Top ${TOP_N} Processes by CPU ---"
    ps aux --sort=-%cpu | head -$((TOP_N + 1)) | awk '{printf "  %-10s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}'
    echo ""

    echo "--- Top ${TOP_N} Processes by Memory ---"
    ps aux --sort=-%mem | head -$((TOP_N + 1)) | awk '{printf "  %-10s %5s%% MEM  %6s RSS  %s\n", $1, $4, $6, $11}'
    echo ""

    echo "============================================="
    echo "  Report Generated: ${REPORT_TIME}"
    echo "============================================="
}

if [ -n "$OUTPUT_FILE" ]; then
    generate_report > "$OUTPUT_FILE"
    echo "Report saved to: ${OUTPUT_FILE}"
else
    generate_report
fi

if [ -n "$ALERT_EMAIL" ]; then
    report_content=$(generate_report)
    echo "$report_content" | mail -s "System Resource Report - ${HOSTNAME} - ${REPORT_TIME}" "$ALERT_EMAIL"
    echo "Report sent to: ${ALERT_EMAIL}"
fi
