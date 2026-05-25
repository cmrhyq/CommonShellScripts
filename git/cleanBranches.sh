#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 清理已合并到主分支的本地Git分支
# @Usage: ./cleanBranches.sh [main_branch]
#   main_branch - 主分支名称，默认 main

set -euo pipefail

readonly MAIN_BRANCH="${1:-main}"

log() {
    echo "[$(date +'%F %T')] $*"
}

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

current_branch=$(git symbolic-ref --short HEAD)
if [ "$current_branch" != "$MAIN_BRANCH" ]; then
    log "Switching to ${MAIN_BRANCH}..."
    git checkout "$MAIN_BRANCH"
fi

log "Fetching and pruning remote..."
git fetch --prune

merged_branches=$(git branch --merged "$MAIN_BRANCH" | grep -vE "^\*|${MAIN_BRANCH}|master|main|develop|dev" || true)

if [ -z "$merged_branches" ]; then
    log "No merged branches to clean"
    exit 0
fi

log "The following branches will be deleted:"
echo "$merged_branches"
echo ""

read -p "Confirm deletion? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "$merged_branches" | xargs -r git branch -d
    log "Branches cleaned successfully"
else
    log "Operation cancelled"
fi
