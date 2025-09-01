# Location: labs/lab_06_production_deployment/nginx/Dockerfile
FROM nginx:1.25-alpine

# Install dependencies
RUN apk add --no-cache \
    curl \
    openssl \
    certbot \
    certbot-nginx

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# Create necessary directories
RUN mkdir -p /var/www/certbot \
    && mkdir -p /var/www/static \
    && mkdir -p /etc/nginx/ssl \
    && mkdir -p /var/log/nginx

# Generate DH parameters for perfect forward secrecy
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Set proper permissions
RUN chown -R nginx:nginx /var/www \
    && chown -R nginx:nginx /var/log/nginx \
    && chmod 755 /var/www/certbot

# Health check script
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Security: Run as non-root user
USER nginx

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

# Start nginx
CMD ["nginx", "-g", "daemon off;"]