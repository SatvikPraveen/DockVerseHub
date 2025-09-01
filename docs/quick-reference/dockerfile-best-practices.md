# Dockerfile Best Practices & Optimization Patterns

**Location: `docs/quick-reference/dockerfile-best-practices.md`**

## Dockerfile Optimization Patterns

### 1. Multi-Stage Builds

```dockerfile
# ✅ GOOD: Multi-stage build
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:16-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./
USER node
CMD ["node", "dist/server.js"]

# ❌ BAD: Single stage
FROM node:16
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["node", "dist/server.js"]
```

### 2. Layer Caching Optimization

```dockerfile
# ✅ GOOD: Dependencies first (better caching)
FROM python:3.9-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]

# ❌ BAD: Code copied before dependencies
FROM python:3.9-alpine
WORKDIR /app
COPY . .  # Changes frequently, breaks cache
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```

### 3. Minimal Base Images

```dockerfile
# ✅ EXCELLENT: Distroless (production)
FROM gcr.io/distroless/java:11
COPY --from=builder /app/target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

# ✅ GOOD: Alpine (small, secure)
FROM openjdk:11-jre-alpine
COPY --from=builder /app/target/app.jar /app.jar
CMD ["java", "-jar", "/app.jar"]

# ❌ AVOID: Full OS (large, attack surface)
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y openjdk-11-jre
COPY app.jar /app.jar
CMD ["java", "-jar", "/app.jar"]
```

## Security Best Practices

### 1. Non-Root User

```dockerfile
# ✅ GOOD: Create and use non-root user
FROM node:16-alpine

# Create app user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

WORKDIR /app
COPY --chown=nextjs:nodejs package*.json ./
RUN npm ci --only=production

COPY --chown=nextjs:nodejs . .

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]

# ❌ BAD: Running as root
FROM node:16-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]  # Runs as root!
```

### 2. Security Scanning & Updates

```dockerfile
# ✅ GOOD: Updated base image with security patches
FROM node:16.20.2-alpine3.18  # Specific version

# Update packages for security
RUN apk update && apk upgrade && \
    apk add --no-cache dumb-init && \
    rm -rf /var/cache/apk/*

# Use init system
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

### 3. Secrets Management

```dockerfile
# ✅ GOOD: Use build secrets (BuildKit)
# syntax=docker/dockerfile:1.4
FROM alpine
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) \
    curl -H "Authorization: Bearer $API_KEY" https://api.example.com/config

# ❌ BAD: Secrets in environment or layers
FROM alpine
ENV API_KEY=secret_key_123  # Visible in image
RUN curl -H "Authorization: Bearer secret_key_123" https://api.example.com/config
```

## Performance Optimization

### 1. Efficient Package Installation

```dockerfile
# ✅ GOOD: Combined RUN commands, cleanup
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ❌ BAD: Multiple RUN commands, no cleanup
FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y wget  # Creates multiple layers
# No cleanup - wastes space
```

### 2. Build Context Optimization

```dockerfile
# ✅ GOOD: Copy only necessary files
FROM node:16-alpine
WORKDIR /app

# Copy package files first
COPY package*.json ./
RUN npm ci --only=production

# Copy only source code
COPY src/ ./src/
COPY public/ ./public/

# ❌ BAD: Copy everything
FROM node:16-alpine
WORKDIR /app
COPY . .  # Copies node_modules, tests, etc.
RUN npm install
```

### 3. .dockerignore Usage

```dockerignore
# Optimize build context
node_modules
npm-debug.log*
.npm
.git
.gitignore
README.md
.env
.env.local
.env.production
coverage/
.nyc_output
*.log
.DS_Store
Dockerfile*
docker-compose*.yml
```

## Application-Specific Patterns

### Node.js Applications

```dockerfile
FROM node:16-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:16-alpine AS runner
WORKDIR /app

# Add non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy dependencies and built app
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --chown=nextjs:nodejs package.json ./

USER nextjs
EXPOSE 3000
ENV NODE_ENV=production
CMD ["npm", "start"]
```

### Python Applications

```dockerfile
FROM python:3.9-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.9-slim AS runtime
WORKDIR /app

# Create non-root user
RUN useradd --create-home --shell /bin/bash app

# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application
COPY --chown=app:app . .

USER app
EXPOSE 8000
CMD ["python", "app.py"]
```

### Java Applications

```dockerfile
FROM maven:3.8-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline  # Download dependencies

COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:11-jre-slim AS runtime
WORKDIR /app

# Create non-root user
RUN useradd --create-home --shell /bin/bash app

# Copy JAR file
COPY --from=builder --chown=app:app /app/target/app.jar ./app.jar

USER app
EXPOSE 8080

# JVM optimization
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
CMD java $JAVA_OPTS -jar app.jar
```

### Go Applications

```dockerfile
FROM golang:1.19-alpine AS builder
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:3.18 AS runtime
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy binary
COPY --from=builder --chown=appuser:appgroup /app/main ./

USER appuser
EXPOSE 8080
CMD ["./main"]

# Alternative: Use scratch for minimal image
# FROM scratch
# COPY --from=builder /app/main ./
# ENTRYPOINT ["./main"]
```

## Health Checks & Monitoring

### 1. Health Check Implementation

```dockerfile
FROM nginx:alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy health check script
COPY healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.sh

# Define health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh || exit 1

COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 2. Application-Specific Health Checks

```dockerfile
# Node.js health check
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

EXPOSE 3000
CMD ["npm", "start"]
```

## Advanced Patterns

### 1. BuildKit Cache Mounts

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:16-alpine

WORKDIR /app

# Use cache mount for npm
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci --only=production

COPY . .
CMD ["npm", "start"]
```

### 2. Multi-Platform Builds

```dockerfile
# syntax=docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM golang:1.19-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build for target platform
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN CGO_ENABLED=0 go build -o main .

FROM alpine:3.18
COPY --from=builder /app/main /usr/local/bin/
CMD ["main"]
```

### 3. Init System Usage

```dockerfile
FROM node:16-alpine

# Install dumb-init
RUN apk add --no-cache dumb-init

# Create app user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

WORKDIR /app
COPY --chown=nextjs:nodejs . .
RUN npm ci --only=production

USER nextjs
EXPOSE 3000

# Use dumb-init as PID 1
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

## Dockerfile Linting & Validation

### 1. Using hadolint

```bash
# Install hadolint
docker pull hadolint/hadolint

# Lint Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile

# Example fixes for common issues:
# DL3008: Pin versions in apt-get install
RUN apt-get update && apt-get install -y \
    curl=7.68.0-1ubuntu2.7 \
    wget=1.20.3-1ubuntu1 \
    && rm -rf /var/lib/apt/lists/*

# DL3009: Delete apt cache
RUN apt-get update && apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# DL3025: Use JSON array for CMD/ENTRYPOINT
CMD ["node", "server.js"]  # Good
CMD node server.js         # Bad
```

### 2. Dockerfile Testing

```bash
#!/bin/bash
# test-dockerfile.sh

echo "Testing Dockerfile..."

# Build image
docker build -t test-app:latest .

# Test image size
SIZE=$(docker images test-app:latest --format "{{.Size}}")
echo "Image size: $SIZE"

# Test security
docker run --rm -i clair-scanner:latest --ip $(hostname -I | awk '{print $1}') test-app:latest

# Test functionality
docker run -d --name test-container test-app:latest
sleep 5

# Check if container is running
if docker ps | grep -q test-container; then
    echo "✅ Container started successfully"
else
    echo "❌ Container failed to start"
    docker logs test-container
fi

# Cleanup
docker rm -f test-container
docker rmi test-app:latest
```

## Common Mistakes to Avoid

### 1. ❌ Large Images

```dockerfile
# BAD: Using full Ubuntu base
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    build-essential \
    git \
    vim \
    nano \
    htop
# Result: ~500MB+

# GOOD: Use minimal base
FROM python:3.9-alpine
RUN apk add --no-cache git
# Result: ~50MB
```

### 2. ❌ Poor Layer Caching

```dockerfile
# BAD: Changes break cache for everything below
COPY . .
RUN npm install
RUN npm run build

# GOOD: Dependencies cached separately
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
```

### 3. ❌ Security Issues

```dockerfile
# BAD: Running as root, secrets exposed
FROM node:16
WORKDIR /app
COPY . .
ENV API_KEY=secret123
RUN npm install
CMD ["node", "server.js"]

# GOOD: Non-root user, secrets via mount
FROM node:16-alpine
RUN adduser -S appuser
WORKDIR /app
COPY --chown=appuser . .
RUN --mount=type=secret,id=api_key npm install
USER appuser
CMD ["node", "server.js"]
```

## Best Practices Checklist

### Build Optimization

- [ ] Use multi-stage builds
- [ ] Order instructions for optimal caching
- [ ] Use minimal base images
- [ ] Combine RUN commands
- [ ] Use .dockerignore
- [ ] Pin package versions

### Security

- [ ] Run as non-root user
- [ ] Use secrets properly
- [ ] Keep base images updated
- [ ] Scan for vulnerabilities
- [ ] Minimize attack surface
- [ ] Use init system for PID 1

### Performance

- [ ] Optimize layer count
- [ ] Use cache mounts (BuildKit)
- [ ] Minimize image size
- [ ] Include health checks
- [ ] Set resource limits
- [ ] Use appropriate WORKDIR

### Maintenance

- [ ] Use specific tags
- [ ] Document with LABEL
- [ ] Include health checks
- [ ] Test builds regularly
- [ ] Monitor image sizes
- [ ] Keep dependencies updated

This guide provides proven patterns for creating efficient, secure, and maintainable Dockerfiles.
