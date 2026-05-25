#!/bin/bash
# @Author: Alan Huang
# @E-mail: cmrhyq@163.com
# @Description: 通用应用部署脚本（拉取代码/编译/备份/重启服务）
# @Usage: ./deploy.sh <app_name> [options]
#   -r repo_dir    - 代码仓库目录
#   -b branch      - 部署分支，默认 main
#   -t target_dir  - 部署目标目录
#   -s service     - systemd服务名称
#   --skip-build   - 跳过编译步骤

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <app_name> [-r repo_dir] [-b branch] [-t target_dir] [-s service] [--skip-build]"
    echo "Example: $0 myapp -r /opt/src/myapp -b main -t /opt/apps/myapp -s myapp"
    exit 1
fi

readonly APP_NAME="${1}"
shift

REPO_DIR="/opt/src/${APP_NAME}"
BRANCH="main"
TARGET_DIR="/opt/apps/${APP_NAME}"
SERVICE_NAME="${APP_NAME}"
SKIP_BUILD=false

while [ $# -gt 0 ]; do
    case "$1" in
        -r) REPO_DIR="$2"; shift 2 ;;
        -b) BRANCH="$2"; shift 2 ;;
        -t) TARGET_DIR="$2"; shift 2 ;;
        -s) SERVICE_NAME="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

readonly BACKUP_DIR="/opt/backup/deploy/${APP_NAME}"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo "[$(date +'%F %T')] [DEPLOY] $*"
}

log "========== Deploying ${APP_NAME} =========="
log "Branch: ${BRANCH}"
log "Repo: ${REPO_DIR}"
log "Target: ${TARGET_DIR}"

if [ ! -d "$REPO_DIR" ]; then
    log "ERROR: Repository not found: $REPO_DIR"
    exit 1
fi

log "Step 1: Pulling latest code..."
cd "$REPO_DIR"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH"
readonly COMMIT=$(git log -1 --format='%h %s')
log "Latest commit: ${COMMIT}"

if [ "$SKIP_BUILD" = false ]; then
    log "Step 2: Building..."
    if [ -f "pom.xml" ]; then
        mvn clean package -DskipTests
    elif [ -f "build.gradle" ]; then
        ./gradlew build -x test
    elif [ -f "package.json" ]; then
        npm install && npm run build
    elif [ -f "Makefile" ]; then
        make clean && make
    else
        log "WARNING: No build system detected, skipping build"
    fi
else
    log "Step 2: Build skipped (--skip-build)"
fi

log "Step 3: Backing up current version..."
mkdir -p "$BACKUP_DIR"
if [ -d "$TARGET_DIR" ]; then
    tar -czf "${BACKUP_DIR}/${APP_NAME}_${TIMESTAMP}.tar.gz" -C "$(dirname "$TARGET_DIR")" "$(basename "$TARGET_DIR")"
    log "Backup saved: ${BACKUP_DIR}/${APP_NAME}_${TIMESTAMP}.tar.gz"
fi

log "Step 4: Deploying new version..."
mkdir -p "$TARGET_DIR"
if [ -d "target" ] && ls target/*.jar &>/dev/null; then
    cp target/*.jar "$TARGET_DIR/"
elif [ -d "dist" ]; then
    rsync -a --delete dist/ "$TARGET_DIR/"
elif [ -d "build" ]; then
    rsync -a --delete build/ "$TARGET_DIR/"
fi

log "Step 5: Restarting service..."
if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl restart "$SERVICE_NAME"
    sleep 3
    if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
        log "Service ${SERVICE_NAME} restarted successfully"
    else
        log "ERROR: Service failed to start, rolling back..."
        exit 1
    fi
else
    log "WARNING: Service ${SERVICE_NAME} not found in systemd"
fi

log "========== Deploy completed =========="
