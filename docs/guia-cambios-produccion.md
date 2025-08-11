# Guía Práctica para Manejar Cambios en Producción

## 🎨 **1. CAMBIOS EN FRONTEND (HTML/CSS/JS)**

**Situación:** Cambias el diseño, añades botones, modificas estilos, etc.

```bash
# En tu máquina local
git add -A
git commit -m "feat: Actualizar diseño del dashboard"
git push origin main

# En el VPS
ssh deploy@tu-vps
cd saas_travel
git pull origin main

# Frontend está montado como volumen, los cambios son INMEDIATOS
# Solo si modificaste nginx config:
docker-compose restart nginx
```

✅ **Tiempo downtime:** 0 segundos  
✅ **Afecta a tenants:** No  
✅ **Rollback:** `git checkout HEAD~1`

---

## 🔧 **2. CAMBIOS EN APIS/CONTROLADORES**

**Situación:** Modificas lógica de negocio, añades endpoints, cambias validaciones.

```bash
# En local - desarrollo y prueba
# Editas el controlador
vim services/auth-service/app/Http/Controllers/Api/AuthController.php

# Pruebas local
docker-compose restart auth-service
# Verificar que funciona

# Subir cambios
git add -A && git commit -m "fix: Corregir validación en login"
git push origin main

# En PRODUCCIÓN
ssh deploy@tu-vps
cd saas_travel
git pull origin main

# Opción A: Reinicio rápido (5 segundos downtime)
docker-compose restart auth-service

# Opción B: Sin downtime (rolling update)
docker-compose up -d --no-deps --build auth-service
```

✅ **Tiempo downtime:** 5 segundos (Opción A) o 0 segundos (Opción B)  
✅ **Afecta a tenants:** Solo si es tenant-service  

---

## 📊 **3. AGREGAR CAMPO A BASE DE DATOS**

**Situación:** Necesitas agregar campo `phone_number` a tabla `users` en TODOS los tenants.

### **Paso 1: Crear Migración en Local**
```bash
# En tu máquina local
cd services/auth-service
php artisan make:migration add_phone_number_to_users_table

# Editar la migración
```

```php
// La migración debe verse así:
public function up()
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('phone_number', 20)->nullable()->after('email');
    });
}

public function down()
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('phone_number');
    });
}
```

### **Paso 2: Probar en Local**
```bash
# Ejecutar migración local
docker exec vtravel-auth php artisan migrate

# Verificar que funciona
docker exec vtravel-auth php artisan tinker
>>> User::first() // Debe mostrar el campo phone_number
```

### **Paso 3: Aplicar en Producción**
```bash
# Commit y push
git add -A && git commit -m "feat: Agregar campo phone_number a usuarios"
git push origin main

# En PRODUCCIÓN
ssh deploy@tu-vps
cd saas_travel

# IMPORTANTE: Backup primero!
make -f Makefile.prod backup

git pull origin main

# Ejecutar migración en base de datos principal (landlord)
docker exec vtravel-auth php artisan migrate --force
```

### **Paso 4: Aplicar a TODOS los Tenants**
```bash
# Opción A: Script para migrar todos los tenants
docker exec vtravel-tenant php artisan tenants:migrate

# Opción B: Migración manual por tenant
docker exec vtravel-tenant php artisan tinker
>>> $tenants = \App\Models\Tenant::all();
>>> foreach($tenants as $tenant) {
>>>     $tenant->run(function() {
>>>         Artisan::call('migrate', ['--force' => true]);
>>>     });
>>> }
```

✅ **Tiempo downtime:** 0 segundos  
✅ **Afecta a tenants:** Sí, TODOS  
✅ **Rollback:** `php artisan migrate:rollback`

---

## 🗑️ **4. ELIMINAR CAMPO DE BASE DE DATOS**

**Situación:** Eliminar campo obsoleto de TODOS los tenants.

```bash
# PASO 1: Crear migración
cd services/auth-service
php artisan make:migration remove_obsolete_field_from_users_table
```

```php
public function up()
{
    // IMPORTANTE: Primero verificar que no se use!
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn('obsolete_field');
    });
}
```

```bash
# PASO 2: En producción - MUY IMPORTANTE
# Primero quitar el campo del modelo y código
git pull origin main

# Reiniciar servicios ANTES de la migración
docker-compose restart auth-service

# LUEGO ejecutar migración
docker exec vtravel-auth php artisan migrate --force

# Para todos los tenants
docker exec vtravel-tenant php artisan tenants:migrate --force
```

⚠️ **IMPORTANTE:** Eliminar en este orden:
1. Quitar del código (modelos, controladores)
2. Deploy y restart
3. LUEGO migración para eliminar de BD

---

## 🔄 **5. CAMBIOS QUE AFECTAN TODOS LOS TENANTS**

**Ejemplos comunes:**

### **A. Agregar nueva funcionalidad global**
```bash
# 1. Desarrollar en local
# 2. Crear migración que se aplique a tenant DB
cd services/tenant-service
php artisan make:migration create_new_feature_table --path=database/migrations/tenant

# 3. En producción
docker exec vtravel-tenant php artisan tenants:migrate
```

### **B. Cambiar lógica de negocio para todos**
```bash
# Cambios en el servicio compartido
vim services/tenant-service/app/Services/SharedBusinessLogic.php

# Deploy
git push origin main

# En producción
git pull
docker-compose restart tenant-service

# Todos los tenants usan la nueva lógica inmediatamente
```

### **C. Actualizar configuración de todos los tenants**
```bash
docker exec vtravel-tenant php artisan tinker
>>> use App\Models\Tenant;
>>> Tenant::all()->each(function($tenant) {
>>>     $tenant->update(['settings->new_feature' => true]);
>>> });
```

---

## 🚀 **6. WORKFLOW PARA CAMBIOS COMPLEJOS**

**Situación:** Reestructuración mayor que afecta frontend, backend y BD.

```bash
# PASO 1: Modo mantenimiento
make -f Makefile.prod maintenance-on

# PASO 2: Backup completo
make -f Makefile.prod backup

# PASO 3: Pull cambios
git pull origin main

# PASO 4: Rebuild servicios afectados
docker-compose up -d --build auth-service tenant-service

# PASO 5: Migraciones
docker exec vtravel-auth php artisan migrate --force
docker exec vtravel-tenant php artisan tenants:migrate --force

# PASO 6: Limpiar caché
docker exec vtravel-auth php artisan cache:clear
docker exec vtravel-tenant php artisan cache:clear

# PASO 7: Verificar
curl https://tudominio.com/health

# PASO 8: Salir de mantenimiento
make -f Makefile.prod maintenance-off
```

---

## 🔥 **7. HOTFIX DE EMERGENCIA**

```bash
# Cambio crítico que debe aplicarse YA

# 1. Fix directo en producción (NO recomendado pero a veces necesario)
ssh deploy@tu-vps
cd saas_travel
vim services/auth-service/app/Http/Controllers/Api/AuthController.php

# 2. Reiniciar inmediatamente
docker-compose restart auth-service

# 3. Commit el fix desde producción
git add -A
git commit -m "HOTFIX: Corregir vulnerabilidad crítica"
git push origin hotfix-critical

# 4. Luego hacer PR y merge proper
```

---

## 📋 **8. CHECKLIST POR TIPO DE CAMBIO**

| Tipo de Cambio | Backup? | Migración? | Restart? | Downtime | Afecta Tenants |
|----------------|---------|------------|----------|----------|----------------|
| Frontend HTML/CSS | No | No | No | 0s | No |
| API Controller | No | No | Sí | 5s | Depende |
| Agregar Campo BD | SÍ | SÍ | No | 0s | SÍ |
| Eliminar Campo BD | SÍ | SÍ | SÍ | 5s | SÍ |
| Nueva Feature | No | Quizás | Sí | 5s | SÍ |
| Config Change | No | No | Sí | 5s | Depende |
| Hotfix | SÍ | No | Sí | 5s | Depende |

---

## 💡 **TIPS IMPORTANTES**

1. **SIEMPRE hacer backup antes de migraciones**
   ```bash
   make -f Makefile.prod backup
   ```

2. **Para cambios en modelos Eloquent**
   ```php
   // En el modelo, agregar campo a $fillable
   protected $fillable = [..., 'phone_number'];
   ```

3. **Para aplicar cambio a UN solo tenant (testing)**
   ```bash
   docker exec vtravel-tenant php artisan tenant:run awesome-travels --option="migrate"
   ```

4. **Ver qué migraciones faltan**
   ```bash
   docker exec vtravel-auth php artisan migrate:status
   ```

5. **Rollback si algo sale mal**
   ```bash
   # Rollback de migración
   docker exec vtravel-auth php artisan migrate:rollback
   
   # Rollback de código
   git revert HEAD
   git push origin main
   ```

6. **Monitorear después de cambios**
   ```bash
   # Ver logs en tiempo real
   docker-compose logs -f auth-service
   
   # Ver errores
   docker-compose logs auth-service | grep ERROR
   ```

---

## 🛡️ **MEJORES PRÁCTICAS**

### **Antes de cualquier cambio:**
- [ ] Probar en entorno local
- [ ] Revisar que no hay procesos críticos corriendo
- [ ] Verificar espacio en disco disponible
- [ ] Tener plan de rollback claro

### **Durante el cambio:**
- [ ] Monitorear logs en tiempo real
- [ ] Tener ventana de mantenimiento si es necesario
- [ ] Comunicar al equipo sobre el cambio

### **Después del cambio:**
- [ ] Verificar funcionalidad afectada
- [ ] Revisar logs por errores
- [ ] Confirmar con usuarios que todo funciona
- [ ] Documentar el cambio realizado

---

## 📞 **CONTACTOS DE EMERGENCIA**

- **Lead Developer:** [contacto]
- **DevOps:** [contacto]
- **Soporte 24/7:** [contacto]

---

## 📚 **REFERENCIAS ADICIONALES**

- [Documentación Laravel Migrations](https://laravel.com/docs/migrations)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Git Flow para Hotfixes](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)