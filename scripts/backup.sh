#!/bin/bash
export LANG=en_US.utf8
VER="1.0.0"

# --- 核心初始化 ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# --- 載入設定與函式庫 ---
# 檢查檔案是否存在，增強穩定性
if [ -f "$SCRIPT_DIR/backup.conf" ]; then
    source "$SCRIPT_DIR/backup.conf"
else
    echo "錯誤：設定檔 backup.conf 不存在！" >&2; exit 1
fi
if [ -f "$SCRIPT_DIR/lib/functions.sh" ]; then
    source "$SCRIPT_DIR/lib/functions.sh"
else
    echo "錯誤：函式庫 lib/functions.sh 不存在！" >&2; exit 1
fi

# --- .env 檔案載入 (會覆蓋 backup.conf 的設定) ---
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# --- 命令列參數解析 (最高優先級) ---
DRY_RUN=false
WHOLE_FILE=false
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
        --tool) CLI_TOOL="$2"; shift ;;
        --rclone-args) CLI_RCLONE_ARGS="$2"; shift ;;
        --discord-webhook) CLI_DISCORD_WEBHOOK="$2"; shift ;;
        --discord-script) CLI_DISCORD_SCRIPT="$2"; shift ;;
        --ai-script) CLI_AI_SCRIPT="$2"; shift ;;
        --grep-exclude) CLI_GREP_EXCLUDE="$2"; shift ;;
        --send-discord) CLI_SEND_DISCORD=true ;;
        --summarize) CLI_SUMMARIZE=true ;;
        --dry-run) DRY_RUN=true ;;
        -w|--whole-file) WHOLE_FILE=true ;;
        -v|--version) show_version ;;
        *) echo "未知參數: $1" >&2; exit 1 ;;
    esac
    shift
done

# --- 設定最終變數值 (優先級: CLI > .env > backup.conf) ---
TOOL="${CLI_TOOL:-$TOOL}"
SOURCE_DIR="${CLI_SOURCE_DIR:-$SOURCE_DIR}"
DEST_ROOT="${CLI_DEST_ROOT:-$DEST_ROOT}"
EXCEPTIONS_FILE="${CLI_EXCEPTIONS_FILE:-$EXCEPTIONS_FILE}"
LOG_DIR_BASE="${CLI_LOG_DIR:-$LOG_DIR_BASE}"
SCRIPT_NAME="${CLI_NAME:-$NAME}"
EXCLUDE_FILE="${CLI_EXCLUDE_FILE:-$EXCLUDE_FILE}"
BW_LIMIT="${CLI_BW_LIMIT:-$BW_LIMIT}"
RETENTION_DAYS="${CLI_RETENTION_DAYS:-$RETENTION_DAYS}"
SEND_DISCORD="${CLI_SEND_DISCORD:-$SEND_DISCORD}"
DISCORD_SCRIPT="${CLI_DISCORD_SCRIPT:-$DISCORD_SCRIPT}"
DISCORD_WEBHOOK="${CLI_DISCORD_WEBHOOK:-$DISCORD_WEBHOOK}"
SUMMARIZE="${CLI_SUMMARIZE:-$SUMMARIZE}"
AI_SCRIPT="${CLI_AI_SCRIPT:-$AI_SCRIPT}"
GREP_EXCLUDE_PATTERN="${CLI_GREP_EXCLUDE:-$GREP_EXCLUDE_PATTERN}"
RCLONE_ARGS="${CLI_RCLONE_ARGS:-$RCLONE_ARGS}"
NFS_MOUNTS="${NFS_MOUNTS:-}"
WHOLE_FILE="${WHOLE_FILE:-${RSYNC_WHOLE_FILE:-false}}"

EXCLUDE_PATTERNS=()
if [ ${#CLI_EXCLUDE_PATTERNS[@]} -gt 0 ]; then
    EXCLUDE_PATTERNS=("${CLI_EXCLUDE_PATTERNS[@]}")
elif [ -n "$RSYNC_EXCLUDE_PATTERNS" ]; then
    read -r -a EXCLUDE_PATTERNS <<< "$RSYNC_EXCLUDE_PATTERNS"
fi

# --- 必要參數檢查 ---
if [ -z "$SOURCE_DIR" ]; then
    echo "錯誤：必須透過 --source 或 .env 提供來源目錄 (SOURCE_DIR)" >&2; exit 1
fi
# 只有 rsync 需要檢查來源目錄是否存在於本機
if [ "$TOOL" = "rsync" ] && [ ! -d "$SOURCE_DIR" ]; then
    echo "錯誤：[rsync模式] 來源目錄 $SOURCE_DIR 不存在或不是目錄" >&2; exit 1
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

# --- 主程式開始 ---
echo "Backup Script v${VER} - Starting..." # 版本顯示
acquire_lock
trap 'cleanup "ERR"; exit 1' INT TERM

# 將版本資訊寫入 Log
echo "-----$DATE_TITLE-----" >>"$LOG_FILE"
echo "Backup Script v${VER}" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 備份開始 (PID: $$, TOOL: $TOOL, SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN)" >>"$LOG_FILE"

# --- 執行前檢查 ---
if [ "$TOOL" = "rsync" ] && [ -n "$NFS_MOUNTS" ]; then
    if ! check_nfs_mounts "$NFS_MOUNTS" >> "$LOG_FILE"; then
        send_simple_discord_error "Backup for ${SRC_BASENAME} skipped due to missing/incorrect NFS mount."
        cleanup "ERR"; exit 1
    fi
fi

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

# --- 命令建構與執行 ---
CMD=""
exit_code=0

if [ "$TOOL" = "rclone" ]; then
    CMD="rclone copy --stats 1m --log-file '$LOG_FILE' --log-level INFO"
    [ "$DRY_RUN" = true ] && CMD="$CMD --dry-run"
    CMD="$CMD --bwlimit ${BW_LIMIT}k"
    [ -n "$EXCLUDE_FILE" ] && CMD="$CMD --exclude-from '$EXCLUDE_FILE'"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        CMD="$CMD --exclude '$pattern'"
    done
    [ -n "$RCLONE_ARGS" ] && CMD="$CMD $RCLONE_ARGS"
    CMD="$CMD '$NORMALIZED_SOURCE_DIR' '$DEST_DIR'"

    # rclone 的日誌處理方式不同，我們讓它直接寫入，然後再追加我們的狀態資訊
    eval "$CMD"
    exit_code=$?

elif [ "$TOOL" = "rsync" ]; then
    CMD="rsync -ah --info=progress2 --stats --delete"
    [ "$DRY_RUN" = true ] && CMD="$CMD --dry-run"
    [ "$WHOLE_FILE" = true ] && CMD="$CMD --whole-file"
    CMD="$CMD --bwlimit=$BW_LIMIT"
    [ -n "$EXCLUDE_FILE" ] && CMD="$CMD --exclude-from='$EXCLUDE_FILE'"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        CMD="$CMD --exclude='$pattern'"
    done
    CMD="$CMD '${SOURCE_DIR%/}/' '$DEST_DIR'"

    eval "$CMD" >>"$LOG_FILE" 2>&1
    exit_code=$?
else
    echo "錯誤：未知的工具 '$TOOL'。只支援 'rsync' 或 'rclone'。" >> "$LOG_FILE"
    exit_code=1
fi

# --- 結果處理 ---
backup_status="ERR"
if [ $exit_code -eq 0 ]; then
    backup_status="OK"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $TOOL 備份成功完成 (DRY_RUN: $DRY_RUN, SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $TOOL 備份執行時發生錯誤(Code: $exit_code) (DRY_RUN: $DRY_RUN, SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
fi

# --- 清理舊日誌 ---
find "$LOG_DIR" -type f -name "${SCRIPT_NAME}_${SRC_BASENAME}_*.log" -mtime +"$RETENTION_DAYS" -exec rm -f {} \;

# --- 腳本結束 ---
cleanup "$backup_status"

