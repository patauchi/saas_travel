#!/bin/bash

# ============================================
# VTravel Production Deployment Script
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_USER="deploy"
DOMAIN="yourdomain.com"
REPO_URL="https://github.com/patauchi/saas_travel.git"
DEPLOY_PATH="/home/${DEPLOY_USER}/saas_travel"
BACKUP_PATH="/backup/vtravel"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/vtravel-deploy-${TIMESTAMP}.log"

# Function to print colored output
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}" | tee -a ${LOG_FILE}
}

# Function to check if running as correct user
check_user() {
    if [ "$USER" != "$DEPLOY_USER" ]; then
        print_color "$RED" "Error: This script must be run as ${DEPLOY_USER} user"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_color "$BLUE" "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_color "$RED" "Docker is not installed!"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_color "$RED" "Docker Compose is not installed!"
        exit 1
    fi

    # Check Git
    if ! command -v git &> /dev/null; then
        print_color "$RED" "Git is not installed!"
        exit 1
    fi

    print_color "$GREEN" "✓ All prerequisites met"
}

# Function to backup current deployment
backup_current() {
    print_color "$YELLOW" "Creating backup of current deployment..."

    # Create backup directory
    mkdir -p ${BACKUP_PATH}

    # Backup databases
    if docker ps | grep -q vtravel-postgres-landlord; then
        docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord | \
            gzip > ${BACKUP_PATH}/landlord_backup_${TIMESTAMP}.sql.gz
        print_color "$GREEN" "✓ Landlord database backed up"
    fi

    if docker ps | grep -q vtravel-postgres-tenant; then
        docker exec vtravel-postgres-tenant pg_dump -U vtravel vtravel_tenants | \
            gzip > ${BACKUP_PATH}/tenant_backup_${TIMESTAMP}.sql.gz
        print_color "$GREEN" "✓ Tenant database backed up"
    fi

    # Backup .env file
    if [ -f "${DEPLOY_PATH}/.env" ]; then
        cp ${DEPLOY_PATH}/.env ${BACKUP_PATH}/env_backup_${TIMESTAMP}
        print_color "$GREEN" "✓ Environment file backed up"
    fi

    # Backup uploaded files
    if [ -d "${DEPLOY_PATH}/storage" ]; then
        tar -czf ${BACKUP_PATH}/storage_backup_${TIMESTAMP}.tar.gz \
            -C ${DEPLOY_PATH} storage/
        print_color "$GREEN" "✓ Storage files backed up"
    fi
}

# Function to pull latest code
pull_latest_code() {
    print_color "$BLUE" "Pulling latest code from repository..."

    cd ${DEPLOY_PATH}

    # Stash any local changes
    git stash

    # Pull latest changes
    git pull origin main

    print_color "$GREEN" "✓ Latest code pulled"
}

# Function to update environment
update_environment() {
    print_color "$BLUE" "Updating environment configuration..."

    # Check if .env exists, if not copy from example
    if [ ! -f "${DEPLOY_PATH}/.env" ]; then
        if [ -f "${DEPLOY_PATH}/.env.production" ]; then
            cp ${DEPLOY_PATH}/.env.production ${DEPLOY_PATH}/.env
            print_color "$YELLOW" "⚠ Created .env from .env.production - Please update with your values!"
        else
            print_color "$RED" "Error: No .env file found!"
            exit 1
        fi
    fi

    print_color "$GREEN" "✓ Environment configuration updated"
}

# Function to build Docker images
build_images() {
    print_color "$BLUE" "Building Docker images..."

    cd ${DEPLOY_PATH}

    # Use production compose file if it exists
    if [ -f "docker-compose.prod.yml" ]; then
        docker-compose -f docker-compose.prod.yml build --no-cache
    else
        docker-compose build --no-cache
    fi

    print_color "$GREEN" "✓ Docker images built"
}

# Function to start services
start_services() {
    print_color "$BLUE" "Starting services..."

    cd ${DEPLOY_PATH}

    # Use production compose file if it exists
    if [ -f "docker-compose.prod.yml" ]; then
        docker-compose -f docker-compose.prod.yml up -d
    else
        docker-compose up -d
    fi

    print_color "$GREEN" "✓ Services started"

    # Wait for services to be ready
    print_color "$YELLOW" "Waiting for services to be ready..."
    sleep 15
}

# Function to run migrations
run_migrations() {
    print_color "$BLUE" "Running database migrations..."

    # Run migrations for auth service
    if docker ps | grep -q vtravel-auth; then
        docker exec vtravel-auth php artisan migrate --force
        print_color "$GREEN" "✓ Auth service migrations completed"
    fi

    # Run migrations for tenant service
    if docker ps | grep -q vtravel-tenant; then
        docker exec vtravel-tenant php artisan migrate --force
        print_color "$GREEN" "✓ Tenant service migrations completed"
    fi
}

# Function to clear caches
clear_caches() {
    print_color "$BLUE" "Clearing and optimizing caches..."

    # Clear caches for auth service
    if docker ps | grep -q vtravel-auth; then
        docker exec vtravel-auth php artisan cache:clear
        docker exec vtravel-auth php artisan config:cache
        docker exec vtravel-auth php artisan route:cache
        docker exec vtravel-auth php artisan view:cache
        print_color "$GREEN" "✓ Auth service caches optimized"
    fi

    # Clear caches for tenant service
    if docker ps | grep -q vtravel-tenant; then
        docker exec vtravel-tenant php artisan cache:clear
        docker exec vtravel-tenant php artisan config:cache
        docker exec vtravel-tenant php artisan route:cache
        docker exec vtravel-tenant php artisan view:cache
        print_color "$GREEN" "✓ Tenant service caches optimized"
    fi
}

# Function to health check
health_check() {
    print_color "$BLUE" "Performing health check..."

    # Check if health endpoint responds
    if curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/health | grep -q "200"; then
        print_color "$GREEN" "✓ Health check passed"
        curl -s https://${DOMAIN}/health | python3 -m json.tool
    else
        print_color "$RED" "✗ Health check failed!"
        print_color "$YELLOW" "Checking individual services..."
        docker-compose ps
    fi
}

# Function to clean up old resources
cleanup() {
    print_color "$BLUE" "Cleaning up old resources..."

    # Remove unused Docker images
    docker image prune -f

    # Remove old backups (keep last 30 days)
    find ${BACKUP_PATH} -type f -mtime +30 -delete

    print_color "$GREEN" "✓ Cleanup completed"
}

# Function to send notification
send_notification() {
    status=$1
    message=$2

    # Send email notification (configure mail server first)
    # echo "${message}" | mail -s "VTravel Deployment ${status}" admin@${DOMAIN}

    # Send to Slack webhook (optional)
    # curl -X POST -H 'Content-type: application/json' \
    #     --data "{\"text\":\"VTravel Deployment ${status}: ${message}\"}" \
    #     YOUR_SLACK_WEBHOOK_URL

    print_color "$BLUE" "Notification: ${status} - ${message}"
}

# Function to rollback on failure
rollback() {
    print_color "$RED" "Deployment failed! Starting rollback..."

    # Restore database from backup
    if [ -f "${BACKUP_PATH}/landlord_backup_${TIMESTAMP}.sql.gz" ]; then
        gunzip < ${BACKUP_PATH}/landlord_backup_${TIMESTAMP}.sql.gz | \
            docker exec -i vtravel-postgres-landlord psql -U vtravel vtravel_landlord
        print_color "$YELLOW" "Database restored from backup"
    fi

    # Revert to previous git commit
    cd ${DEPLOY_PATH}
    git reset --hard HEAD~1

    # Rebuild and restart services
    docker-compose down
    docker-compose up -d

    print_color "$YELLOW" "Rollback completed"
    send_notification "FAILED" "Deployment failed and was rolled back"
    exit 1
}

# Main deployment function
main() {
    print_color "$GREEN" "============================================"
    print_color "$GREEN" "VTravel Production Deployment"
    print_color "$GREEN" "Started at: $(date)"
    print_color "$GREEN" "============================================"

    # Set error trap
    trap rollback ERR

    # Run deployment steps
    check_user
    check_prerequisites
    backup_current
    pull_latest_code
    update_environment
    build_images
    start_services
    run_migrations
    clear_caches
    health_check
    cleanup

    # Remove error trap
    trap - ERR

    print_color "$GREEN" "============================================"
    print_color "$GREEN" "Deployment completed successfully!"
    print_color "$GREEN" "Finished at: $(date)"
    print_color "$GREEN" "============================================"

    send_notification "SUCCESS" "Deployment completed successfully at $(date)"
}

# Show help
show_help() {
    echo "VTravel Production Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -b, --backup    Only perform backup"
    echo "  -m, --migrate   Only run migrations"
    echo "  -c, --check     Only perform health check"
    echo "  -r, --rollback  Rollback to previous version"
    echo ""
    echo "Examples:"
    echo "  $0              # Full deployment"
    echo "  $0 --backup     # Backup only"
    echo "  $0 --check      # Health check only"
}

# Parse command line arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -b|--backup)
        check_user
        backup_current
        exit 0
        ;;
    -m|--migrate)
        check_user
        run_migrations
        exit 0
        ;;
    -c|--check)
        health_check
        exit 0
        ;;
    -r|--rollback)
        check_user
        rollback
        exit 0
        ;;
    *)
        main
        ;;
esac
