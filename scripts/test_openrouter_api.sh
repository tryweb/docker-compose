#!/bin/bash

# 測試 OpenRouter API 的工具程式
# 用途：協助釐清 call_openrouter_api() 呼叫失敗的問題

# --- 顏色設定 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 設定載入 ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 載入 .env 檔案
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
  echo -e "${GREEN}✓${NC} 已載入 .env 設定檔"
else
  echo -e "${YELLOW}⚠${NC} 未找到 .env 檔案，使用預設值"
fi

# 設定預設值
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-YOUR_OPENROUTER_API_KEY}"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-z-ai/glm-4.5-air:free}"
OPENROUTER_API_URL="${OPENROUTER_API_URL:-https://openrouter.ai/api/v1/chat/completions}"
TEST_PROMPT="${TEST_PROMPT:-請用繁體中文回答：什麼是 Docker？請用一句話簡短回答。}"

# 從命令列參數解析
for arg in "$@"; do
    case $arg in
        OPENROUTER_API_KEY=*) OPENROUTER_API_KEY="${arg#*=}" ;;
        OPENROUTER_MODEL=*) OPENROUTER_MODEL="${arg#*=}" ;;
        OPENROUTER_API_URL=*) OPENROUTER_API_URL="${arg#*=}" ;;
        TEST_PROMPT=*) TEST_PROMPT="${arg#*=}" ;;
        --help|-h)
            echo "使用方法: $0 [選項]"
            echo ""
            echo "選項:"
            echo "  OPENROUTER_API_KEY=<key>    設定 OpenRouter API 金鑰"
            echo "  OPENROUTER_MODEL=<model>    設定使用的模型 (預設: openai/gpt-4o-mini)"
            echo "  OPENROUTER_API_URL=<url>    設定 API URL"
            echo "  TEST_PROMPT=<text>          設定測試提示詞"
            echo "  --help, -h                  顯示此說明"
            echo ""
            echo "範例:"
            echo "  $0"
            echo "  $0 OPENROUTER_MODEL=anthropic/claude-3-haiku"
            exit 0
            ;;
    esac
done

# --- 顯示測試資訊 ---
echo ""
echo "=========================================="
echo "  OpenRouter API 測試工具"
echo "=========================================="
echo ""
echo -e "${BLUE}測試設定:${NC}"
echo "  API URL: $OPENROUTER_API_URL"
echo "  模型: $OPENROUTER_MODEL"
echo "  API 金鑰: ${OPENROUTER_API_KEY:0:20}..." 
echo "  測試提示: $TEST_PROMPT"
echo ""

# --- 參數檢查 ---
if [ "$OPENROUTER_API_KEY" = "YOUR_OPENROUTER_API_KEY" ] || [ -z "$OPENROUTER_API_KEY" ]; then
    echo -e "${RED}✗ 錯誤${NC}: 請先設定有效的 OPENROUTER_API_KEY"
    echo ""
    echo "方法 1: 在 scripts/.env 檔案中設定"
    echo "方法 2: 使用命令列參數 OPENROUTER_API_KEY=your_key"
    echo "方法 3: 設定環境變數 export OPENROUTER_API_KEY=your_key"
    exit 1
fi

# --- 檢查必要工具 ---
echo -e "${BLUE}檢查必要工具...${NC}"
for cmd in curl jq; do
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd"
    else
        echo -e "${RED}✗${NC} $cmd 未安裝"
        exit 1
    fi
done
echo ""

# --- 測試函式 ---
test_openrouter_api() {
    local APP_URL="https://github.com/tryweb"
    local APP_TITLE="OpenRouter_API_Test"
    
    echo -e "${BLUE}開始測試 API 呼叫...${NC}"
    echo ""
    
    local start_time
    start_time=$(date +%s)
    
    # 建立請求 payload
    local payload
    payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": %s}]}' \
        "$OPENROUTER_MODEL" \
        "$(echo "$TEST_PROMPT" | jq -Rs .)")
    
    echo -e "${YELLOW}請求 Payload:${NC}"
    echo "$payload" | jq .
    echo ""
    
    # 建立臨時檔案儲存完整回應
    local temp_response=$(mktemp)
    local temp_headers=$(mktemp)
    
    # 執行 API 呼叫並儲存完整回應和 headers
    local http_code
    http_code=$(echo "$payload" | curl -s -X POST "$OPENROUTER_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: $APP_URL" \
        -H "X-Title: $APP_TITLE" \
        -w "%{http_code}" \
        -D "$temp_headers" \
        -d @- \
        -o "$temp_response")
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo -e "${BLUE}測試結果:${NC}"
    echo "  HTTP 狀態碼: $http_code"
    echo "  回應時間: ${duration} 秒"
    echo ""
    
    # 讀取回應內容
    local response_body
    response_body=$(cat "$temp_response")
    
    # 顯示 HTTP Headers (只顯示關鍵資訊)
    echo -e "${YELLOW}關鍵 HTTP Headers:${NC}"
    grep -i "content-type\|x-ratelimit\|openrouter" "$temp_headers" || echo "  (無特殊 headers)"
    echo ""
    
    # 分析回應
    echo -e "${YELLOW}完整 API 回應:${NC}"
    if echo "$response_body" | jq . &> /dev/null; then
        echo "$response_body" | jq .
    else
        echo "$response_body"
    fi
    echo ""
    
    # 判斷是否成功
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        # 嘗試解析回應內容
        local content
        content=$(echo "$response_body" | jq -r '.choices[0].message.content' 2>/dev/null)
        
        if [ -n "$content" ] && [ "$content" != "null" ]; then
            echo -e "${GREEN}✓ API 呼叫成功!${NC}"
            echo ""
            echo -e "${BLUE}AI 回應內容:${NC}"
            echo "----------------------------------------"
            echo "$content"
            echo "----------------------------------------"
            
            # 顯示使用量資訊
            local usage
            usage=$(echo "$response_body" | jq -r '.usage' 2>/dev/null)
            if [ -n "$usage" ] && [ "$usage" != "null" ]; then
                echo ""
                echo -e "${BLUE}Token 使用量:${NC}"
                echo "$usage" | jq .
            fi
        else
            echo -e "${RED}✗ 無法解析 AI 回應內容${NC}"
            echo "可能原因："
            echo "  - 回應格式不符合預期"
            echo "  - choices[0].message.content 路徑不存在"
        fi
    else
        echo -e "${RED}✗ API 呼叫失敗 (HTTP $http_code)${NC}"
        echo ""
        
        # 嘗試解析錯誤訊息
        local error_msg
        error_msg=$(echo "$response_body" | jq -r '.error.message' 2>/dev/null)
        local error_type
        error_type=$(echo "$response_body" | jq -r '.error.type' 2>/dev/null)
        local error_code
        error_code=$(echo "$response_body" | jq -r '.error.code' 2>/dev/null)
        
        if [ -n "$error_msg" ] && [ "$error_msg" != "null" ]; then
            echo -e "${RED}錯誤訊息:${NC} $error_msg"
            [ -n "$error_type" ] && [ "$error_type" != "null" ] && echo -e "${RED}錯誤類型:${NC} $error_type"
            [ -n "$error_code" ] && [ "$error_code" != "null" ] && echo -e "${RED}錯誤代碼:${NC} $error_code"
        fi
        
        echo ""
        echo -e "${YELLOW}常見問題診斷:${NC}"
        case $http_code in
            401)
                echo "  • API 金鑰無效或未授權"
                echo "  • 請檢查 OPENROUTER_API_KEY 是否正確"
                ;;
            402)
                echo "  • 帳戶餘額不足"
                echo "  • 請至 OpenRouter 網站檢查帳戶餘額"
                ;;
            403)
                echo "  • 請求被拒絕"
                echo "  • 可能是 API 金鑰權限不足或地區限制"
                ;;
            404)
                echo "  • 找不到指定的模型"
                echo "  • 請檢查 OPENROUTER_MODEL 是否正確"
                echo "  • 當前設定: $OPENROUTER_MODEL"
                ;;
            429)
                echo "  • 超過速率限制"
                echo "  • 請稍後再試或升級帳戶方案"
                ;;
            500|502|503|504)
                echo "  • OpenRouter 伺服器錯誤"
                echo "  • 請稍後再試"
                ;;
            *)
                echo "  • 未知錯誤，請查看上方完整回應"
                ;;
        esac
    fi
    
    # 清理臨時檔案
    rm -f "$temp_response" "$temp_headers"
    
    echo ""
    echo "=========================================="
    echo "  測試完成"
    echo "=========================================="
}

# --- 執行測試 ---
test_openrouter_api