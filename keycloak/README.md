# Keycloak Docker Compose Setup

This directory contains a Docker Compose configuration for running Keycloak with PostgreSQL database.

## Components

- **Keycloak**: Identity and Access Management solution
- **PostgreSQL**: Database backend for Keycloak

## Prerequisites

- Docker
- Docker Compose

## Configuration

The setup uses environment variables for configuration. These are stored in a `.env` file.

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Configure the environment variables in `.env`:

### PostgreSQL Settings
- `POSTGRES_DB`: Database name for Keycloak
- `POSTGRES_USER`: Database user for Keycloak
- `POSTGRES_PASSWORD`: Database password for Keycloak

### Keycloak Settings
- `KEYCLOAK_ADMIN`: Admin username for Keycloak
- `KEYCLOAK_ADMIN_PASSWORD`: Admin password for Keycloak

### Port Settings
- `KEYCLOAK_PORT`: Port for Keycloak service (default: 8080)

### Container Names
- `keycloak_postgres`: PostgreSQL container name
- `keycloak`: Keycloak container name

## Directory Structure

```
.
├── postgres_data/    # PostgreSQL data (auto-created)
├── .env             # Environment variables
├── .env.example     # Environment template
├── .gitignore       # Git ignore rules
├── docker-compose.yml
└── README.md
```

## Usage

### Starting the Services

```bash
docker-compose up -d
```

### Stopping the Services

```bash
docker-compose down
```

## Access

- Keycloak Admin Console: `http://localhost:8080`
- Default admin credentials:
  - Username: specified in `KEYCLOAK_ADMIN`
  - Password: specified in `KEYCLOAK_ADMIN_PASSWORD`

## Data Persistence and Backup

The setup maintains data persistence through the following:

- `postgres_data/`: Contains all PostgreSQL database files
  - Stores Keycloak configurations
  - User data
  - Realm settings
  - Client configurations

To backup your Keycloak installation:

1. Stop the services:
   ```bash
   docker-compose down
   ```

2. Backup the data directory:
   ```bash
   tar -czf keycloak_backup.tar.gz postgres_data/
   ```

3. Backup the environment configuration:
   ```bash
   cp .env env_backup
   ```

To restore from backup:

1. Stop the services if running
2. Replace the `postgres_data/` directory with the backup
3. Restore the `.env` file
4. Restart the services

## Security Notes

- The `.env` file contains sensitive information and is excluded from Git
- Always change the default passwords in production environments
- Review and adjust the security settings in Keycloak before going to production
