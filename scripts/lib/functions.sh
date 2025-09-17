#!/bin/bash
# lib/functions.sh - Helper functions for the backup script

# 函式：顯示腳本版本並退出
show_version() {
    echo "Backup Script Version: $VER"
    exit 0
}

# 函式：檢查 NFS 掛載點是否正確
check_nfs_mounts() {
    # ... (此函式內容與原腳本完全相同)
    local nfs_mounts_json=$1
    local mount_points=()
    local expected_sources=()
    local i=0

    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed. Please install it to parse the JSON."
        return 1
    fi

    while read -r mount_point expected_source; do
        mount_points[i]="$mount_point"
        expected_sources[i]="$expected_source"
        ((i++))
    done < <(echo "$nfs_mounts_json" | jq -r '
        .[] |
        to_entries[] |
        "\(.key) \(.value)"
    ')

    for ((j=0; j<i; j++)); do
        mount_point="${mount_points[j]}"
        expected_source="${expected_sources[j]}"
        echo "Checking mount point: $mount_point"

        if [ ! -d "$mount_point" ]; then
            echo "Error: Directory does not exist: $mount_point"
            return 1
        fi

        if ! df -P "$mount_point" | grep -q "^$expected_source"; then
            echo "Error: Mount point $mount_point is not correctly mounted to $expected_source"
            echo "Current mounts:"
            df -P "$mount_point"
            return 1
        fi
        echo "Success: $mount_point is correctly mounted."
    done

    return 0
}

# 函式：發送簡單的錯誤通知，用於鎖定失敗或 NFS 檢查失敗
send_simple_discord_error() {
    # ... (此函式內容與原腳本完全相同)
    local error_message="$1"
    local error_title="🚨 Backup Script Alert: ${SRC_BASENAME}"

    local tmp_err_file="${LOG_FILE}.err_msg"
    echo "$error_message" > "$tmp_err_file"

    "$DISCORD_SCRIPT" \
    "LOG_FILE=${tmp_err_file}" \
    "WEBHOOK_URL=${DISCORD_WEBHOOK}" \
    "TITLE=${error_title}" \
    "MSGTYPE=ERR"

    rm "$tmp_err_file"
}

# 函式：獲取鎖
acquire_lock() {
    # ... (此函式內容與原腳本完全相同)
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        local log_msg="$(date '+%Y-%m-%d %H:%M:%S') - $SCRIPT_NAME ($SOURCE_DIR) 已在執行中，退出"
        echo "$log_msg" >>"$LOG_FILE"
        if [ "$SEND_DISCORD" = true ]; then
            send_simple_discord_error "$SCRIPT_NAME for $SOURCE_DIR is already running. This backup was skipped."
        fi
        exit 1
    fi
    echo $$ >&200
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 獲得鎖定 (PID: $$, SOURCE: $SOURCE_DIR)" >>"$LOG_FILE"
}

# 函式：發送 Discord 通知
send_discord_notification() {
    # ... (此函式內容與原腳本完全相同)
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

# 函式：腳本清理
cleanup() {
    local status="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 腳本執行完畢 (SOURCE: $SOURCE_DIR, DRY_RUN: $DRY_RUN, STATUS: $status)" >>"$LOG_FILE"
    send_discord_notification "$status"
}
