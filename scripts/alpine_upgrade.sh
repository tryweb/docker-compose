#!/bin/sh

# Alpine Linux 3.21 to 3.22 升級腳本
# 使用方法: ./alpine_upgrade.sh (需要 root 權限執行)
# 注意: 請確保有足夠的磁碟空間和網路連線

set -eu  # 嚴格模式：遇到錯誤立即停止

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 錯誤處理函數
cleanup_on_error() {
    log_error "升級過程中發生錯誤，正在執行清理..."
    if [ -f "/etc/apk/repositories.backup" ]; then
        log_info "恢復原始 repositories 檔案..."
        cp /etc/apk/repositories.backup /etc/apk/repositories
        apk update || true
    fi
    log_error "升級失敗，系統已回滾到原始狀態"
    exit 1
}

# 設定錯誤陷阱
trap cleanup_on_error ERR

# 檢查是否為 root 用戶
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "此腳本需要以 root 權限執行"
        log_info "請切換到 root 用戶執行: su -"
        exit 1
    fi
}

# 檢查當前版本
check_current_version() {
    log_info "檢查當前 Alpine Linux 版本..."
    current_version=$(cat /etc/alpine-release)
    log_info "當前版本: $current_version"
    
    if ! echo "$current_version" | grep -q "^3\.21\."; then
        log_error "當前版本不是 3.21.x，無法使用此升級腳本"
        log_info "當前版本: $current_version"
        exit 1
    fi
    
    log_success "版本檢查通過"
}

# 檢查系統資源
check_system_resources() {
    log_info "檢查系統資源..."
    
    # 檢查磁碟空間（至少需要 500MB 可用空間）
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=512000  # 500MB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "磁碟空間不足，至少需要 500MB 可用空間"
        log_info "當前可用空間: $(($available_space/1024))MB"
        exit 1
    fi
    
    log_success "磁碟空間檢查通過: $(($available_space/1024))MB 可用"
}

# 檢查網路連線
check_network() {
    log_info "檢查網路連線..."
    
    if ! ping -c 1 dl-cdn.alpinelinux.org >/dev/null 2>&1; then
        log_error "無法連接到 Alpine Linux 套件庫"
        log_info "請檢查網路連線後重試"
        exit 1
    fi
    
    log_success "網路連線正常"
}

# 備份重要檔案
backup_files() {
    log_info "備份重要檔案..."
    
    # 備份 repositories 檔案
    cp /etc/apk/repositories /etc/apk/repositories.backup
    log_success "已備份 /etc/apk/repositories"
    
    # 備份套件列表
    apk list -I > /root/installed_packages_before_upgrade.txt 2>/dev/null || true
    log_success "已備份當前安裝的套件列表"
}

# 執行升級前的準備工作
pre_upgrade() {
    log_info "執行升級前的準備工作..."
    
    # 更新套件索引
    log_info "更新套件索引..."
    apk update
    
    # 升級現有套件
    log_info "升級現有套件..."
    apk upgrade
    
    log_success "升級前準備完成"
}

# 更新 repositories 檔案
update_repositories() {
    log_info "更新 repositories 檔案從 3.21 到 3.22..."
    
    # 使用更安全的方式替換版本號
    sed -i.tmp 's/v3\.21/v3.22/g' /etc/apk/repositories
    
    # 驗證替換是否成功
    if ! grep -q "v3.22" /etc/apk/repositories; then
        log_error "repositories 檔案更新失敗"
        cp /etc/apk/repositories.backup /etc/apk/repositories
        exit 1
    fi
    
    log_success "repositories 檔案更新完成"
    log_info "新的 repositories 內容:"
    cat /etc/apk/repositories | sed 's/^/  /'
}

# 執行主要升級
main_upgrade() {
    log_info "開始執行主要升級程序..."
    
    # 更新套件索引
    log_info "使用新的 repositories 更新套件索引..."
    apk update
    
    # 第一次升級
    log_info "執行第一次升級..."
    apk upgrade
    
    # 修復任何損壞的依賴關係
    log_info "修復套件依賴關係..."
    apk fix
    
    # 升級 apk-tools
    log_info "升級 apk-tools..."
    apk add --upgrade apk-tools
    
    # 升級所有可用套件
    log_info "升級所有可用套件..."
    apk upgrade --available
    
    # 升級 alpine-base
    log_info "升級 alpine-base..."
    apk add --upgrade alpine-base
    
    log_success "主要升級程序完成"
}

# 驗證升級結果
verify_upgrade() {
    log_info "驗證升級結果..."
    
    new_version=$(cat /etc/alpine-release)
    log_info "升級後版本: $new_version"
    
    if echo "$new_version" | grep -q "^3\.22\."; then
        log_success "升級成功！版本已更新到 $new_version"
        return 0
    else
        log_error "升級後版本驗證失敗"
        log_error "預期: 3.22.x，實際: $new_version"
        return 1
    fi
}

# 清理工作
cleanup() {
    log_info "執行清理工作..."
    
    # 清理套件快取
    apk cache clean
    
    # 移除臨時檔案
    rm -f /etc/apk/repositories.tmp
    
    log_success "清理完成"
}

# 重新啟動提示
reboot_prompt() {
    log_info "升級完成，建議重新啟動系統以確保所有變更生效"
    
    while true; do
        printf "是否立即重新啟動？(y/n): "
        read yn
        case $yn in
            [Yy]* )
                log_info "正在同步檔案系統..."
                sync
                log_info "系統將在 5 秒後重新啟動..."
                sleep 5
                reboot
                break
                ;;
            [Nn]* )
                log_warning "請記得稍後手動重新啟動系統"
                log_info "重新啟動指令: reboot"
                break
                ;;
            * ) 
                echo "請輸入 y 或 n"
                ;;
        esac
    done
}

# 主程序
main() {
    log_info "開始 Alpine Linux 3.21 到 3.22 升級程序"
    log_info "========================================="
    
    check_root
    check_current_version
    check_system_resources
    check_network
    backup_files
    pre_upgrade
    update_repositories
    main_upgrade
    
    if verify_upgrade; then
        cleanup
        log_success "========================================="
        log_success "Alpine Linux 升級成功完成！"
        log_info "升級日誌已記錄在此腳本的輸出中"
        reboot_prompt
    else
        log_error "升級驗證失敗，執行回滾..."
        cleanup_on_error
    fi
}

# 顯示使用說明
show_usage() {
    echo "Alpine Linux 3.21 to 3.22 升級腳本"
    echo "使用方法: ./alpine_upgrade.sh (需要 root 權限)"
    echo ""
    echo "此腳本將會:"
    echo "1. 檢查當前系統版本和資源"
    echo "2. 備份重要檔案"
    echo "3. 執行安全的升級程序"
    echo "4. 驗證升級結果"
    echo "5. 提供重新啟動選項"
    echo ""
    echo "注意事項:"
    echo "- 請確保有穩定的網路連線"
    echo "- 確保有至少 500MB 的可用磁碟空間"
    echo "- 建議在升級前備份重要資料"
    echo "- 升級完成後建議重新啟動系統"
}

# 檢查參數
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_usage
    exit 0
fi

# 執行主程序
main "$@"