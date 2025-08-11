#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directory if it doesn't exist
ensure_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_color "✓ Created directory: $1" "$GREEN"
    fi
}

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Header
print_color "╔════════════════════════════════════════════════════════════════╗" "$BLUE"
print_color "║     Laravel Microservices with stancl/tenancy Setup Script    ║" "$BLUE"
print_color "╚════════════════════════════════════════════════════════════════╝" "$BLUE"
echo ""

# Check prerequisites
print_color "Checking prerequisites..." "$YELLOW"

if ! command_exists docker; then
    print_color "✗ Docker is not installed. Please install Docker first." "$RED"
    exit 1
fi

if ! command_exists docker-compose; then
    print_color "✗ Docker Compose is not installed. Please install Docker Compose first." "$RED"
    exit 1
fi

print_color "✓ All prerequisites met" "$GREEN"
echo ""

# Create necessary directories
print_color "Creating project structure..." "$YELLOW"

ensure_directory "secrets"
ensure_directory "nginx/logs"
ensure_directory "nginx/ssl"
ensure_directory "scripts/postgres-init"
ensure_directory "backups"

# Generate secrets
print_color "Generating secrets..." "$YELLOW"

POSTGRES_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_password)
SERVICE_TOKEN=$(generate_password)
REDIS_PASSWORD=$(generate_password)

# Save secrets to files
echo "$POSTGRES_PASSWORD" > secrets/postgres_password.txt
echo "$JWT_SECRET" > secrets/jwt_secret.txt
echo "$SERVICE_TOKEN" > secrets/service_token.txt
echo "$REDIS_PASSWORD" > secrets/redis_password.txt

print_color "✓ Secrets generated and saved" "$GREEN"

# Create .env files for each service
print_color "Creating environment files..." "$YELLOW"

# Central Management .env
cat > services/central-management/.env <<EOF
APP_NAME="Central Management"
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost:8001

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=postgres-central
DB_PORT=5432
DB_DATABASE=central_management
DB_USERNAME=laravel_user

TENANCY_DB_HOST=postgres-tenants
TENANCY_DB_PORT=5432

BROADCAST_DRIVER=redis
CACHE_DRIVER=redis
FILESYSTEM_DRIVER=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=admin@saas.local
MAIL_FROM_NAME="\${APP_NAME}"

SERVICE_TOKEN=$SERVICE_TOKEN
EOF

# Auth Service .env
cat > services/auth-service/.env <<EOF
APP_NAME="Auth Service"
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost:8002

LOG_CHANNEL=stack
LOG_LEVEL=debug

CENTRAL_MANAGEMENT_URL=http://central-management

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

JWT_SECRET=$JWT_SECRET
JWT_TTL=60
JWT_REFRESH_TTL=20160
JWT_BLACKLIST_ENABLED=true

SERVICE_TOKEN=$SERVICE_TOKEN
EOF

# Sales Service .env
cat > services/sales-service/.env <<EOF
APP_NAME="Sales Service"
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost:8003

LOG_CHANNEL=stack
LOG_LEVEL=debug

CENTRAL_MANAGEMENT_URL=http://central-management
AUTH_SERVICE_URL=http://auth-service

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

SERVICE_TOKEN=$SERVICE_TOKEN
EOF

# Operations Service .env
cat > services/operations-service/.env <<EOF
APP_NAME="Operations Service"
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost:8004

LOG_CHANNEL=stack
LOG_LEVEL=debug

CENTRAL_MANAGEMENT_URL=http://central-management
AUTH_SERVICE_URL=http://auth-service

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

SERVICE_TOKEN=$SERVICE_TOKEN
EOF

print_color "✓ Environment files created" "$GREEN"

# Update docker-compose.yml with the correct Redis password
sed -i.bak "s/yourredispassword/$REDIS_PASSWORD/g" docker-compose.yml
rm docker-compose.yml.bak

# Create PostgreSQL initialization script
print_color "Creating PostgreSQL initialization script..." "$YELLOW"

cat > scripts/postgres-init/01-create-databases.sql <<EOF
-- Create template database for tenants
CREATE DATABASE template_tenant;

-- Connect to template database
\c template_tenant;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE template_tenant TO laravel_user;
GRANT ALL PRIVILEGES ON DATABASE central_management TO laravel_user;

-- Ensure laravel_user can create databases (for tenant creation)
ALTER USER laravel_user CREATEDB;
EOF

print_color "✓ PostgreSQL initialization script created" "$GREEN"

# Create backup script
print_color "Creating backup script..." "$YELLOW"

cat > scripts/backup-tenants.sh <<'EOF'
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
EOF

chmod +x scripts/backup-tenants.sh
print_color "✓ Backup script created" "$GREEN"

# Build and start containers
print_color "Building Docker containers..." "$YELLOW"
docker-compose build --no-cache

print_color "Starting Docker containers..." "$YELLOW"
docker-compose up -d

# Wait for services to be ready
print_color "Waiting for services to be ready..." "$YELLOW"
sleep 30

# Check service health
print_color "Checking service health..." "$YELLOW"

check_service() {
    SERVICE_NAME=$1
    PORT=$2

    if curl -f http://localhost:$PORT/health >/dev/null 2>&1; then
        print_color "✓ $SERVICE_NAME is healthy" "$GREEN"
    else
        print_color "✗ $SERVICE_NAME is not responding" "$RED"
    fi
}

check_service "API Gateway" 80
check_service "Central Management" 8001
check_service "Auth Service" 8002
check_service "Sales Service" 8003
check_service "Operations Service" 8004

# Display summary
echo ""
print_color "╔════════════════════════════════════════════════════════════════╗" "$GREEN"
print_color "║                    Setup Complete! 🎉                         ║" "$GREEN"
print_color "╚════════════════════════════════════════════════════════════════╝" "$GREEN"
echo ""
print_color "Services are running at:" "$BLUE"
echo "  • API Gateway:        http://localhost"
echo "  • Central Management: http://localhost:8001"
echo "  • Auth Service:       http://localhost:8002"
echo "  • Sales Service:      http://localhost:8003"
echo "  • Operations Service: http://localhost:8004"
echo "  • Mailhog:           http://localhost:8025"
echo "  • Redis Commander:    http://localhost:8081 (if enabled)"
echo ""
print_color "Database connections:" "$BLUE"
echo "  • Central PostgreSQL: localhost:5432"
echo "  • Tenants PostgreSQL: localhost:5433"
echo "  • Redis:             localhost:6379"
echo ""
print_color "Credentials saved in:" "$BLUE"
echo "  • secrets/postgres_password.txt"
echo "  • secrets/jwt_secret.txt"
echo "  • secrets/service_token.txt"
echo "  • secrets/redis_password.txt"
echo ""
print_color "Next steps:" "$YELLOW"
echo "  1. Install Laravel in each service directory:"
echo "     cd services/central-management && composer create-project laravel/laravel . --prefer-dist"
echo ""
echo "  2. Install stancl/tenancy in central-management:"
echo "     cd services/central-management && composer require stancl/tenancy"
echo ""
echo "  3. Create your first tenant:"
echo '     curl -X POST http://localhost/api/tenants \'
echo '       -H "Content-Type: application/json" \'
echo '       -H "X-Service-Token: '$SERVICE_TOKEN'" \'
echo '       -d "{"name": "Acme Corp", "email": "admin@acme.com", "domain": "acme.localhost"}"'
echo ""
print_color "For production deployment:" "$YELLOW"
echo "  • Update secrets with strong passwords"
echo "  • Configure SSL certificates"
echo "  • Set up monitoring and logging"
echo "  • Configure backup automation"
echo "  • Review security settings"
echo ""
print_color "Documentation:" "$BLUE"
echo "  • View logs: docker-compose logs -f [service-name]"
echo "  • Stop services: docker-compose down"
echo "  • Restart services: docker-compose restart"
echo "  • Backup databases: ./scripts/backup-tenants.sh"
echo ""
