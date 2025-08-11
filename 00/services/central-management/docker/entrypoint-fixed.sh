#!/bin/sh
set -e

echo "========================================="
echo "Starting Central Management Service"
echo "========================================="

# Function to wait for a service
wait_for_service() {
    host="$1"
    port="$2"
    service_name="$3"

    echo "⏳ Waiting for $service_name at $host:$port..."
    until nc -z "$host" "$port" 2>/dev/null; do
        echo "   Waiting for $service_name to be ready..."
        sleep 2
    done
    echo "✅ $service_name is ready!"
}

# Wait for PostgreSQL Central
wait_for_service "postgres-central" "5432" "PostgreSQL Central"

# Wait for PostgreSQL Tenants
wait_for_service "postgres-tenants" "5432" "PostgreSQL Tenants"

# Wait for Redis
wait_for_service "redis" "6379" "Redis"

# Read passwords from secrets if available
if [ -f /run/secrets/postgres_password ]; then
    DB_PASSWORD=$(cat /run/secrets/postgres_password | tr -d '\n\r ')
    echo "🔐 Database password loaded from secret"
else
    DB_PASSWORD="${DB_PASSWORD:-yourpassword}"
    echo "⚠️  Using default database password"
fi

if [ -f /run/secrets/jwt_secret ]; then
    JWT_SECRET=$(cat /run/secrets/jwt_secret | tr -d '\n\r ')
    echo "🔐 JWT secret loaded from secret"
else
    JWT_SECRET="${JWT_SECRET:-YourJWTSecretKey}"
    echo "⚠️  Using default JWT secret"
fi

# Create or update .env file
echo "📝 Creating/updating .env file..."
cat > /var/www/html/.env <<EOF
APP_NAME="Central Management"
APP_ENV=${APP_ENV:-local}
APP_KEY=${APP_KEY:-base64:YourBase64EncodedKeyHere}
APP_DEBUG=${APP_DEBUG:-true}
APP_URL=${APP_URL:-http://localhost:8001}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

# Central database connection
DB_CONNECTION=central
DB_HOST=postgres-central
DB_PORT=5432
DB_DATABASE=central_management
DB_USERNAME=laravel_user
DB_PASSWORD=${DB_PASSWORD}

# Tenant database connection
TENANCY_DB_HOST=postgres-tenants
TENANCY_DB_PORT=5432
TENANCY_DB_DATABASE=postgres
TENANCY_DB_USERNAME=laravel_user
TENANCY_DB_PASSWORD=${DB_PASSWORD}

# Cache and session
BROADCAST_DRIVER=log
CACHE_DRIVER=${CACHE_DRIVER:-redis}
FILESYSTEM_DISK=local
QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}
SESSION_DRIVER=${SESSION_DRIVER:-redis}
SESSION_LIFETIME=120

# Redis
REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASSWORD:-OZehmQFsGbBgU9hAA7jojlzpL}
REDIS_PORT=6379

# Mail
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_TTL=60
JWT_REFRESH_TTL=20160
JWT_ALGO=HS256

# Service tokens for inter-service communication
SERVICE_TOKEN=${SERVICE_TOKEN:-your_service_token_here}
CENTRAL_MANAGEMENT_URL=http://central-management
AUTH_SERVICE_URL=http://auth-service
EOF

echo "✅ .env file created/updated"

# Create storage directories
echo "📁 Setting up storage directories..."
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/testing
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Set proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Check if vendor directory exists
if [ ! -d /var/www/html/vendor ]; then
    echo "📦 Installing composer dependencies..."
    cd /var/www/html
    composer install --no-dev --optimize-autoloader --no-interaction
else
    echo "✅ Vendor directory exists"
fi

# Generate application key if needed
if grep -q "YourBase64EncodedKeyHere" /var/www/html/.env; then
    echo "🔑 Generating application key..."
    cd /var/www/html
    php artisan key:generate --force
fi

# Update database configuration for central connection
echo "🔧 Configuring database connections..."
cd /var/www/html

# Create database configuration override
cat > /var/www/html/config/database_override.php <<'EOF'
<?php
return [
    'default' => 'central',
    'connections' => [
        'central' => [
            'driver' => 'pgsql',
            'host' => env('DB_HOST', 'postgres-central'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'central_management'),
            'username' => env('DB_USERNAME', 'laravel_user'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'schema' => 'public',
            'sslmode' => 'prefer',
        ],
        'pgsql' => [
            'driver' => 'pgsql',
            'host' => env('DB_HOST', 'postgres-central'),
            'port' => env('DB_PORT', '5432'),
            'database' => env('DB_DATABASE', 'central_management'),
            'username' => env('DB_USERNAME', 'laravel_user'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'schema' => 'public',
            'sslmode' => 'prefer',
        ],
        'pgsql_tenant' => [
            'driver' => 'pgsql',
            'host' => env('TENANCY_DB_HOST', 'postgres-tenants'),
            'port' => env('TENANCY_DB_PORT', '5432'),
            'database' => env('TENANCY_DB_DATABASE', 'postgres'),
            'username' => env('TENANCY_DB_USERNAME', 'laravel_user'),
            'password' => env('TENANCY_DB_PASSWORD', ''),
            'charset' => 'utf8',
            'prefix' => '',
            'prefix_indexes' => true,
            'schema' => 'public',
            'sslmode' => 'prefer',
        ],
    ],
];
EOF

# Clear caches (without database dependency)
echo "🧹 Clearing caches..."
rm -rf /var/www/html/storage/framework/cache/data/*
rm -rf /var/www/html/storage/framework/sessions/*
rm -rf /var/www/html/storage/framework/views/*
rm -rf /var/www/html/bootstrap/cache/*

# Test database connection
echo "🔌 Testing database connection..."
cd /var/www/html
php -r "
\$host = 'postgres-central';
\$port = '5432';
\$dbname = 'central_management';
\$user = 'laravel_user';
\$password = trim(file_get_contents('/run/secrets/postgres_password') ?: getenv('DB_PASSWORD'));

try {
    \$dsn = \"pgsql:host=\$host;port=\$port;dbname=\$dbname\";
    \$pdo = new PDO(\$dsn, \$user, \$password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    echo \"✅ Database connection successful\n\";
} catch (PDOException \$e) {
    echo \"❌ Database connection failed: \" . \$e->getMessage() . \"\n\";
    echo \"   DSN: \$dsn\n\";
    echo \"   User: \$user\n\";
    exit(1);
}
"

# Run migrations if in development
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then
    echo "🗄️  Running migrations..."
    cd /var/www/html

    # Check if migrations table exists
    php artisan migrate:status 2>/dev/null || php artisan migrate:install --force

    # Run migrations
    php artisan migrate --force || echo "⚠️  Migration failed or already run"

    # Check if stancl/tenancy is installed and configured
    if [ -f "vendor/stancl/tenancy/src/TenancyServiceProvider.php" ]; then
        echo "🏠 Setting up tenancy..."
        php artisan tenancy:install --force 2>/dev/null || echo "   Tenancy already installed"
    fi
fi

# Optimize for production
if [ "$APP_ENV" = "production" ]; then
    echo "⚡ Optimizing for production..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

echo "========================================="
echo "✨ Central Management Service is ready!"
echo "========================================="

# Start supervisord
echo "🚀 Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
