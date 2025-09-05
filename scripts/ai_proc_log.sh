#!/bin/bash

# --- 設定載入 ---
# 優先級: 命令列參數 > 環境變數 > .env 檔案 > 腳本內預設值

# 取得腳本所在的目錄
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 如果 .env 檔案存在，則載入它
# 這會將 .env 檔案中的變數載入為環境變數
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a # 自動將後續定義的變數導出為環境變數
  source "$SCRIPT_DIR/.env"
  set +a # 取消自動導出
fi

# --- 參數設定區 ---
# 為所有設定變數提供預設值 (如果環境變數或 .env 未設定)
# 格式: ${VARIABLE_NAME:-DEFAULT_VALUE}
API_SERVICE="${API_SERVICE:-openrouter}"
OLLAMA_API_URL="${OLLAMA_API_URL:-http://localhost:11434/api/generate}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-YOUR_OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-openai/gpt-4o-mini}"
OPENROUTER_API_URL="${OPENROUTER_API_URL:-https://openrouter.ai/api/v1/chat/completions}"
LOG_FILE="" # LOG_FILE 必須由參數提供

# 從命令列參數解析，這會覆蓋所有先前的設定 (最高優先級)
for arg in "$@"; do
    case $arg in
        LOG_FILE=*) LOG_FILE="${arg#*=}" ;; 
        API_SERVICE=*) API_SERVICE="${arg#*=}" ;; 
        OLLAMA_API_URL=*) OLLAMA_API_URL="${arg#*=}" ;; 
        OLLAMA_MODEL=*) OLLAMA_MODEL="${arg#*=}" ;; 
        OPENROUTER_API_KEY=*) OPENROUTER_API_KEY="${arg#*=}" ;; 
        OPENROUTER_MODEL=*) OPENROUTER_MODEL="${arg#*=}" ;; 
        OPENROUTER_API_URL=*) OPENROUTER_API_URL="${arg#*=}" ;; 
    esac
done



# --- 參數檢查 ---
# 檢查必要的 LOG_FILE 參數
if [ -z "$LOG_FILE" ]; then
    echo "錯誤: 未指定 LOG_FILE。"
    echo "使用方法: $0 LOG_FILE=/path/to/logfile [API_SERVICE=ollama] [OPENROUTER_API_KEY=... ]"
    exit 1
fi

# 檢查 Log 檔案是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo "錯誤：找不到檔案在 $LOG_FILE"
    exit 1
fi

# --- 主程式 ---
# 定義一個函式來生成 prompt，這樣可以串流處理，避免將整個 Log 讀入記憶體
get_prompt() {
    echo "請分析以下 Log 內容，並提供一個簡潔的摘要。請以正體中文回覆重點摘要。請列出："
    echo "1. 重要的錯誤訊息（如果有）。"
    echo "2. 關鍵事件的時間點。"
    echo "3. 問題的可能原因和解決建議。"
    echo "--- Log 內容開始 ---"
    cat "$LOG_FILE"
    echo "--- Log 內容結束 ---"
}

# --- 函式：呼叫 Ollama API ---
call_ollama_api() {
    local start_time
    start_time=$(date +%s)

    ( 
        printf '{"model": "%s", "stream": false, "prompt": ' "$OLLAMA_MODEL"
        get_prompt | jq -Rs .
        printf '}'
    ) | curl -s -X POST "$OLLAMA_API_URL" \
        -H "Content-Type: application/json" \
        -d @- \
        | jq -r '.response'

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "API call took $duration seconds." >&2
}

# --- 函式：呼叫 OpenRouter API ---
call_openrouter_api() {
    if [ "$OPENROUTER_API_KEY" = "YOUR_OPENROUTER_API_KEY" ]; then
        echo "錯誤：請先將 OPENROUTER_API_KEY 替換成你的金鑰。"
        exit 1
    fi

    local start_time
    start_time=$(date +%s)

    ( 
        printf '{"model": "%s", "messages": [{"role": "user", "content": ' "$OPENROUTER_MODEL"
        get_prompt | jq -Rs .
        printf '}]}'
    ) | curl -s -X POST "$OPENROUTER_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d @- \
        | jq -r '.choices[0].message.content'

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "API call took $duration seconds." >&2
}




# --- 主程式：根據選擇的服務呼叫對應的函式 ---
echo "正在使用 $API_SERVICE 服務分析 Log 檔案..."

if [ "$API_SERVICE" = "ollama" ]; then
    RESPONSE=$(call_ollama_api)
elif [ "$API_SERVICE" = "openrouter" ]; then
    RESPONSE=$(call_openrouter_api)
else
    echo "錯誤：未知的 API 服務 '$API_SERVICE'。"
    exit 1
fi

# 輸出結果
if [ -z "$RESPONSE" ]; then
    echo "API 請求失敗，或回傳內容為空。請檢查設定和網路連線。"
else
    echo "--- Log 摘要與分析結果 ---"
    echo "$RESPONSE"
fi
