#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 从Logstash容器复制配置文件到本地目录
# @Usage: ./copyConfig.sh <container_id> [target_dir]
#   container_id - Docker容器ID或名称
#   target_dir   - 本地目标目录，默认 /mnt/remote/data/elastic/logstash_02

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <container_id> [target_dir]"
    echo "Example: $0 abc123def /opt/logstash-backup"
    exit 1
fi

readonly CONTAINER_ID="${1}"
readonly TARGET_DIR="${2:-/mnt/remote/data/elastic/logstash_02}"

if ! docker inspect "$CONTAINER_ID" &>/dev/null; then
    echo "ERROR: Container not found: $CONTAINER_ID"
    exit 1
fi

mkdir -p "$TARGET_DIR"

declare -a PATHS=(
    "/usr/share/logstash/config"
    "/usr/share/logstash/data"
    "/usr/share/logstash/modules"
    "/usr/share/logstash/pipeline"
    "/usr/share/logstash/tools"
)

for src in "${PATHS[@]}"; do
    echo "Copying ${src} ..."
    sudo docker cp "${CONTAINER_ID}:${src}" "${TARGET_DIR}/"
done

echo "Copying /var/log ..."
sudo docker cp "${CONTAINER_ID}:/var/log" "${TARGET_DIR}/log"

echo "Done. Files copied to: ${TARGET_DIR}"
