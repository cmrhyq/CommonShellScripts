#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 按日期筛选文件，根据文件名前缀移动到不同目录
# @Usage: ./moveFile.sh <date>
#   date - 筛选日期，格式 YYYY-MM-DD

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <date>"
    echo "Example: $0 2023-01-15"
    exit 1
fi

readonly DATE="${1}"
readonly FILE_PATH_1="/opt"
readonly FILE_PATH_2="/tmp"

for FILE in $(find . -maxdepth 1 -newermt "${DATE}"); do
    if [[ "$FILE" == *HM* ]]; then
        echo "Moving file ${FILE} to ${FILE_PATH_1}"
        mv "$FILE" "${FILE_PATH_1}/"
    elif [[ "$FILE" == *VS* ]]; then
        echo "Moving file ${FILE} to ${FILE_PATH_2}"
        mv "$FILE" "${FILE_PATH_2}/"
    else
        echo "Skipped: ${FILE}"
    fi
done
