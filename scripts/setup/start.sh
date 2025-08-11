#!/bin/bash

# VTravel SaaS Platform - Quick Start Script
# ==========================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    echo -e "${2}${1}${NC}"
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    VTravel SaaS Platform Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_message "Checking prerequisites..." "$YELLOW"

    local missing_deps=()

    if ! command_exists docker; then
        missing_deps+=("Docker")
    fi

    if ! command_exists docker-compose; then
        missing_deps+=("Docker Compose")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message "Missing dependencies: ${missing_deps[*]}" "$RED"
        print_message "Please install the missing dependencies and try again." "$RED"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_message "Docker is not running. Please start Docker and try again." "$RED"
        exit 1
    fi

    print_message "✓ All prerequisites met" "$GREEN"
}

# Create necessary directories
create_directories() {
    print_message "Creating necessary directories..." "$YELLOW"

    mkdir -p infrastructure/postgres/init/landlord
    mkdir -p infrastructure/postgres/init/tenant
    mkdir -p infrastructure/redis
    mkdir -p infrastructure/rabbitmq
    mkdir -p secrets
    mkdir -p backups
    mkdir -p logs

    # Create placeholder files for Laravel services
    for service in auth tenant crm sales financial operations communication; do
        mkdir -p services/${service}-service/app
        mkdir -p services/${service}-service/database
        mkdir -p services/${service}-service/routes

        # Create a basic Dockerfile if it doesn't exist
        if [ ! -f "services/${service}-service/Dockerfile" ]; then
            cat > "services/${service}-service/Dockerfile" <<EOF
FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    curl \
    git \
    zip \
    unzip

RUN docker-php-ext-install pdo pdo_pgsql

WORKDIR /var/www/html

# Create health check file
RUN echo "<?php echo json_encode(['status' => 'ok', 'service' => '${service}']);" > health.php

EXPOSE 9000

CMD ["php-fpm"]
EOF
        fi

        # Create a basic health check PHP file
        if [ ! -f "services/${service}-service/app/health.php" ]; then
            mkdir -p "services/${service}-service/app"
            echo "<?php echo json_encode(['status' => 'ok', 'service' => '${service}', 'timestamp' => date('c')]);" > "services/${service}-service/app/health.php"
        fi
    done

    print_message "✓ Directories created" "$GREEN"
}

# Setup environment file
setup_env() {
    print_message "Setting up environment configuration..." "$YELLOW"

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_message "✓ Created .env from .env.example" "$GREEN"
        else
            print_message "Warning: .env.example not found, .env not created" "$YELLOW"
        fi
    else
        print_message "✓ .env file already exists" "$GREEN"
    fi
}

# Create Docker network
create_network() {
    print_message "Creating Docker network..." "$YELLOW"

    if docker network ls | grep -q vtravel-network; then
        print_message "✓ Network 'vtravel-network' already exists" "$GREEN"
    else
        docker network create vtravel-network
        print_message "✓ Network 'vtravel-network' created" "$GREEN"
    fi
}

# Build Docker images
build_images() {
    print_message "Building Docker images..." "$YELLOW"
    print_message "This may take several minutes on first run..." "$YELLOW"

    docker-compose build --no-cache

    if [ $? -eq 0 ]; then
        print_message "✓ Docker images built successfully" "$GREEN"
    else
        print_message "✗ Failed to build Docker images" "$RED"
        exit 1
    fi
}

# Start services
start_services() {
    print_message "Starting services..." "$YELLOW"

    docker-compose up -d

    if [ $? -eq 0 ]; then
        print_message "✓ Services started successfully" "$GREEN"
    else
        print_message "✗ Failed to start services" "$RED"
        exit 1
    fi
}

# Wait for services to be ready
wait_for_services() {
    print_message "Waiting for services to be ready..." "$YELLOW"

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/health >/dev/null 2>&1; then
            print_message "✓ Services are ready!" "$GREEN"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    echo ""
    print_message "⚠ Services are taking longer than expected to start" "$YELLOW"
    print_message "You can check the status manually with: make health" "$YELLOW"
}

# Check service health
check_health() {
    print_message "\nChecking service health..." "$YELLOW"

    if command_exists curl && command_exists python3; then
        curl -s http://localhost:3000/health/services 2>/dev/null | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)
    print('\nService Health Status:')
    print('=' * 40)

    if 'summary' in data:
        summary = data['summary']
        print(f\"Total Services: {summary.get('total', 0)}\")
        print(f\"Healthy: {summary.get('healthy', 0)}\")
        print(f\"Unhealthy: {summary.get('unhealthy', 0)}\")

    print('\nIndividual Services:')
    print('-' * 40)

    if 'services' in data:
        for service, info in data['services'].items():
            status = info.get('status', 'unknown')
            status_symbol = '✓' if status == 'healthy' else '✗'
            status_color = '\033[0;32m' if status == 'healthy' else '\033[0;31m'
            print(f\"{status_color}{status_symbol}\033[0m {service}: {status}\")

    print('=' * 40)
except Exception as e:
    print('Could not parse health check response')
    print(f'Error: {e}')
" || print_message "Health check endpoint not available yet" "$YELLOW"
    else
        print_message "Install curl and python3 for detailed health check" "$YELLOW"
    fi
}

# Show access information
show_access_info() {
    echo ""
    print_message "========================================" "$GREEN"
    print_message "    VTravel Platform is Ready!" "$GREEN"
    print_message "========================================" "$GREEN"
    echo ""
    print_message "Access Points:" "$BLUE"
    echo "  • Health Dashboard: http://localhost:3000/health/services"
    echo "  • API Gateway: http://localhost/api"
    echo "  • RabbitMQ Admin: http://localhost:15672 (admin/admin123)"
    echo "  • MinIO Console: http://localhost:9010 (minioadmin/minioadmin123)"
    echo ""
    print_message "Database Access:" "$BLUE"
    echo "  • PostgreSQL Landlord: localhost:5432 (vtravel/vtravel123)"
    echo "  • PostgreSQL Tenant: localhost:5433 (vtravel/vtravel123)"
    echo "  • Redis: localhost:6379"
    echo ""
    print_message "Useful Commands:" "$BLUE"
    echo "  • Check status: make ps"
    echo "  • View logs: make logs"
    echo "  • Health check: make health"
    echo "  • Stop services: make down"
    echo "  • Connect to DB: make db-landlord"
    echo ""
}

# Main execution
main() {
    print_header

    # Parse arguments
    case "${1:-}" in
        --quick|-q)
            print_message "Quick start mode - skipping build" "$YELLOW"
            SKIP_BUILD=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick, -q    Skip building images (use existing)"
            echo "  --help, -h     Show this help message"
            echo ""
            exit 0
            ;;
    esac

    check_prerequisites
    create_directories
    setup_env
    create_network

    if [ "${SKIP_BUILD:-false}" != "true" ]; then
        build_images
    fi

    start_services
    wait_for_services
    check_health
    show_access_info

    print_message "✅ Setup complete!" "$GREEN"
}

# Run main function
main "$@"
