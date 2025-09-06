#!/bin/bash
export LANG=en_US.utf8

# --- .env 檔案載入 ---
# 取得腳本所在的目錄
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 如果 .env 檔案存在，則載入它
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# --- 命令列參數解析 ---
# 注意：此處只處理命令列傳入的參數，最終值的確定在後面
DRY_RUN=false
CLI_EXCLUDE_PATTERNS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) CLI_SOURCE_DIR="$2"; shift ;; 
        -d|--dest-root) CLI_DEST_ROOT="$2"; shift ;; 
        -e|--exceptions) CLI_EXCEPTIONS_FILE="$2"; shift ;; 
        -l|--log-dir) CLI_LOG_DIR="$2"; shift ;; 
        -n|--name) CLI_NAME="$2"; shift ;; 
        -f|--exclude-file) CLI_EXCLUDE_FILE="$2"; shift ;; 
        -x|--exclude) CLI_EXCLUDE_PATTERNS+=("$2"); shift ;; 
        -b|--bwlimit) CLI_BW_LIMIT="$2"; shift ;; 
        -r|--retention-days) CLI_RETENTION_DAYS="$2"; shift ;; 
        --discord-webhook) CLI_DISCORD_WEBHOOK="$2"; shift ;; 
        --discord-script) CLI_DISCORD_SCRIPT="$2"; shift ;; 
        --ai-script) CLI_AI_SCRIPT="$2"; shift ;; 
        --grep-exclude) CLI_GREP_EXCLUDE="$2"; shift ;; 
        --send-discord) CLI_SEND_DISCORD=true ;; 
        --summarize) CLI_SUMMARIZE=true ;; 
        --dry-run|-n) DRY_RUN=true ;; 
        *) echo "未知參數: $1" >>/dev/stderr; exit 1 ;; 
    esac
    shift
done

# --- 設定最終變數值 (優先級: CLI > .env > 硬編碼預設值) ---
SOURCE_DIR="${CLI_SOURCE_DIR:-$SOURCE_DIR}"
DEST_ROOT="${CLI_DEST_ROOT:-${DEST_ROOT:-/volumeUSB1/usbshare1-2/TP-Data-Server}}"
EXCEPTIONS_FILE="${CLI_EXCEPTIONS_FILE:-$EXCEPTIONS_FILE}"
LOG_DIR_BASE="${CLI_LOG_DIR:-${LOG_DIR:-/volume1/homes/tprsynclog}}"
SCRIPT_NAME="${CLI_NAME:-${NAME:-rsync_backup}}"
EXCLUDE_FILE="${CLI_EXCLUDE_FILE:-${EXCLUDE_FILE:-/volume1/homes/nonecopy}}"
BW_LIMIT="${CLI_BW_LIMIT:-${BW_LIMIT:-10000}}"
RETENTION_DAYS="${CLI_RETENTION_DAYS:-${RETENTION_DAYS:-7}}"

SEND_DISCORD="${CLI_SEND_DISCORD:-${SEND_DISCORD:-true}}"
DISCORD_SCRIPT="${CLI_DISCORD_SCRIPT:-${DISCORD_SCRIPT:-/volume1/homes/send_logs_to_discord.sh}}"
DISCORD_WEBHOOK="${CLI_DISCORD_WEBHOOK:-$DISCORD_WEBHOOK}"

SUMMARIZE="${CLI_SUMMARIZE:-${SUMMARIZE:-false}}"
AI_SCRIPT="${CLI_AI_SCRIPT:-${AI_SCRIPT:-/home/jonathan/github/docker-compose/scripts/ai_proc_log.sh}}"
GREP_EXCLUDE_PATTERN="${CLI_GREP_EXCLUDE:-${GREP_EXCLUDE_PATTERN:-"sending incremental file list"}}"

# 處理排除模式陣列
EXCLUDE_PATTERNS=()
if [ ${#CLI_EXCLUDE_PATTERNS[@]} -gt 0 ]; then
    EXCLUDE_PATTERNS=("${CLI_EXCLUDE_PATTERNS[@]}")
elif [ -n "$RSYNC_EXCLUDE_PATTERNS" ]; then
    read -r -a EXCLUDE_PATTERNS <<< "$RSYNC_EXCLUDE_PATTERNS"
fi

# --- 必要參數檢查 ---
if [ -z "$SOURCE_DIR" ]; then
    echo "錯誤：必須透過 --source 或 .env 提供來源目錄 (SOURCE_DIR)" >>/dev/stderr
    exit 1
fi

# ... (腳本其餘部分邏輯不變) ...

if [ ! -d "$SOURCE_DIR" ]; then
    echo "錯誤：來源目錄 $SOURCE_DIR 不存在或不是目錄" >>/dev/stderr
    exit 1
fi

SRC_BASENAME=$(basename "$SOURCE_DIR")
NORMALIZED_SOURCE_DIR="${SOURCE_DIR%/}"
LOG_DIR="${LOG_DIR_BASE}/${SRC_BASENAME}"

if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

DATE_TITLE=$(date +%F)
DATE_TODAY=$(date +%F-%H%M%S)
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_${SRC_BASENAME}_${DATE_TODAY}.log"
LOCK_FILE="/tmp/${SCRIPT_NAME}_$(echo -n "$SOURCE_DIR" | md5sum | awk '{print $1}').lock"

acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $SCRIPT_NAME ($SOURCE_DIR) 已在執行中，退出" >>"$LOG_FILE"
        if [ "$SEND_DISCORD" = true ]; then
            ERROR_MSG="$SCRIPT_NAME ($SOURCE_DIR) 已在執行中，本次備份跳過。"
            curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$ERROR_MSG\"}" "$DISCORD_WEBHOOK"
        fi
        exit 1
    fi
    echo $$ >&200
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 獲得鎖定 (PID: $$, SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
}

send_discord_notification() {
    if ! [ "$SEND_DISCORD" = true ] || [ -z "$DISCORD_WEBHOOK" ] || [ ! -f "$DISCORD_SCRIPT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知條件不滿足，跳過發送" >>"$LOG_FILE"
        return
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - 準備發送 Discord 通知..." >>"$LOG_FILE"
    
    local file_to_send="$LOG_FILE"
    local title="Backup ${SOURCE_DIR} Result..."

    if [ "$SUMMARIZE" = true ] && [ -f "$AI_SCRIPT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 啟用 AI 摘要功能" >>"$LOG_FILE"
        local filtered_log="${LOG_FILE}.filtered"
        local summary_file="${LOG_FILE}.summary"

        echo "$(date '+%Y-%m-%d %H:%M:%S') - 過濾 Log，排除模式: '$GREP_EXCLUDE_PATTERN'" >>"$LOG_FILE"
        grep -v "$GREP_EXCLUDE_PATTERN" "$LOG_FILE" > "$filtered_log"

        echo "$(date '+%Y-%m-%d %H:%M:%S') - 呼叫 AI 腳本產生摘要..." >>"$LOG_FILE"
        bash "$AI_SCRIPT" LOG_FILE="$filtered_log" > "$summary_file"

        if [ -s "$summary_file" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - AI 摘要產生成功" >>"$LOG_FILE"
            file_to_send="$summary_file"
            title="AI Summary for ${SOURCE_DIR}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: AI 摘要產生失敗或為空，將發送過濾後的 Log" >>"$LOG_FILE"
            file_to_send="$filtered_log"
            title="Filtered Log for ${SOURCE_DIR} (AI Summary Failed)"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 未啟用 AI 摘要，將發送原始 Log (截斷為 1500 字元)" >>"$LOG_FILE"
        tail -c 1500 "$LOG_FILE" > "${LOG_FILE}.truncated"
        file_to_send="${LOG_FILE}.truncated"
    fi

    "$DISCORD_SCRIPT" \
    "LOG_FILE=${file_to_send}" \
    "WEBHOOK_URL=${DISCORD_WEBHOOK}" \
    "TITLE=${title}"
    
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知發送成功" >>"$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知發送失敗" >>"$LOG_FILE"
    fi

    [ -f "${LOG_FILE}.filtered" ] && rm "${LOG_FILE}.filtered"
    [ -f "${LOG_FILE}.summary" ] && rm "${LOG_FILE}.summary"
    [ -f "${LOG_FILE}.truncated" ] && rm "${LOG_FILE}.truncated"
}

cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 腳本執行完畢 (SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"
    send_discord_notification
}

acquire_lock
# trap 只處理中斷和終止信號，確保在被手動停止時也能清理
# 正常結束的流程將在腳本末端明確呼叫 cleanup
trap 'cleanup; exit 1' INT TERM

if [ -n "$EXCLUDE_FILE" ] && [ ! -f "$EXCLUDE_FILE" ]; then
    echo "警告：排除清單檔案 $EXCLUDE_FILE 不存在，將忽略排除清單" >>"$LOG_FILE"
    EXCLUDE_FILE=""
fi

declare -A EXCEPTION_MAP
if [ -n "$EXCEPTIONS_FILE" ] && [ -f "$EXCEPTIONS_FILE" ]; then
    while IFS='=' read -r src dest; do
        src=$(echo "$src" | sed 's/[[:space:]]*$//; s/\\\/*$//')
        dest=$(echo "$dest" | sed 's/[[:space:]]*$//; s/\\\/*$//')
        if [ -n "$src" ] && [ -n "$dest" ]; then
            EXCEPTION_MAP["$src"]="$dest"
        fi
    done < "$EXCEPTIONS_FILE"
fi

if [ -n "${EXCEPTION_MAP[$NORMALIZED_SOURCE_DIR]}" ]; then
    DEST_DIR="${EXCEPTION_MAP[$NORMALIZED_SOURCE_DIR]}/"
else
    DEST_DIR="${DEST_ROOT}/${SRC_BASENAME}/"
fi

echo "-----$DATE_TITLE-----" >>"$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份開始 (PID: $$, SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"

RSYNC_CMD="rsync -ah --stats --whole-file --delete"
[ "$DRY_RUN" = true ] && RSYNC_CMD="$RSYNC_CMD --dry-run"
RSYNC_CMD="$RSYNC_CMD --bwlimit=$BW_LIMIT"
[ -n "$EXCLUDE_FILE" ] && RSYNC_CMD="$RSYNC_CMD --exclude-from='$EXCLUDE_FILE'"
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    RSYNC_CMD="$RSYNC_CMD --exclude='$pattern'"
done
RSYNC_CMD="$RSYNC_CMD '$SOURCE_DIR' '$DEST_DIR'"

eval "$RSYNC_CMD" >>"$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Dry-run 模擬備份成功完成 (SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份成功完成 (SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份執行時發生錯誤 (SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"
fi

find "$LOG_DIR" -type f -name "${SCRIPT_NAME}_${SRC_BASENAME}_*.log" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

# 在腳本正常執行流程的最後明確呼叫 cleanup，確保 rsync 已完成
cleanup
