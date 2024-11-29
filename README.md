# Docker Compose Collection

This repository contains a collection of Docker Compose configurations for various applications.

## Available Services

### Keycloak

Identity and Access Management solution with PostgreSQL database.

[View Keycloak Setup](keycloak/README.md)

Features:
- Keycloak server with PostgreSQL backend
- Environment-based configuration
- Data persistence
- Detailed backup procedures

### WordPress

WordPress CMS with MySQL database.

[View WordPress Setup](wordpress/README.md)

Features:
- WordPress with MySQL backend
- Environment-based configuration
- Data persistence for both WordPress and MySQL
- Detailed backup procedures

## Directory Structure

```
.
├── keycloak/           # Keycloak with PostgreSQL
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
