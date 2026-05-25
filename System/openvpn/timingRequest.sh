#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 定时请求网站保持VPN连接活跃
# @Usage: 添加到crontab: */5 * * * * /path/to/timingRequest.sh

set -euo pipefail

readonly CERT_PATH="${HOME}/script/timer/R3.ca"
readonly TARGET_URL="https://10.21.0.5:8001/portal/"

if [ ! -f "$CERT_PATH" ]; then
    echo "ERROR: Certificate not found: $CERT_PATH"
    exit 1
fi

curl --silent --cacert "$CERT_PATH" "$TARGET_URL" > /dev/null 2>&1
