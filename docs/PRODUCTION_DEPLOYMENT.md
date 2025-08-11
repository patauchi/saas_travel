# 🚀 Guía de Despliegue en Producción - VPS

## 📋 Requisitos del VPS

### Especificaciones Mínimas
- **CPU**: 2 vCPUs
- **RAM**: 4 GB (8 GB recomendado)
- **Almacenamiento**: 40 GB SSD
- **OS**: Ubuntu 22.04 LTS
- **Puertos**: 80, 443, 22 (SSH)

### Software Requerido
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instalar herramientas útiles
sudo apt install -y git nginx certbot python3-certbot-nginx ufw fail2ban
```

## 🔐 Configuración de Seguridad

### 1. Configurar Firewall
```bash
# Configurar UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### 2. Configurar Fail2ban
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. Crear usuario de despliegue
```bash
sudo adduser deploy
sudo usermod -aG docker deploy
sudo usermod -aG sudo deploy
```

## 📦 Archivos de Configuración para Producción

### 1. docker-compose.prod.yml
```yaml
version: '3.9'

networks:
  vtravel-network:
    driver: bridge

volumes:
  postgres-landlord-data:
  postgres-tenant-data:
  redis-data:
  rabbitmq-data:
  minio-data:
  app-storage:

services:
  # Nginx - API Gateway
  nginx:
    image: vtravel-nginx:latest
    container_name: vtravel-nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.prod.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./frontend:/usr/share/nginx/html/frontend:ro
    networks:
      - vtravel-network
    depends_on:
      - auth-service
      - tenant-service

  # PostgreSQL - Landlord Database
  postgres-landlord:
    image: postgres:15-alpine
    container_name: vtravel-postgres-landlord
    restart: always
    environment:
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_LANDLORD_DATABASE}
      POSTGRES_MAX_CONNECTIONS: 200
    volumes:
      - postgres-landlord-data:/var/lib/postgresql/data
    networks:
      - vtravel-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Auth Service
  auth-service:
    image: vtravel-auth-service:latest
    container_name: vtravel-auth
    restart: always
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
      APP_KEY: ${AUTH_APP_KEY}
      DB_HOST: postgres-landlord
      DB_DATABASE: ${DB_LANDLORD_DATABASE}
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      REDIS_HOST: redis
    networks:
      - vtravel-network
    volumes:
      - app-storage:/var/www/html/storage
    depends_on:
      - postgres-landlord
      - redis

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: vtravel-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis-data:/data
    networks:
      - vtravel-network
```

### 2. .env.production
```env
# Application
APP_NAME=VTravel
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

# Database
DB_USERNAME=vtravel_prod
DB_PASSWORD=CHANGE_THIS_STRONG_PASSWORD
DB_LANDLORD_DATABASE=vtravel_landlord
DB_TENANT_DATABASE=vtravel_tenants

# Redis
REDIS_PASSWORD=CHANGE_THIS_STRONG_PASSWORD

# JWT
JWT_SECRET=CHANGE_THIS_GENERATE_WITH_OPENSSL

# RabbitMQ
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=CHANGE_THIS_STRONG_PASSWORD

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=CHANGE_THIS_STRONG_PASSWORD

# App Keys (generate with: openssl rand -base64 32)
AUTH_APP_KEY=base64:GENERATE_THIS
TENANT_APP_KEY=base64:GENERATE_THIS
```

### 3. nginx.prod.conf
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # Frontend
    location / {
        root /usr/share/nginx/html/frontend;
        try_files $uri $uri/ /index.html;
    }

    # API Gateway
    location /api {
        proxy_pass http://nginx:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🚀 Proceso de Despliegue

### 1. Preparación Inicial
```bash
# Conectar al VPS
ssh deploy@your-vps-ip

# Clonar repositorio
git clone https://github.com/patauchi/saas_travel.git
cd saas_travel

# Crear archivo de environment
cp .env.production .env
nano .env  # Editar con valores seguros

# Generar secrets
openssl rand -base64 32  # Para APP_KEY
openssl rand -base64 32  # Para JWT_SECRET
```

### 2. Construir Imágenes
```bash
# Construir para producción
docker-compose -f docker-compose.prod.yml build

# O usar imágenes pre-construidas
./scripts/build-production.sh
```

### 3. Configurar SSL con Let's Encrypt
```bash
# Instalar certificado SSL
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renovación
sudo systemctl enable certbot.timer
```

### 4. Iniciar Servicios
```bash
# Iniciar en modo producción
docker-compose -f docker-compose.prod.yml up -d

# Verificar estado
docker-compose -f docker-compose.prod.yml ps

# Ver logs
docker-compose -f docker-compose.prod.yml logs -f
```

### 5. Ejecutar Migraciones
```bash
# Migraciones de base de datos
docker exec vtravel-auth php artisan migrate --force
docker exec vtravel-tenant php artisan migrate --force

# Crear usuario admin
docker exec vtravel-auth php artisan tinker
>>> \App\Models\User::create(['email' => 'admin@yourdomain.com', 'password' => bcrypt('secure_password'), 'role' => 'super_admin']);
```

## 📊 Monitoreo y Mantenimiento

### 1. Script de Monitoreo
```bash
#!/bin/bash
# monitor.sh

# Check services
docker-compose -f docker-compose.prod.yml ps

# Check disk usage
df -h

# Check memory
free -m

# Check logs for errors
docker-compose -f docker-compose.prod.yml logs --tail=50 | grep ERROR

# Health check
curl -s https://yourdomain.com/health | jq .
```

### 2. Backups Automatizados
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/vtravel"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup databases
docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord | gzip > $BACKUP_DIR/landlord_$DATE.sql.gz
docker exec vtravel-postgres-tenant pg_dump -U vtravel vtravel_tenants | gzip > $BACKUP_DIR/tenants_$DATE.sql.gz

# Backup files
tar -czf $BACKUP_DIR/files_$DATE.tar.gz ./frontend ./nginx

# Upload to S3 (opcional)
aws s3 cp $BACKUP_DIR/ s3://your-backup-bucket/ --recursive

# Clean old backups (keep 30 days)
find $BACKUP_DIR -type f -mtime +30 -delete
```

### 3. Cron Jobs
```bash
# Editar crontab
crontab -e

# Backup diario a las 2 AM
0 2 * * * /home/deploy/saas_travel/scripts/backup.sh

# Limpieza de logs cada semana
0 3 * * 0 docker exec vtravel-auth php artisan log:clear

# Health check cada 5 minutos
*/5 * * * * curl -s https://yourdomain.com/health || echo "Health check failed" | mail -s "VTravel Alert" admin@yourdomain.com
```

## 🔧 Optimizaciones para Producción

### 1. Docker Optimizations
```yaml
# En docker-compose.prod.yml
services:
  auth-service:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 2. PHP Optimizations
```bash
# En el Dockerfile de producción
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache
RUN composer install --optimize-autoloader --no-dev
```

### 3. Database Optimizations
```sql
-- Índices importantes
CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_domain ON tenants(domain);
```

## 🚨 Troubleshooting

### Problema: Servicios no inician
```bash
# Ver logs detallados
docker-compose -f docker-compose.prod.yml logs [service-name]

# Reiniciar servicio específico
docker-compose -f docker-compose.prod.yml restart [service-name]
```

### Problema: Memoria insuficiente
```bash
# Crear swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Problema: Disco lleno
```bash
# Limpiar Docker
docker system prune -a -f
docker volume prune -f

# Limpiar logs
truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

## 📈 Escalamiento

### Escalamiento Vertical
1. Aumentar recursos del VPS
2. Optimizar configuraciones de Docker
3. Usar CDN para assets estáticos

### Escalamiento Horizontal
1. Load Balancer (Nginx/HAProxy)
2. Múltiples instancias de servicios
3. Base de datos en cluster (PostgreSQL replication)
4. Redis Cluster
5. Kubernetes para orquestación

## 🔐 Checklist de Seguridad

- [ ] Cambiar todas las contraseñas por defecto
- [ ] Configurar SSL/TLS
- [ ] Habilitar firewall
- [ ] Configurar fail2ban
- [ ] Deshabilitar root SSH
- [ ] Usar SSH keys en lugar de passwords
- [ ] Configurar backups automáticos
- [ ] Monitoreo activo
- [ ] Rate limiting configurado
- [ ] Secrets en variables de entorno
- [ ] Logs centralizados
- [ ] Actualizaciones de seguridad automáticas

## 📞 Comandos Útiles en Producción

```bash
# Ver estado general
make -f Makefile.prod status

# Reiniciar servicios sin downtime
make -f Makefile.prod rolling-restart

# Backup inmediato
make -f Makefile.prod backup

# Ver métricas
make -f Makefile.prod metrics

# Ejecutar mantenimiento
make -f Makefile.prod maintenance-on
make -f Makefile.prod maintenance-off
```

## 🎯 Performance Benchmarks

Objetivos de rendimiento:
- Tiempo de respuesta API: < 200ms
- Uptime: 99.9%
- Concurrent users: 1000+
- Database queries: < 50ms
- Page load time: < 2s

---

**Importante**: Siempre prueba los cambios en staging antes de producción!