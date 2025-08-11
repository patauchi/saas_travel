#!/bin/sh
set -e

echo "Starting simplified entrypoint script..."

# Function to wait for a service
wait_for_service() {
    host="$1"
    port="$2"
    service_name="$3"

    echo "Waiting for $service_name at $host:$port..."
    while ! nc -z "$host" "$port"; do
        echo "Waiting for $service_name to be ready..."
        sleep 2
    done
    echo "$service_name is ready!"
}

# Wait for PostgreSQL
wait_for_service "postgres-central" "5432" "PostgreSQL Central"

# Wait for Redis
wait_for_service "redis" "6379" "Redis"

# Read password from secret file
if [ -f /run/secrets/postgres_password ]; then
    DB_PASSWORD=$(cat /run/secrets/postgres_password | tr -d '\n\r')
    echo "Database password loaded from secret"
else
    DB_PASSWORD="yourpassword"
    echo "Warning: Using default database password"
fi

# Create .env file
echo "Creating .env file..."
cat > /var/www/html/.env <<EOF
APP_NAME=CentralManagement
APP_ENV=local
APP_KEY=base64:YourBase64EncodedKeyHere
APP_DEBUG=true
APP_URL=http://localhost:8001

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=postgres-central
DB_PORT=5432
DB_DATABASE=central_management
DB_USERNAME=laravel_user
DB_PASSWORD=${DB_PASSWORD}

TENANCY_DB_HOST=postgres-tenants
TENANCY_DB_PORT=5432
TENANCY_DB_USERNAME=laravel_user
TENANCY_DB_PASSWORD=${DB_PASSWORD}

CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

REDIS_HOST=redis
REDIS_PASSWORD=OZehmQFsGbBgU9hAA7jojlzpL
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"
EOF

echo ".env file created"

# Check if vendor directory exists
if [ ! -d /var/www/html/vendor ]; then
    echo "Installing composer dependencies..."
    cd /var/www/html
    composer install --no-dev --optimize-autoloader --no-interaction
else
    echo "Vendor directory exists"
fi

# Generate application key if needed
if grep -q "YourBase64EncodedKeyHere" /var/www/html/.env; then
    echo "Generating application key..."
    cd /var/www/html
    php artisan key:generate --force
fi

# Create storage directories
echo "Setting up storage directories..."
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Clear caches without database connection
echo "Clearing caches (filesystem only)..."
cd /var/www/html
rm -rf storage/framework/cache/*
rm -rf storage/framework/sessions/*
rm -rf storage/framework/views/*
rm -rf bootstrap/cache/*

echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
