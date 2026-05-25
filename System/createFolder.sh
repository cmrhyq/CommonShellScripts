#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量创建带子目录结构的文件夹
# @Usage: ./createFolder.sh <path> <prefix>
#   path   - 父目录路径
#   prefix - 文件夹名前缀

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <path> <prefix>"
    echo "Example: $0 /opt/apps executor"
    exit 1
fi

readonly BASE_PATH="${1}"
readonly PREFIX="${2}"
readonly SUFFIXES=("100" "200" "300")

if [ ! -d "$BASE_PATH" ]; then
    echo "ERROR: Directory does not exist: $BASE_PATH"
    exit 1
fi

for suffix in "${SUFFIXES[@]}"; do
    dir="${BASE_PATH}/${PREFIX}-${suffix}"
    mkdir -p "${dir}/in" "${dir}/out" "${dir}/err"
    echo "Created: ${dir}/{in,out,err}"
done
