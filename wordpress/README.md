# WordPress Docker Compose Setup

This repository contains Docker Compose configuration for setting up WordPress with MySQL database.

## Prerequisites

- Docker
- Docker Compose

## Installation

1. Clone this repository
   ```bash
   git clone <repository-url>
   cd wordpress
   ```

2. Copy the environment file
   ```bash
   cp .env.example .env
   ```

3. Configure the environment variables in `.env`:
   - `WORDPRESS_PORT`: Port for WordPress site (default: 80)
   - `MYSQL_ROOT_PASSWORD`: MySQL root password
   - `MYSQL_PASSWORD`: WordPress database user password

4. Start the containers
   ```bash
   docker-compose up -d
   ```

## Configuration

### Environment Variables

#### WordPress Settings
- `WORDPRESS_PORT`: Port for WordPress site (default: 80)
- `WORDPRESS_IMAGE`: WordPress Docker image version

#### Database Settings
- `MYSQL_IMAGE`: MySQL version (default: 5.7)
- `MYSQL_ROOT_PASSWORD`: Root password for MySQL
- `MYSQL_DATABASE`: Database name for WordPress
- `MYSQL_USER`: Database user for WordPress
- `MYSQL_PASSWORD`: Database password for WordPress

#### Other Settings
- `WORDPRESS_DEBUG`: WordPress debug mode
- `WORDPRESS_CONFIG_EXTRA`: Additional WordPress configurations
- `TZ`: Timezone (default: Asia/Taipei)

#### Container Names
- `CONTAINER_DB`: MySQL container name
- `CONTAINER_WP`: WordPress container name

## Directory Structure

```
.
├── data/
│   ├── db/    # MySQL data
│   └── wp/    # WordPress files
├── .env.example
├── docker-compose.yml
└── README.md
```

## Usage

1. Access WordPress:
   ```
   http://localhost:<WORDPRESS_PORT>
   ```

2. Start containers:
   ```bash
   docker-compose up -d
   ```

3. Stop containers:
   ```bash
   docker-compose down
   ```

4. View logs:
   ```bash
   docker-compose logs -f
   ```

## Data Persistence and Backup

All data is stored in the `data` directory:

- `data/db`: MySQL database files
- `data/wp`: WordPress files and uploads

To backup your WordPress installation, you can copy or archive these directories. This ensures you have a complete backup of both your database and WordPress files.
