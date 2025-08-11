#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           System Configuration Check for SaaS Travel          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ "$1" = "ok" ]; then
        echo -e "${GREEN}✓${NC} $2"
    elif [ "$1" = "warning" ]; then
        echo -e "${YELLOW}⚠${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Check Docker
echo -e "${BLUE}1. Checking Docker Installation...${NC}"
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_status "ok" "Docker installed (version: $DOCKER_VERSION)"

    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        print_status "ok" "Docker daemon is running"
    else
        print_status "error" "Docker daemon is not running"
    fi
else
    print_status "error" "Docker is not installed"
fi

# Check Docker Compose
echo -e "\n${BLUE}2. Checking Docker Compose...${NC}"
if command_exists docker-compose; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | sed 's/,//')
    print_status "ok" "Docker Compose installed (version: $COMPOSE_VERSION)"
else
    print_status "error" "Docker Compose is not installed"
fi

# Check required directories
echo -e "\n${BLUE}3. Checking Project Structure...${NC}"
REQUIRED_DIRS=(
    "services/central-management"
    "services/auth-service"
    "services/sales-service"
    "services/operations-service"
    "nginx"
    "scripts"
    "secrets"
    "shared"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_status "ok" "Directory exists: $dir"
    else
        print_status "error" "Directory missing: $dir"
    fi
done

# Check secret files
echo -e "\n${BLUE}4. Checking Secret Files...${NC}"
SECRET_FILES=(
    "secrets/postgres_password.txt"
    "secrets/jwt_secret.txt"
    "secrets/redis_password.txt"
    "secrets/service_token.txt"
)

for file in "${SECRET_FILES[@]}"; do
    if [ -f "$file" ]; then
        FILE_SIZE=$(wc -c < "$file")
        if [ "$FILE_SIZE" -gt 10 ]; then
            print_status "ok" "Secret file exists: $file"
        else
            print_status "warning" "Secret file exists but may be empty: $file"
        fi
    else
        print_status "error" "Secret file missing: $file"
    fi
done

# Check Docker containers
echo -e "\n${BLUE}5. Checking Docker Containers...${NC}"
if command_exists docker && docker info >/dev/null 2>&1; then
    # Get container status
    CONTAINERS=(
        "postgres-central"
        "postgres-tenants"
        "redis-cache"
        "central-management"
        "auth-service"
        "sales-service"
        "operations-service"
        "api-gateway"
        "mailhog"
    )

    for container in "${CONTAINERS[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "running")
            if [ "$STATUS" = "healthy" ] || [ "$STATUS" = "running" ]; then
                print_status "ok" "Container $container is running ($STATUS)"
            else
                print_status "warning" "Container $container is $STATUS"
            fi
        else
            print_status "error" "Container $container is not running"
        fi
    done
fi

# Check ports
echo -e "\n${BLUE}6. Checking Service Ports...${NC}"
PORTS=(
    "80:API Gateway"
    "8001:Central Management"
    "8002:Auth Service"
    "8003:Sales Service"
    "8004:Operations Service"
    "5432:PostgreSQL Central"
    "5433:PostgreSQL Tenants"
    "6379:Redis"
    "8025:Mailhog Web UI"
    "1025:Mailhog SMTP"
)

for port_info in "${PORTS[@]}"; do
    PORT=$(echo "$port_info" | cut -d: -f1)
    SERVICE=$(echo "$port_info" | cut -d: -f2)

    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_status "ok" "Port $PORT is listening ($SERVICE)"
    else
        print_status "warning" "Port $PORT is not listening ($SERVICE)"
    fi
done

# Check health endpoints
echo -e "\n${BLUE}7. Checking Health Endpoints...${NC}"
HEALTH_ENDPOINTS=(
    "http://localhost:8001/health.php:Central Management"
    "http://localhost:8002/health.php:Auth Service"
    "http://localhost:8003/health.php:Sales Service"
    "http://localhost:8004/health.php:Operations Service"
)

for endpoint_info in "${HEALTH_ENDPOINTS[@]}"; do
    ENDPOINT=$(echo "$endpoint_info" | cut -d: -f1-3)
    SERVICE=$(echo "$endpoint_info" | cut -d: -f4)

    if curl -f -s "$ENDPOINT" >/dev/null 2>&1; then
        print_status "ok" "Health check passed: $SERVICE"
    else
        print_status "error" "Health check failed: $SERVICE"
    fi
done

# Check database connections
echo -e "\n${BLUE}8. Checking Database Connections...${NC}"
if command_exists docker && docker ps --format "{{.Names}}" | grep -q "postgres-central"; then
    # Check if we can connect to PostgreSQL Central
    if docker exec postgres-central pg_isready -U laravel_user -d central_management >/dev/null 2>&1; then
        print_status "ok" "PostgreSQL Central is accepting connections"
    else
        print_status "error" "PostgreSQL Central is not accepting connections"
    fi

    if docker exec postgres-tenants pg_isready -U laravel_user >/dev/null 2>&1; then
        print_status "ok" "PostgreSQL Tenants is accepting connections"
    else
        print_status "error" "PostgreSQL Tenants is not accepting connections"
    fi
fi

# Check Redis connection
echo -e "\n${BLUE}9. Checking Redis Connection...${NC}"
if command_exists docker && docker ps --format "{{.Names}}" | grep -q "redis-cache"; then
    if docker exec redis-cache redis-cli ping >/dev/null 2>&1; then
        print_status "ok" "Redis is responding to ping"
    else
        print_status "error" "Redis is not responding"
    fi
fi

# Check Laravel installations
echo -e "\n${BLUE}10. Checking Laravel Installations...${NC}"
SERVICES=("central-management" "auth-service" "sales-service" "operations-service")

for service in "${SERVICES[@]}"; do
    if [ -f "services/$service/artisan" ]; then
        print_status "ok" "Laravel artisan found in $service"

        # Check if vendor directory exists
        if [ -d "services/$service/vendor" ]; then
            print_status "ok" "Vendor directory exists in $service"
        else
            print_status "warning" "Vendor directory missing in $service (run composer install)"
        fi

        # Check if .env file exists
        if [ -f "services/$service/.env" ]; then
            print_status "ok" ".env file exists in $service"
        else
            print_status "warning" ".env file missing in $service"
        fi
    else
        print_status "error" "Laravel not found in $service"
    fi
done

# Check disk space
echo -e "\n${BLUE}11. Checking Disk Space...${NC}"
DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_FREE=$(df -h . | awk 'NR==2 {print $4}')

if [ "$DISK_USAGE" -lt 80 ]; then
    print_status "ok" "Disk usage is ${DISK_USAGE}% (${DISK_FREE} free)"
else
    print_status "warning" "Disk usage is ${DISK_USAGE}% (${DISK_FREE} free)"
fi

# Check memory
echo -e "\n${BLUE}12. Checking System Memory...${NC}"
if command_exists free; then
    MEM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
    MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
    MEM_PERCENT=$((100 - (MEM_AVAILABLE * 100 / MEM_TOTAL)))

    if [ "$MEM_PERCENT" -lt 80 ]; then
        print_status "ok" "Memory usage is ${MEM_PERCENT}% (${MEM_AVAILABLE}MB available)"
    else
        print_status "warning" "Memory usage is ${MEM_PERCENT}% (${MEM_AVAILABLE}MB available)"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS memory check
    MEM_PRESSURE=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')
    if [ -n "$MEM_PRESSURE" ] && [ "$MEM_PRESSURE" -gt 20 ]; then
        print_status "ok" "Memory free: ${MEM_PRESSURE}%"
    else
        print_status "warning" "Memory may be under pressure"
    fi
fi

# Summary
echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Configuration check complete!${NC}"
echo ""
echo "If you see any errors or warnings above, please address them before"
echo "proceeding with the system setup."
echo ""
echo "Quick fixes:"
echo "  • Missing secrets: Run ./scripts/init.sh"
echo "  • Containers not running: docker-compose up -d"
echo "  • Vendor missing: docker-compose exec <service> composer install"
echo "  • Build issues: docker-compose build --no-cache"
echo ""
