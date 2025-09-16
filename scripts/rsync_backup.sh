#!/bin/bash
export LANG=en_US.utf8

# --- .env 檔案載入 ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# --- 命令列參數解析 ---
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
        --dry-run|-n) DRY_RUN=true ;; # -n 是 rsync 的 dry-run, 此處沿用
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
if [ ! -d "$SOURCE_DIR" ]; then
    echo "錯誤：來源目錄 $SOURCE_DIR 不存在或不是目錄" >>/dev/stderr
    exit 1
fi

# --- 環境變數設定 ---
SRC_BASENAME=$(basename "$SOURCE_DIR")
NORMALIZED_SOURCE_DIR="${SOURCE_DIR%/}"
LOG_DIR="${LOG_DIR_BASE}/${SRC_BASENAME}"
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
DATE_TITLE=$(date +%F)
DATE_TODAY=$(date +%F-%H%M%S)
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}_${SRC_BASENAME}_${DATE_TODAY}.log"
LOCK_FILE="/tmp/${SCRIPT_NAME}_$(echo -n "$SOURCE_DIR" | md5sum | awk '{print $1}').lock"

# --- 函式定義 ---

# 【修改】函式：發送簡單的錯誤通知，用於鎖定失敗等情況
send_simple_discord_error() {
    local error_message="$1"
    local error_title="🚨 Backup Script Alert: ${SRC_BASENAME}"
    
    # 直接建立一個臨時文件來傳遞簡單的錯誤訊息
    local tmp_err_file="${LOG_FILE}.err_msg"
    echo "$error_message" > "$tmp_err_file"

    "$DISCORD_SCRIPT" \
    "LOG_FILE=${tmp_err_file}" \
    "WEBHOOK_URL=${DISCORD_WEBHOOK}" \
    "TITLE=${error_title}" \
    "MSGTYPE=ERR"
    
    rm "$tmp_err_file"
}

# 【修改】函式：獲取鎖
acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        local log_msg="$(date '+%Y-%m-%d %H:%M:%S') - $SCRIPT_NAME ($SOURCE_DIR) 已在執行中，退出"
        echo "$log_msg" >>"$LOG_FILE"
        if [ "$SEND_DISCORD" = true ]; then
            # 使用新的錯誤通知函式，發送帶有顏色的通知
            send_simple_discord_error "$SCRIPT_NAME for $SOURCE_DIR is already running. This backup was skipped."
        fi
        exit 1
    fi
    echo $$ >&200
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 獲得鎖定 (PID: $$, SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
}

# 【修改】函式：發送 Discord 通知（與上一版回答相同）
send_discord_notification() {
    local status="$1"
    local msg_type=""
    case "$status" in
        OK) msg_type="OK" ;;
        ERR) msg_type="ERR" ;;
    esac

    if ! [ "$SEND_DISCORD" = true ] || [ -z "$DISCORD_WEBHOOK" ] || [ ! -f "$DISCORD_SCRIPT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知條件不滿足，跳過發送" >>"$LOG_FILE"; return
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - 準備發送 Discord 通知 (狀態: ${status:-"Default"})" >>"$LOG_FILE"
    
    local file_to_send="$LOG_FILE"
    local title="Backup ${SOURCE_DIR} Result..."
    if [ "$status" = "OK" ]; then title="✅ Backup Successful: ${SRC_BASENAME}"; elif [ "$status" = "ERR" ]; then title="❌ Backup Failed: ${SRC_BASENAME}"; fi

    if [ "$SUMMARIZE" = true ] && [ -f "$AI_SCRIPT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 啟用 AI 摘要功能" >>"$LOG_FILE"
        local filtered_log="${LOG_FILE}.filtered"; local summary_file="${LOG_FILE}.summary"
        grep -v "$GREP_EXCLUDE_PATTERN" "$LOG_FILE" > "$filtered_log"
        bash "$AI_SCRIPT" LOG_FILE="$filtered_log" REMOTE_CONFIG_URL="$REMOTE_CONFIG_URL" > "$summary_file"
        if [ -s "$summary_file" ]; then
            file_to_send="$summary_file"
            if [ "$status" = "OK" ]; then title="✅ AI Summary (Success): ${SRC_BASENAME}"; elif [ "$status" = "ERR" ]; then title="❌ AI Summary (Failure): ${SRC_BASENAME}"; else title="AI Summary for ${SRC_BASENAME}"; fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: AI 摘要產生失敗或為空" >>"$LOG_FILE"; file_to_send="$filtered_log"; title="Filtered Log for ${SRC_BASENAME} (AI Summary Failed)"
        fi
    else
        if [ "$status" = "ERR" ]; then
            tail -n 50 "$LOG_FILE" > "${LOG_FILE}.truncated"
        else
            tail -c 1500 "$LOG_FILE" > "${LOG_FILE}.truncated"
        fi
        file_to_send="${LOG_FILE}.truncated"
    fi

    "$DISCORD_SCRIPT" "LOG_FILE=${file_to_send}" "WEBHOOK_URL=${DISCORD_WEBHOOK}" "TITLE=${title}" "MSGTYPE=${msg_type}"
    if [ $? -eq 0 ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知發送成功" >>"$LOG_FILE"; else echo "$(date '+%Y-%m-%d %H:%M:%S') - Discord 通知發送失敗" >>"$LOG_FILE"; fi
    
    [ -f "${LOG_FILE}.filtered" ] && rm "${LOG_FILE}.filtered"
    [ -f "${LOG_FILE}.summary" ] && rm "${LOG_FILE}.summary"
    [ -f "${LOG_FILE}.truncated" ] && rm "${LOG_FILE}.truncated"
}

# 【修改】函式：腳本清理
cleanup() {
    local status="$1" # 接收狀態
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 腳本執行完畢 (SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN, STATUS: $status)" >>"$LOG_FILE"
    send_discord_notification "$status" # 將狀態傳給通知函式
}

# --- 主程式開始 ---

acquire_lock
# 【修改】trap：當腳本被中斷時，視為錯誤，呼叫 cleanup "ERR"
trap 'cleanup "ERR"; exit 1' INT TERM

# ... 參數檢查 ...
if [ -n "$EXCLUDE_FILE" ] && [ ! -f "$EXCLUDE_FILE" ]; then
    echo "警告：排除清單檔案 $EXCLUDE_FILE 不存在" >>"$LOG_FILE"; EXCLUDE_FILE=""
fi
declare -A EXCEPTION_MAP
if [ -n "$EXCEPTIONS_FILE" ] && [ -f "$EXCEPTIONS_FILE" ]; then
    while IFS='=' read -r src dest; do
        src=$(echo "$src" | sed 's/[[:space:]]*$//; s/\\\/*$//'); dest=$(echo "$dest" | sed 's/[[:space:]]*$//; s/\\\/*$//')
        if [ -n "$src" ] && [ -n "$dest" ]; then EXCEPTION_MAP["$src"]="$dest"; fi
    done < "$EXCEPTIONS_FILE"
fi
if [ -n "${EXCEPTION_MAP[$NORMALIZED_SOURCE_DIR]}" ]; then
    DEST_DIR="${EXCEPTION_MAP[$NORMALIZED_SOURCE_DIR]}/"
else
    DEST_DIR="${DEST_ROOT}/${SRC_BASENAME}/"
fi

echo "-----$DATE_TITLE-----" >>"$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份開始 (PID: $$, SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"

# --- Rsync 執行 ---
RSYNC_CMD="rsync -ah --info=progress2 --stats --whole-file --delete"
[ "$DRY_RUN" = true ] && RSYNC_CMD="$RSYNC_CMD --dry-run"
RSYNC_CMD="$RSYNC_CMD --bwlimit=$BW_LIMIT"
[ -n "$EXCLUDE_FILE" ] && RSYNC_CMD="$RSYNC_CMD --exclude-from='$EXCLUDE_FILE'"
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    RSYNC_CMD="$RSYNC_CMD --exclude='$pattern'"
done
RSYNC_CMD="$RSYNC_CMD '$SOURCE_DIR' '$DEST_DIR'"

eval "$RSYNC_CMD" >>"$LOG_FILE" 2>&1
# 【核心修改】立即捕獲 rsync 的結束代碼
rsync_exit_code=$?

# 【核心修改】根據結束代碼設定狀態並記錄日誌
backup_status="ERR" # 預設為失敗
if [ $rsync_exit_code -eq 0 ]; then
    backup_status="OK"
    if [ "$DRY_RUN" = true ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Dry-run 模擬備份成功完成 (SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份成功完成 (SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份執行時發生錯誤(Code: $rsync_exit_code) (SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"
fi

# --- 清理舊日誌 ---
find "$LOG_DIR" -type f -name "${SCRIPT_NAME}_${SRC_BASENAME}_*.log" -mtime +"$RETENTION_DAYS" -exec rm -rf {} \;

# 【核心修改】在腳本正常結束時，呼叫 cleanup 並傳入最終狀態
cleanup "$backup_status"