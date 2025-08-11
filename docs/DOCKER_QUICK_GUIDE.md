# 🐳 Docker Quick Guide - Desarrollo Diario

## Comandos Esenciales para Desarrollo

### 🚀 Iniciar/Detener Servicios

```bash
# Iniciar todos los servicios (sin reconstruir)
docker-compose up -d

# Detener servicios (mantiene los datos)
docker-compose stop

# Detener y eliminar contenedores (MANTIENE los volúmenes/datos)
docker-compose down

# ⚠️ PELIGRO: Eliminar TODO incluyendo datos
docker-compose down -v
```

### 📝 Actualizar Solo el Frontend

```bash
# El frontend está montado como volumen, los cambios son automáticos
# Solo necesitas recargar el navegador

# Si modificaste nginx config:
docker-compose restart nginx
```

### 🔧 Actualizar Un Microservicio Específico

```bash
# Ejemplo: Solo actualizar auth-service
docker-compose up -d --build auth-service

# Reiniciar un servicio sin reconstruir
docker-compose restart auth-service

# Ver logs de un servicio específico
docker-compose logs -f auth-service
```

### 📊 Agregar Campo a Base de Datos (Migraciones)

```bash
# 1. Crear migración en tu máquina local
cd services/auth-service
php artisan make:migration add_campo_to_users_table

# 2. Editar el archivo de migración creado

# 3. Ejecutar migración en el contenedor
docker exec vtravel-auth php artisan migrate

# Para revertir última migración
docker exec vtravel-auth php artisan migrate:rollback
```

### 🎯 Casos de Uso Comunes

#### **Caso 1: Solo cambié HTML/CSS/JS del frontend**
```bash
# No hacer nada! Solo recargar el navegador
# Los archivos están montados como volumen
```

#### **Caso 2: Modifiqué un controlador en auth-service**
```bash
# Opción A: Reiniciar el servicio (más rápido)
docker-compose restart auth-service

# Opción B: Si agregaste dependencias composer
docker-compose up -d --build auth-service
```

#### **Caso 3: Necesito agregar un campo a la BD**
```bash
# Crear y editar migración localmente
cd services/auth-service
php artisan make:migration add_phone_to_users_table

# Ejecutar en el contenedor
docker exec vtravel-auth php artisan migrate
```

#### **Caso 4: Modifiqué variables de entorno**
```bash
# Reiniciar el servicio afectado
docker-compose restart auth-service

# O reiniciar todos
docker-compose restart
```

#### **Caso 5: Instalé un paquete nuevo con Composer**
```bash
# Reconstruir solo ese servicio
docker-compose up -d --build auth-service

# O ejecutar composer en el contenedor
docker exec vtravel-auth composer require nombre/paquete
```

### 🔍 Comandos de Debugging

```bash
# Ver todos los contenedores
docker ps

# Ver logs de un servicio
docker-compose logs -f auth-service

# Entrar a un contenedor
docker exec -it vtravel-auth sh

# Ver uso de recursos
docker stats

# Limpiar cache de Laravel
docker exec vtravel-auth php artisan cache:clear
docker exec vtravel-auth php artisan config:clear
```

### 💾 Backup de Datos

```bash
# Backup de base de datos
docker exec vtravel-postgres-landlord pg_dump -U vtravel vtravel_landlord > backup_landlord.sql

# Restaurar base de datos
docker exec -i vtravel-postgres-landlord psql -U vtravel vtravel_landlord < backup_landlord.sql
```

### 🏃‍♂️ Workflow Recomendado

1. **Inicio del día:**
   ```bash
   docker-compose up -d
   ```

2. **Durante desarrollo:**
   - Frontend: Solo guardar archivos y recargar navegador
   - Backend: Guardar y `docker-compose restart [servicio]`
   - Migraciones: Crear local, ejecutar en contenedor

3. **Fin del día:**
   ```bash
   docker-compose stop  # Mantiene los datos
   ```

### ⚡ Tips de Rendimiento

1. **NO uses `docker-compose down -v`** a menos que quieras borrar TODOS los datos
2. **NO reconstruyas** si solo cambiaste código PHP (usa restart)
3. **USA volúmenes** para código en desarrollo (ya configurado)
4. **REVISA logs** si algo falla: `docker-compose logs [servicio]`

### 🚨 Solución de Problemas Comunes

#### Puerto en uso
```bash
# Ver qué usa el puerto
lsof -i :9001

# Cambiar puerto en docker-compose.yml
```

#### Contenedor no inicia
```bash
# Ver logs
docker-compose logs auth-service

# Reconstruir si es necesario
docker-compose up -d --build auth-service
```

#### Base de datos corrupta
```bash
# Último recurso: recrear volumen
docker-compose down
docker volume rm vtravel_postgres-landlord-data
docker-compose up -d
```

### 📋 Resumen de Cuándo Usar Cada Comando

| Cambio | Comando | Pierde Datos |
|--------|---------|--------------|
| HTML/CSS/JS | Ninguno (recargar browser) | No |
| PHP Controller | `docker-compose restart [servicio]` | No |
| Nueva migración | `docker exec [servicio] php artisan migrate` | No |
| Nuevo paquete Composer | `docker-compose up -d --build [servicio]` | No |
| Config nginx | `docker-compose restart nginx` | No |
| Variables .env | `docker-compose restart [servicio]` | No |
| Limpiar todo | `docker-compose down -v` | **SÍ** |

---

**Regla de Oro:** Si no estás seguro, usa `docker-compose restart [servicio]` - es rápido y no pierdes datos.