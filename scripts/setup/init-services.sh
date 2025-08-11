#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== VTravel Services Initialization Script ===${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Starting core services...${NC}"
docker-compose up -d postgres-landlord postgres-tenant redis rabbitmq minio

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Step 2: Waiting for PostgreSQL to be ready...${NC}"
sleep 10

# Function to check if PostgreSQL is ready
check_postgres() {
    docker exec $1 pg_isready -U vtravel > /dev/null 2>&1
    return $?
}

# Wait for landlord database
echo -n "Waiting for postgres-landlord..."
while ! check_postgres vtravel-postgres-landlord; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}Ready!${NC}"

# Wait for tenant database
echo -n "Waiting for postgres-tenant..."
while ! check_postgres vtravel-postgres-tenant; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}Ready!${NC}"

# Create databases if they don't exist
echo -e "${YELLOW}Step 3: Creating databases...${NC}"

# Create landlord database
docker exec vtravel-postgres-landlord psql -U vtravel -tc "SELECT 1 FROM pg_database WHERE datname = 'vtravel_landlord'" | grep -q 1 || \
docker exec vtravel-postgres-landlord psql -U vtravel -c "CREATE DATABASE vtravel_landlord;"
echo -e "Database vtravel_landlord ${GREEN}✓${NC}"

# Create central tenant database
docker exec vtravel-postgres-tenant psql -U vtravel -tc "SELECT 1 FROM pg_database WHERE datname = 'vtravel_central'" | grep -q 1 || \
docker exec vtravel-postgres-tenant psql -U vtravel -c "CREATE DATABASE vtravel_central;"
echo -e "Database vtravel_central ${GREEN}✓${NC}"

# Start Laravel services
echo -e "${YELLOW}Step 4: Starting Laravel services...${NC}"
docker-compose up -d auth-service tenant-service

# Wait for services to be ready
sleep 10

# Run migrations for auth-service
echo -e "${YELLOW}Step 5: Running migrations for auth-service...${NC}"
docker exec vtravel-auth php artisan migrate --force
if [ $? -eq 0 ]; then
    echo -e "Auth service migrations ${GREEN}✓${NC}"
else
    echo -e "${RED}Auth service migrations failed${NC}"
fi

# Run migrations for tenant-service
echo -e "${YELLOW}Step 6: Running migrations for tenant-service...${NC}"
docker exec vtravel-tenant php artisan migrate --force
if [ $? -eq 0 ]; then
    echo -e "Tenant service migrations ${GREEN}✓${NC}"
else
    echo -e "${RED}Tenant service migrations failed${NC}"
fi

# Create super admin user
echo -e "${YELLOW}Step 7: Creating super admin user...${NC}"
docker exec vtravel-auth php artisan tinker --execute="
    \$tenant = \App\Models\Tenant::firstOrCreate(
        ['slug' => 'system'],
        [
            'name' => 'System',
            'database' => 'vtravel_central',
            'status' => 'active',
            'plan' => 'enterprise'
        ]
    );

    \$user = \App\Models\User::firstOrCreate(
        ['email' => 'admin@vtravel.com'],
        [
            'name' => 'Super Admin',
            'password' => bcrypt('admin123'),
            'tenant_id' => \$tenant->id,
            'role' => 'super_admin',
            'is_active' => true
        ]
    );

    echo 'Super admin created: admin@vtravel.com / admin123';
"

# Start remaining services
echo -e "${YELLOW}Step 8: Starting remaining services...${NC}"
docker-compose up -d

# Wait for all services
sleep 5

# Check health of all services
echo -e "${YELLOW}Step 9: Checking service health...${NC}"
echo ""

# Function to check service health
check_service() {
    local service=$1
    local url=$2

    if curl -s -o /dev/null -w "%{http_code}" $url | grep -q "200\|301\|302"; then
        echo -e "$service: ${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "$service: ${RED}✗ Not responding${NC}"
        return 1
    fi
}

# Check each service
check_service "Nginx Gateway" "http://localhost:8080/"
check_service "Health Service" "http://localhost:8080/health"
check_service "Auth Service" "http://localhost:9001/api/health"
check_service "Tenant Service" "http://localhost:9002/api/health"
check_service "RabbitMQ Management" "http://localhost:15672/"
check_service "MinIO Console" "http://localhost:9010/"

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Access points:"
echo "  - Main Application: http://localhost:8080"
echo "  - Admin Dashboard: http://localhost:8080/central/"
echo "  - RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo "  - MinIO Console: http://localhost:9010 (minioadmin/minioadmin)"
echo ""
echo "Default admin credentials:"
echo "  Email: admin@vtravel.com"
echo "  Password: admin123"
echo ""
echo -e "${YELLOW}Note: Some services may take a few more seconds to be fully operational.${NC}"
