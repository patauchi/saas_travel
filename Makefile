# VTravel SaaS Platform - Makefile
# ========================================

# Variables
COMPOSE = docker-compose
COMPOSE_FILE = docker-compose.yml
PROJECT_NAME = vtravel

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)VTravel SaaS Platform - Docker Management$(NC)"
	@echo "============================================"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make setup     - Initial setup"
	@echo "  make up        - Start all services"
	@echo "  make health    - Check services health"
	@echo ""

# ========================================
# SETUP COMMANDS
# ========================================

.PHONY: setup
setup: ## Initial setup - build images and prepare environment
	@echo "$(GREEN)Setting up VTravel SaaS Platform...$(NC)"
	@cp .env.example .env 2>/dev/null || true
	@mkdir -p infrastructure/postgres/init/landlord
	@mkdir -p infrastructure/postgres/init/tenant
	@mkdir -p infrastructure/redis
	@mkdir -p infrastructure/rabbitmq
	@mkdir -p secrets
	@echo "$(GREEN)Creating Docker networks...$(NC)"
	@docker network create vtravel-network 2>/dev/null || true
	@echo "$(GREEN)Building Docker images...$(NC)"
	@$(COMPOSE) build --no-cache
	@echo "$(GREEN)Setup complete!$(NC)"

.PHONY: build
build: ## Build all Docker images
	@echo "$(GREEN)Building Docker images...$(NC)"
	@$(COMPOSE) build

.PHONY: build-no-cache
build-no-cache: ## Build all Docker images without cache
	@echo "$(GREEN)Building Docker images (no cache)...$(NC)"
	@$(COMPOSE) build --no-cache

# ========================================
# CONTAINER MANAGEMENT
# ========================================

.PHONY: up
up: ## Start all services
	@echo "$(GREEN)Starting all services...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)Services started! Waiting for them to be ready...$(NC)"
	@sleep 10
	@make health

.PHONY: up-verbose
up-verbose: ## Start all services with logs
	@echo "$(GREEN)Starting all services with logs...$(NC)"
	@$(COMPOSE) up

.PHONY: down
down: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(COMPOSE) down

.PHONY: down-volumes
down-volumes: ## Stop all services and remove volumes
	@echo "$(RED)Stopping all services and removing volumes...$(NC)"
	@$(COMPOSE) down -v

.PHONY: restart
restart: ## Restart all services
	@echo "$(YELLOW)Restarting all services...$(NC)"
	@$(COMPOSE) restart

.PHONY: stop
stop: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(COMPOSE) stop

.PHONY: start
start: ## Start stopped services
	@echo "$(GREEN)Starting services...$(NC)"
	@$(COMPOSE) start

# ========================================
# SERVICE SPECIFIC COMMANDS
# ========================================

.PHONY: up-db
up-db: ## Start only database services
	@echo "$(GREEN)Starting database services...$(NC)"
	@$(COMPOSE) up -d postgres-landlord postgres-tenant redis

.PHONY: up-core
up-core: ## Start core services (DB, Redis, RabbitMQ)
	@echo "$(GREEN)Starting core services...$(NC)"
	@$(COMPOSE) up -d postgres-landlord postgres-tenant redis rabbitmq minio

.PHONY: up-services
up-services: ## Start only microservices
	@echo "$(GREEN)Starting microservices...$(NC)"
	@$(COMPOSE) up -d auth-service tenant-service crm-service sales-service financial-service operations-service communication-service

# ========================================
# HEALTH & MONITORING
# ========================================

.PHONY: health
health: ## Check health of all services
	@echo "$(GREEN)Checking health status of all services...$(NC)"
	@echo "============================================"
	@curl -s http://localhost:3000/health/services | python3 -m json.tool 2>/dev/null || \
		(echo "$(RED)Health service not responding. Services might still be starting...$(NC)" && \
		echo "$(YELLOW)Checking individual services...$(NC)" && \
		make ps)

.PHONY: health-simple
health-simple: ## Simple health check
	@curl -s http://localhost:3000/health | python3 -m json.tool

.PHONY: ps
ps: ## Show status of all containers
	@echo "$(GREEN)Container Status:$(NC)"
	@$(COMPOSE) ps

.PHONY: logs
logs: ## Show logs from all services
	@$(COMPOSE) logs -f

.PHONY: logs-tail
logs-tail: ## Show last 100 lines of logs
	@$(COMPOSE) logs --tail=100

# ========================================
# SERVICE LOGS
# ========================================

.PHONY: logs-auth
logs-auth: ## Show auth service logs
	@$(COMPOSE) logs -f auth-service

.PHONY: logs-tenant
logs-tenant: ## Show tenant service logs
	@$(COMPOSE) logs -f tenant-service

.PHONY: logs-crm
logs-crm: ## Show CRM service logs
	@$(COMPOSE) logs -f crm-service

.PHONY: logs-sales
logs-sales: ## Show sales service logs
	@$(COMPOSE) logs -f sales-service

.PHONY: logs-nginx
logs-nginx: ## Show nginx logs
	@$(COMPOSE) logs -f nginx

.PHONY: logs-db
logs-db: ## Show database logs
	@$(COMPOSE) logs -f postgres-landlord postgres-tenant

# ========================================
# DATABASE COMMANDS
# ========================================

.PHONY: db-landlord
db-landlord: ## Connect to landlord database
	@echo "$(GREEN)Connecting to landlord database...$(NC)"
	@docker exec -it vtravel-postgres-landlord psql -U vtravel -d vtravel_landlord

.PHONY: db-tenant
db-tenant: ## Connect to tenant database
	@echo "$(GREEN)Connecting to tenant database...$(NC)"
	@docker exec -it vtravel-postgres-tenant psql -U vtravel -d tenant_template

.PHONY: redis-cli
redis-cli: ## Connect to Redis CLI
	@echo "$(GREEN)Connecting to Redis...$(NC)"
	@docker exec -it vtravel-redis redis-cli

# ========================================
# DEVELOPMENT COMMANDS
# ========================================

.PHONY: shell-auth
shell-auth: ## Open shell in auth service
	@docker exec -it vtravel-auth /bin/sh

.PHONY: shell-tenant
shell-tenant: ## Open shell in tenant service
	@docker exec -it vtravel-tenant /bin/sh

.PHONY: shell-nginx
shell-nginx: ## Open shell in nginx
	@docker exec -it vtravel-nginx /bin/sh

.PHONY: shell-health
shell-health: ## Open shell in health service
	@docker exec -it vtravel-health /bin/sh

# ========================================
# TENANT MANAGEMENT
# ========================================

.PHONY: create-tenant
create-tenant: ## Create a new tenant (usage: make create-tenant NAME=agency1)
	@echo "$(GREEN)Creating new tenant: $(NAME)$(NC)"
	@docker exec -it vtravel-tenant php artisan tenant:create $(NAME)

.PHONY: list-tenants
list-tenants: ## List all tenants
	@echo "$(GREEN)Listing all tenants...$(NC)"
	@docker exec -it vtravel-tenant php artisan tenant:list

# ========================================
# CLEANUP COMMANDS
# ========================================

.PHONY: clean
clean: ## Clean up stopped containers and unused images
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker system prune -f

.PHONY: clean-all
clean-all: ## Clean up everything including volumes (WARNING: Data loss!)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(COMPOSE) down -v
	@docker system prune -af --volumes

.PHONY: reset
reset: down-volumes clean setup up ## Complete reset and restart
	@echo "$(GREEN)Reset complete!$(NC)"

# ========================================
# MONITORING & ADMIN PANELS
# ========================================

.PHONY: open-rabbitmq
open-rabbitmq: ## Open RabbitMQ management console
	@echo "$(GREEN)Opening RabbitMQ Management Console...$(NC)"
	@echo "URL: http://localhost:15672"
	@echo "Username: admin"
	@echo "Password: admin123"
	@command -v open >/dev/null 2>&1 && open http://localhost:15672 || echo "Please open http://localhost:15672 in your browser"

.PHONY: open-minio
open-minio: ## Open MinIO console
	@echo "$(GREEN)Opening MinIO Console...$(NC)"
	@echo "URL: http://localhost:9010"
	@echo "Username: minioadmin"
	@echo "Password: minioadmin123"
	@command -v open >/dev/null 2>&1 && open http://localhost:9010 || echo "Please open http://localhost:9010 in your browser"

.PHONY: open-health
open-health: ## Open health dashboard
	@echo "$(GREEN)Opening Health Dashboard...$(NC)"
	@command -v open >/dev/null 2>&1 && open http://localhost:3000/health/services || echo "Please open http://localhost:3000/health/services in your browser"

# ========================================
# TESTING
# ========================================

.PHONY: test-auth
test-auth: ## Test auth service endpoints
	@echo "$(GREEN)Testing Auth Service...$(NC)"
	@curl -X GET http://localhost:9001/health

.PHONY: test-api
test-api: ## Test API endpoints through Nginx
	@echo "$(GREEN)Testing API Endpoints...$(NC)"
	@echo "Health Check:"
	@curl -s http://localhost/health | python3 -m json.tool
	@echo "\nAuth Service:"
	@curl -s http://localhost/api/auth/health | head -n 5

# ========================================
# BACKUP & RESTORE
# ========================================

.PHONY: backup
backup: ## Backup databases
	@echo "$(GREEN)Creating backup...$(NC)"
	@mkdir -p backups
	@docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord > backups/landlord_$$(date +%Y%m%d_%H%M%S).sql
	@docker exec vtravel-postgres-tenant pg_dump -U vtravel tenant_template > backups/tenant_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Backup completed!$(NC)"

.PHONY: restore-landlord
restore-landlord: ## Restore landlord database (usage: make restore-landlord FILE=backup.sql)
	@echo "$(GREEN)Restoring landlord database from $(FILE)...$(NC)"
	@docker exec -i vtravel-postgres-landlord psql -U vtravel vtravel_landlord < $(FILE)

# ========================================
# UTILITIES
# ========================================

.PHONY: stats
stats: ## Show Docker resource usage
	@echo "$(GREEN)Docker Resource Usage:$(NC)"
	@docker stats --no-stream

.PHONY: network-inspect
network-inspect: ## Inspect Docker network
	@docker network inspect vtravel-network

.PHONY: version
version: ## Show versions
	@echo "$(GREEN)Component Versions:$(NC)"
	@docker --version
	@docker-compose --version
	@echo "Project: VTravel SaaS Platform v1.0.0"

# Default target
.DEFAULT_GOAL := help
