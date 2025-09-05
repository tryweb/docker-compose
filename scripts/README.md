# Scripts Documentation

This directory contains a collection of shell scripts designed for server administration, including automated backups with AI-powered log summarization, Discord notifications, and system maintenance.

## Table of Contents

- [Quick Start & Setup](#quick-start--setup)
- [Scripts Overview](#scripts-overview)
  - [1. rsync_backup.sh](#1-rsync_backupsh)
  - [2. ai_proc_log.sh](#2-ai_proc_logsh)
  - [3. send_logs_to_discord.sh](#3-send_logs_to_discordsh)
  - [4. alpine_upgrade.sh](#4-alpine_upgradesh)
- [Core Workflow: Automated Backup with AI Summary](#core-workflow-automated-backup-with-ai-summary)
- [Configuration (`.env` file)](#configuration-env-file)

---

## Quick Start & Setup

The behavior of these scripts is primarily controlled by a central `.env` file.

1.  **Create `.env` file**: Copy the example file to create your own configuration file.
    ```sh
    cp scripts/.env.example scripts/.env
    ```

2.  **Edit `.env` file**: Open `scripts/.env` with a text editor and modify the variables according to your environment (e.g., file paths, API keys, webhook URLs). All available variables are documented in the `.env.example` file and in the [Configuration](#configuration-env-file) section below.

---

## Scripts Overview

### 1. rsync_backup.sh

This is the main orchestration script for performing `rsync` backups. It is highly configurable and integrates the other scripts to provide logging, AI summarization, and Discord notifications.

#### Purpose

-   Performs `rsync` backups from a source to a destination.
-   Ensures only one instance of a backup job for a specific source runs at a time using a lock file.
-   Generates detailed logs for each backup operation.
-   Automatically rotates and deletes old logs.
-   Can filter logs, generate an AI summary, and send the result to Discord.

#### Usage

The script is designed to be run from the command line, with most settings configured in the `.env` file. The only required parameter is `--source`.

```sh
# Basic execution, relies on .env for all settings
./scripts/rsync_backup.sh --source /path/to/your/data

# Enable AI summarization for this specific run
./scripts/rsync_backup.sh --source /path/to/your/data --summarize

# Override the bandwidth limit for this run
./scripts/rsync_backup.sh --source /path/to/your/data --bwlimit 5000
```

#### Parameters

All parameters can be set via command-line flags, which will override any settings in the `.env` file.

| CLI Flag | `.env` Variable | Description |
| :--- | :--- | :--- |
| `--source <path>` | `SOURCE_DIR` | **Required.** The source directory to back up. |
| `--dest-root <path>` | `DEST_ROOT` | The root directory where backups will be stored. |
| `--name <name>` | `NAME` | The name of the backup job, used in log file names. |
| `--log-dir <path>` | `LOG_DIR` | The root directory for storing log files. |
| `--retention-days <N>`| `RETENTION_DAYS` | How many days to keep log files. |
| `--bwlimit <KB/s>` | `BW_LIMIT` | Bandwidth limit for rsync in KB/s. |
| `--exclude-file <path>`| `EXCLUDE_FILE` | Path to a file containing rsync exclude patterns. |
| `--exclude <pattern>` | `RSYNC_EXCLUDE_PATTERNS`| A single exclude pattern. Can be used multiple times. |
| `--summarize` | `SUMMARIZE` | `true` or `false`. Enables the AI summarization feature. |
| `--ai-script <path>` | `AI_SCRIPT` | Path to the `ai_proc_log.sh` script. |
| `--grep-exclude <pat>`| `GREP_EXCLUDE_PATTERN`| A pattern to filter out from the log before AI analysis. |
| `--send-discord` | `SEND_DISCORD` | `true` or `false`. Enables Discord notifications. |
| `--discord-script <path>`| `DISCORD_SCRIPT` | Path to the `send_logs_to_discord.sh` script. |
| `--discord-webhook <url>`| `DISCORD_WEBHOOK` | The Discord webhook URL. |
| `--dry-run` | N/A | Perform a trial run with no changes made. |

---

### 2. ai_proc_log.sh

This script takes a log file, sends its content to a specified AI service (Ollama or OpenRouter), and prints the resulting summary to standard output.

#### Purpose

-   Connects to Ollama or OpenRouter APIs.
-   Prompts the AI to analyze and summarize log content in Traditional Chinese.
-   Measures and reports the API call duration to standard error.

#### Usage

This script is primarily called by `rsync_backup.sh`, but can be used independently.

```sh
# Analyze a log file using settings from .env
bash ./scripts/ai_proc_log.sh LOG_FILE=/path/to/some.log
```

---

### 3. send_logs_to_discord.sh

This script sends the content of a given file to a Discord webhook.

#### Purpose

-   Reads a file and sends its content to Discord.
-   Automatically splits long messages into multiple chunks to respect Discord's character limit.
-   Allows setting a title for the message.

#### Usage

```sh
bash ./scripts/send_logs_to_discord.sh \
  LOG_FILE=/path/to/message.txt \
  WEBHOOK_URL="https://discord.com/api/webhooks/..." \
  TITLE="Important Update"
```

---

### 4. alpine_upgrade.sh

A standalone utility script for upgrading Alpine Linux systems.

#### Purpose

-   Safely upgrades an Alpine Linux system from version 3.21 to 3.22.
-   Performs pre-flight checks (root user, version, disk space, network).
-   Backs up and restores repository files.
-   Provides interactive prompts for rebooting after the upgrade.

#### Usage

**Important**: This script must be run with root privileges.

```sh
# Connect to your Alpine machine and run:
sudo ./scripts/alpine_upgrade.sh
```

---

## Core Workflow: Automated Backup with AI Summary

The primary workflow involves using `rsync_backup.sh` to orchestrate the entire process.

1.  **Execution**: A `cron` job or manual execution runs `rsync_backup.sh --source /data/important --summarize`.
2.  **Backup**: The script performs the `rsync` backup, creating a log file (e.g., `/logs/important/rsync_backup_important_...log`). The log contains summary stats instead of a verbose file list.
3.  **Notification Trigger**: At the end of the script (success or failure), the `send_discord_notification` function is called.
4.  **Summarization**:
    -   Because `--summarize` was used, the function first calls `grep` to filter the log.
    -   It then calls `ai_proc_log.sh`, passing the filtered log.
    -   `ai_proc_log.sh` sends the log to your configured AI (e.g., Ollama) and gets a summary back.
    -   The summary is saved to a temporary file (e.g., `...log.summary`).
5.  **Delivery**:
    -   `send_logs_to_discord.sh` is called with the path to the summary file.
    -   The script sends the concise, AI-generated summary to your Discord channel.
6.  **Cleanup**: All temporary files (`.filtered`, `.summary`) are deleted.

---

## Configuration (`.env` file)

Below is a detailed explanation of all variables you can set in your `scripts/.env` file.

```bash
# ----------------------------------------------------------------------
# AI Log Processor (@scripts/ai_proc_log.sh) Settings
# ----------------------------------------------------------------------

# AI service to use: "ollama" or "openrouter"
API_SERVICE="ollama"

# --- Ollama Settings ---
OLLAMA_API_URL="http://localhost:11434/api/generate"
OLLAMA_MODEL="llama3"

# --- OpenRouter Settings ---
# OPENROUTER_API_KEY="YOUR_OPENROUTER_API_KEY"
# OPENROUTER_MODEL="openai/gpt-4o-mini"


# ----------------------------------------------------------------------
# Rsync Backup (@scripts/rsync_backup.sh) Settings
# ----------------------------------------------------------------------

# --- Basic Backup Settings ---
# Required. Source directory for the backup.
# It's recommended to set this via the --source flag for clarity.
# SOURCE_DIR="/path/to/source"

# Root directory for storing backups.
DEST_ROOT="/volumeUSB1/usbshare1-2/TP-Data-Server"

# Name for the backup job (used in log and lock file names).
NAME="rsync_backup"

# rsync bandwidth limit in KB/s.
BW_LIMIT=10000

# --- Log Settings ---
# Root directory for log files.
LOG_DIR="/volume1/homes/tprsynclog"

# Number of days to keep log files.
RETENTION_DAYS=7

# --- File Exclusion Settings ---
# Path to a global file with rsync exclude patterns (one per line).
EXCLUDE_FILE="/volume1/homes/nonecopy"

# Space-separated list of exclude patterns.
# Example: RSYNC_EXCLUDE_PATTERNS="#recycle .DS_Store 'some dir'"
RSYNC_EXCLUDE_PATTERNS="#recycle"


# ----------------------------------------------------------------------
# Discord Notification & AI Summary Settings
# ----------------------------------------------------------------------

# --- Discord Notifications ---
# Enable/disable Discord notifications (true/false).
SEND_DISCORD=true

# Path to the send_logs_to_discord.sh script.
DISCORD_SCRIPT="/volume1/homes/send_logs_to_discord.sh"

# Your Discord Webhook URL.
DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."

# --- AI Summarization ---
# Enable/disable AI summarization (true/false).
SUMMARIZE=true

# Path to the ai_proc_log.sh script.
AI_SCRIPT="/home/jonathan/github/docker-compose/scripts/ai_proc_log.sh"

# Regex pattern for grep -v to filter logs before AI analysis.
GREP_EXCLUDE_PATTERN="sending incremental file list"
