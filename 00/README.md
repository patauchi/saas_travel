# Laravel Microservices with stancl/tenancy

A production-ready microservices architecture for SaaS applications using Laravel and stancl/tenancy for multi-tenant support.

## 🏗️ Architecture Overview

This project implements a robust microservices architecture with the following components:

- **Central Management Service**: Manages tenants using stancl/tenancy
- **Auth Service**: Centralized authentication with JWT
- **Sales Service**: Handles sales-related operations
- **Operations Service**: Manages operational workflows
- **API Gateway**: Nginx-based load balancer and reverse proxy
- **PostgreSQL**: Separate databases for central management and tenants
- **Redis**: Caching and session management
- **Queue Workers**: Background job processing

## 📋 Prerequisites

- Docker & Docker Compose
- Git
- 8GB RAM minimum (recommended 16GB)
- 20GB free disk space

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd saas_travel
```

### 2. Initialize the Environment

```bash
chmod +x scripts/init.sh
./scripts/init.sh
```

This script will:
- Generate secure passwords and secrets
- Create necessary directories
- Configure environment files
- Build and start Docker containers
- Set up PostgreSQL databases

### 3. Install Laravel in Services

```bash
chmod +x scripts/install-laravel.sh
./scripts/install-laravel.sh
```

This will install Laravel and required packages in each service.

### 4. Configure Tenancy

```bash
# Access the central management container
docker-compose exec central-management bash

# Install tenancy
php artisan tenancy:install

# Run migrations
php artisan migrate

# Exit container
exit
```

### 5. Create Your First Tenant

```bash
# Using curl
curl -X POST http://localhost:8001/api/tenants \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Corporation",
    "email": "admin@acme.com",
    "domain": "acme.localhost",
    "plan": "premium"
  }'

# Or using Artisan Tinker
docker-compose exec central-management php artisan tinker
>>> $tenant = App\Models\Tenant::create(['id' => 'acme', 'name' => 'Acme Corp']);
>>> $tenant->domains()->create(['domain' => 'acme.localhost']);
```

## 🏢 Project Structure

```
saas_travel/
├── docker-compose.yml           # Docker services configuration
├── nginx/
│   ├── api-gateway.conf        # API Gateway configuration
│   ├── ssl/                    # SSL certificates (production)
│   └── logs/                   # Nginx logs
├── services/
│   ├── central-management/     # Tenant management service
│   ├── auth-service/          # Authentication service
│   ├── sales-service/         # Sales operations
│   └── operations-service/    # Business operations
├── shared/
│   ├── middleware/            # Shared middleware components
│   │   └── TenantResolver.php # Tenant resolution middleware
│   ├── traits/               # Shared PHP traits
│   └── configs/              # Shared configurations
├── scripts/
│   ├── init.sh               # Initial setup script
│   ├── install-laravel.sh    # Laravel installation script
│   ├── backup-tenants.sh     # Database backup script
│   └── postgres-init/        # PostgreSQL initialization
├── secrets/                   # Generated secrets (git-ignored)
└── backups/                  # Database backups
```

## 🔌 Service Endpoints

| Service | Port | Health Check | Description |
|---------|------|--------------|-------------|
| API Gateway | 80 | `/health` | Main entry point |
| Central Management | 8001 | `/health.php` | Tenant management |
| Auth Service | 8002 | `/health.php` | Authentication |
| Sales Service | 8003 | `/health.php` | Sales operations |
| Operations Service | 8004 | `/health.php` | Business operations |
| PostgreSQL Central | 5432 | - | Central database |
| PostgreSQL Tenants | 5433 | - | Tenant databases |
| Redis | 6379 | - | Cache & sessions |
| Mailhog | 8025 | - | Email testing UI |

## 🔐 Security Features

### Authentication & Authorization
- JWT-based authentication
- Service-to-service authentication tokens
- Role-based access control (RBAC)
- Tenant isolation

### Network Security
- Rate limiting per endpoint
- CORS configuration
- Security headers (XSS, CSRF protection)
- Circuit breaker pattern

### Data Security
- Encrypted secrets management
- Database-level tenant isolation
- Secure password storage
- SSL/TLS support (production)

## 📊 Database Architecture

### Central Database
- Manages tenant metadata
- Stores domains and configurations
- Handles billing and plans

### Tenant Databases
- Complete data isolation
- Separate database per tenant
- Automatic provisioning
- Independent migrations

## 🔧 Configuration

### Environment Variables

Each service has its own `.env` file in `services/<service-name>/.env`

Key variables:
- `APP_KEY`: Laravel application key
- `JWT_SECRET`: JWT signing secret
- `SERVICE_TOKEN`: Inter-service authentication
- `REDIS_PASSWORD`: Redis authentication
- `DB_PASSWORD`: PostgreSQL password

### Tenant Configuration

Edit `services/central-management/config/tenancy.php`:

```php
return [
    'tenant_model' => \App\Models\Tenant::class,
    'id_generator' => Stancl\Tenancy\UUIDGenerator::class,
    'database' => [
        'prefix_base' => 'tenant_',
    ],
];
```

## 🛠️ Development

### Accessing Services

```bash
# Enter a service container
docker-compose exec <service-name> bash

# Run Artisan commands
docker-compose exec central-management php artisan migrate

# View logs
docker-compose logs -f <service-name>

# Restart a service
docker-compose restart <service-name>
```

### Adding a New Service

1. Create service directory: `mkdir services/new-service`
2. Copy Dockerfile: `cp services/central-management/Dockerfile services/new-service/`
3. Add to `docker-compose.yml`
4. Configure environment variables
5. Rebuild: `docker-compose build new-service`

### Running Tests

```bash
# Run tests for a specific service
docker-compose exec central-management php artisan test

# Run with coverage
docker-compose exec central-management php artisan test --coverage
```

## 📈 Monitoring & Logging

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f central-management

# Nginx access logs
tail -f nginx/logs/access.log
```

### Health Checks

```bash
# Check all services
curl http://localhost/health
curl http://localhost:8001/health.php
curl http://localhost:8002/health.php
curl http://localhost:8003/health.php
curl http://localhost:8004/health.php
```

### Performance Monitoring

The system includes:
- Request/response time logging
- Database query logging
- Cache hit/miss ratios
- Queue job metrics

## 🔄 Backup & Recovery

### Manual Backup

```bash
./scripts/backup-tenants.sh
```

### Automated Backups

Add to crontab:
```bash
0 2 * * * /path/to/project/scripts/backup-tenants.sh
```

### Restore from Backup

```bash
# Extract backup
tar -xzf backups/backup_TIMESTAMP.tar.gz

# Restore central database
docker exec -i postgres-central psql -U laravel_user central_management < central_TIMESTAMP.sql

# Restore tenant database
docker exec -i postgres-tenants psql -U laravel_user tenant_ID < tenant_ID_TIMESTAMP.sql
```

## 🚀 Production Deployment

### 1. Update Secrets

```bash
# Generate strong passwords
openssl rand -base64 32 > secrets/postgres_password.txt
openssl rand -base64 32 > secrets/jwt_secret.txt
openssl rand -base64 32 > secrets/service_token.txt
```

### 2. Configure SSL

Place SSL certificates in `nginx/ssl/`:
- `cert.pem`: SSL certificate
- `key.pem`: Private key

Uncomment HTTPS configuration in `nginx/api-gateway.conf`

### 3. Environment Configuration

Update `.env` files for production:
- Set `APP_ENV=production`
- Set `APP_DEBUG=false`
- Configure production database credentials
- Set proper APP_URL

### 4. Optimize Laravel

```bash
# For each service
docker-compose exec <service> php artisan config:cache
docker-compose exec <service> php artisan route:cache
docker-compose exec <service> php artisan view:cache
```

### 5. Scale Services

Edit `docker-compose.yml`:
```yaml
services:
  central-management:
    deploy:
      replicas: 3
```

## 🐛 Troubleshooting

### Common Issues

#### Services not starting
```bash
# Check logs
docker-compose logs <service-name>

# Rebuild containers
docker-compose build --no-cache
docker-compose up -d
```

#### Database connection errors
```bash
# Check PostgreSQL is running
docker-compose ps

# Test connection
docker-compose exec postgres-central psql -U laravel_user -d central_management
```

#### Permission errors
```bash
# Fix storage permissions
docker-compose exec <service> chmod -R 777 storage bootstrap/cache
```

#### Redis connection issues
```bash
# Check Redis is running
docker-compose exec redis redis-cli ping

# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL
```

## 📚 API Documentation

### Tenant Management

#### Create Tenant
```http
POST /api/tenants
Content-Type: application/json
X-Service-Token: {service_token}

{
  "name": "Company Name",
  "email": "admin@company.com",
  "domain": "company.localhost",
  "plan": "premium"
}
```

#### Get Tenant
```http
GET /api/tenants/{tenant_id}
X-Service-Token: {service_token}
```

### Authentication

#### Login
```http
POST /api/auth/login
Content-Type: application/json
X-Tenant-ID: {tenant_id}

{
  "email": "user@example.com",
  "password": "password"
}
```

#### Refresh Token
```http
POST /api/auth/refresh
Authorization: Bearer {token}
X-Tenant-ID: {tenant_id}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the [Wiki](wiki-url) for detailed documentation
- Contact the development team

## 🙏 Acknowledgments

- [Laravel](https://laravel.com)
- [stancl/tenancy](https://tenancyforlaravel.com)
- [Docker](https://docker.com)
- [PostgreSQL](https://postgresql.org)
- [Redis](https://redis.io)
- [Nginx](https://nginx.org)

---

Built with ❤️ for scalable SaaS applications