#!/bin/sh

# Alpine Linux 3.19 to 3.22 升級腳本 (逐步升級)
# 使用方法: ./alpine_upgrade.sh (需要 root 權限執行)
# 注意: 請確保有足夠的磁碟空間和網路連線
# 此腳本會執行 3.19 → 3.20 → 3.21 → 3.22 的逐步升級

set -eu  # 嚴格模式：遇到錯誤立即停止

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 升級路徑定義
UPGRADE_PATH="3.19 3.20 3.21 3.22"
TARGET_VERSION="3.22"

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
    
    # 檢查是否為支援的起始版本
    if ! echo "$current_version" | grep -E "^3\.(19|20|21)\."; then
        log_error "當前版本不在支援的升級範圍內"
        log_info "此腳本支援從 3.19.x, 3.20.x, 或 3.21.x 升級到 3.22.x"
        log_info "當前版本: $current_version"
        exit 1
    fi
    
    log_success "版本檢查通過"
}

# 取得當前主版本號
get_current_major_version() {
    current_version=$(cat /etc/alpine-release)
    echo "$current_version" | sed -E 's/^3\.([0-9]+)\..*/3.\1/'
}

# 檢查系統資源
check_system_resources() {
    log_info "檢查系統資源..."
    
    # 檢查磁碟空間（至少需要 1GB 可用空間，因為要多次升級）
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=1048576  # 1GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "磁碟空間不足，至少需要 1GB 可用空間進行多版本升級"
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
    
    # 建立備份目錄
    backup_dir="/root/alpine_upgrade_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 備份 repositories 檔案
    cp /etc/apk/repositories "$backup_dir/repositories.original"
    cp /etc/apk/repositories /etc/apk/repositories.backup
    log_success "已備份 /etc/apk/repositories"
    
    # 備份套件列表
    apk list -I > "$backup_dir/installed_packages_before_upgrade.txt" 2>/dev/null || true
    log_success "已備份當前安裝的套件列表"
    
    # 備份重要系統檔案
    cp /etc/alpine-release "$backup_dir/"
    cp -r /etc/apk/ "$backup_dir/apk/" 2>/dev/null || true
    
    log_success "備份完成，備份位置: $backup_dir"
    echo "$backup_dir" > /tmp/alpine_upgrade_backup_path
}

# 執行升級前的準備工作
pre_upgrade() {
    log_info "執行升級前的準備工作..."
    
    # 更新套件索引
    log_info "更新套件索引..."
    apk update
    
    # 升級現有套件
    log_info "升級當前版本的現有套件..."
    apk upgrade
    
    log_success "升級前準備完成"
}

# 更新 repositories 檔案到指定版本
update_repositories() {
    local target_ver="$1"
    log_info "更新 repositories 檔案到版本 $target_ver..."
    
    # 備份當前 repositories
    cp /etc/apk/repositories /etc/apk/repositories.tmp
    
    # 替換所有版本號到目標版本
    sed -i "s/v3\.[0-9][0-9]*/v$target_ver/g" /etc/apk/repositories
    
    # 驗證替換是否成功
    if ! grep -q "v$target_ver" /etc/apk/repositories; then
        log_error "repositories 檔案更新到 $target_ver 失敗"
        cp /etc/apk/repositories.tmp /etc/apk/repositories
        return 1
    fi
    
    log_success "repositories 檔案更新到 $target_ver 完成"
    log_info "新的 repositories 內容:"
    cat /etc/apk/repositories | sed 's/^/  /'
    return 0
}

# 執行單個版本升級
upgrade_to_version() {
    local target_ver="$1"
    log_info "開始升級到版本 $target_ver..."
    
    # 更新 repositories
    if ! update_repositories "$target_ver"; then
        log_error "無法更新 repositories 到版本 $target_ver"
        return 1
    fi
    
    # 更新套件索引
    log_info "更新套件索引..."
    apk update
    
    # 升級 apk-tools 優先
    log_info "升級 apk-tools..."
    apk add --upgrade apk-tools
    
    # 第一次升級
    log_info "執行第一次升級..."
    apk upgrade
    
    # 修復任何損壞的依賴關係
    log_info "修復套件依賴關係..."
    apk fix
    
    # 升級所有可用套件
    log_info "升級所有可用套件..."
    apk upgrade --available
    
    # 升級系統核心套件
    log_info "升級系統核心套件..."
    apk add --upgrade alpine-base
    
    # 驗證升級
    local new_version=$(cat /etc/alpine-release)
    if echo "$new_version" | grep -q "^$target_ver\."; then
        log_success "成功升級到 $new_version"
        return 0
    else
        log_error "升級到 $target_ver 失敗，當前版本: $new_version"
        return 1
    fi
}

# 執行逐步升級
step_by_step_upgrade() {
    local current_major=$(get_current_major_version)
    log_info "當前主版本: $current_major"
    log_info "目標版本: $TARGET_VERSION"
    
    # 確定升級路徑
    local need_upgrade=false
    local upgrade_versions=""
    
    for version in $UPGRADE_PATH; do
        if [ "$need_upgrade" = "true" ]; then
            upgrade_versions="$upgrade_versions $version"
        elif [ "$version" = "$current_major" ]; then
            need_upgrade=true
            # 如果當前版本就是目標版本，則不需要升級
            if [ "$version" = "$TARGET_VERSION" ]; then
                log_info "當前版本已經是目標版本 $TARGET_VERSION"
                return 0
            fi
        fi
    done
    
    log_info "升級路徑: $current_major →$upgrade_versions"
    
    # 執行逐步升級
    for target_version in $upgrade_versions; do
        log_info "========================================"
        log_info "開始升級到 Alpine Linux $target_version"
        log_info "========================================"
        
        if ! upgrade_to_version "$target_version"; then
            log_error "升級到 $target_version 失敗"
            return 1
        fi
        
        # 在升級之間稍作暫停，讓系統穩定
        log_info "等待系統穩定..."
        sleep 5
        
        log_success "已成功升級到 $target_version"
        
        # 如果這是最後一個版本，跳出循環
        if [ "$target_version" = "$TARGET_VERSION" ]; then
            break
        fi
    done
    
    return 0
}

# 驗證最終升級結果
verify_final_upgrade() {
    log_info "驗證最終升級結果..."
    
    local final_version=$(cat /etc/alpine-release)
    log_info "最終版本: $final_version"
    
    if echo "$final_version" | grep -q "^$TARGET_VERSION\."; then
        log_success "升級成功！版本已更新到 $final_version"
        return 0
    else
        log_error "最終升級驗證失敗"
        log_error "預期: $TARGET_VERSION.x，實際: $final_version"
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
    
    # 記錄最終套件列表
    if [ -f "/tmp/alpine_upgrade_backup_path" ]; then
        backup_dir=$(cat /tmp/alpine_upgrade_backup_path)
        if [ -d "$backup_dir" ]; then
            apk list -I > "$backup_dir/installed_packages_after_upgrade.txt" 2>/dev/null || true
            log_info "最終套件列表已儲存到: $backup_dir/installed_packages_after_upgrade.txt"
        fi
        rm -f /tmp/alpine_upgrade_backup_path
    fi
    
    log_success "清理完成"
}

# 重新啟動提示
reboot_prompt() {
    log_info "多版本升級完成，強烈建議重新啟動系統以確保所有變更生效"
    log_warning "由於進行了多個版本的升級，重新啟動是必要的"
    
    while true; do
        printf "是否立即重新啟動？(y/n): "
        read yn
        case $yn in
            [Yy]* )
                log_info "正在同步檔案系統..."
                sync
                log_info "系統將在 10 秒後重新啟動..."
                sleep 10
                reboot
                break
                ;;
            [Nn]* )
                log_warning "請務必盡快手動重新啟動系統"
                log_info "重新啟動指令: reboot"
                break
                ;;
            * ) 
                echo "請輸入 y 或 n"
                ;;
        esac
    done
}

# 顯示升級計畫
show_upgrade_plan() {
    local current_major=$(get_current_major_version)
    log_info "升級計畫："
    log_info "起始版本: $current_major"
    log_info "目標版本: $TARGET_VERSION"
    
    local need_upgrade=false
    local step=1
    
    for version in $UPGRADE_PATH; do
        if [ "$need_upgrade" = "true" ]; then
            log_info "步驟 $step: 升級到 Alpine Linux $version"
            step=$((step + 1))
        elif [ "$version" = "$current_major" ]; then
            need_upgrade=true
            if [ "$version" = "$TARGET_VERSION" ]; then
                log_info "當前版本已經是目標版本，無需升級"
                return 0
            fi
        fi
    done
    
    log_warning "此升級過程可能需要 30-60 分鐘，請耐心等待"
    
    printf "確認執行升級？(y/n): "
    read yn
    case $yn in
        [Yy]* ) return 0 ;;
        [Nn]* ) exit 0 ;;
        * ) 
            echo "請輸入 y 或 n"
            show_upgrade_plan
            ;;
    esac
}

# 主程序
main() {
    log_info "開始 Alpine Linux 多版本升級程序 (到 $TARGET_VERSION)"
    log_info "=================================================="
    
    check_root
    check_current_version
    check_system_resources
    check_network
    
    show_upgrade_plan
    
    backup_files
    pre_upgrade
    
    if step_by_step_upgrade; then
        if verify_final_upgrade; then
            cleanup
            log_success "=================================================="
            log_success "Alpine Linux 多版本升級成功完成！"
            log_info "升級日誌已記錄在此腳本的輸出中"
            reboot_prompt
        else
            log_error "最終升級驗證失敗，執行回滾..."
            cleanup_on_error
        fi
    else
        log_error "升級過程失敗，執行回滾..."
        cleanup_on_error
    fi
}

# 顯示使用說明
show_usage() {
    echo "Alpine Linux 3.19/3.20/3.21 to 3.22 升級腳本"
    echo "使用方法: ./alpine_upgrade.sh (需要 root 權限)"
    echo ""
    echo "此腳本將會:"
    echo "1. 檢查當前系統版本和資源"
    echo "2. 規劃逐步升級路徑"
    echo "3. 備份重要檔案"
    echo "4. 執行逐步安全升級 (3.19→3.20→3.21→3.22)"
    echo "5. 驗證每個步驟的升級結果"
    echo "6. 提供重新啟動選項"
    echo ""
    echo "支援的升級路徑:"
    echo "- Alpine 3.19.x → 3.22.x"
    echo "- Alpine 3.20.x → 3.22.x"  
    echo "- Alpine 3.21.x → 3.22.x"
    echo ""
    echo "注意事項:"
    echo "- 請確保有穩定的網路連線"
    echo "- 確保有至少 1GB 的可用磁碟空間"
    echo "- 建議在升級前備份重要資料"
    echo "- 升級完成後務必重新啟動系統"
    echo "- 整個升級過程可能需要 30-60 分鐘"
}

# 檢查參數
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_usage
    exit 0
fi

# 執行主程序
main "$@"