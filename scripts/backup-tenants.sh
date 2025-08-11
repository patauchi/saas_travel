#!/bin/bash

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting backup process...${NC}"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Backup central database
echo "Backing up central management database..."
docker exec postgres-central pg_dump -U laravel_user central_management > "$BACKUP_DIR/central_${DATE}.sql"

# Get list of tenant databases
TENANT_DBS=$(docker exec postgres-tenants psql -U laravel_user -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'tenant_%';")

# Backup each tenant database
for DB in $TENANT_DBS; do
    DB=$(echo $DB | xargs) # Trim whitespace
    if [ ! -z "$DB" ]; then
        echo "Backing up tenant database: $DB"
        docker exec postgres-tenants pg_dump -U laravel_user $DB > "$BACKUP_DIR/${DB}_${DATE}.sql"
    fi
done

# Compress backups
echo "Compressing backups..."
tar -czf "$BACKUP_DIR/backup_${DATE}.tar.gz" -C "$BACKUP_DIR" --exclude="*.tar.gz" .
rm "$BACKUP_DIR"/*.sql

echo -e "${GREEN}Backup completed: $BACKUP_DIR/backup_${DATE}.tar.gz${NC}"
