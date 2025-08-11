FROM php:8.2-cli-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    curl \
    postgresql-dev \
    && docker-php-ext-install pdo pdo_pgsql \
    && apk del postgresql-dev \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /var/www/html

# Create health check file
RUN echo '<?php \
header("Content-Type: application/json"); \
$service = getenv("SERVICE_NAME") ?: "unknown"; \
$response = [ \
    "status" => "healthy", \
    "service" => $service, \
    "timestamp" => date("c"), \
    "php_version" => PHP_VERSION \
]; \
echo json_encode($response); \
?>' > /var/www/html/health.php

# Create index file
RUN echo '<?php \
header("Content-Type: application/json"); \
$service = getenv("SERVICE_NAME") ?: "unknown"; \
echo json_encode([ \
    "service" => $service, \
    "status" => "running", \
    "timestamp" => date("c"), \
    "endpoints" => [ \
        "/health.php" => "Health check endpoint", \
        "/" => "Service info" \
    ] \
]); \
?>' > /var/www/html/index.php

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/health.php || exit 1

# Start PHP built-in server
CMD ["php", "-S", "0.0.0.0:9000", "-t", "/var/www/html"]
