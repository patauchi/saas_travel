# 🚀 VTravel SaaS Platform - Guía de Implementación Completa

## 📋 Tabla de Contenidos

1. [Descripción General](#descripción-general)
2. [Requisitos Previos](#requisitos-previos)
3. [Arquitectura del Sistema](#arquitectura-del-sistema)
4. [Instalación Paso a Paso](#instalación-paso-a-paso)
5. [Configuración de Servicios](#configuración-de-servicios)
6. [Verificación de la Instalación](#verificación-de-la-instalación)
7. [Solución de Problemas](#solución-de-problemas)
8. [Mantenimiento y Operaciones](#mantenimiento-y-operaciones)

## 📖 Descripción General

VTravel SaaS es una plataforma multi-tenant completa para agencias de viajes, construida con arquitectura de microservicios usando Docker, Laravel, PostgreSQL y tecnologías modernas de desarrollo web.

### Características Principales

- **Multi-tenancy**: Cada agencia tiene su propio subdominio y base de datos aislada
- **Microservicios**: Arquitectura modular con servicios independientes
- **Monitoreo en tiempo real**: Sistema de health check para todos los servicios
- **Escalabilidad**: Diseñado para crecer horizontalmente
- **Seguridad**: Aislamiento de datos por tenant, autenticación JWT

### Módulos del Sistema

- **CRM**: Gestión de contactos, leads y oportunidades
- **Ventas**: Cotizaciones, órdenes y servicios
- **Operaciones**: Bookings, proveedores y reviews
- **Finanzas**: Facturación, pagos y gastos
- **Comunicación**: Chat interno y mensajería multi-canal

## 🔧 Requisitos Previos

### Software Requerido

```bash
# Verificar versiones instaladas
docker --version          # Docker version 24.0+ requerido
docker-compose --version   # Docker Compose version 2.20+ requerido
make --version            # GNU Make 3.81+ requerido
git --version             # Git 2.30+ requerido
```

### Requisitos del Sistema

- **Sistema Operativo**: macOS, Linux o Windows con WSL2
- **RAM**: Mínimo 4GB disponibles para Docker
- **Almacenamiento**: 10GB de espacio libre
- **CPU**: 2 cores mínimo, 4 cores recomendado

### Puertos Requeridos

Asegúrese de que los siguientes puertos estén disponibles:

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| 80 | Nginx | Gateway principal (opcional) |
| 3000 | Health Service | Dashboard de monitoreo |
| 5432 | PostgreSQL Landlord | Base de datos principal |
| 5433 | PostgreSQL Tenant | Base de datos de tenants |
| 6379 | Redis | Cache y sesiones |
| 9000 | MinIO | Almacenamiento S3 |
| 9001-9007 | Microservicios | Servicios Laravel |
| 9010 | MinIO Console | Consola de administración |
| 15672 | RabbitMQ | Panel de administración |

## 🏗️ Arquitectura del Sistema

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                      Clientes (Web/Mobile)                  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     NGINX (API Gateway)                     │
│                    Puerto 80 (opcional)                     │
└─────────────────────────────────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│Health Service│     │Microservicios│     │  Frontend    │
│   (3000)     │     │ (9001-9007)  │     │   Apps       │
└──────────────┘     └──────────────┘     └──────────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Capa de Datos                            │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│PostgreSQL│PostgreSQL│  Redis   │RabbitMQ  │    MinIO      │
│ Landlord │  Tenant  │  (6379)  │ (5672)   │   (9000)      │
│  (5432)  │  (5433)  │          │          │               │
└──────────┴──────────┴──────────┴──────────┴────────────────┘
```

### Componentes del Sistema

#### Servicios de Infraestructura

1. **PostgreSQL Landlord** (puerto 5432)
   - Base de datos central
   - Gestión de tenants y suscripciones
   - Configuración del sistema

2. **PostgreSQL Tenant** (puerto 5433)
   - Bases de datos aisladas por tenant
   - Datos de negocio de cada agencia

3. **Redis** (puerto 6379)
   - Cache de aplicación
   - Gestión de sesiones
   - Colas de trabajos ligeros

4. **RabbitMQ** (puertos 5672, 15672)
   - Mensajería entre servicios
   - Procesamiento asíncrono
   - Event sourcing

5. **MinIO** (puertos 9000, 9010)
   - Almacenamiento de archivos
   - Compatible con S3
   - Backup de documentos

#### Microservicios de Negocio

1. **Auth Service** (puerto 9001)
   - Autenticación JWT
   - Gestión de usuarios
   - Control de acceso

2. **Tenant Service** (puerto 9002)
   - Gestión de agencias
   - Provisioning de recursos
   - Planes y suscripciones

3. **CRM Service** (puerto 9003)
   - Gestión de contactos
   - Leads y oportunidades
   - Pipeline de ventas

4. **Sales Service** (puerto 9004)
   - Cotizaciones
   - Órdenes de venta
   - Catálogo de servicios

5. **Financial Service** (puerto 9005)
   - Facturación
   - Gestión de pagos
   - Control de gastos

6. **Operations Service** (puerto 9006)
   - Gestión de bookings
   - Control de proveedores
   - Logística operativa

7. **Communication Service** (puerto 9007)
   - Chat interno
   - Integración multi-canal
   - Notificaciones

#### Sistema de Monitoreo

**Health Service** (puerto 3000)
- Dashboard de salud en tiempo real
- Monitoreo de todos los servicios
- Alertas y métricas
- API de health checks

## 📦 Instalación Paso a Paso

### Paso 1: Clonar o Crear el Proyecto

```bash
# Opción A: Si ya tienes el proyecto
cd /Users/pjoser/Dropbox/ZS/Sites/saas_travel

# Opción B: Clonar desde repositorio
git clone https://github.com/tu-usuario/saas_travel.git
cd saas_travel
```

### Paso 2: Crear Estructura de Directorios

```bash
# Crear estructura completa de directorios
mkdir -p services/{auth,tenant,crm,sales,financial,operations,communication}-service/{app,database,routes}
mkdir -p infrastructure/{postgres/init/{landlord,tenant},redis,rabbitmq}
mkdir -p frontend/{web-app,admin-app,mobile-app}
mkdir -p monitoring/{grafana,prometheus,loki}
mkdir -p nginx/{conf.d,ssl}
mkdir -p scripts/{docker,database,setup}
mkdir -p secrets backups logs
```

### Paso 3: Configurar Variables de Entorno

```bash
# Crear archivo .env desde el ejemplo
cat > .env << 'EOF'
# Application
APP_NAME=VTravel
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost
APP_DOMAIN=localhost

# Database Configuration
DB_USERNAME=vtravel
DB_PASSWORD=vtravel123
DB_HOST=postgres-landlord
DB_PORT=5432

# Tenant Database Configuration
TENANT_DB_HOST=postgres-tenant
TENANT_DB_PORT=5432
TENANT_DB_PREFIX=tenant_

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# RabbitMQ Configuration
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin123

# MinIO Storage Configuration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123
MINIO_ENDPOINT=http://minio:9000
MINIO_USE_SSL=false
MINIO_BUCKET=vtravel

# JWT Configuration
JWT_SECRET=jwt_secret_key_123456789_vtravel_saas_platform
JWT_REFRESH_SECRET=jwt_refresh_secret_key_987654321_vtravel
JWT_TTL=60
JWT_REFRESH_TTL=20160

# Service Keys
AUTH_APP_KEY=base64:YXV0aHNlcnZpY2VrZXkxMjM0NTY3ODkwYWJjZGVmZ2hpams=
TENANT_APP_KEY=base64:dGVuYW50c2VydmljZWtleTEyMzQ1Njc4OTBhYmNkZWZnaGlqaw==
CRM_APP_KEY=base64:Y3Jtc2VydmljZWtleTEyMzQ1Njc4OTBhYmNkZWZnaGlqaw==
SALES_APP_KEY=base64:c2FsZXNzZXJ2aWNla2V5MTIzNDU2Nzg5MGFiY2RlZmdoaWpr
FINANCIAL_APP_KEY=base64:ZmluYW5jaWFsc2VydmljZWtleTEyMzQ1Njc4OTBhYmNkZWZn
OPERATIONS_APP_KEY=base64:b3BlcmF0aW9uc3NlcnZpY2VrZXkxMjM0NTY3ODkwYWJjZGVm
COMM_APP_KEY=base64:Y29tbXVuaWNhdGlvbnNlcnZpY2VrZXkxMjM0NTY3ODkwYWJj

# Development Settings
COMPOSE_PROJECT_NAME=vtravel
NODE_ENV=development
EOF
```

### Paso 4: Crear Archivos de Configuración Base

#### 4.1 Docker Compose Principal

```bash
# El archivo docker-compose.yml ya debe existir con la configuración completa
# Si no existe, créalo con el contenido proporcionado en el proyecto
```

#### 4.2 Makefile para Comandos

```bash
# El Makefile ya debe existir con todos los comandos útiles
# Verificar que existe con:
ls -la Makefile
```

#### 4.3 Health Service

```bash
# Instalar dependencias del Health Service
cd services/health-service
npm init -y
npm install express axios cors helmet pg redis amqplib winston express-rate-limit

# Volver al directorio raíz
cd ../..
```

#### 4.4 Dockerfiles para Servicios PHP

```bash
# Crear Dockerfile base para servicios PHP
cat > services/shared/Dockerfile.base << 'EOF'
FROM php:8.2-cli-alpine

RUN apk add --no-cache curl postgresql-dev \
    && docker-php-ext-install pdo pdo_pgsql \
    && apk del postgresql-dev \
    && rm -rf /var/cache/apk/*

WORKDIR /var/www/html

RUN echo '<?php \
header("Content-Type: application/json"); \
$service = getenv("SERVICE_NAME") ?: "unknown"; \
echo json_encode(["status" => "healthy", "service" => $service, "timestamp" => date("c")]); \
?>' > /var/www/html/health.php

EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/health.php || exit 1

CMD ["php", "-S", "0.0.0.0:9000", "-t", "/var/www/html"]
EOF

# Copiar Dockerfile base a todos los servicios
for service in auth tenant crm sales financial operations communication; do
    cp services/shared/Dockerfile.base services/${service}-service/Dockerfile
done
```

### Paso 5: Construir Imágenes Docker

```bash
# Construir todas las imágenes
docker-compose build --no-cache

# O usar Make
make build-no-cache
```

### Paso 6: Iniciar Servicios

```bash
# Iniciar servicios de infraestructura primero
docker-compose up -d postgres-landlord postgres-tenant redis rabbitmq minio

# Esperar a que estén listos (30 segundos aproximadamente)
sleep 30

# Iniciar health service
docker-compose up -d health-service

# Verificar que los servicios básicos estén funcionando
curl http://localhost:3000/health

# Iniciar microservicios (opcional, si tienes los Dockerfiles configurados)
docker-compose up -d auth-service tenant-service crm-service sales-service financial-service operations-service communication-service
```

## ✅ Verificación de la Instalación

### Verificación Rápida

```bash
# Usar el comando Make
make health

# O verificar manualmente
curl -s http://localhost:3000/health/services | python3 -m json.tool
```

### Verificación Detallada por Servicio

#### 1. PostgreSQL Landlord

```bash
# Verificar conexión
docker exec -it vtravel-postgres-landlord psql -U vtravel -c "SELECT version();"

# Verificar health check
curl http://localhost:3000/health/postgres-landlord
```

#### 2. PostgreSQL Tenant

```bash
# Verificar conexión
docker exec -it vtravel-postgres-tenant psql -U vtravel -c "SELECT version();"

# Verificar health check
curl http://localhost:3000/health/postgres-tenant
```

#### 3. Redis

```bash
# Verificar conexión
docker exec -it vtravel-redis redis-cli ping

# Verificar health check
curl http://localhost:3000/health/redis
```

#### 4. RabbitMQ

```bash
# Verificar panel de administración
open http://localhost:15672
# Usuario: admin
# Contraseña: admin123

# Verificar health check
curl http://localhost:3000/health/rabbitmq
```

#### 5. MinIO

```bash
# Verificar consola
open http://localhost:9010
# Usuario: minioadmin
# Contraseña: minioadmin123

# Verificar health check
curl http://localhost:3000/health/minio
```

### Dashboard de Salud Completo

```bash
# Ver estado de todos los servicios en formato legible
curl -s http://localhost:3000/health/services | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('='*50)
print(f'Estado General: {data[\"status\"].upper()}')
print(f'Ambiente: {data[\"environment\"]}')
print('='*50)
print(f'Total de Servicios: {data[\"summary\"][\"total\"]}')
print(f'Saludables: {data[\"summary\"][\"healthy\"]}')
print(f'No Saludables: {data[\"summary\"][\"unhealthy\"]}')
print('='*50)
print('\nServicios Saludables:')
for k,v in data['services'].items():
    if v['status'] == 'healthy':
        print(f'  ✓ {v[\"name\"]} ({k})')
print('\nServicios No Disponibles:')
for k,v in data['services'].items():
    if v['status'] != 'healthy':
        print(f'  ✗ {v[\"name\"]} ({k}): {v[\"message\"]}')
"
```

## 🔧 Comandos Útiles

### Gestión de Servicios

```bash
# Iniciar todos los servicios
make up

# Detener todos los servicios
make down

# Reiniciar servicios
make restart

# Ver estado de contenedores
make ps

# Ver logs en tiempo real
make logs

# Ver logs de un servicio específico
docker logs -f vtravel-postgres-landlord
```

### Acceso a Bases de Datos

```bash
# Conectar a PostgreSQL Landlord
make db-landlord
# O directamente:
docker exec -it vtravel-postgres-landlord psql -U vtravel -d vtravel_landlord

# Conectar a PostgreSQL Tenant
make db-tenant
# O directamente:
docker exec -it vtravel-postgres-tenant psql -U vtravel -d tenant_template

# Conectar a Redis
make redis-cli
# O directamente:
docker exec -it vtravel-redis redis-cli
```

### Limpieza y Mantenimiento

```bash
# Limpiar contenedores detenidos
make clean

# Eliminar todo (CUIDADO: borra datos)
make clean-all

# Hacer backup de bases de datos
make backup

# Ver uso de recursos
make stats
```

## 🚨 Solución de Problemas

### Problema: Puerto 80 en uso

```bash
# Verificar qué está usando el puerto
lsof -i :80

# Solución 1: Detener el servicio que usa el puerto
sudo nginx -s stop  # Si es nginx local

# Solución 2: Cambiar el puerto en docker-compose.yml
# Cambiar "80:80" por "8080:80" en el servicio nginx
```

### Problema: Servicios no inician

```bash
# Verificar logs del servicio problemático
docker logs vtravel-[nombre-servicio]

# Verificar recursos de Docker
docker system df
docker stats

# Limpiar recursos no utilizados
docker system prune -a
```

### Problema: Base de datos no conecta

```bash
# Verificar que el servicio esté corriendo
docker ps | grep postgres

# Verificar conectividad
docker exec -it vtravel-postgres-landlord pg_isready

# Verificar logs
docker logs vtravel-postgres-landlord

# Reiniciar servicio
docker-compose restart postgres-landlord
```

### Problema: Health Service reporta servicios como unhealthy

```bash
# Verificar que el servicio esté corriendo
docker ps

# Verificar conectividad de red
docker network ls
docker network inspect vtravel_vtravel-network

# Verificar que los servicios estén en la misma red
docker inspect [container-name] | grep NetworkMode
```

## 📊 Monitoreo y Mantenimiento

### Monitoreo en Tiempo Real

```bash
# Dashboard de salud
open http://localhost:3000/health/services

# Métricas para Prometheus
curl http://localhost:3000/metrics

# Logs centralizados
docker-compose logs -f --tail=100
```

### Backup y Restauración

#### Backup de Bases de Datos

```bash
# Crear directorio de backups
mkdir -p backups

# Backup de PostgreSQL Landlord
docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord > backups/landlord_$(date +%Y%m%d_%H%M%S).sql

# Backup de PostgreSQL Tenant
docker exec vtravel-postgres-tenant pg_dump -U vtravel tenant_template > backups/tenant_$(date +%Y%m%d_%H%M%S).sql

# Backup de Redis
docker exec vtravel-redis redis-cli SAVE
docker cp vtravel-redis:/data/dump.rdb backups/redis_$(date +%Y%m%d_%H%M%S).rdb
```

#### Restauración

```bash
# Restaurar PostgreSQL Landlord
docker exec -i vtravel-postgres-landlord psql -U vtravel vtravel_landlord < backups/landlord_YYYYMMDD_HHMMSS.sql

# Restaurar PostgreSQL Tenant
docker exec -i vtravel-postgres-tenant psql -U vtravel tenant_template < backups/tenant_YYYYMMDD_HHMMSS.sql

# Restaurar Redis
docker cp backups/redis_YYYYMMDD_HHMMSS.rdb vtravel-redis:/data/dump.rdb
docker restart vtravel-redis
```

### Actualización de Servicios

```bash
# Actualizar un servicio específico
docker-compose build [service-name]
docker-compose up -d [service-name]

# Actualizar todos los servicios
docker-compose build
docker-compose up -d

# Verificar que todo funcione después de actualizar
make health
```

## 🔐 Seguridad

### Credenciales por Defecto

**IMPORTANTE**: Cambiar estas credenciales en producción

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| PostgreSQL | vtravel | vtravel123 |
| RabbitMQ | admin | admin123 |
| MinIO | minioadmin | minioadmin123 |

### Cambiar Credenciales

1. Actualizar el archivo `.env` con nuevas credenciales
2. Recrear los contenedores:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Configuración de SSL/TLS

Para producción, configurar certificados SSL:

```bash
# Generar certificados con Let's Encrypt
docker run -it --rm \
  -v ./nginx/ssl:/etc/letsencrypt \
  certbot/certbot certonly \
  --standalone \
  -d tu-dominio.com
```

## 📈 Escalamiento

### Escalamiento Horizontal

```bash
# Escalar un servicio específico
docker-compose up -d --scale crm-service=3

# Verificar instancias
docker ps | grep crm-service
```

### Configuración para Producción

1. Usar Docker Swarm o Kubernetes
2. Configurar load balancer externo
3. Implementar cache distribuido
4. Configurar réplicas de base de datos
5. Implementar monitoreo avanzado con Prometheus + Grafana

## 📚 Referencias y Recursos

### Documentación Oficial

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [PostgreSQL](https://www.postgresql.org/docs/)
- [Redis](https://redis.io/documentation)
- [RabbitMQ](https://www.rabbitmq.com/documentation.html)
- [MinIO](https://docs.min.io/)

### Comandos de Emergencia

```bash
# Detener todo inmediatamente
docker stop $(docker ps -q)

# Eliminar todos los contenedores
docker rm $(docker ps -a -q)

# Eliminar todas las imágenes
docker rmi $(docker images -q)

# Reiniciar Docker
# En macOS:
killall Docker && open /Applications/Docker.app

# En Linux:
sudo systemctl restart docker
```

## 🎯 Checklist de Implementación

- [ ] Requisitos del sistema verificados
- [ ] Docker y Docker Compose instalados
- [ ] Puertos disponibles verificados
- [ ] Estructura de directorios creada
- [ ] Archivo `.env` configurado
- [ ] Imágenes Docker construidas
- [ ] Servicios de infraestructura iniciados
- [ ] Health Service funcionando
- [ ] Dashboard de salud accesible
- [ ] Bases de datos verificadas
- [ ] Redis conectado
- [ ] RabbitMQ panel accesible
- [ ] MinIO consola funcionando
- [ ] Backup inicial realizado
- [ ] Documentación revisada

## 🆘 Soporte

Si encuentras problemas durante la implementación:

1. Revisa los logs del servicio afectado
2. Verifica el dashboard de salud
3. Consulta la sección de solución de problemas
4. Verifica que todos los servicios estén en la misma red Docker
5. Asegúrate de que los puertos no estén en uso

---

**Última actualización**: Agosto 2024  
**Versión**: 1.0.0  
**Autor**: VTravel Development Team