#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show menu
show_menu() {
    echo ""
    print_color "$BLUE" "=== VTravel Docker Development Helper ==="
    echo ""
    echo "1) Start all services"
    echo "2) Stop all services (keep data)"
    echo "3) Restart a specific service"
    echo "4) View logs of a service"
    echo "5) Run migrations"
    echo "6) Clear Laravel cache"
    echo "7) Enter a container shell"
    echo "8) Rebuild a specific service"
    echo "9) Check system status"
    echo "10) Backup database"
    echo "11) Quick restart (all services)"
    echo "0) Exit"
    echo ""
}

# Function to select service
select_service() {
    echo "Select service:"
    echo "1) auth-service"
    echo "2) tenant-service"
    echo "3) crm-service"
    echo "4) sales-service"
    echo "5) financial-service"
    echo "6) operations-service"
    echo "7) communication-service"
    echo "8) nginx"
    echo "9) postgres-landlord"
    echo "10) postgres-tenant"
    read -p "Enter choice: " service_choice

    case $service_choice in
        1) SERVICE="auth-service" ;;
        2) SERVICE="tenant-service" ;;
        3) SERVICE="crm-service" ;;
        4) SERVICE="sales-service" ;;
        5) SERVICE="financial-service" ;;
        6) SERVICE="operations-service" ;;
        7) SERVICE="communication-service" ;;
        8) SERVICE="nginx" ;;
        9) SERVICE="postgres-landlord" ;;
        10) SERVICE="postgres-tenant" ;;
        *) SERVICE="" ;;
    esac
}

# Main loop
while true; do
    show_menu
    read -p "Enter choice [0-11]: " choice

    case $choice in
        1)
            print_color "$GREEN" "Starting all services..."
            docker-compose up -d
            print_color "$GREEN" "✓ All services started"
            ;;

        2)
            print_color "$YELLOW" "Stopping all services (data will be preserved)..."
            docker-compose stop
            print_color "$GREEN" "✓ All services stopped"
            ;;

        3)
            select_service
            if [ -n "$SERVICE" ]; then
                print_color "$YELLOW" "Restarting $SERVICE..."
                docker-compose restart $SERVICE
                print_color "$GREEN" "✓ $SERVICE restarted"
            else
                print_color "$RED" "Invalid service selection"
            fi
            ;;

        4)
            select_service
            if [ -n "$SERVICE" ]; then
                print_color "$BLUE" "Showing logs for $SERVICE (Ctrl+C to exit)..."
                docker-compose logs -f $SERVICE
            else
                print_color "$RED" "Invalid service selection"
            fi
            ;;

        5)
            echo "Select service for migrations:"
            echo "1) auth-service"
            echo "2) tenant-service"
            read -p "Enter choice: " mig_choice

            case $mig_choice in
                1)
                    print_color "$YELLOW" "Running migrations in auth-service..."
                    docker exec vtravel-auth php artisan migrate
                    print_color "$GREEN" "✓ Migrations completed"
                    ;;
                2)
                    print_color "$YELLOW" "Running migrations in tenant-service..."
                    docker exec vtravel-tenant php artisan migrate
                    print_color "$GREEN" "✓ Migrations completed"
                    ;;
                *)
                    print_color "$RED" "Invalid selection"
                    ;;
            esac
            ;;

        6)
            echo "Select service to clear cache:"
            echo "1) auth-service"
            echo "2) tenant-service"
            read -p "Enter choice: " cache_choice

            case $cache_choice in
                1)
                    print_color "$YELLOW" "Clearing cache in auth-service..."
                    docker exec vtravel-auth php artisan cache:clear
                    docker exec vtravel-auth php artisan config:clear
                    docker exec vtravel-auth php artisan view:clear
                    print_color "$GREEN" "✓ Cache cleared"
                    ;;
                2)
                    print_color "$YELLOW" "Clearing cache in tenant-service..."
                    docker exec vtravel-tenant php artisan cache:clear
                    docker exec vtravel-tenant php artisan config:clear
                    docker exec vtravel-tenant php artisan view:clear
                    print_color "$GREEN" "✓ Cache cleared"
                    ;;
                *)
                    print_color "$RED" "Invalid selection"
                    ;;
            esac
            ;;

        7)
            select_service
            if [ -n "$SERVICE" ]; then
                print_color "$BLUE" "Entering shell for vtravel-$SERVICE..."
                docker exec -it vtravel-$SERVICE sh
            else
                print_color "$RED" "Invalid service selection"
            fi
            ;;

        8)
            select_service
            if [ -n "$SERVICE" ]; then
                print_color "$YELLOW" "Rebuilding $SERVICE..."
                docker-compose up -d --build $SERVICE
                print_color "$GREEN" "✓ $SERVICE rebuilt and started"
            else
                print_color "$RED" "Invalid service selection"
            fi
            ;;

        9)
            print_color "$BLUE" "Checking system status..."
            echo ""
            docker-compose ps
            echo ""
            print_color "$YELLOW" "Health check:"
            curl -s http://localhost:8080/health | jq '.' 2>/dev/null || echo "Health check failed"
            ;;

        10)
            print_color "$YELLOW" "Backing up databases..."
            mkdir -p backups
            timestamp=$(date +%Y%m%d_%H%M%S)

            docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord > backups/landlord_${timestamp}.sql
            docker exec vtravel-postgres-tenant pg_dump -U vtravel vtravel_central > backups/tenant_${timestamp}.sql

            print_color "$GREEN" "✓ Databases backed up to backups/ directory"
            ;;

        11)
            print_color "$YELLOW" "Quick restarting all services..."
            docker-compose restart
            print_color "$GREEN" "✓ All services restarted"
            ;;

        0)
            print_color "$GREEN" "Goodbye!"
            exit 0
            ;;

        *)
            print_color "$RED" "Invalid option. Please try again."
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
done
