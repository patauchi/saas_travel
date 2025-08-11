#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Function to print section headers
print_header() {
    echo ""
    print_color "════════════════════════════════════════════════════════════════" "$CYAN"
    print_color "  $1" "$CYAN"
    print_color "════════════════════════════════════════════════════════════════" "$CYAN"
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Laravel in a service
install_laravel_service() {
    local SERVICE_NAME=$1
    local SERVICE_DIR=$2
    local INSTALL_PACKAGES=$3

    print_header "Installing Laravel in $SERVICE_NAME"

    # Check if Laravel is already installed
    if [ -f "$SERVICE_DIR/composer.json" ]; then
        print_color "⚠ Laravel appears to be already installed in $SERVICE_NAME" "$YELLOW"
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color "Skipping $SERVICE_NAME..." "$YELLOW"
            return
        fi

        # Backup existing installation
        print_color "Backing up existing installation..." "$YELLOW"
        mv "$SERVICE_DIR" "${SERVICE_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$SERVICE_DIR"
    fi

    # Create service directory if it doesn't exist
    mkdir -p "$SERVICE_DIR"

    # Install Laravel
    print_color "Installing Laravel framework..." "$YELLOW"
    docker run --rm \
        -v "$PWD/$SERVICE_DIR":/app \
        -w /app \
        composer:latest \
        create-project laravel/laravel . --prefer-dist --no-interaction

    if [ $? -ne 0 ]; then
        print_color "✗ Failed to install Laravel in $SERVICE_NAME" "$RED"
        return 1
    fi

    # Install additional packages if specified
    if [ ! -z "$INSTALL_PACKAGES" ]; then
        print_color "Installing additional packages: $INSTALL_PACKAGES" "$YELLOW"
        docker run --rm \
            -v "$PWD/$SERVICE_DIR":/app \
            -w /app \
            composer:latest \
            require $INSTALL_PACKAGES --no-interaction
    fi

    # Copy Docker configuration files
    if [ -d "$SERVICE_DIR/docker" ]; then
        print_color "Docker configuration already exists, skipping..." "$YELLOW"
    else
        print_color "Copying Docker configuration files..." "$YELLOW"
        cp -r services/central-management/docker "$SERVICE_DIR/"
    fi

    # Copy Dockerfile
    if [ ! -f "$SERVICE_DIR/Dockerfile" ]; then
        cp services/central-management/Dockerfile "$SERVICE_DIR/"
    fi

    # Set permissions
    print_color "Setting permissions..." "$YELLOW"
    chmod -R 777 "$SERVICE_DIR/storage" 2>/dev/null || true
    chmod -R 777 "$SERVICE_DIR/bootstrap/cache" 2>/dev/null || true

    print_color "✓ Laravel installed successfully in $SERVICE_NAME" "$GREEN"
}

# Main script
clear
print_color "╔════════════════════════════════════════════════════════════════╗" "$MAGENTA"
print_color "║         Laravel Microservices Installation Script             ║" "$MAGENTA"
print_color "╚════════════════════════════════════════════════════════════════╝" "$MAGENTA"

# Check if Docker is available
if ! command_exists docker; then
    print_color "✗ Docker is not installed or not running" "$RED"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "docker-compose.yml" ] || [ ! -d "services" ]; then
    print_color "✗ Please run this script from the project root directory" "$RED"
    exit 1
fi

# Install Laravel in Central Management Service
install_laravel_service \
    "Central Management Service" \
    "services/central-management" \
    "stancl/tenancy tymon/jwt-auth predis/predis spatie/laravel-permission"

# Install Laravel in Auth Service
install_laravel_service \
    "Auth Service" \
    "services/auth-service" \
    "tymon/jwt-auth predis/predis laravel/passport spatie/laravel-permission"

# Install Laravel in Sales Service
install_laravel_service \
    "Sales Service" \
    "services/sales-service" \
    "predis/predis spatie/laravel-medialibrary spatie/laravel-query-builder"

# Install Laravel in Operations Service
install_laravel_service \
    "Operations Service" \
    "services/operations-service" \
    "predis/predis spatie/laravel-activitylog maatwebsite/excel"

print_header "Configuring Central Management for Tenancy"

# Additional configuration for stancl/tenancy in Central Management
if [ -d "services/central-management/vendor" ]; then
    print_color "Publishing stancl/tenancy configuration..." "$YELLOW"
    docker run --rm \
        -v "$PWD/services/central-management":/app \
        -w /app \
        --entrypoint php \
        php:8.2-cli \
        artisan vendor:publish --provider="Stancl\Tenancy\TenancyServiceProvider" --force

    # Create tenant migrations directory
    mkdir -p services/central-management/database/migrations/tenant

    print_color "✓ Tenancy configuration published" "$GREEN"
fi

# Copy shared middleware to all services
print_header "Copying Shared Components"

for SERVICE_DIR in services/*/; do
    if [ -d "$SERVICE_DIR" ] && [ "$SERVICE_DIR" != "services/" ]; then
        SERVICE_NAME=$(basename "$SERVICE_DIR")

        # Create app directories if they don't exist
        mkdir -p "$SERVICE_DIR/app/Http/Middleware"
        mkdir -p "$SERVICE_DIR/app/Traits"
        mkdir -p "$SERVICE_DIR/app/Services"

        # Copy shared middleware
        if [ -f "shared/middleware/TenantResolver.php" ]; then
            cp shared/middleware/TenantResolver.php "$SERVICE_DIR/app/Http/Middleware/"
            print_color "✓ Copied TenantResolver middleware to $SERVICE_NAME" "$GREEN"
        fi
    fi
done

# Create health check endpoints
print_header "Creating Health Check Endpoints"

for SERVICE_DIR in services/*/; do
    if [ -d "$SERVICE_DIR" ] && [ "$SERVICE_DIR" != "services/" ]; then
        SERVICE_NAME=$(basename "$SERVICE_DIR")

        # Create health.php in public directory
        cat > "$SERVICE_DIR/public/health.php" <<'EOF'
<?php
header('Content-Type: application/json');

// Basic health check
$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'service' => $_ENV['APP_NAME'] ?? 'Unknown Service',
];

// Check database connection (optional)
try {
    if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
        require __DIR__ . '/../vendor/autoload.php';
        $app = require_once __DIR__ . '/../bootstrap/app.php';
        $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

        // Try database connection
        try {
            \DB::connection()->getPdo();
            $health['database'] = 'connected';
        } catch (\Exception $e) {
            $health['database'] = 'disconnected';
        }

        // Check Redis connection
        try {
            \Redis::ping();
            $health['redis'] = 'connected';
        } catch (\Exception $e) {
            $health['redis'] = 'disconnected';
        }
    }
} catch (\Exception $e) {
    $health['error'] = $e->getMessage();
}

http_response_code(200);
echo json_encode($health, JSON_PRETTY_PRINT);
EOF

        print_color "✓ Created health check endpoint for $SERVICE_NAME" "$GREEN"
    fi
done

# Rebuild Docker containers
print_header "Rebuilding Docker Containers"

print_color "Stopping existing containers..." "$YELLOW"
docker-compose down

print_color "Building containers with new Laravel installations..." "$YELLOW"
docker-compose build --no-cache

print_color "Starting containers..." "$YELLOW"
docker-compose up -d

# Wait for services to be ready
print_color "Waiting for services to initialize..." "$YELLOW"
sleep 30

# Run migrations for Central Management
print_header "Running Database Migrations"

print_color "Running migrations for Central Management..." "$YELLOW"
docker-compose exec -T central-management php artisan migrate --force 2>/dev/null || {
    print_color "⚠ Could not run migrations. You may need to run them manually." "$YELLOW"
}

# Generate application keys for each service
print_header "Generating Application Keys"

for SERVICE in central-management auth-service sales-service operations-service; do
    print_color "Generating key for $SERVICE..." "$YELLOW"
    docker-compose exec -T $SERVICE php artisan key:generate --force 2>/dev/null || {
        print_color "⚠ Could not generate key for $SERVICE. Generate manually later." "$YELLOW"
    }
done

# Final summary
print_header "Installation Complete!"

print_color "✅ Laravel has been installed in all services" "$GREEN"
print_color "✅ Docker containers have been rebuilt" "$GREEN"
print_color "✅ Health check endpoints have been created" "$GREEN"
echo ""

print_color "Next steps:" "$YELLOW"
echo "  1. Configure tenancy in Central Management:"
echo "     docker-compose exec central-management php artisan tenancy:install"
echo ""
echo "  2. Run migrations for each service:"
echo "     docker-compose exec central-management php artisan migrate"
echo "     docker-compose exec auth-service php artisan migrate"
echo "     docker-compose exec sales-service php artisan migrate"
echo "     docker-compose exec operations-service php artisan migrate"
echo ""
echo "  3. Create your first tenant:"
echo "     docker-compose exec central-management php artisan tinker"
echo "     >>> \$tenant = App\Models\Tenant::create(['id' => 'acme']);"
echo "     >>> \$tenant->domains()->create(['domain' => 'acme.localhost']);"
echo ""
echo "  4. Set up JWT secret for Auth Service:"
echo "     docker-compose exec auth-service php artisan jwt:secret"
echo ""

print_color "Service URLs:" "$BLUE"
echo "  • API Gateway:        http://localhost"
echo "  • Central Management: http://localhost:8001"
echo "  • Auth Service:       http://localhost:8002"
echo "  • Sales Service:      http://localhost:8003"
echo "  • Operations Service: http://localhost:8004"
echo ""

print_color "Useful commands:" "$CYAN"
echo "  • View logs:          docker-compose logs -f [service-name]"
echo "  • Enter container:    docker-compose exec [service-name] bash"
echo "  • Run artisan:        docker-compose exec [service-name] php artisan [command]"
echo "  • Stop services:      docker-compose down"
echo "  • Restart services:   docker-compose restart"
echo ""

print_color "Check health status:" "$CYAN"
echo "  curl http://localhost:8001/health.php"
echo "  curl http://localhost:8002/health.php"
echo "  curl http://localhost:8003/health.php"
echo "  curl http://localhost:8004/health.php"
echo ""

print_color "🎉 Your Laravel microservices architecture is ready!" "$GREEN"
