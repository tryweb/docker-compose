#!/bin/bash

# ==============================================================================
# Script Name: setup_scripts.sh (Version 7 - Merge & Overwrite Strategy)
# Description: 從 GitHub 下載 scripts。此版本採用合併更新策略：
#              如果 scripts 目錄已存在，則將新版下載至暫存目錄，
#              然後覆蓋回原目錄。這能確保更新腳本的同時，
#              保留使用者自行新增的檔案（例如 exceptions.txt）。
# Author: Gemini
# Dependencies: curl, wget, jq
# ==============================================================================

# --- 設定變數 ---
# ANSI 顏色代碼
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub API URL
API_URL="https://api.github.com/repos/tryweb/docker-compose/contents/scripts"
TARGET_DIR="scripts"
DOWNLOAD_DIR="${TARGET_DIR}.download" # 暫存下載目錄

# --- 函式定義 ---

# 腳本結束時執行的清理函式
cleanup() {
  if [ -d "$DOWNLOAD_DIR" ]; then
    rm -rf "$DOWNLOAD_DIR"
    echo -e "\n${BLUE}已清除暫時下載目錄 ($DOWNLOAD_DIR)。${NC}"
  fi
}

# 設定 trap，確保無論腳本如何結束，都會執行 cleanup 函式
trap cleanup EXIT

# 檢查必要的指令是否存在
check_dependencies() {
    echo -e "${BLUE}step 1 -> 正在檢查相依套件...${NC}"
    local missing_deps=0
    for cmd in curl wget jq; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${YELLOW}錯誤：找不到必要的指令 '$cmd'。請先安裝它。${NC}"
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        echo -e "${YELLOW}請安裝完缺少的套件後再重新執行 script。${NC}"
        exit 1
    fi
    echo -e "${GREEN}所有必要的套件都已安裝。${NC}\n"
}

# 從 GitHub 下載檔案（採用合併更新策略）
download_files() {
    echo -e "${BLUE}step 2 -> 準備從 GitHub 下載檔案...${NC}"

    local download_target=""

    # 根據目標目錄是否存在，決定下載策略
    if [ -d "$TARGET_DIR" ]; then
        echo "目錄 '$TARGET_DIR' 已存在，將採用合併更新模式。"
        # 清理可能存在的舊暫存檔並建立新的
        rm -rf "$DOWNLOAD_DIR"
        mkdir -p "$DOWNLOAD_DIR"
        download_target="$DOWNLOAD_DIR"
        echo "檔案將暫時下載至 '$DOWNLOAD_DIR'。"
    else
        echo "目錄 '$TARGET_DIR' 不存在，將直接建立並下載。"
        mkdir -p "$TARGET_DIR"
        download_target="$TARGET_DIR"
    fi

    download_urls=$(curl -sL "$API_URL" | jq -r '.[] | select(.type == "file") | .download_url')

    if [ -z "$download_urls" ]; then
        echo -e "${YELLOW}無法從 GitHub API 取得檔案列表。請檢查網路連線或 URL 是否正確。${NC}"
        # 如果是更新模式，需要清理建立的暫存目錄
        if [ "$download_target" == "$DOWNLOAD_DIR" ]; then
            rm -rf "$DOWNLOAD_DIR"
        fi
        exit 1
    fi

    echo "正在下載檔案到 '$download_target/'..."
    echo "$download_urls" | wget -q --show-progress -P "$download_target/" -i -
    
    # 如果是更新模式，則執行複製覆蓋操作
    if [ "$download_target" == "$DOWNLOAD_DIR" ]; then
        echo "正在將新檔案合併至 '$TARGET_DIR'..."
        # 使用 cp -f 來強制覆蓋同名檔案
        cp -f "${DOWNLOAD_DIR}"/* "${TARGET_DIR}/"
        echo -e "${GREEN}檔案合併完成。您自訂的檔案已被保留。${NC}"
        # 清理工作交給 trap function 即可
    fi

    echo -e "${GREEN}檔案下載與更新操作完成。${NC}\n"
}

# 設定 .sh 檔案為可執行
set_permissions() {
    echo -e "${BLUE}step 3 -> 正在設定 .sh 檔案的執行權限...${NC}"
    cd "$TARGET_DIR"

    if ls *.sh 1> /dev/null 2>&1; then
        for file in *.sh; do
            chmod +x "$file"
            echo "  - 已將 '$file' 設定為可執行。"
        done
        echo -e "${GREEN}所有 .sh 檔案權限設定完成。${NC}\n"
    else
        echo -e "${YELLOW}在 '$TARGET_DIR' 目錄中沒有找到任何 .sh 檔案。${NC}\n"
    fi
}

# 檢查並建立 .env 設定檔
create_env_file() {
    echo -e "${BLUE}step 4 -> 正在檢查/建立 .env 設定檔...${NC}"
    
    if [ ! -f ".env.example" ]; then
        echo -e "${YELLOW}錯誤：在 '$TARGET_DIR' 中找不到 '.env.example' 檔案。無法建立 .env。${NC}"
        cd ..
        exit 1
    fi

    if [ -f ".env" ]; then
        echo -e "${GREEN}'.env' 檔案已存在。將檢查並補全缺少的參數...${NC}"
        
        example_keys=$(grep -vE '^\s*#|^\s*$' .env.example | cut -d '=' -f 1 | sort)
        current_keys=$(grep -vE '^\s*#|^\s*$' .env | cut -d '=' -f 1 | sort)
        missing_keys=$(comm -23 <(echo "$example_keys") <(echo "$current_keys"))

        if [ -z "$missing_keys" ]; then
            echo -e "${GREEN}您的 .env 檔案已包含所有範本中的參數，無需更新。${NC}"
        else
            echo -e "${YELLOW}偵測到以下參數在您的 .env 中不存在，將從 .env.example 自動補上：${NC}"
            echo -e "\n# --- 以下是由 setup_script.sh 於 $(date '+%Y-%m-%d %H:%M:%S') 自動新增的參數 ---" >> .env
            for key in $missing_keys; do
                grep "^${key}=" .env.example >> .env
                echo -e "  - ${GREEN}已新增: ${key}${NC}"
            done
            echo -e "${GREEN}參數已補全。${NC}"
        fi

    else
        echo "'.env' 檔案不存在，將從 '.env.example' 複製一份新的。"
        cp .env.example .env
        echo -e "${GREEN}已成功將 '.env.example' 複製為 '.env'。${NC}"
    fi
    
    echo -e "\n${YELLOW}======================== 重要提示 ========================${NC}"
    echo -e "${YELLOW}  請務必檢查並編輯 '${TARGET_DIR}/.env' 檔案，          ${NC}"
    echo -e "${YELLOW}  確認所有設定值都符合您的需求。                      ${NC}"
    echo -e "${YELLOW}========================================================${NC}\n"
    
    cd ..
}

# --- 主程式 ---
main() {
    check_dependencies
    download_files
    set_permissions
    create_env_file
    echo -e "${GREEN}=== 所有操作已成功完成！請記得檢查並修改 .env 檔案。 ===${NC}"
}

main "$@"