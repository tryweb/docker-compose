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
OLLAMA_MODEL_BAK="${OLLAMA_MODEL_BAK:-}" # 備用模型，預設為空
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-YOUR_OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-openai/gpt-4o-mini}"
OPENROUTER_MODEL_BAK="${OPENROUTER_MODEL_BAK:-}" # 備用模型，預設為空
OPENROUTER_API_URL="${OPENROUTER_API_URL:-https://openrouter.ai/api/v1/chat/completions}"
LOG_FILE="" # LOG_FILE 必須由參數提供

# 從命令列參數解析，這會覆蓋所有先前的設定 (最高優先級)
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
    esac
done

# --- 參數檢查 ---
# 檢查必要的 LOG_FILE 參數
if [ -z "$LOG_FILE" ]; then
    echo "錯誤: 未指定 LOG_FILE。"
    echo "使用方法: $0 LOG_FILE=/path/to/logfile [API_SERVICE=ollama] [...]"
    exit 1
fi

# 檢查 Log 檔案是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo "錯誤：找不到檔案在 $LOG_FILE"
    exit 1
fi

# --- 函式區 ---
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
# 接收模型名稱作為參數 $1
call_ollama_api() {
    local model_to_use="$1"
    local start_time
    start_time=$(date +%s)

    ( 
        printf '{"model": "%s", "stream": false, "prompt": ' "$model_to_use"
        get_prompt | jq -Rs .
        printf '}'
    ) | curl -s -X POST "$OLLAMA_API_URL" \
        -H "Content-Type: application/json" \
        -d @- \
        | jq -r '.response'

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    API_DURATION=$duration # 將執行時間存到全域變數
    echo "($model_to_use) API call took $duration seconds." >&2
}

# --- 函式：呼叫 OpenRouter API ---
# 接收模型名稱作為參數 $1
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

    ( 
        printf '{"model": "%s", "messages": [{"role": "user", "content": ' "$model_to_use"
        get_prompt | jq -Rs .
        printf '}]}'
    ) | curl -s -X POST "$OPENROUTER_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: $APP_URL" \
        -H "X-Title: $APP_TITLE" \
        -d @- \
        | jq -r '.choices[0].message.content'

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    API_DURATION=$duration # 將執行時間存到全域變數
    echo "($model_to_use) API call took $duration seconds." >&2
}

# --- 主程式：根據選擇的服務呼叫對應的函式 ---
echo "正在使用 $API_SERVICE 服務分析 Log 檔案..."

# 初始化共用變數
RESPONSE=""
SELECTED_MODEL=""
API_DURATION=0

if [ "$API_SERVICE" = "ollama" ]; then
    # 嘗試主要模型
    SELECTED_MODEL="$OLLAMA_MODEL"
    RESPONSE=$(call_ollama_api "$SELECTED_MODEL")

    # 如果失敗且有備用模型，則重試
    if ([ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]) && [ -n "$OLLAMA_MODEL_BAK" ]; then
        echo "主模型 ($SELECTED_MODEL) 呼叫失敗，嘗試備用模型 ($OLLAMA_MODEL_BAK)..." >&2
        SELECTED_MODEL="$OLLAMA_MODEL_BAK"
        RESPONSE=$(call_ollama_api "$SELECTED_MODEL")
    fi

elif [ "$API_SERVICE" = "openrouter" ]; then
    # 嘗試主要模型
    SELECTED_MODEL="$OPENROUTER_MODEL"
    RESPONSE=$(call_openrouter_api "$SELECTED_MODEL")

    # 如果失敗且有備用模型，則重試
    if ([ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]) && [ -n "$OPENROUTER_MODEL_BAK" ]; then
        echo "主模型 ($SELECTED_MODEL) 呼叫失敗，嘗試備用模型 ($OPENROUTER_MODEL_BAK)..." >&2
        SELECTED_MODEL="$OPENROUTER_MODEL_BAK"
        RESPONSE=$(call_openrouter_api "$SELECTED_MODEL")
    fi

else
    echo "錯誤：未知的 API 服務 '$API_SERVICE'。"
    exit 1
fi

# 輸出結果
# 檢查最終的回應是否為空字串或字串 "null"
if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    echo "API 請求失敗，或回傳內容為空 (empty or null)。請檢查設定、API 金鑰和網路連線。"
else
    echo "--- Log 摘要與分析結果 ---"
    echo "分析模型: $SELECTED_MODEL"
    echo "API 請求時間: $API_DURATION 秒"
    echo "---------------------------------"
    echo "$RESPONSE"
fi