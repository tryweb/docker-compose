#!/bin/bash

# 默認值
LOG_FILE=""
WEBHOOK_URL="${WEBHOOK_URL:-}"
TITLE="${TITLE:-}"
MAX_CHARS=1500

# 顏色定義 (十進制格式)
COLOR_SUCCESS=65280    # 綠色 #00FF00
COLOR_ERROR=16711680   # 紅色 #FF0000
COLOR_INFO=3447003     # 藍色 #3498DB
COLOR_WARNING=16776960 # 黃色 #FFFF00

# 解析命令行參數
for arg in "$@"; do
    case $arg in
        LOG_FILE=*)
        LOG_FILE="${arg#*=}"
        ;;
        WEBHOOK_URL=*)
        WEBHOOK_URL="${arg#*=}"
        ;;
        TITLE=*)
        TITLE="${arg#*=}"
        ;;
    esac
done

# 檢查必要參數
if [ -z "$LOG_FILE" ] || [ -z "$WEBHOOK_URL" ]; then
    echo "使用方法: $0 LOG_FILE=/path/to/logfile WEBHOOK_URL=https://discord.com/api/webhooks/... [TITLE=\"訊息標題\"]"
    exit 1
fi

# 檢查日誌文件是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo "錯誤: 日誌文件 '$LOG_FILE' 不存在"
    exit 1
fi

buffer=""
char_count=0
message_count=0
success_count=0
error_count=0

send_message() {
    local content="$1"
    local color="$2"
    local is_status_message="$3"
    
    if [ -n "$content" ]; then
        # 構建消息標題
        local message_title=""
        if [ $message_count -eq 0 ] && [ -n "$TITLE" ] && [ "$is_status_message" != "true" ]; then
            message_title="$TITLE"
        fi

        # 如果不是狀態訊息，消息計數加1
        if [ "$is_status_message" != "true" ]; then
            message_count=$((message_count + 1))
        fi

        # 使用jq構建JSON
        local payload
        if [ -n "$message_title" ]; then
            payload=$(jq -n --arg title "$message_title" --arg desc "$content" --argjson color "$color" '{embeds: [{title: $title, description: $desc, color: $color}]}')
        else
            payload=$(jq -n --arg desc "$content" --argjson color "$color" '{embeds: [{description: $desc, color: $color}]}')
        fi

        response=$(curl -s -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL")

        # 檢查是否有錯誤
        if [[ "$response" == *"\"code\":"* ]] || [[ "$response" == *"\"message\":"* ]]; then
            if [ "$is_status_message" != "true" ]; then
                echo "發送失敗 (訊息 $message_count): $response"
                error_count=$((error_count + 1))
            fi
            return 1
        else
            if [ "$is_status_message" != "true" ]; then
                echo "成功發送訊息 $message_count"
                success_count=$((success_count + 1))
            fi
            return 0
        fi
    fi
}

# 發送開始狀態訊息
echo "開始發送日誌文件: $(basename "$LOG_FILE") (類型: $MSGTYPE)"

while IFS= read -r line; do
    line_length=${#line}

    if [ $line_length -gt $MAX_CHARS ]; then
        # 如果目前的 buffer 不為空，先發送 buffer
        if [ $char_count -gt 0 ]; then
            send_message "$buffer"
            buffer=""
            char_count=0
        fi

        # 分割超長行
        for ((i=0; i<$line_length; i+=$MAX_CHARS)); do
            chunk="${line:$i:$MAX_CHARS}"
            send_message "$chunk"
        done
    else
        # 檢查新增這一行是否會超過限制
        if [ $((char_count + line_length + 1)) -gt $MAX_CHARS ]; then
            # 如果會超過，先發送當前 buffer
            send_message "$buffer"
            buffer="$line"
            char_count=$line_length
        else
            # 如果不會超過，加到 buffer 中
            if [ $char_count -gt 0 ]; then
                buffer="$buffer"$'\n'"$line"
                char_count=$((char_count + line_length + 1))
            else
                buffer="$line"
                char_count=$line_length
            fi
        fi
    fi

    sleep 1  # 避免 Discord 的速率限制
done < "$LOG_FILE"

# 發送剩餘的 buffer
if [ $char_count -gt 0 ]; then
    send_message "$buffer"
fi

echo "完成! 發送了 $message_count 條 $MSGTYPE 類型的訊息到 Discord"
