# WordPress Docker Compose Setup
# WordPress Docker Compose 安裝設定

This repository contains Docker Compose configuration for setting up WordPress with MySQL.
此專案包含使用 Docker Compose 建立 WordPress 和 MySQL 的設定。

## Prerequisites 先決條件

- Docker
- Docker Compose

## Installation 安裝步驟

1. Clone this repository
   ```bash
   git clone <repository-url>
   cd wordpress
   ```

2. Copy the environment file
   ```bash
   cp .env.example .env
   ```

3. Modify the .env file with your preferred settings
   主要修改 .env 檔案的設定值：
   - `WORDPRESS_PORT`: WordPress 網站埠號 (預設: 80)
   - `MYSQL_ROOT_PASSWORD`: MySQL root 密碼
   - `MYSQL_PASSWORD`: WordPress 資料庫使用者密碼

4. Start the containers
   ```bash
   docker-compose up -d
   ```

## Configuration 設定說明

### Environment Variables 環境變數

#### WordPress Settings WordPress 設定
- `WORDPRESS_PORT`: Port for WordPress site (default: 80)
- `WORDPRESS_IMAGE`: WordPress Docker image version

#### Database Settings 資料庫設定
- `MYSQL_IMAGE`: MySQL version (default: 5.7)
- `MYSQL_ROOT_PASSWORD`: Root password for MySQL
- `MYSQL_DATABASE`: Database name for WordPress
- `MYSQL_USER`: Database user for WordPress
- `MYSQL_PASSWORD`: Database password for WordPress

#### Other Settings 其他設定
- `WORDPRESS_DEBUG`: WordPress debug mode
- `WORDPRESS_CONFIG_EXTRA`: Additional WordPress configurations
- `TZ`: Timezone (default: Asia/Taipei)

#### Container Names 容器名稱
- `CONTAINER_DB`: MySQL container name
- `CONTAINER_WP`: WordPress container name

## Directory Structure 目錄結構

```
.
├── data/
│   ├── db/    # MySQL data
│   └── wp/    # WordPress files
├── .env.example
├── docker-compose.yml
└── README.md
```

## Usage 使用方式

1. Access WordPress:
   開啟 WordPress 網站：
   ```
   http://localhost:<WORDPRESS_PORT>
   ```

2. Start containers:
   啟動容器：
   ```bash
   docker-compose up -d
   ```

3. Stop containers:
   停止容器：
   ```bash
   docker-compose down
   ```

4. View logs:
   查看記錄：
   ```bash
   docker-compose logs -f
   ```

## Backup 備份方式

The WordPress files and MySQL data are stored in the `data` directory:
WordPress 檔案和 MySQL 資料都存放在 `data` 目錄：

- `data/db`: MySQL data 資料庫資料
- `data/wp`: WordPress files WordPress 檔案

You can backup these directories for data persistence.
您可以備份這些目錄來保存資料。
