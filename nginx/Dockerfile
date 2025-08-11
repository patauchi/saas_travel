FROM nginx:alpine

# Install necessary packages
RUN apk add --no-cache \
    curl \
    openssl \
    certbot \
    certbot-nginx

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/*.conf /etc/nginx/conf.d/

# Create necessary directories
RUN mkdir -p /var/cache/nginx \
    /var/log/nginx \
    /etc/nginx/ssl \
    /usr/share/nginx/html

# Create a self-signed SSL certificate for development
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/self-signed.key \
    -out /etc/nginx/ssl/self-signed.crt \
    -subj "/C=US/ST=State/L=City/O=VTravel/CN=*.vtravel.local"

# Copy health check page
RUN echo "OK" > /usr/share/nginx/html/health

# Set proper permissions
RUN chown -R nginx:nginx /var/cache/nginx \
    /var/log/nginx \
    /usr/share/nginx/html

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
