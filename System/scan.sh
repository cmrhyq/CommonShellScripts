#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 使用GScan插件扫描主机，生成安全扫描报告并发送到指定邮箱
# @Usage: bash scan.sh [email]
# @Dependency: GScan (https://github.com/grayddq/GScan.git), mailx

set -euo pipefail

readonly MAIL="${1:-cmrhyq@163.com}"
readonly GSCAN_DIR="/opt/GScan"

if [ ! -d "$GSCAN_DIR" ]; then
    echo "ERROR: GScan not found at $GSCAN_DIR"
    echo "Install: git clone https://github.com/grayddq/GScan.git $GSCAN_DIR"
    exit 1
fi

python "${GSCAN_DIR}/GScan.py" --sug --pro

if [ -f "${GSCAN_DIR}/log/gscan.log" ]; then
    echo "Host Security Scan Log" | mail -s 'Host Security Scan Log' "$MAIL" \
        -a "${GSCAN_DIR}/log/log.log" < "${GSCAN_DIR}/log/gscan.log"
    echo "Report sent to: $MAIL"
else
    echo "ERROR: Scan log not found"
    exit 1
fi
