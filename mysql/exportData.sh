#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量导出MySQL数据库表数据
# @Usage: ./exportData.sh <username> <password>
#   username - MySQL用户名
#   password - MySQL密码

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo "Example: $0 root mypassword"
    exit 1
fi

readonly USERNAME="${1}"
readonly PASSWORD="${2}"
readonly EXPORT_DIR="/var/lib/mysql"

dic=(
    'ApolloConfigDB'
    'ApolloPortalDB'
    'hfish'
    'nacos_config'
    'store'
    'store_dev'
    'xxl_job'
)

log() {
    echo "[$(date +'%F %T')] $*"
}

for dbname in "${dic[@]}"; do
    log "Exporting ${dbname} ..."
    if mysqldump --databases "${dbname}" -u"${USERNAME}" -p"${PASSWORD}" > "${EXPORT_DIR}/${dbname}.sql" 2>/dev/null; then
        log "Export ${dbname} succeeded"
    else
        log "ERROR: Export ${dbname} failed"
    fi
done

log "All exports completed"
