# File Location: labs/lab_02_multi_container_compose/frontend/Dockerfile

# Multi-stage build for React frontend
FROM node:22-alpine AS base

# Set working directory
WORKDIR /app

# Install dumb-init for proper signal handling and curl for the health check
RUN apk add --no-cache dumb-init curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S reactjs -u 1001

# Development stage
FROM base AS development

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci

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

# Start the Vite development server (npm start is an alias for vite)
ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]

# Build stage
FROM base AS build

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application. Vite inlines VITE_* variables at build time:
# docker build --build-arg VITE_API_URL=http://host:5000 .
ARG VITE_API_URL=http://localhost:5000
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Production stage
FROM nginx:alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy built app from build stage
COPY --from=build /app/dist /usr/share/nginx/html

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