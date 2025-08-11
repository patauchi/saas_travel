FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    curl \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    postgresql-dev \
    nginx \
    supervisor

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_pgsql \
    pgsql \
    bcmath \
    xml \
    tokenizer \
    ctype \
    json

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Create necessary directories and set permissions
RUN mkdir -p storage/logs \
    && mkdir -p storage/framework/cache \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p bootstrap/cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage \
    && chmod -R 775 bootstrap/cache

# Copy nginx configuration
RUN echo "server { \
    listen 9000; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    location / { \
    try_files \$uri \$uri/ /index.php?\$query_string; \
    } \
    location ~ \.php$ { \
    fastcgi_pass 127.0.0.1:9002; \
    fastcgi_index index.php; \
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; \
    include fastcgi_params; \
    } \
    }" > /etc/nginx/http.d/default.conf

# Copy supervisor configuration
RUN echo "[supervisord] \
    nodaemon=true \
    [program:php-fpm] \
    command=php-fpm -F \
    stdout_logfile=/dev/stdout \
    stdout_logfile_maxbytes=0 \
    stderr_logfile=/dev/stderr \
    stderr_logfile_maxbytes=0 \
    [program:nginx] \
    command=nginx -g 'daemon off;' \
    stdout_logfile=/dev/stdout \
    stdout_logfile_maxbytes=0 \
    stderr_logfile=/dev/stderr \
    stderr_logfile_maxbytes=0" > /etc/supervisor/conf.d/supervisord.conf

# Configure PHP-FPM to listen on port 9002
RUN sed -i 's/listen = 9000/listen = 9002/g' /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy environment file
COPY .env.example .env

# Generate application key
RUN php artisan key:generate

# Cache configuration
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/api/health || exit 1

# Expose port
EXPOSE 9000

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
