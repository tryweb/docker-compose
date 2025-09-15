#!/bin/bash

# 默認值
LOG_FILE=""
WEBHOOK_URL="${WEBHOOK_URL:-}"
TITLE="${TITLE:-}"
MSGTYPE="" # 新增：訊息類型參數
MAX_CHARS=1500

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
        MSGTYPE=*) # 新增：解析 MSGTYPE
        MSGTYPE="${arg#*=}"
        ;;
    esac
done

# 檢查必要參數
if [ -z "$LOG_FILE" ] || [ -z "$WEBHOOK_URL" ]; then
    # 更新：使用說明
    echo "使用方法: $0 LOG_FILE=/path/to/logfile WEBHOOK_URL=https://discord.com/api/webhooks/... [TITLE=\"訊息標題\"] [MSGTYPE=OK|ERR]"
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

send_message() {
    local content="$1"
    if [ -n "$content" ]; then
        # 新增：根據 MSGTYPE 設置顏色
        local color_decimal
        case "$MSGTYPE" in
            ERR)
            color_decimal=15158332 # 紅色
            ;;
            OK)
            color_decimal=3066993 # 綠色
            ;;
            *)
            color_decimal=9807270 # 預設灰色
            ;;
        esac

        # 構建消息標題
        local message_title=""
        if [ $message_count -eq 0 ] && [ -n "$TITLE" ]; then
            message_title="$TITLE"
        else
            # 使用一致的格式，但續傳消息沒有標題
            message_title=""
        fi

        # 消息計數加1
        message_count=$((message_count + 1))

        # 更新：使用jq構建包含顏色的JSON
        local payload
        if [ -n "$message_title" ]; then
            payload=$(jq -n --arg title "$message_title" --arg desc "$content" --argjson color "$color_decimal" \
                '{embeds: [{title: $title, description: $desc, color: $color}]}')
        else
            # 沒有標題的消息也使用embed格式保持一致性
            payload=$(jq -n --arg desc "$content" --argjson color "$color_decimal" \
                '{embeds: [{description: $desc, color: $color}]}')
        fi

        response=$(curl -s -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL")

        # 檢查是否有錯誤
        if [[ "$response" == *"\"code\":"* ]]; then
            echo "發送失敗: $response"
        fi

        sleep 1  # 避免 Discord 的速率限制
    fi
}

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
done < "$LOG_FILE"

# 發送剩餘的 buffer
if [ $char_count -gt 0 ]; then
    send_message "$buffer"
fi

echo "完成! 日誌內容已發送到 Discord。"