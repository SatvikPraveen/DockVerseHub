# Location: utilities/performance/optimization-guides/dockerfile-optimization.md

# Dockerfile Optimization Guide

A comprehensive guide to optimizing Dockerfiles for better performance, smaller images, and faster builds.

## Table of Contents

- [Layer Optimization](#layer-optimization)
- [Image Size Reduction](#image-size-reduction)
- [Build Speed Optimization](#build-speed-optimization)
- [Multi-Stage Builds](#multi-stage-builds)
- [Base Image Selection](#base-image-selection)
- [Caching Strategies](#caching-strategies)
- [Best Practices](#best-practices)

## Layer Optimization

### Minimize the Number of Layers

Each `RUN`, `COPY`, `ADD` instruction creates a new layer. Combine commands when possible.

**❌ Bad:**

```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y wget
RUN rm -rf /var/lib/apt/lists/*
```

**✅ Good:**

```dockerfile
RUN apt-get update && \
    apt-get install -y curl wget && \
    rm -rf /var/lib/apt/lists/*
```

### Order Instructions by Change Frequency

Place instructions that change frequently at the end to maximize cache usage.

**✅ Optimal Order:**

```dockerfile
# 1. Base image (rarely changes)
FROM node:18-alpine

# 2. System dependencies (occasionally change)
RUN apk add --no-cache git

# 3. Application dependencies (change moderately)
COPY package*.json ./
RUN npm ci --only=production

# 4. Application code (changes frequently)
COPY . .

# 5. Runtime configuration
CMD ["npm", "start"]
```

## Image Size Reduction

### Use Alpine or Distroless Images

Alpine Linux images are significantly smaller than full distributions.

```dockerfile
# Size comparison:
FROM ubuntu:22.04        # ~77MB
FROM node:18             # ~993MB
FROM node:18-alpine      # ~174MB
FROM gcr.io/distroless/nodejs18-debian11  # ~128MB
```

### Multi-Stage Builds for Build Dependencies

Separate build dependencies from runtime dependencies.

```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine AS production
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --from=builder /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

### Remove Package Managers and Caches

Clean up after package installations.

```dockerfile
# APT (Debian/Ubuntu)
RUN apt-get update && \
    apt-get install -y package1 package2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# APK (Alpine)
RUN apk add --no-cache package1 package2

# YUM/DNF (RHEL/CentOS/Fedora)
RUN yum install -y package1 package2 && \
    yum clean all
```

### Use .dockerignore

Exclude unnecessary files from the build context.

```dockerignore
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.coverage
*.md
.DS_Store
```

## Build Speed Optimization

### Leverage Build Cache

Structure Dockerfile to maximize cache hits.

```dockerfile
# Dependencies change less frequently than source code
COPY package*.json ./
RUN npm install

# Source code changes more frequently
COPY src/ ./src/
```

### Use Specific COPY Commands

Copy only what you need, when you need it.

**❌ Bad:**

```dockerfile
COPY . .
RUN npm install
```

**✅ Good:**

```dockerfile
COPY package*.json ./
RUN npm install
COPY src/ ./src/
```

### Parallel Multi-Stage Builds

Use BuildKit for parallel stage execution.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine:latest AS base
RUN apk add --no-cache ca-certificates

FROM base AS build1
RUN echo "Building component 1"

FROM base AS build2
RUN echo "Building component 2"

FROM base AS final
COPY --from=build1 /app1 /app1
COPY --from=build2 /app2 /app2
```

## Multi-Stage Builds

### Development vs Production Stages

Create different targets for different environments.

```dockerfile
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./

# Development stage
FROM base AS development
RUN npm install
COPY . .
CMD ["npm", "run", "dev"]

# Build stage
FROM base AS build
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM base AS production
RUN npm ci --only=production && npm cache clean --force
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Named Stages for Clarity

Use descriptive names for build stages.

```dockerfile
FROM node:18-alpine AS dependencies
# Install dependencies

FROM dependencies AS builder
# Build application

FROM node:18-alpine AS runtime
# Runtime configuration
```

## Base Image Selection

### Image Size Comparison

Choose the smallest suitable base image.

| Base Image          | Size  | Use Case                |
| ------------------- | ----- | ----------------------- |
| `scratch`           | 0MB   | Static binaries only    |
| `alpine:3.19`       | 7MB   | Minimal Linux           |
| `distroless/static` | 2MB   | Static Go/Rust binaries |
| `distroless/java`   | 189MB | Java applications       |
| `ubuntu:22.04`      | 77MB  | Full Ubuntu features    |

### Security Considerations

Smaller images have fewer vulnerabilities.

```dockerfile
# Security-focused base images
FROM gcr.io/distroless/nodejs18-debian11  # No shell, minimal packages
FROM alpine:3.19  # Security-focused, regularly updated
```

## Caching Strategies

### BuildKit Cache Mounts

Use cache mounts for package managers.

```dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine
RUN --mount=type=cache,target=/root/.npm \
    npm install
```

### Registry Cache

Use registry-based caching for CI/CD.

```bash
# Build with registry cache
docker buildx build \
  --cache-from type=registry,ref=myregistry.com/myapp:cache \
  --cache-to type=registry,ref=myregistry.com/myapp:cache,mode=max \
  --push \
  -t myregistry.com/myapp:latest .
```

### Layer Caching Best Practices

1. **Order by frequency of change**
2. **Separate dependencies from code**
3. **Use specific COPY commands**
4. **Combine related operations**

```dockerfile
FROM python:3.11-slim

# System packages (rarely change)
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies (change occasionally)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code (changes frequently)
COPY src/ ./src/
```

## Best Practices

### Security Hardening

```dockerfile
# Don't run as root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001 -G nodejs
USER nodeuser

# Use specific versions
FROM node:18.17.0-alpine3.18

# Remove unnecessary packages
RUN apk del .build-deps
```

### Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

### Environment Configuration

```dockerfile
# Use build arguments for flexibility
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Set working directory
WORKDIR /app

# Proper signal handling
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
```

### Dockerfile Linting

Use tools to validate your Dockerfile:

```bash
# hadolint
hadolint Dockerfile

# Custom linter
python utilities/dev-tools/dockerfile-linter.py Dockerfile
```

## Performance Testing

### Build Time Measurement

```bash
# Time build
time docker build -t myapp .

# Analyze build performance
python utilities/performance/benchmarks/image-build-performance.py Dockerfile
```

### Image Size Analysis

```bash
# Check image size
docker images myapp

# Analyze layers
docker history myapp

# Use dive tool
dive myapp
```

## Common Anti-Patterns to Avoid

### ❌ Installing Unnecessary Packages

```dockerfile
# Don't install recommended packages by default
RUN apt-get install -y --no-install-recommends package
```

### ❌ Using ADD Instead of COPY

```dockerfile
# Use COPY for local files
COPY file.txt /app/
# Use ADD only for archives or URLs
ADD https://example.com/file.tar.gz /app/
```

### ❌ Not Using .dockerignore

Always create a .dockerignore file to exclude unnecessary files.

### ❌ Running as Root

```dockerfile
# Create and use non-root user
RUN useradd -m -u 1001 appuser
USER appuser
```

### ❌ Hardcoding Values

```dockerfile
# Use ARG and ENV for configuration
ARG APP_VERSION=1.0.0
ENV VERSION=$APP_VERSION
```

## Optimization Checklist

- [ ] Use appropriate base image (Alpine/Distroless)
- [ ] Implement multi-stage builds
- [ ] Order instructions by change frequency
- [ ] Combine RUN commands where appropriate
- [ ] Use .dockerignore file
- [ ] Remove package manager caches
- [ ] Run as non-root user
- [ ] Add health checks
- [ ] Use specific versions/tags
- [ ] Minimize the number of layers
- [ ] Use COPY instead of ADD for local files
- [ ] Set proper working directory
- [ ] Configure proper signal handling

## Measuring Success

### Build Performance Metrics

- Build time reduction
- Cache hit rate improvement
- Layer count reduction
- Build context size

### Runtime Performance Metrics

- Container startup time
- Memory usage
- CPU utilization
- Image vulnerability count

### Tools for Measurement

```bash
# Build analysis
python utilities/performance/benchmarks/image-build-performance.py

# Runtime benchmarking
python utilities/performance/benchmarks/container-startup-times.py

# Security scanning
bash utilities/scripts/security_scan.sh

# General performance
bash utilities/scripts/performance_benchmark.sh
```

Following these optimization guidelines will result in faster builds, smaller images, better security, and improved runtime performance.
