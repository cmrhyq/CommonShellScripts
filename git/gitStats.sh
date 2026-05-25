#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: Git提交统计（按作者、日期范围统计提交数和代码行数变化）
# @Usage: ./gitStats.sh [since] [until] [author]
#   since  - 起始日期，默认30天前 (格式: YYYY-MM-DD)
#   until  - 截止日期，默认今天
#   author - 按作者过滤，默认所有作者

set -euo pipefail

readonly SINCE="${1:-$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)}"
readonly UNTIL="${2:-$(date +%Y-%m-%d)}"
readonly AUTHOR="${3:-}"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

echo "========================================="
echo "  Git Statistics Report"
echo "========================================="
echo "  Period: ${SINCE} ~ ${UNTIL}"
[ -n "$AUTHOR" ] && echo "  Author: ${AUTHOR}"
echo "========================================="
echo ""

author_filter=""
if [ -n "$AUTHOR" ]; then
    author_filter="--author=${AUTHOR}"
fi

echo "--- Commits per Author ---"
git shortlog -sn --since="$SINCE" --until="$UNTIL" $author_filter
echo ""

echo "--- Code Changes per Author ---"
git log --since="$SINCE" --until="$UNTIL" $author_filter --format='%aN' --numstat | \
    awk '
    BEGIN { current="" }
    /^[a-zA-Z]/ { current=$0; next }
    /^[0-9]/ { added[current]+=$1; deleted[current]+=$2 }
    END {
        printf "%-30s %10s %10s %10s\n", "Author", "Added", "Deleted", "Net"
        printf "%-30s %10s %10s %10s\n", "------", "-----", "-------", "---"
        for (author in added) {
            net = added[author] - deleted[author]
            printf "%-30s %10d %10d %10d\n", author, added[author], deleted[author], net
        }
    }'
echo ""

echo "--- Commits per Day ---"
git log --since="$SINCE" --until="$UNTIL" $author_filter --format='%ad' --date=short | \
    sort | uniq -c | sort -rn | head -20
echo ""

echo "--- Most Active Files (Top 10) ---"
git log --since="$SINCE" --until="$UNTIL" $author_filter --name-only --format='' | \
    sort | uniq -c | sort -rn | head -10
