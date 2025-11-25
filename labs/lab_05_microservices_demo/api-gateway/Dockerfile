# File Location: labs/lab_05_microservices_demo/api-gateway/Dockerfile

FROM node:18-alpine as middleware-builder

WORKDIR /app

# Copy middleware files
COPY auth-middleware.js .
COPY package.json .

# Install dependencies
RUN npm install

# Nginx with custom middleware
FROM nginx:alpine as base

# Install Node.js for middleware
RUN apk add --no-cache nodejs npm curl

# Install Lua for advanced rate limiting
RUN apk add --no-cache lua5.1 lua5.1-dev

WORKDIR /app

# Copy middleware from builder
COPY --from=middleware-builder /app /app

# Development stage
FROM base as development

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY rate-limiting.conf /etc/nginx/conf.d/rate-limiting.conf

# Create log directories
RUN mkdir -p /var/log/nginx /var/cache/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]

# Production stage
FROM base as production

# Copy optimized configurations
COPY nginx.conf /etc/nginx/nginx.conf
COPY rate-limiting.conf /etc/nginx/conf.d/rate-limiting.conf

# Security enhancements
# Note: nginx user/group already exists in Alpine, so we just ensure proper permissions
RUN mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/ssl && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /etc/nginx/ssl

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Labels
LABEL maintainer="DockVerseHub" \
      version="1.0" \
      description="API Gateway with rate limiting and authentication"

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]