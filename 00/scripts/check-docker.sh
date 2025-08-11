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

# Function to check if Docker is running
check_docker_running() {
    docker info >/dev/null 2>&1
    return $?
}

# Function to check if Docker Desktop is installed on macOS
check_docker_desktop_macos() {
    if [ -d "/Applications/Docker.app" ]; then
        return 0
    fi
    return 1
}

# Function to start Docker Desktop on macOS
start_docker_macos() {
    print_color "Starting Docker Desktop..." "$YELLOW"
    open -a Docker

    # Wait for Docker to start
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if check_docker_running; then
            print_color "✓ Docker Desktop is now running!" "$GREEN"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""
    print_color "✗ Docker Desktop failed to start within 60 seconds" "$RED"
    return 1
}

# Main script
clear
print_color "╔════════════════════════════════════════════════════════════════╗" "$MAGENTA"
print_color "║              Docker Status Check & Service Starter            ║" "$MAGENTA"
print_color "╚════════════════════════════════════════════════════════════════╝" "$MAGENTA"

print_header "Checking Docker Installation"

# Check if Docker is installed
if ! command_exists docker; then
    print_color "✗ Docker is not installed" "$RED"
    echo ""
    print_color "Please install Docker Desktop from:" "$YELLOW"
    echo "  https://www.docker.com/products/docker-desktop"
    exit 1
fi

DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
print_color "✓ Docker is installed (version: $DOCKER_VERSION)" "$GREEN"

# Check if Docker Compose is installed
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    print_color "✗ Docker Compose is not installed" "$RED"
    exit 1
fi

if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null)
    print_color "✓ Docker Compose is installed (version: $COMPOSE_VERSION)" "$GREEN"
else
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
    print_color "✓ Docker Compose is installed (version: $COMPOSE_VERSION)" "$GREEN"
fi

print_header "Checking Docker Daemon Status"

# Check if Docker daemon is running
if check_docker_running; then
    print_color "✓ Docker daemon is running" "$GREEN"

    # Get Docker system info
    CONTAINERS=$(docker ps -q | wc -l | xargs)
    IMAGES=$(docker images -q | wc -l | xargs)

    echo ""
    print_color "Docker System Info:" "$BLUE"
    echo "  • Active containers: $CONTAINERS"
    echo "  • Downloaded images: $IMAGES"

else
    print_color "✗ Docker daemon is not running" "$RED"

    # Check OS and try to start Docker
    OS=$(uname -s)

    if [ "$OS" = "Darwin" ]; then
        # macOS
        echo ""
        print_color "Detected macOS system" "$YELLOW"

        if check_docker_desktop_macos; then
            read -p "Would you like to start Docker Desktop? (y/n): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if start_docker_macos; then
                    echo ""
                    print_color "Docker Desktop started successfully!" "$GREEN"
                else
                    print_color "Failed to start Docker Desktop automatically" "$RED"
                    echo ""
                    print_color "Please start Docker Desktop manually:" "$YELLOW"
                    echo "  1. Open Finder"
                    echo "  2. Go to Applications"
                    echo "  3. Double-click Docker"
                    echo "  4. Wait for the Docker icon in the menu bar to stop animating"
                    echo "  5. Run this script again"
                    exit 1
                fi
            else
                print_color "Please start Docker Desktop manually to continue" "$YELLOW"
                exit 1
            fi
        else
            print_color "Docker Desktop app not found in Applications" "$RED"
            print_color "Please install Docker Desktop from:" "$YELLOW"
            echo "  https://www.docker.com/products/docker-desktop"
            exit 1
        fi

    elif [ "$OS" = "Linux" ]; then
        # Linux
        echo ""
        print_color "Detected Linux system" "$YELLOW"
        print_color "Trying to start Docker service..." "$YELLOW"

        if command_exists systemctl; then
            sudo systemctl start docker
            sleep 2

            if check_docker_running; then
                print_color "✓ Docker service started successfully" "$GREEN"
            else
                print_color "✗ Failed to start Docker service" "$RED"
                print_color "Try running: sudo systemctl start docker" "$YELLOW"
                exit 1
            fi
        else
            print_color "Please start Docker service manually" "$YELLOW"
            print_color "Try running: sudo service docker start" "$YELLOW"
            exit 1
        fi
    else
        print_color "Unsupported operating system: $OS" "$RED"
        exit 1
    fi
fi

print_header "Checking Project Services"

# Check if we're in the correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_color "✗ docker-compose.yml not found" "$RED"
    print_color "Please run this script from the project root directory" "$YELLOW"
    exit 1
fi

print_color "✓ Project structure found" "$GREEN"

# Check if services are running
RUNNING_SERVICES=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l | xargs)

if [ "$RUNNING_SERVICES" -gt 0 ]; then
    print_color "Found $RUNNING_SERVICES running service(s):" "$GREEN"
    docker-compose ps --services --filter "status=running" 2>/dev/null | while read service; do
        echo "  • $service"
    done

    echo ""
    read -p "Would you like to restart all services? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "Restarting services..." "$YELLOW"
        docker-compose down
        docker-compose up -d
    fi
else
    print_color "No services are currently running" "$YELLOW"

    echo ""
    read -p "Would you like to start all services? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "Starting services..." "$YELLOW"

        # Check if secrets exist
        if [ ! -f "secrets/postgres_password.txt" ]; then
            print_color "Secrets not found. Running initialization script first..." "$YELLOW"
            if [ -f "scripts/init.sh" ]; then
                ./scripts/init.sh
            else
                print_color "✗ Initialization script not found" "$RED"
                exit 1
            fi
        else
            docker-compose up -d

            print_color "Waiting for services to start..." "$YELLOW"
            sleep 10

            # Check service health
            print_header "Service Health Status"

            check_service_health() {
                SERVICE_NAME=$1
                PORT=$2

                if curl -f http://localhost:$PORT/health >/dev/null 2>&1 || \
                   curl -f http://localhost:$PORT/health.php >/dev/null 2>&1; then
                    print_color "✓ $SERVICE_NAME is healthy" "$GREEN"
                else
                    print_color "✗ $SERVICE_NAME is not responding yet" "$YELLOW"
                fi
            }

            check_service_health "API Gateway" 80
            check_service_health "Central Management" 8001
            check_service_health "Auth Service" 8002
            check_service_health "Sales Service" 8003
            check_service_health "Operations Service" 8004

            echo ""
            print_color "Services are starting up. They may take a few moments to be fully ready." "$YELLOW"
            print_color "You can check the logs with: docker-compose logs -f" "$BLUE"
        fi
    fi
fi

print_header "Quick Commands Reference"

print_color "Service Management:" "$BLUE"
echo "  • Start services:    docker-compose up -d"
echo "  • Stop services:     docker-compose down"
echo "  • Restart services:  docker-compose restart"
echo "  • View logs:         docker-compose logs -f [service-name]"
echo ""

print_color "Service URLs:" "$BLUE"
echo "  • API Gateway:        http://localhost"
echo "  • Central Management: http://localhost:8001"
echo "  • Auth Service:       http://localhost:8002"
echo "  • Sales Service:      http://localhost:8003"
echo "  • Operations Service: http://localhost:8004"
echo "  • Mailhog:           http://localhost:8025"
echo ""

print_color "Database Access:" "$BLUE"
echo "  • PostgreSQL Central: localhost:5432"
echo "  • PostgreSQL Tenants: localhost:5433"
echo "  • Redis:             localhost:6379"
echo ""

print_color "Health Checks:" "$BLUE"
echo "  • curl http://localhost/health"
echo "  • curl http://localhost:8001/health.php"
echo ""

print_color "✨ Docker and project check complete!" "$GREEN"
