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

# Check if composer is installed
check_composer() {
    if command -v composer >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Install Laravel in a service directory preserving Docker files
install_laravel_in_service() {
    local SERVICE_NAME=$1
    local SERVICE_PATH=$2
    local PACKAGES=$3

    print_header "Installing Laravel in $SERVICE_NAME"

    # Check if we're in the right directory
    if [ ! -d "$SERVICE_PATH" ]; then
        print_color "✗ Directory $SERVICE_PATH does not exist" "$RED"
        return 1
    fi

    cd "$SERVICE_PATH"

    # Save Docker files if they exist
    print_color "Preserving Docker configuration files..." "$YELLOW"

    TEMP_DIR=$(mktemp -d)

    # List of files/directories to preserve
    PRESERVE_ITEMS=(
        "Dockerfile"
        "docker"
        ".dockerignore"
        "docker-compose.yml"
        "docker-compose.override.yml"
    )

    # Copy files to preserve
    for item in "${PRESERVE_ITEMS[@]}"; do
        if [ -e "$item" ]; then
            cp -r "$item" "$TEMP_DIR/"
            print_color "  • Preserved: $item" "$GREEN"
        fi
    done

    # Check if Laravel is already installed
    if [ -f "composer.json" ]; then
        print_color "⚠ Laravel appears to be already installed in $SERVICE_NAME" "$YELLOW"
        read -p "Do you want to reinstall? This will preserve Docker files (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color "Skipping $SERVICE_NAME..." "$YELLOW"
            cd - > /dev/null
            return 0
        fi

        # Backup existing Laravel installation
        BACKUP_DIR="../${SERVICE_NAME}_backup_$(date +%Y%m%d_%H%M%S)"
        print_color "Creating backup at $BACKUP_DIR..." "$YELLOW"
        cd ..
        mv "$SERVICE_NAME" "$BACKUP_DIR"
        mkdir "$SERVICE_NAME"
        cd "$SERVICE_NAME"
    fi

    # Install Laravel
    print_color "Installing Laravel framework..." "$YELLOW"

    if check_composer; then
        # Use local composer
        composer create-project laravel/laravel . --prefer-dist --no-interaction
    else
        # Use Docker to run composer
        print_color "Using Docker to run Composer..." "$YELLOW"
        docker run --rm \
            -v "$(pwd)":/app \
            -w /app \
            composer:latest \
            create-project laravel/laravel . --prefer-dist --no-interaction
    fi

    if [ $? -ne 0 ]; then
        print_color "✗ Failed to install Laravel in $SERVICE_NAME" "$RED"

        # Restore preserved files
        for item in "${PRESERVE_ITEMS[@]}"; do
            if [ -e "$TEMP_DIR/$item" ]; then
                cp -r "$TEMP_DIR/$item" .
            fi
        done
        rm -rf "$TEMP_DIR"
        cd - > /dev/null
        return 1
    fi

    # Restore preserved Docker files
    print_color "Restoring Docker configuration files..." "$YELLOW"
    for item in "${PRESERVE_ITEMS[@]}"; do
        if [ -e "$TEMP_DIR/$item" ]; then
            cp -r "$TEMP_DIR/$item" .
            print_color "  • Restored: $item" "$GREEN"
        fi
    done

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Install additional packages if specified
    if [ ! -z "$PACKAGES" ]; then
        print_color "Installing additional packages: $PACKAGES" "$YELLOW"

        if check_composer; then
            composer require $PACKAGES --no-interaction
        else
            docker run --rm \
                -v "$(pwd)":/app \
                -w /app \
                composer:latest \
                require $PACKAGES --no-interaction
        fi
    fi

    # Update .env file with service-specific configurations
    if [ -f ".env" ]; then
        print_color "Updating .env configuration..." "$YELLOW"

        # Update APP_NAME
        sed -i.bak "s/APP_NAME=Laravel/APP_NAME=\"$SERVICE_NAME\"/" .env

        # Update database configuration for tenant resolver
        if [ "$SERVICE_NAME" != "Central Management" ]; then
            echo "" >> .env
            echo "# Service Configuration" >> .env
            echo "CENTRAL_MANAGEMENT_URL=http://central-management" >> .env
            echo "SERVICE_TOKEN=\${SERVICE_TOKEN}" >> .env
        fi

        # Add Redis configuration
        sed -i.bak "s/CACHE_DRIVER=file/CACHE_DRIVER=redis/" .env
        sed -i.bak "s/SESSION_DRIVER=file/SESSION_DRIVER=redis/" .env
        sed -i.bak "s/QUEUE_CONNECTION=sync/QUEUE_CONNECTION=redis/" .env

        # Remove backup files
        rm -f .env.bak
    fi

    # Set permissions
    print_color "Setting permissions..." "$YELLOW"
    chmod -R 777 storage 2>/dev/null || true
    chmod -R 777 bootstrap/cache 2>/dev/null || true

    # Create health check endpoint
    print_color "Creating health check endpoint..." "$YELLOW"
    cat > public/health.php <<'EOF'
<?php
header('Content-Type: application/json');

$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'service' => $_ENV['APP_NAME'] ?? 'Laravel Service',
];

// Basic checks
try {
    if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
        require __DIR__ . '/../vendor/autoload.php';
        $app = require_once __DIR__ . '/../bootstrap/app.php';

        // Check if we can load the kernel
        $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
        $health['laravel'] = 'loaded';
    }
} catch (Exception $e) {
    $health['status'] = 'unhealthy';
    $health['error'] = $e->getMessage();
}

http_response_code($health['status'] === 'healthy' ? 200 : 503);
echo json_encode($health, JSON_PRETTY_PRINT);
EOF

    print_color "✓ Laravel installed successfully in $SERVICE_NAME" "$GREEN"

    cd - > /dev/null
}

# Main script
clear
print_color "╔════════════════════════════════════════════════════════════════╗" "$MAGENTA"
print_color "║       Safe Laravel Installation Script (Preserves Docker)     ║" "$MAGENTA"
print_color "╚════════════════════════════════════════════════════════════════╝" "$MAGENTA"

# Check if we're in the project root
if [ ! -f "docker-compose.yml" ] || [ ! -d "services" ]; then
    print_color "✗ Please run this script from the project root directory" "$RED"
    exit 1
fi

# Check if Composer is available
if check_composer; then
    COMPOSER_VERSION=$(composer --version 2>/dev/null | cut -d' ' -f3)
    print_color "✓ Composer is installed locally (version: $COMPOSER_VERSION)" "$GREEN"
else
    print_color "⚠ Composer not found locally, will use Docker" "$YELLOW"

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_color "✗ Docker is not running. Please start Docker first." "$RED"
        print_color "Run: ./scripts/check-docker.sh" "$YELLOW"
        exit 1
    fi
fi

# Install Laravel in each service
install_laravel_in_service \
    "Central Management" \
    "services/central-management" \
    "stancl/tenancy predis/predis tymon/jwt-auth spatie/laravel-permission"

install_laravel_in_service \
    "Auth Service" \
    "services/auth-service" \
    "tymon/jwt-auth predis/predis spatie/laravel-permission laravel/sanctum"

install_laravel_in_service \
    "Sales Service" \
    "services/sales-service" \
    "predis/predis spatie/laravel-query-builder spatie/laravel-medialibrary"

install_laravel_in_service \
    "Operations Service" \
    "services/operations-service" \
    "predis/predis spatie/laravel-activitylog maatwebsite/excel"

print_header "Post-Installation Setup"

# Configure stancl/tenancy for Central Management
if [ -d "services/central-management/vendor/stancl" ]; then
    print_color "Publishing stancl/tenancy configuration..." "$YELLOW"
    cd services/central-management

    if check_composer; then
        php artisan vendor:publish --provider="Stancl\Tenancy\TenancyServiceProvider" --force
    else
        docker run --rm \
            -v "$(pwd)":/app \
            -w /app \
            --entrypoint php \
            php:8.2-cli \
            artisan vendor:publish --provider="Stancl\Tenancy\TenancyServiceProvider" --force
    fi

    # Create tenant migrations directory
    mkdir -p database/migrations/tenant

    print_color "✓ Tenancy configuration published" "$GREEN"
    cd ../..
fi

# Copy shared middleware to all services
print_header "Installing Shared Components"

for SERVICE_DIR in services/*/; do
    if [ -d "$SERVICE_DIR" ] && [ -f "$SERVICE_DIR/composer.json" ]; then
        SERVICE_NAME=$(basename "$SERVICE_DIR")

        # Create directories
        mkdir -p "$SERVICE_DIR/app/Http/Middleware"

        # Copy TenantResolver middleware if it exists
        if [ -f "shared/middleware/TenantResolver.php" ]; then
            cp shared/middleware/TenantResolver.php "$SERVICE_DIR/app/Http/Middleware/"
            print_color "✓ Copied TenantResolver middleware to $SERVICE_NAME" "$GREEN"
        fi
    fi
done

print_header "Next Steps"

print_color "Installation complete! Now you need to:" "$GREEN"
echo ""
print_color "1. Rebuild Docker containers:" "$YELLOW"
echo "   docker-compose down"
echo "   docker-compose build --no-cache"
echo "   docker-compose up -d"
echo ""
print_color "2. Generate application keys:" "$YELLOW"
echo "   docker-compose exec central-management php artisan key:generate"
echo "   docker-compose exec auth-service php artisan key:generate"
echo "   docker-compose exec sales-service php artisan key:generate"
echo "   docker-compose exec operations-service php artisan key:generate"
echo ""
print_color "3. Run migrations:" "$YELLOW"
echo "   docker-compose exec central-management php artisan migrate"
echo "   docker-compose exec auth-service php artisan migrate"
echo ""
print_color "4. Configure tenancy:" "$YELLOW"
echo "   docker-compose exec central-management php artisan tenancy:install"
echo ""
print_color "5. Create your first tenant:" "$YELLOW"
echo "   docker-compose exec central-management php artisan tinker"
echo "   >>> \$tenant = App\Models\Tenant::create(['id' => 'acme']);"
echo "   >>> \$tenant->domains()->create(['domain' => 'acme.localhost']);"
echo ""

print_color "Service URLs:" "$BLUE"
echo "  • API Gateway:        http://localhost"
echo "  • Central Management: http://localhost:8001"
echo "  • Auth Service:       http://localhost:8002"
echo "  • Sales Service:      http://localhost:8003"
echo "  • Operations Service: http://localhost:8004"
echo ""

print_color "Check service health:" "$CYAN"
echo "  curl http://localhost:8001/health.php"
echo "  curl http://localhost:8002/health.php"
echo ""

print_color "🎉 Laravel has been safely installed with Docker files preserved!" "$GREEN"
