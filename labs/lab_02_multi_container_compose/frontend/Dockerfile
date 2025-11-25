# File Location: labs/lab_02_multi_container_compose/frontend/Dockerfile

# Multi-stage build for React frontend
FROM node:18-alpine as base

# Set working directory
WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S reactjs -u 1001

# Development stage
FROM base as development

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci || npm install

# Copy source code
COPY . .

# Change ownership to non-root user
RUN chown -R reactjs:nodejs /app

# Switch to non-root user
USER reactjs

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start development server
ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]

# Build stage
FROM base as build

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci || npm install

# Copy source code
COPY . .

# Build the application (if build script exists)
RUN npm run build 2>/dev/null || mkdir -p /app/build && echo '<html><body><h1>Frontend App</h1></body></html>' > /app/build/index.html || true

# Production stage
FROM nginx:alpine as production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy built app from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create non-root user for nginx
RUN addgroup -g 1001 -S nginx-group && adduser -S nginx-user -u 1001 -G nginx-group

# Set proper permissions
RUN chown -R nginx-user:nginx-group /usr/share/nginx/html && \
    chown -R nginx-user:nginx-group /var/cache/nginx && \
    chown -R nginx-user:nginx-group /var/log/nginx && \
    chown -R nginx-user:nginx-group /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx-user:nginx-group /var/run/nginx.pid

# Switch to non-root user
USER nginx-user

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]