# 伺服器管理腳本工具集 🧰

這是一系列專為伺服器管理設計的 Shell 腳本，提供自動化備份、日誌 AI 摘要、Discord 通知及系統維護等強大功能。

## ✨ 功能亮點

-   **自動化 Rsync 備份**：穩定可靠的檔案同步與備份機制。
-   **智慧日誌摘要**：整合 Ollama 或 OpenRouter，將繁瑣的日誌自動生成簡潔的中文摘要。
-   **即時狀態通知**：透過 Discord Webhook 即時掌握備份成功或失敗的狀態。
-   **高度模組化**：腳本彼此獨立，可單獨使用或組合以完成複雜的工作流。
-   **高彈性設定**：所有行為皆可透過 `.env` 檔案或命令列參數進行配置。

## 🚀 快速上手

所有腳本的行為都由一個中央設定檔 `.env` 控制。

1.  **一鍵下載並安裝**
    執行以下指令，它會自動下載所有腳本至 `scripts` 目錄，並建立設定檔範本。
    ```sh
    curl -sSL [https://raw.githubusercontent.com/tryweb/docker-compose/main/scripts/setup_scripts.sh](https://raw.githubusercontent.com/tryweb/docker-compose/main/scripts/setup_scripts.sh) | bash
    ```

2.  **編輯設定檔**
    使用您喜歡的編輯器打開 `scripts/.env` 檔案，根據您的環境（例如：檔案路徑、API 金鑰、Webhook 網址）修改變數。所有可用變數的說明都記錄在檔案內及下方的 [**詳細設定**](#-詳細設定-env) 章節。

---

## 📜 腳本功能一覽

### 1. `rsync_backup.sh`

這是執行 `rsync` 備份的核心腳本。它高度可配置，並整合了其他腳本來提供日誌記錄、AI 摘要和 Discord 通知功能。

-   **核心功能**：
    -   從來源路徑執行 `rsync` 備份至目標位置。
    -   透過鎖定檔 (`.lock`) 確保同一備份任務不會重複執行。
    -   為每次操作生成詳細的日誌，並自動清理舊日誌。
    -   整合 AI 摘要與 Discord 通知，打造完整自動化流程。
-   **使用方式**：
    腳本設計為透過命令列執行，`--source` 是唯一必要的參數，其餘設定建議在 `.env` 中配置。
    ```sh
    # 基本執行，所有設定依賴 .env
    ./scripts/rsync_backup.sh --source /path/to/your/data

    # 本次執行強制啟用 AI 摘要
    ./scripts/rsync_backup.sh --source /path/to/your/data --summarize

    # 本次執行覆寫頻寬限制為 5000 KB/s
    ./scripts/rsync_backup.sh --source /path/to/your/data --bwlimit 5000
    ```
-   **命令列參數**：
    所有命令列參數的優先級**高於** `.env` 檔案中的設定。

| 參數 | `.env` 變數 | 說明 |
| :--- | :--- | :--- |
| `--source <路徑>` | `SOURCE_DIR` | **[必要]** 要備份的來源目錄。 |
| `--dest-root <路徑>` | `DEST_ROOT` | 存放備份的根目錄。 |
| `--name <名稱>` | `NAME` | 備份任務名稱，用於日誌和鎖定檔。 |
| `--log-dir <路徑>` | `LOG_DIR` | 存放日誌的根目錄。 |
| `--retention-days <天數>`| `RETENTION_DAYS` | 日誌檔案的保留天數。 |
| `--bwlimit <KB/s>` | `BW_LIMIT` | `rsync` 的頻寬限制 (單位 KB/s)。 |
| `--exclude-file <路徑>`| `EXCLUDE_FILE` | 指定包含排除規則的檔案路徑。 |
| `--exclude <規則>` | `RSYNC_EXCLUDE_PATTERNS`| 單一排除規則，可重複使用。 |
| `--summarize` | `SUMMARIZE` | `true` 或 `false`，啟用 AI 摘要功能。 |
| `--ai-script <路徑>` | `AI_SCRIPT` | `ai_proc_log.sh` 腳本的路徑。 |
| `--grep-exclude <規則>`| `GREP_EXCLUDE_PATTERN`| AI 分析前，從日誌中過濾掉的內容。 |
| `--send-discord` | `SEND_DISCORD` | `true` 或 `false`，啟用 Discord 通知。 |
| `--discord-script <路徑>`| `DISCORD_SCRIPT` | `send_logs_to_discord.sh` 腳本的路徑。 |
| `--discord-webhook <網址>`| `DISCORD_WEBHOOK` | Discord Webhook 的網址。 |
| `--dry-run` | N/A | 模擬執行，不會對檔案做任何變更。 |

---

### 2. `ai_proc_log.sh`

此腳本讀取一個日誌檔，將其內容傳送至指定的 AI 服務（Ollama 或 OpenRouter），並將摘要結果輸出。

-   **核心功能**：
    -   連接 Ollama 或 OpenRouter API。
    -   提示 AI 以繁體中文分析並總結日誌內容。
-   **使用方式**：
    主要由 `rsync_backup.sh` 自動呼叫，也可獨立使用。
    ```sh
    # 使用 .env 中的設定來分析指定日誌檔
    bash ./scripts/ai_proc_log.sh LOG_FILE=/path/to/some.log
    ```

---

### 3. `send_logs_to_discord.sh`

此腳本能將指定檔案的內容，透過 Webhook 傳送到 Discord 頻道。

-   **核心功能**：
    -   自動將長訊息分割成多個區塊發送，以符合 Discord 的字數限制。
    -   可自訂訊息標題。
	-   可自訂訊息顏色條。(OK:綠色 ERR:紅色 預設灰色)
-   **使用方式**：
    ```sh
    bash ./scripts/send_logs_to_discord.sh \
      LOG_FILE=/path/to/message.txt \
      WEBHOOK_URL="[https://discord.com/api/webhooks/](https://discord.com/api/webhooks/)..." \
      TITLE="伺服器重要更新" \
	  MSGTYPE=OK
    ```

---

### 4. `alpine_upgrade.sh`

用於升級 Alpine Linux 系統的獨立工具腳本。

-   **核心功能**：
    -   安全地將 Alpine Linux 系統從 3.19 → 3.20 → 3.21 → 3.22 逐步升級到 3.22。
    -   執行多項前置檢查（root 權限、版本、磁碟空間、網路）。
    -   自動備份與還原軟體庫設定。
-   **使用方式**：
    **警告**：此腳本必須以 root 權限執行。
    ```sh
    # 登入您的 Alpine 主機並執行
    sudo ./scripts/alpine_upgrade.sh
    ```

---

## ⚙️ 核心工作流程：自動備份與 AI 摘要

整個自動化流程以 `rsync_backup.sh` 為核心進行調度。

1.  **觸發**：透過 `cron` 排程或手動執行 `rsync_backup.sh --source /data/important --summarize`。
2.  **備份與記錄**：腳本執行 `rsync` 備份，並產生一份僅包含統計資訊的簡潔日誌檔。
3.  **觸發通知**：備份結束後（無論成功或失敗），腳本會呼叫通知函式。
4.  **AI 摘要**：
    -   由於指定了 `--summarize`，腳本會先用 `grep` 過濾日誌。
    -   接著呼叫 `ai_proc_log.sh`，將過濾後的日誌傳給 AI 服務（如 Ollama）。
    -   AI 回傳摘要，並暫存於 `.summary` 檔案。
5.  **發送通知**：
    -   呼叫 `send_logs_to_discord.sh`，將摘要內容傳送出去。
    -   您會在 Discord 頻道收到一份簡潔、由 AI 生成的備份報告。
6.  **清理**：刪除過程中產生的所有暫存檔。



---

## 🔧 詳細設定 (`.env`)

以下是您可以在 `scripts/.env` 檔案中設定的所有變數詳解。

```bash
# ======================================================================
# AI 日誌處理器 (`ai_proc_log.sh`) 設定
# ======================================================================

# 使用的 AI 服務: "ollama" 或 "openrouter"
API_SERVICE="ollama"

# --- Ollama 設定 ---
OLLAMA_API_URL="http://localhost:11434/api/generate"
OLLAMA_MODEL="llama3"

# --- OpenRouter 設定 ---
# OPENROUTER_API_KEY="你的_OPENROUTER_API_金鑰"
# OPENROUTER_MODEL="openai/gpt-4o-mini"


# ======================================================================
# Rsync 備份 (`rsync_backup.sh`) 設定
# ======================================================================

# --- 基本備份設定 ---
# 備份來源目錄 (建議在命令列透過 --source 指定)
# SOURCE_DIR="/path/to/source"

# 備份儲存的根目錄
DEST_ROOT="/volumeUSB1/usbshare1-2/MyData"

# 備份任務名稱 (用於日誌與鎖定檔)
NAME="rsync_backup"

# rsync 頻寬限制 (單位 KB/s)
BW_LIMIT=10000

# --- 日誌設定 ---
# 日誌檔案的根目錄
LOG_DIR="/volume1/homes/rsynclog"

# 日誌保留天數
RETENTION_DAYS=7

# --- 檔案排除設定 ---
# 全域排除檔案的路徑 (每行一個規則)
#EXCLUDE_FILE="/volume1/homes/nonecopy"

# 以空格分隔的排除規則
# 範例: RSYNC_EXCLUDE_PATTERNS="#recycle .DS_Store 'some dir'"
RSYNC_EXCLUDE_PATTERNS="#recycle"


# ======================================================================
# Discord 通知 & AI 摘要設定
# ======================================================================

# --- Discord 通知 ---
# 是否啟用 Discord 通知 (true/false)
SEND_DISCORD=true

# `send_logs_to_discord.sh` 腳本的路徑
DISCORD_SCRIPT="/volume1/homes/send_logs_to_discord.sh"

# 你的 Discord Webhook 網址
DISCORD_WEBHOOK="[https://discord.com/api/webhooks/](https://discord.com/api/webhooks/)..."

# --- AI 摘要 ---
# 是否啟用 AI 摘要 (true/false)
SUMMARIZE=true

# `ai_proc_log.sh` 腳本的路徑
AI_SCRIPT="/home/jonathan/github/docker-compose/scripts/ai_proc_log.sh"

# 在進行摘要前，要從 Log 中排除的文字模式 (grep -v 的正則表達式)
GREP_EXCLUDE_PATTERN="[0-9]%"
