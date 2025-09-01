# Location: utilities/Dockerfile.templates/nodejs.Dockerfile
# Node.js optimized Dockerfile template

# Use official Node.js Alpine image
FROM node:18-alpine AS base

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Development stage
FROM base AS development

# Install development dependencies
RUN apk add --no-cache git

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY --chown=nodeuser:nodejs . .

USER nodeuser

EXPOSE 3000

CMD ["dumb-init", "npm", "run", "dev"]

# Production dependencies stage
FROM base AS deps

COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Production build stage
FROM base AS build

COPY package*.json ./
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM base AS production

ENV NODE_ENV=production
ENV PORT=3000

# Copy built application
COPY --from=build --chown=nodeuser:nodejs /app/dist ./dist
COPY --from=build --chown=nodeuser:nodejs /app/package*.json ./

# Copy production dependencies
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Switch to non-root user
USER nodeuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

EXPOSE $PORT

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

CMD ["node", "dist/server.js"]