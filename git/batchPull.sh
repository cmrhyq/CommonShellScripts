#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 批量拉取指定目录下所有Git仓库的最新代码
# @Usage: ./batchPull.sh [parent_dir] [branch]
#   parent_dir - 包含多个Git仓库的父目录，默认当前目录
#   branch     - 要拉取的分支名，默认当前分支

set -euo pipefail

readonly PARENT_DIR="${1:-.}"
readonly BRANCH="${2:-}"

log() {
    echo "[$(date +'%F %T')] $*"
}

if [ ! -d "$PARENT_DIR" ]; then
    echo "ERROR: Directory not found: $PARENT_DIR"
    exit 1
fi

success_count=0
fail_count=0

for dir in "$PARENT_DIR"/*/; do
    [ -d "${dir}.git" ] || continue

    repo_name=$(basename "$dir")
    log "Pulling: ${repo_name}"

    if cd "$dir"; then
        target_branch="${BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null || echo 'main')}"
        if git pull origin "$target_branch" 2>&1; then
            ((success_count++))
        else
            log "WARNING: Failed to pull ${repo_name}"
            ((fail_count++))
        fi
        cd - > /dev/null
    fi
done

log "Completed: ${success_count} success, ${fail_count} failed"
