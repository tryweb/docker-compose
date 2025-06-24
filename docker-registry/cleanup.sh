#!/bin/sh

# Registry 清理腳本
# 此腳本會清理超過 7 天未訪問的資料

REGISTRY_DATA_DIR="/var/lib/registry"
LOG_FILE="/tmp/registry-cleanup.log"

# 從環境變數讀取清理天數，如果未設定，則預設為 7 天
DAYS_OLD=${CLEANUP_DAYS_OLD:-7}

# 創建日志函數
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "開始執行 Registry 清理作業..."
log "清理天數設定為: $DAYS_OLD 天"

# 檢查 registry 資料目錄是否存在
if [ ! -d "$REGISTRY_DATA_DIR" ]; then
    log "錯誤: Registry 資料目錄不存在: $REGISTRY_DATA_DIR"
    exit 1
fi

# 計算清理前的磁碟使用量
BEFORE_SIZE=$(du -sh "$REGISTRY_DATA_DIR" | cut -f1)
log "清理前磁碟使用量: $BEFORE_SIZE"

# 清理超過指定天數未訪問的 blob 檔案
log "正在清理超過 $DAYS_OLD 天未訪問的檔案..."
DELETED_COUNT=$(find "$REGISTRY_DATA_DIR" -name "data" -type f -atime +$DAYS_OLD -print | wc -l)

if [ "$DELETED_COUNT" -gt 0 ]; then
    find "$REGISTRY_DATA_DIR" -name "data" -type f -atime +$DAYS_OLD -delete
    log "已刪除 $DELETED_COUNT 個過期的 blob 檔案"
else
    log "沒有找到需要清理的過期檔案"
fi

# 執行 registry 垃圾回收
log "執行 Registry 垃圾回收..."
if registry garbage-collect /etc/docker/registry/config.yml; then
    log "垃圾回收執行成功"
else
    log "警告: 垃圾回收執行失敗"
fi

# 計算清理後的磁碟使用量
AFTER_SIZE=$(du -sh "$REGISTRY_DATA_DIR" | cut -f1)
log "清理後磁碟使用量: $AFTER_SIZE"

# 清理空的目錄
log "清理空目錄..."
find "$REGISTRY_DATA_DIR" -type d -empty -delete 2>/dev/null || true

log "Registry 清理作業完成"
log "----------------------------------------"
