#!/bin/bash

# ============================================
# VTravel - Simple Secrets Generator
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    VTravel Secrets Generator${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Create secrets directory
mkdir -p secrets
chmod 700 secrets

# Generate random key
generate_key() {
    openssl rand -base64 32 2>/dev/null || cat /dev/urandom | head -c 32 | base64
}

# Generate Laravel key
generate_laravel_key() {
    echo "base64:$(generate_key)"
}

echo -e "${YELLOW}Generating secure keys...${NC}"

# Create secrets file
cat > secrets/.env.secrets << EOF
# Generated on $(date)
# KEEP THIS FILE SECRET - DO NOT COMMIT TO GIT

# Database
DB_PASSWORD=$(generate_key | tr -d '/+=' | cut -c1-16)

# JWT
JWT_SECRET=$(generate_key)
JWT_REFRESH_SECRET=$(generate_key)

# Service Keys
AUTH_APP_KEY=$(generate_laravel_key)
TENANT_APP_KEY=$(generate_laravel_key)
CRM_APP_KEY=$(generate_laravel_key)
SALES_APP_KEY=$(generate_laravel_key)
FINANCIAL_APP_KEY=$(generate_laravel_key)
OPERATIONS_APP_KEY=$(generate_laravel_key)
COMM_APP_KEY=$(generate_laravel_key)

# Storage
MINIO_ROOT_PASSWORD=$(generate_key | tr -d '/+=' | cut -c1-16)

# RabbitMQ
RABBITMQ_PASSWORD=$(generate_key | tr -d '/+=' | cut -c1-16)

# Redis
REDIS_PASSWORD=$(generate_key | tr -d '/+=' | cut -c1-16)

# Master Key
MASTER_KEY=$(generate_key)
EOF

chmod 600 secrets/.env.secrets

# Create .gitignore for secrets
cat > secrets/.gitignore << EOF
*
!.gitignore
EOF

echo -e "${GREEN}✓ Secrets generated successfully!${NC}"
echo ""
echo "Files created:"
echo "  • secrets/.env.secrets (keep this file secret)"
echo ""
echo "To use with Docker:"
echo "  docker-compose --env-file secrets/.env.secrets up -d"
echo ""
echo -e "${RED}⚠️  Never commit secrets to Git!${NC}"
