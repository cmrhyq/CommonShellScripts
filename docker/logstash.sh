#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 创建Logstash Docker容器
# @Usage: ./logstash.sh [version] [name]
#   version - Logstash版本号，默认 8.2.2
#   name    - 容器名称，默认 logstash

set -euo pipefail

readonly VERSION="${1:-8.2.2}"
readonly CONTAINER_NAME="${2:-logstash}"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '${CONTAINER_NAME}' already exists"
    echo "Use: docker rm -f ${CONTAINER_NAME}"
    exit 1
fi

docker run -dit \
    --name="${CONTAINER_NAME}" \
    --restart=always \
    --privileged=true \
    -e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
    -p 5044:5044 \
    "logstash:${VERSION}"

echo "Logstash container '${CONTAINER_NAME}' created (version: ${VERSION})"
