#!/bin/bash

# --- 設定載入 ---
# 優先級: 命令列參數 > 遠端設定檔 > 環境變數 > .env 檔案 > 腳本內預設值

# 取得腳本所在的目錄
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 1. 如果 .env 檔案存在，則載入它 (優先級最低)
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
fi

# 2. 為所有設定變數提供腳本內預設值
API_SERVICE="${API_SERVICE:-openrouter}"
OLLAMA_API_URL="${OLLAMA_API_URL:-http://localhost:11434/api/generate}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3}"
OLLAMA_MODEL_BAK="${OLLAMA_MODEL_BAK:-}"  # 支援逗號分隔的多個備用模型，例如：model1,model2,model3
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-YOUR_OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-openai/gpt-4o-mini}"
OPENROUTER_MODEL_BAK="${OPENROUTER_MODEL_BAK:-}"  # 支援逗號分隔的多個備用模型，例如：model1,model2,model3
OPENROUTER_API_URL="${OPENROUTER_API_URL:-https://openrouter.ai/api/v1/chat/completions}"
LOG_FILE=""
REMOTE_CONFIG_URL="${REMOTE_CONFIG_URL:-}"
PROMPT_TEXT="${PROMPT_TEXT:-請分析以下 Log 內容，並提供一個簡潔的摘要。請以正體中文回覆重點摘要。請列出：
1. 重要的錯誤訊息（如果有）。
2. 關鍵事件的時間點。
3. 問題的可能原因和解決建議。
最後彙整花費時間、同步檔案大小與數量}"

# 3. 從命令列參數解析
for arg in "$@"; do
    case $arg in
        LOG_FILE=*) LOG_FILE="${arg#*=}" ;;
        API_SERVICE=*) API_SERVICE="${arg#*=}" ;;
        OLLAMA_API_URL=*) OLLAMA_API_URL="${arg#*=}" ;;
        OLLAMA_MODEL=*) OLLAMA_MODEL="${arg#*=}" ;;
        OLLAMA_MODEL_BAK=*) OLLAMA_MODEL_BAK="${arg#*=}" ;;
        OPENROUTER_API_KEY=*) OPENROUTER_API_KEY="${arg#*=}" ;;
        OPENROUTER_MODEL=*) OPENROUTER_MODEL="${arg#*=}" ;;
        OPENROUTER_MODEL_BAK=*) OPENROUTER_MODEL_BAK="${arg#*=}" ;;
        OPENROUTER_API_URL=*) OPENROUTER_API_URL="${arg#*=}" ;;
        REMOTE_CONFIG_URL=*) REMOTE_CONFIG_URL="${arg#*=}" ;;
        PROMPT_TEXT=*) PROMPT_TEXT="${arg#*=}" ;;
    esac
done

# 4. 載入遠端設定
if [ -n "$REMOTE_CONFIG_URL" ]; then
    echo "正在從遠端載入設定: $REMOTE_CONFIG_URL" >&2
    # 加上隨機參數避免快取問題
    RANDOM_PARAM="nocache=$(($(date +%s%N)))"
    # 正確處理 URL 查詢參數：如果 URL 已包含 ?，使用 &；否則使用 ?
    if [[ "$REMOTE_CONFIG_URL" == *"?"* ]]; then
        CONFIG_URL="${REMOTE_CONFIG_URL}&${RANDOM_PARAM}"
    else
        CONFIG_URL="${REMOTE_CONFIG_URL}?${RANDOM_PARAM}"
    fi
    echo "完整 URL: $CONFIG_URL" >&2
    # 使用 -f 參數讓 curl 在 HTTP 錯誤時失敗，並捕獲退出碼
    if REMOTE_SETTINGS=$(curl -fsSL "$CONFIG_URL" 2>&1); then
        if [ -n "$REMOTE_SETTINGS" ]; then
            # 檢查內容是否像 shell 腳本（包含 = 或 export）
            if echo "$REMOTE_SETTINGS" | grep -qE '(^|[[:space:]])([A-Z_][A-Z0-9_]*=|export[[:space:]])'; then
                set -a
                # shellcheck source=/dev/null
                # 載入遠端設定，忽略可能的非致命警告（如多行字串格式問題）
                source <(echo "$REMOTE_SETTINGS") 2>/dev/null || true
                set +a
                echo "遠端設定載入成功。" >&2
            else
                echo "警告: 遠端設定檔格式不正確（不包含有效的環境變數設定），將使用本地設定。" >&2
            fi
        else
            echo "警告: 遠端設定檔內容為空。" >&2
        fi
    else
        echo "警告: 無法從遠端 URL 下載設定（HTTP 錯誤或網路問題），將使用本地設定。" >&2
    fi
fi

# 5. 再次從命令列參數解析，確保最高優先級
for arg in "$@"; do
    case $arg in
        LOG_FILE=*) LOG_FILE="${arg#*=}" ;;
        API_SERVICE=*) API_SERVICE="${arg#*=}" ;;
        OLLAMA_MODEL=*) OLLAMA_MODEL="${arg#*=}" ;;
        OLLAMA_MODEL_BAK=*) OLLAMA_MODEL_BAK="${arg#*=}" ;;
        OPENROUTER_MODEL=*) OPENROUTER_MODEL="${arg#*=}" ;;
        OPENROUTER_MODEL_BAK=*) OPENROUTER_MODEL_BAK="${arg#*=}" ;;
        PROMPT_TEXT=*) PROMPT_TEXT="${arg#*=}" ;;
    esac
done

# --- 參數檢查 ---
if [ -z "$LOG_FILE" ]; then
    echo "錯誤: 未指定 LOG_FILE。"
    echo "使用方法: $0 LOG_FILE=/path/to/logfile [...]"
    exit 1
fi
if [ ! -f "$LOG_FILE" ]; then
    echo "錯誤：找不到檔案在 $LOG_FILE"
    exit 1
fi

# --- 函式區 ---
get_prompt() {
    echo "$PROMPT_TEXT"
    echo "--- Log 內容開始 ---"
    cat "$LOG_FILE"
    echo "--- Log 內容結束 ---"
}

# --- 函式：呼叫 Ollama API (已修改) ---
call_ollama_api() {
    local model_to_use="$1"
    local start_time
    start_time=$(date +%s)

    # 先將 API 回應存到變數中
    local api_response
    api_response=$( {
        printf '{"model": "%s", "stream": false, "prompt": ' "$model_to_use"
        get_prompt | jq -Rs .
        printf '}'
    } | curl -s -X POST "$OLLAMA_API_URL" \
        -H "Content-Type: application/json" \
        -d @- \
        | jq -r '.response')

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "($model_to_use) API call took $duration seconds." >&2
    
    # 將執行時間和 API 回應都輸出到 STDOUT
    echo "$duration"
    echo "$api_response"
}

# --- 函式：呼叫 OpenRouter API (已修改) ---
call_openrouter_api() {
    local model_to_use="$1"
    if [ "$OPENROUTER_API_KEY" = "YOUR_OPENROUTER_API_KEY" ]; then
        echo "錯誤：請先將 OPENROUTER_API_KEY 替換成你的金鑰。" >&2
        exit 1
    fi

    local APP_URL="https://github.com/tryweb"
    local APP_TITLE="AI_Proc_Log"
    
    local start_time
    start_time=$(date +%s)

    # 先取得完整的 API 回應以便檢查錯誤
    local full_response
    full_response=$( {
        printf '{"model": "%s", "messages": [{"role": "user", "content": ' "$model_to_use"
        get_prompt | jq -Rs .
        printf '}]}'
    } | curl -s -X POST "$OPENROUTER_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: $APP_URL" \
        -H "X-Title: $APP_TITLE" \
        -d @-)

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo "($model_to_use) API call took $duration seconds." >&2
    
    # 檢查是否有錯誤訊息
    local error_msg
    error_msg=$(echo "$full_response" | jq -r '.error.message // empty' 2>/dev/null)
    
    if [ -n "$error_msg" ]; then
        echo "API 錯誤: $error_msg" >&2
        echo "完整回應: $full_response" >&2
        # 輸出空值表示失敗
        echo "$duration"
        echo ""
        return
    fi
    
    # 提取回應內容
    local api_response
    api_response=$(echo "$full_response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    
    if [ -z "$api_response" ]; then
        echo "警告: 無法從回應中提取內容" >&2
        echo "完整回應: $full_response" >&2
    fi
    
    # 將執行時間和 API 回應都輸出到 STDOUT
    echo "$duration"
    echo "$api_response"
}

# --- 主程式：(已修改) ---
echo "正在使用 $API_SERVICE 服務分析 Log 檔案..."

# 初始化共用變數
RESPONSE=""
SELECTED_MODEL=""
API_DURATION=0

execute_and_parse_api_call() {
    local service_func="$1"
    local model="$2"
    
    SELECTED_MODEL="$model"
    # 接收合併的輸出
    local combined_output
    combined_output=$("$service_func" "$SELECTED_MODEL")
    
    # 從合併的輸出中解析出時間和回應
    API_DURATION=$(echo "$combined_output" | head -n 1)
    RESPONSE=$(echo "$combined_output" | tail -n +2)
}

if [ "$API_SERVICE" = "ollama" ]; then
    execute_and_parse_api_call "call_ollama_api" "$OLLAMA_MODEL"

    # 如果主模型失敗且有備用模型，依序嘗試所有備用模型
    if { [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; } && [ -n "$OLLAMA_MODEL_BAK" ]; then
        # 將逗號分隔的備用模型字串轉換成陣列
        IFS=',' read -ra BACKUP_MODELS <<< "$OLLAMA_MODEL_BAK"
        
        for backup_model in "${BACKUP_MODELS[@]}"; do
            # 移除前後空白
            backup_model=$(echo "$backup_model" | xargs)
            
            if [ -n "$backup_model" ]; then
                echo "主模型 ($OLLAMA_MODEL) 呼叫失敗，嘗試備用模型 ($backup_model)..." >&2
                execute_and_parse_api_call "call_ollama_api" "$backup_model"
                
                # 如果這個備用模型成功，就停止嘗試
                if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
                    break
                fi
            fi
        done
    fi

elif [ "$API_SERVICE" = "openrouter" ]; then
    execute_and_parse_api_call "call_openrouter_api" "$OPENROUTER_MODEL"

    # 如果主模型失敗且有備用模型，依序嘗試所有備用模型
    if { [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; } && [ -n "$OPENROUTER_MODEL_BAK" ]; then
        # 將逗號分隔的備用模型字串轉換成陣列
        IFS=',' read -ra BACKUP_MODELS <<< "$OPENROUTER_MODEL_BAK"
        
        for backup_model in "${BACKUP_MODELS[@]}"; do
            # 移除前後空白
            backup_model=$(echo "$backup_model" | xargs)
            
            if [ -n "$backup_model" ]; then
                echo "主模型 ($OPENROUTER_MODEL) 呼叫失敗，嘗試備用模型 ($backup_model)..." >&2
                execute_and_parse_api_call "call_openrouter_api" "$backup_model"
                
                # 如果這個備用模型成功，就停止嘗試
                if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
                    break
                fi
            fi
        done
    fi
else
    echo "錯誤：未知的 API 服務 '$API_SERVICE'。"
    exit 1
fi

# 輸出結果
if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    echo "API 請求失敗，或回傳內容為空 (empty or null)。請檢查設定、API 金鑰和網路連線。"
else
    echo "--- Log 摘要與分析結果 ---"
    echo "分析模型: $SELECTED_MODEL"
    echo "API 請求時間: $API_DURATION 秒"
    echo "---------------------------------"
    echo "$RESPONSE"
fi