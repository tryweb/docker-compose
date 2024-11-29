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
   ```
   # PostgreSQL Configuration
   POSTGRES_DB=keycloak
   POSTGRES_USER=keycloak
   POSTGRES_PASSWORD=keycloak_password

   # Keycloak Configuration
   KEYCLOAK_ADMIN=admin
   KEYCLOAK_ADMIN_PASSWORD=admin

   # Port Configuration
   KEYCLOAK_PORT=8080
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

## Data Persistence

- PostgreSQL data is stored in `./postgres_data/`
- This directory is automatically created when the container starts
- The directory is excluded from Git via `.gitignore`

## Security Notes

- The `.env` file contains sensitive information and is excluded from Git
- Always change the default passwords in production environments
- Review and adjust the security settings in Keycloak before going to production
