FROM php:8.2-fpm-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    curl \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    postgresql-dev \
    && docker-php-ext-install \
    pdo \
    pdo_pgsql \
    bcmath \
    && rm -rf /var/cache/apk/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Check if vendor exists, if not install dependencies
RUN if [ ! -d "vendor" ]; then \
    composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Create necessary directories and set permissions
RUN mkdir -p storage/logs \
    && mkdir -p storage/framework/cache \
    && mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p bootstrap/cache \
    && chmod -R 777 storage \
    && chmod -R 777 bootstrap/cache

# Copy .env.example to .env if it doesn't exist
RUN if [ ! -f .env ]; then \
    cp .env.example .env; \
    fi

# Generate application key if needed
RUN php artisan key:generate --force || true

# Clear and cache configs
RUN php artisan config:clear \
    && php artisan cache:clear \
    && php artisan view:clear || true

# Create a simple health check endpoint
RUN echo '<?php echo json_encode(["status" => "healthy", "service" => "auth-service"]); ?>' > public/health.php

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/health.php || exit 1

# Start PHP built-in server instead of FPM for simplicity
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=9000"]
