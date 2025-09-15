#!/bin/bash

# ==============================================================================
# Script Name: setup_scripts.sh (Version 4 - Non-interactive)
# Description: 從指定的 GitHub 目錄下載 scripts，設定 .sh 檔案為可執行，
#              然後直接複製 .env.example 為 .env，並提示使用者手動編輯。
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

# --- 函式定義 ---

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

# 從 GitHub 下載檔案
download_files() {
    echo -e "${BLUE}step 2 -> 準備從 GitHub 下載檔案...${NC}"
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}目錄 '$TARGET_DIR' 已存在，將會被移除並重新下載以確保內容最新。${NC}"
        rm -rf "$TARGET_DIR"
    fi
    mkdir -p "$TARGET_DIR"
    echo -e "已建立目錄 '$TARGET_DIR'。"

    download_urls=$(curl -sL "$API_URL" | jq -r '.[] | select(.type == "file") | .download_url')

    if [ -z "$download_urls" ]; then
        echo -e "${YELLOW}無法從 GitHub API 取得檔案列表。請檢查網路連線或 URL 是否正確。${NC}"
        exit 1
    fi

    echo "正在下載檔案到 '$TARGET_DIR/'..."
    echo "$download_urls" | wget -q --show-progress -P "$TARGET_DIR/" -i -
    
    echo -e "${GREEN}所有檔案下載完成。${NC}\n"
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

# 複製 .env.example 為 .env 並顯示提示訊息
create_env_file() {
    echo -e "${BLUE}step 4 -> 正在建立 .env 設定檔...${NC}"
    if [ ! -f ".env.example" ]; then
        echo -e "${YELLOW}錯誤：找不到 '.env.example' 檔案。無法建立 .env。${NC}"
        cd ..
        exit 1
    fi

    # 執行複製
    cp .env.example .env
    echo -e "${GREEN}已成功將 '.env.example' 複製為 '.env'。${NC}"
    
    # 顯示重要提示
    echo -e "\n${YELLOW}======================== 重要提示 ========================${NC}"
    echo -e "${YELLOW} Script 已為您建立好設定檔範本。                     ${NC}"
    echo -e "${YELLOW}                                                      ${NC}"
    echo -e "${YELLOW}   請務必手動編輯 '${TARGET_DIR}/.env' 檔案，          ${NC}"
    echo -e "${YELLOW}   將其中的設定值修改成您自己的內容。                 ${NC}"
    echo -e "${YELLOW}========================================================${NC}\n"
    
    cd .. # 完成後返回上一層目錄
}


# --- 主程式 ---
main() {
    check_dependencies
    download_files
    set_permissions
    create_env_file
    echo -e "${GREEN}=== 所有操作已成功完成！請記得手動修改 .env 檔案。 ===${NC}"
}

main "$@"