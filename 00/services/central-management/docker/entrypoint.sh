#!/bin/sh
set -e

echo "Starting entrypoint script..."

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
if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
    wait_for_service "$DB_HOST" "$DB_PORT" "PostgreSQL Central"
fi

# Wait for Redis
if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ]; then
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis"
fi

# Create .env file if it doesn't exist
if [ ! -f /var/www/html/.env ]; then
    echo "Creating .env file from environment variables..."

    # Read password from secret file if available
    if [ -f /run/secrets/postgres_password ]; then
        export DB_PASSWORD=$(cat /run/secrets/postgres_password | tr -d '\n')
    else
        echo "Warning: postgres_password secret file not found, using default"
        export DB_PASSWORD="yourpassword"
    fi

    if [ -f /run/secrets/jwt_secret ]; then
        export JWT_SECRET=$(cat /run/secrets/jwt_secret | tr -d '\n')
    else
        echo "Warning: jwt_secret file not found, using default"
        export JWT_SECRET="YourJWTSecretKey"
    fi

    cat > /var/www/html/.env <<EOF
APP_NAME=CentralManagement
APP_ENV=${APP_ENV:-local}
APP_KEY=${APP_KEY:-base64:YourBase64EncodedKeyHere}
APP_DEBUG=${APP_DEBUG:-true}
APP_URL=${APP_URL:-http://localhost:8001}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=${DB_CONNECTION:-pgsql}
DB_HOST=${DB_HOST:-postgres-central}
DB_PORT=${DB_PORT:-5432}
DB_DATABASE=${DB_DATABASE:-central_management}
DB_USERNAME=${DB_USERNAME:-laravel_user}
DB_PASSWORD=${DB_PASSWORD:-yourpassword}

TENANCY_DB_HOST=${TENANCY_DB_HOST:-postgres-tenants}
TENANCY_DB_PORT=${TENANCY_DB_PORT:-5432}
TENANCY_DB_USERNAME=${DB_USERNAME:-laravel_user}
TENANCY_DB_PASSWORD=${DB_PASSWORD:-yourpassword}

BROADCAST_DRIVER=log
CACHE_DRIVER=${CACHE_DRIVER:-redis}
FILESYSTEM_DISK=local
QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}
SESSION_DRIVER=${SESSION_DRIVER:-redis}
SESSION_LIFETIME=120

REDIS_HOST=${REDIS_HOST:-redis}
REDIS_PASSWORD=${REDIS_PASSWORD:-null}
REDIS_PORT=${REDIS_PORT:-6379}

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"

JWT_SECRET=${JWT_SECRET:-YourJWTSecretKey}
EOF

    echo ".env file created successfully"
else
    echo ".env file already exists, updating database password from secrets..."
    # Update the password in existing .env file if secret exists
    if [ -f /run/secrets/postgres_password ]; then
        DB_PASSWORD=$(cat /run/secrets/postgres_password | tr -d '\n')
        # Update DB_PASSWORD in .env if it exists
        if grep -q "^DB_PASSWORD=" /var/www/html/.env; then
            sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" /var/www/html/.env
        else
            echo "DB_PASSWORD=${DB_PASSWORD}" >> /var/www/html/.env
        fi
    fi
fi

# Check if vendor directory exists
if [ ! -d /var/www/html/vendor ]; then
    echo "Installing composer dependencies..."
    cd /var/www/html
    composer install --no-dev --optimize-autoloader --no-interaction
else
    echo "Vendor directory exists, skipping composer install"
fi

# Generate application key if needed
if grep -q "base64:YourBase64EncodedKeyHere" /var/www/html/.env; then
    echo "Generating application key..."
    cd /var/www/html
    php artisan key:generate --force
fi

# Clear and optimize caches
echo "Clearing caches..."
cd /var/www/html
php artisan config:clear
php artisan cache:clear
php artisan view:clear

# Create storage directories if they don't exist
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

# Run migrations if in development
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    echo "Running migrations..."
    cd /var/www/html
    php artisan migrate --force || echo "Migration failed or already run"
fi

# Start supervisord
echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
