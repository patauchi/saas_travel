# VTravel SaaS Platform

A comprehensive multi-tenant SaaS platform for travel agencies built with Docker, Laravel microservices, and modern web technologies.

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose installed
- Make command available (optional but recommended)
- At least 4GB of RAM available for Docker
- Ports 80, 443, 3000, 5432, 5433, 6379, 9000-9010 available

### Setup & Run

1. **Clone the repository** (if not already done):
```bash
cd /Users/pjoser/Dropbox/ZS/Sites/saas_travel
```

2. **Initial setup** (first time only):
```bash
# Using Make (recommended)
make setup

# Or manually
cp .env.example .env
docker-compose build --no-cache
```

3. **Start all services**:
```bash
# Using Make
make up

# Or using Docker Compose directly
docker-compose up -d
```

4. **Check services health**:
```bash
# Using Make
make health

# Or directly via curl
curl http://localhost:3000/health/services | python3 -m json.tool
```

## 📊 Service Health Dashboard

Once all services are running, you can access the health dashboard at:
- **Health Check**: http://localhost:3000/health
- **Detailed Services Status**: http://localhost:3000/health/services
- **Individual Service**: http://localhost:3000/health/{service-name}

## 🏗️ Architecture Overview

### Microservices

| Service | Port | Description | Health Check |
|---------|------|-------------|--------------|
| **Nginx Gateway** | 80, 443 | API Gateway & Reverse Proxy | http://localhost/health |
| **Health Service** | 3000 | System monitoring & health checks | http://localhost:3000/health |
| **Auth Service** | 9001 | Authentication & authorization | http://localhost:9001/health |
| **Tenant Service** | 9002 | Multi-tenancy management | http://localhost:9002/health |
| **CRM Service** | 9003 | Customer relationship management | http://localhost:9003/health |
| **Sales Service** | 9004 | Quotes, orders & sales | http://localhost:9004/health |
| **Financial Service** | 9005 | Invoicing & payments | http://localhost:9005/health |
| **Operations Service** | 9006 | Bookings & operations | http://localhost:9006/health |
| **Communication Service** | 9007 | Chat, inbox & notifications | http://localhost:9007/health |

### Infrastructure Services

| Service | Port | Description | Credentials |
|---------|------|-------------|-------------|
| **PostgreSQL Landlord** | 5432 | Central database | vtravel / vtravel123 |
| **PostgreSQL Tenant** | 5433 | Tenant databases | vtravel / vtravel123 |
| **Redis** | 6379 | Cache & sessions | No auth |
| **RabbitMQ** | 5672, 15672 | Message queue | admin / admin123 |
| **MinIO** | 9000, 9010 | Object storage | minioadmin / minioadmin123 |

## 🛠️ Common Commands

### Using Make (Recommended)

```bash
# Service Management
make up              # Start all services
make down            # Stop all services
make restart         # Restart all services
make ps             # Show container status
make logs           # Show all logs
make health         # Check health status

# Database Access
make db-landlord    # Connect to landlord database
make db-tenant      # Connect to tenant database
make redis-cli      # Connect to Redis CLI

# Service Logs
make logs-auth      # Auth service logs
make logs-nginx     # Nginx logs
make logs-db        # Database logs

# Development
make shell-auth     # Shell into auth service
make shell-health   # Shell into health service

# Cleanup
make clean          # Clean up Docker resources
make clean-all      # WARNING: Remove everything including data
```

### Direct Docker Commands

```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Stop services
docker-compose down

# Rebuild services
docker-compose build [service-name]
```

## 🔍 Health Check API

### Check All Services
```bash
curl http://localhost:3000/health/services
```

### Check Specific Service
```bash
curl http://localhost:3000/health/postgres-landlord
curl http://localhost:3000/health/redis
curl http://localhost:3000/health/auth-service
```

### Response Format
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "services": {
    "postgres-landlord": {
      "status": "healthy",
      "name": "PostgreSQL Landlord",
      "type": "database",
      "message": "Connected successfully"
    },
    "redis": {
      "status": "healthy",
      "name": "Redis Cache",
      "type": "cache",
      "message": "Connected successfully"
    }
  },
  "summary": {
    "total": 11,
    "healthy": 11,
    "unhealthy": 0
  }
}
```

## 🌐 Multi-Tenant Architecture

The platform supports multiple tenants with isolated databases:

1. **Main domain**: `vtravel.com` (Landing page)
2. **Tenant subdomains**: `{tenant}.vtravel.com` (Tenant applications)
3. **Admin panel**: `admin.vtravel.com` (System administration)

### Creating a New Tenant

```bash
# Using Make
make create-tenant NAME=agency1

# Or directly
docker exec -it vtravel-tenant php artisan tenant:create agency1
```

## 📦 Project Structure

```
saas_travel/
├── docker-compose.yml       # Main Docker configuration
├── .env                     # Environment variables
├── Makefile                # Convenient commands
├── nginx/                  # Nginx gateway configuration
├── services/               # Microservices
│   ├── health-service/     # System health monitoring
│   ├── auth-service/       # Authentication service
│   ├── tenant-service/     # Tenant management
│   ├── crm-service/        # CRM module
│   ├── sales-service/      # Sales module
│   ├── financial-service/  # Financial module
│   ├── operations-service/ # Operations module
│   └── communication-service/ # Communication module
├── frontend/               # Frontend applications
├── infrastructure/         # Infrastructure configs
└── monitoring/            # Monitoring tools
```

## 🔧 Troubleshooting

### Services not starting

1. Check if ports are available:
```bash
lsof -i :80 -i :3000 -i :5432 -i :6379
```

2. Check Docker logs:
```bash
docker-compose logs [service-name]
```

3. Verify Docker resources:
```bash
docker system df
docker stats
```

### Database connection issues

1. Wait for databases to be ready:
```bash
# Check PostgreSQL status
docker exec vtravel-postgres-landlord pg_isready
docker exec vtravel-postgres-tenant pg_isready
```

2. Verify credentials in `.env` file

### Health check failures

1. Check individual service health:
```bash
curl http://localhost:3000/health/[service-name]
```

2. Restart problematic service:
```bash
docker-compose restart [service-name]
```

## 📱 Admin Panels

- **RabbitMQ Management**: http://localhost:15672 (admin/admin123)
- **MinIO Console**: http://localhost:9010 (minioadmin/minioadmin123)
- **Health Dashboard**: http://localhost:3000/health/services

## 🔐 Security

- All passwords are stored in `.env` file
- JWT tokens for API authentication
- SSL/TLS support configured in Nginx
- Rate limiting enabled on API endpoints
- CORS configured for API access

## 📝 API Documentation

API endpoints are available through the Nginx gateway:

- Auth: `http://localhost/api/auth/*`
- Tenant: `http://localhost/api/tenant/*`
- CRM: `http://localhost/api/crm/*`
- Sales: `http://localhost/api/sales/*`
- Financial: `http://localhost/api/financial/*`
- Operations: `http://localhost/api/operations/*`
- Communication: `http://localhost/api/communication/*`

## 🚦 Development Workflow

1. **Make changes** to service code
2. **Rebuild** the affected service:
   ```bash
   docker-compose build [service-name]
   ```
3. **Restart** the service:
   ```bash
   docker-compose restart [service-name]
   ```
4. **Check logs** for errors:
   ```bash
   docker-compose logs -f [service-name]
   ```

## 📊 Monitoring

The platform includes comprehensive monitoring:

- **Health checks** for all services
- **Prometheus metrics** at `/metrics`
- **Structured JSON logging**
- **Activity and audit logs**

## 🆘 Support

For issues or questions:
1. Check the health dashboard first
2. Review service logs
3. Verify environment configuration
4. Check Docker resource usage

## 📄 License

Proprietary - VTravel SaaS Platform

---

**Version**: 1.0.0  
**Last Updated**: 2024