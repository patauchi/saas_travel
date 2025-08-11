# 🚀 VTravel SaaS - Guía de Inicio Rápido

## ⚡ Instalación en 5 Minutos

### Prerequisitos
- Docker Desktop instalado y ejecutándose
- 4GB RAM disponible
- Puertos libres: 3000, 5432, 5433, 6379, 9000-9010, 15672

### Paso 1: Clonar/Preparar el Proyecto
```bash
cd /Users/pjoser/Dropbox/ZS/Sites/saas_travel
# O clonar: git clone [tu-repositorio] saas_travel && cd saas_travel
```

### Paso 2: Configuración Inicial
```bash
# Crear estructura de directorios
mkdir -p services/{health-service,auth-service,tenant-service,crm-service,sales-service,financial-service,operations-service,communication-service}/{app,database,routes}
mkdir -p infrastructure/{postgres/init/{landlord,tenant},redis,rabbitmq}
mkdir -p nginx/{conf.d,ssl}
mkdir -p secrets backups logs

# Crear archivo de variables de entorno
cat > .env << 'EOF'
COMPOSE_PROJECT_NAME=vtravel
DB_USERNAME=vtravel
DB_PASSWORD=vtravel123
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin123
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123
JWT_SECRET=jwt_secret_key_123456789
EOF
```

### Paso 3: Preparar Health Service
```bash
cd services/health-service
npm init -y
npm install express axios cors helmet pg redis amqplib winston express-rate-limit
cd ../..
```

### Paso 4: Levantar Servicios
```bash
# Construir imágenes
docker-compose build

# Iniciar servicios de infraestructura
docker-compose up -d postgres-landlord postgres-tenant redis rabbitmq minio health-service

# Esperar 30 segundos para que los servicios estén listos
sleep 30
```

### Paso 5: Verificar Instalación
```bash
# Verificar salud del sistema
curl http://localhost:3000/health

# Ver dashboard completo
curl -s http://localhost:3000/health/services | python3 -m json.tool | head -20
```

## ✅ Verificación Rápida

### Panel de Control de Salud
```bash
open http://localhost:3000/health/services
```

### Servicios y Accesos

| Servicio | URL/Puerto | Usuario | Contraseña | Estado |
|----------|------------|---------|------------|--------|
| **Health Dashboard** | http://localhost:3000 | - | - | ✅ |
| **PostgreSQL Landlord** | localhost:5432 | vtravel | vtravel123 | ✅ |
| **PostgreSQL Tenant** | localhost:5433 | vtravel | vtravel123 | ✅ |
| **Redis** | localhost:6379 | - | - | ✅ |
| **RabbitMQ Admin** | http://localhost:15672 | admin | admin123 | ✅ |
| **MinIO Console** | http://localhost:9010 | minioadmin | minioadmin123 | ✅ |

## 🎯 Comandos Esenciales

### Gestión Básica
```bash
# Ver estado de todos los servicios
docker ps

# Ver logs de un servicio
docker logs vtravel-health

# Detener todo
docker-compose down

# Reiniciar un servicio
docker-compose restart [nombre-servicio]
```

### Usando Make (si está disponible)
```bash
make up          # Iniciar todo
make health      # Ver estado de salud
make ps          # Ver contenedores
make logs        # Ver logs
make down        # Detener todo
```

## 🔍 Verificación de Servicios

### Test Rápido de Conectividad
```bash
# PostgreSQL
docker exec vtravel-postgres-landlord pg_isready

# Redis
docker exec vtravel-redis redis-cli ping

# RabbitMQ
curl -u admin:admin123 http://localhost:15672/api/overview

# MinIO
curl http://localhost:9000/minio/health/live
```

### Dashboard de Estado
```python
# Guardar como check_status.py y ejecutar con: python3 check_status.py
import requests
import json

response = requests.get('http://localhost:3000/health/services')
data = response.json()

print("="*50)
print(f"Estado: {data['status'].upper()}")
print(f"Total: {data['summary']['total']} servicios")
print(f"✅ Activos: {data['summary']['healthy']}")
print(f"❌ Inactivos: {data['summary']['unhealthy']}")
print("="*50)

for name, info in data['services'].items():
    status = "✅" if info['status'] == 'healthy' else "❌"
    print(f"{status} {info['name']:<25} ({name})")
```

## 🚨 Solución Rápida de Problemas

### Puerto en Uso
```bash
# Ver qué usa un puerto
lsof -i :3000

# Matar proceso en puerto
kill -9 $(lsof -t -i:3000)
```

### Servicio No Responde
```bash
# Reiniciar servicio específico
docker-compose restart [servicio]

# Ver logs del servicio
docker logs --tail 50 vtravel-[servicio]
```

### Limpiar Todo y Empezar de Nuevo
```bash
# CUIDADO: Esto borra todo
docker-compose down -v
docker system prune -a
# Luego repetir desde Paso 4
```

## 📊 Script de Monitoreo Completo

```bash
#!/bin/bash
# Guardar como monitor.sh y ejecutar con: bash monitor.sh

echo "🔍 Verificando VTravel SaaS Platform..."
echo "========================================"

# Verificar Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker no está ejecutándose"
    exit 1
fi

# Verificar servicios
services=("postgres-landlord" "postgres-tenant" "redis" "rabbitmq" "minio" "health")
for service in "${services[@]}"; do
    if docker ps | grep -q "vtravel-$service"; then
        echo "✅ $service está activo"
    else
        echo "❌ $service no está activo"
    fi
done

# Verificar health endpoint
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Health Service respondiendo"
    
    # Mostrar resumen
    curl -s http://localhost:3000/health/services | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"\n📊 Resumen: {data['summary']['healthy']}/{data['summary']['total']} servicios activos\")
"
else
    echo "❌ Health Service no responde"
fi

echo "========================================"
echo "✅ Verificación completada"
```

## 🎉 ¡Listo!

Tu plataforma VTravel SaaS está funcionando con:
- ✅ Bases de datos PostgreSQL (multi-tenant)
- ✅ Cache Redis
- ✅ Cola de mensajes RabbitMQ  
- ✅ Almacenamiento MinIO (S3-compatible)
- ✅ Sistema de monitoreo de salud

### Próximos Pasos
1. Explorar el dashboard de salud: http://localhost:3000/health/services
2. Acceder a RabbitMQ Admin: http://localhost:15672
3. Acceder a MinIO Console: http://localhost:9010
4. Revisar documentación completa: `IMPLEMENTATION.md`

### Comandos Útiles Finales
```bash
# Ver resumen del sistema
curl -s http://localhost:3000/health | jq '.'

# Backup rápido
docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord > backup.sql

# Ver uso de recursos
docker stats --no-stream
```

---
**¿Problemas?** Revisa `IMPLEMENTATION.md` para guía detallada de solución de problemas.