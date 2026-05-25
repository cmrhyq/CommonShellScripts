#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 初始化Oracle数据库所需的用户组和权限
# @Usage: sudo bash initOraclePermission.sh [data_dir]
#   data_dir - Oracle数据目录（包含oradata和scripts），默认当前目录

set -euo pipefail

readonly DATA_DIR="${1:-.}"

groupadd -g 54321 oinstall  2>/dev/null || true
groupadd -g 54322 dba       2>/dev/null || true
groupadd -g 54323 oper      2>/dev/null || true
groupadd -g 54324 backupdba 2>/dev/null || true
groupadd -g 54325 dgdba     2>/dev/null || true
groupadd -g 54326 kmdba     2>/dev/null || true
groupadd -g 54330 racdba    2>/dev/null || true

if ! id oracle &>/dev/null; then
    useradd oracle -u 54321 -G oinstall,dba,oper,backupdba,dgdba,kmdba,racdba
    echo "User 'oracle' created"
else
    echo "User 'oracle' already exists"
fi

if [ -d "${DATA_DIR}/oradata" ] && [ -d "${DATA_DIR}/scripts" ]; then
    chown 54321:54321 "${DATA_DIR}/oradata" "${DATA_DIR}/scripts"
    echo "Permissions set on oradata and scripts directories"
else
    echo "WARNING: oradata/scripts directories not found in ${DATA_DIR}"
fi
