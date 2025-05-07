# Docker Compose Collection

This repository contains a collection of Docker Compose configurations for various applications.

## Available Services

### Keycloak

Identity and Access Management solution with PostgreSQL database.

- Wiki - https://www.ichiayi.com/tech/keycloak
- [View Keycloak Setup](keycloak/README.md)

Features:
- Keycloak server with PostgreSQL backend
- Environment-based configuration
- Data persistence
- Detailed backup procedures

### WordPress

WordPress CMS with MySQL database.

- Wiki - https://www.ichiayi.com/tech/wordpress_docker
- [View WordPress Setup](wordpress/README.md)

Features:
- WordPress with MySQL backend
- Environment-based configuration
- Data persistence for both WordPress and MySQL
- Detailed backup procedures

### Cloudflare Tunnel
Secure tunnel proxy service for exposing local services through Cloudflare.

- Wiki - https://www.ichiayi.com/tech/cloudflare_tunnel

Features:
- Cloudflared tunnel client configuration
- Environment variable management
- Automatic TLS certificate handling

### DokuWiki
Lightweight wiki platform with PHP backend.

- Wiki - https://www.ichiayi.com/tech/dokuwiki

Features:
- PHP-FPM with Nginx reverse proxy
- Custom initialization scripts
- Persistent data volume for wiki content
- MySQLi extension support

### GitLab CE
Self-hosted Git repository management system.

- Wiki - https://www.ichiayi.com/tech/gitlabtips

Features:
- Integrated CI/CD pipelines
- Cloudflare Tunnel configuration template
- PostgreSQL and Redis backends

### Immich
Self-hosted photo backup solution.

- Wiki - https://www.ichiayi.com/tech/immich

Features:
- Microservices architecture (API, worker, ML)
- PostgreSQL and Redis dependencies
- Machine learning image analysis

### LibreNMS
Network monitoring and management system.

- Wiki - https://www.ichiayi.com/tech/k8s_librenms

Features:
- SMART disk monitoring integration
- Custom health check scripts
- SNMP-based device discovery

### Mailpit
Email testing tool with web interface.

- Wiki - https://www.ichiayi.com/tech/mailpit

Features:
- SMTP server with TLS support (port 1025)
- Web-based email viewing interface (port 8025)
- TLS/STARTTLS configuration options
- Traditional Chinese (zh_TW) interface
- Auto-refresh functionality
- SSL certificates management

### OpenVAS
Comprehensive vulnerability assessment system.

- Wiki - https://www.ichiayi.com/tech/openvas

Features:
- Greenbone Community Edition microservices architecture
- Vulnerability testing database
- PostgreSQL and Redis backends
- Modular scanning components
- Email notification integration
- Web interface for scan management
- Regular updates via script

### OwnTracks
Personal location tracking system.

- Wiki - https://www.ichiayi.com/tech/owntrack

Features:
- Recorder service for storing location data
- Web frontend for visualization
- Authentication system
- Data persistence
- Includes rec2gpx converter tool
- REST API support

### Rclone
Cloud storage synchronization tool.

- Wiki - https://www.ichiayi.com/tech/rclone_docker

Features:
- Web UI for configuration and management
- Scheduled synchronization via cron jobs
- Discord webhook notifications
- Configuration persistence
- Timezone configuration support
- Multiple cloud service provider support

### Syslog-ng
Centralized logging system for collecting and processing logs.

- Wiki - https://www.ichiayi.com/tech/logsrv_docker

Features:
- Flexible log collection from multiple sources (TCP/UDP)
- Advanced log filtering and routing capabilities
- Custom configuration file with SCL support
- Per-host log organization with automatic directory creation
- Log rotation with 90-day retention policy
- Multiple protocol support (UDP/514, TCP/601, TLS/6514)
- Customizable timestamp and message formatting
- Support for various log formats and protocols

## Directory Structure

```
.
├── cloudflared/        # Cloudflare Tunnel client
├── dokuwiki/           # DokuWiki with Nginx
├── gitlab/             # GitLab CE with CI/CD
├── immich/             # Photo backup system
├── keycloak/           # Keycloak with PostgreSQL
├── librenms/           # Server and Network monitoring
├── mailpit/            # Email testing tool
├── openvas/            # Server Vulnerability scanner
├── owntracks/          # Location tracking system
├── rclone/             # Cloud storage sync
├── scripts/            # Utility scripts
│   └── send_logs_to_discord.sh  # Discord log notification script
├── syslog-ng/          # Centralized logging system
├── wordpress/          # WordPress with MySQL
└── README.md
```

## Usage

Each service has its own directory with a complete setup including:
- docker-compose.yml
- Environment configuration (.env.example)
- Documentation (README.md)
- Data persistence configuration
- Git ignore rules

To use any service:

1. Navigate to the service directory:
   ```bash
   cd <service-directory>
   ```

2. Follow the service-specific README for:
   - Configuration
   - Installation
   - Usage instructions
   - Backup procedures

## Requirements

- Docker
- Docker Compose

## Security Notes

- Each service uses `.env` files for configuration
- Sensitive files and data directories are excluded via `.gitignore`
- Default credentials should be changed before deployment
- Review security settings before production use

## Scripts

### send_logs_to_discord.sh

A utility script for sending log messages to Discord channels via webhooks.

Features:
- Sends formatted log messages to Discord
- Supports custom titles and message content
- Can be integrated with any service for notification purposes
- Useful for monitoring and alerts

## Contribution

To contribute to this repository:

1. Fork the repository
2. Create a new branch for your feature or fix
3. Add or update the service configuration
4. Include or update README documentation
5. Submit a pull request

Please ensure that new services follow the same structure as existing ones, including:
- docker-compose.yml with proper container configurations
- .env.example for configuration templates
- Documentation with setup and usage instructions
