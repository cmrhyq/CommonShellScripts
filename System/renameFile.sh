#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量重命名文件
# @Usage: ./renameFile.sh <mode> <pattern>
#   mode=1: 删除文件名左边的pattern前缀 (使用 # 截取)
#   mode=2: 删除文件名右边的pattern后缀并添加abc前缀 (使用 % 截取)
#
# Shell字符串截取说明:
#   ${var#pattern}  - 从左删除最短匹配
#   ${var##pattern} - 从左删除最长匹配
#   ${var%pattern}  - 从右删除最短匹配
#   ${var%%pattern} - 从右删除最长匹配

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <mode> <pattern>"
    echo "  mode=1: Remove prefix matching pattern from filenames"
    echo "  mode=2: Remove suffix matching pattern and add 'abc' prefix"
    echo "Example: $0 1 'GS53YNCKTX'"
    exit 1
fi

readonly CHOOSE="${1}"
readonly CUT="${2}"

case "$CHOOSE" in
    1)
        for name in *; do
            [ -e "$name" ] || continue
            new_name="${name#${CUT}}"
            if [ "$name" != "$new_name" ]; then
                mv "$name" "$new_name"
                echo "Renamed: $name -> $new_name"
            fi
        done
        ;;
    2)
        for name in *"${CUT}"*; do
            [ -e "$name" ] || continue
            new_name="abc${name%${CUT}*}"
            mv "$name" "$new_name"
            echo "Renamed: $name -> $new_name"
        done
        ;;
    *)
        echo "ERROR: Invalid mode '$CHOOSE'. Use 1 or 2."
        exit 1
        ;;
esac
