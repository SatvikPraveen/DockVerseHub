# Multi-Stage Build Patterns and Best Practices

**File Location:** `labs/lab_03_image_optimization/optimization-strategies/multi-stage-patterns.md`

## Overview

Multi-stage builds are one of Docker's most powerful features for image optimization. They enable separation of build-time dependencies from runtime requirements, resulting in smaller, more secure final images while maintaining build flexibility.

## Core Concepts

### Single vs Multi-Stage Comparison

#### Traditional Single-Stage Build

```dockerfile
FROM python:3.11
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    python3-dev \
    libpq-dev \
    build-essential
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
RUN python -m compileall .
CMD ["python", "app.py"]
```

**Result**: 1.2GB image with build tools

#### Multi-Stage Build

```dockerfile
# Build stage
FROM python:3.11 as builder
RUN apt-get update && apt-get install -y gcc g++ python3-dev libpq-dev
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Runtime stage
FROM python:3.11-slim as runtime
COPY --from=builder /root/.local /home/app/.local
COPY . .
USER app
CMD ["python", "app.py"]
```

**Result**: 180MB image without build tools

## Common Multi-Stage Patterns

### Pattern 1: Builder Pattern

#### Use Case: Compiled Applications

```dockerfile
# Build stage - contains all build tools
FROM golang:1.21 as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app ./cmd/main.go

# Runtime stage - minimal runtime environment
FROM alpine:3.18 as runtime
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /app/app .
EXPOSE 8080
CMD ["./app"]
```

**Benefits:**

- Final image: ~10MB (vs 800MB+ with build tools)
- No Go toolchain in production
- Enhanced security (no compiler)

### Pattern 2: Asset Builder Pattern

#### Use Case: Frontend Applications

```dockerfile
# Node build stage
FROM node:18-alpine as node-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src/ ./src/
COPY public/ ./public/
RUN npm run build

# Python build stage
FROM python:3.11-slim as python-builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Final runtime stage
FROM python:3.11-slim as runtime
COPY --from=python-builder /root/.local /home/app/.local
COPY --from=node-builder /app/dist /app/static/
COPY server/ /app/server/
WORKDIR /app
CMD ["python", "server/app.py"]
```

**Benefits:**

- Separates frontend and backend builds
- No Node.js in final runtime
- Static assets optimized separately

### Pattern 3: Dependency Isolation Pattern

#### Use Case: Complex Dependencies

```dockerfile
# System dependencies stage
FROM ubuntu:22.04 as system-deps
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies stage
FROM python:3.11 as python-deps
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Application build stage
FROM python:3.11 as app-builder
COPY src/ ./src/
RUN python -m compileall src/

# Final runtime stage
FROM ubuntu:22.04 as runtime
COPY --from=system-deps /usr/lib/x86_64-linux-gnu/libpq.so.5 /usr/lib/x86_64-linux-gnu/
COPY --from=python-deps /root/.local /home/app/.local
COPY --from=app-builder /src /app/src
USER app
CMD ["python", "/app/src/main.py"]
```

### Pattern 4: Test Runner Pattern

#### Use Case: Testing in Build Pipeline

```dockerfile
# Base dependencies
FROM python:3.11-slim as base
COPY requirements.txt .
RUN pip install -r requirements.txt

# Test stage
FROM base as test
COPY requirements-test.txt .
RUN pip install -r requirements-test.txt
COPY tests/ ./tests/
COPY src/ ./src/
RUN python -m pytest tests/ --cov=src/

# Production stage
FROM base as production
COPY --from=test /src ./src
# Only copy if tests pass
USER 1000
CMD ["python", "src/app.py"]
```

**Usage:**

```bash
# Run tests
docker build --target=test .

# Build production (tests must pass)
docker build --target=production -t app:prod .
```

## Advanced Multi-Stage Patterns

### Pattern 5: Parallel Build Stages

#### Use Case: Independent Build Processes

```dockerfile
# Python backend (parallel build 1)
FROM python:3.11-slim as python-app
COPY requirements.txt .
RUN pip install --user -r requirements.txt
COPY backend/ ./backend/

# Go microservice (parallel build 2)
FROM golang:1.21-alpine as go-service
WORKDIR /app
COPY service/go.mod service/go.sum ./
RUN go mod download
COPY service/ .
RUN go build -o service ./cmd/

# Node.js frontend (parallel build 3)
FROM node:18-alpine as frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# Nginx runtime (combines all)
FROM nginx:alpine as runtime
COPY --from=frontend /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
```

### Pattern 6: Development vs Production Pattern

#### Use Case: Environment-Specific Builds

```dockerfile
FROM python:3.11-slim as base
COPY requirements.txt .
RUN pip install -r requirements.txt

# Development stage with dev tools
FROM base as development
COPY requirements-dev.txt .
RUN pip install -r requirements-dev.txt
RUN apt-get update && apt-get install -y vim curl
COPY . .
ENV FLASK_ENV=development
CMD ["flask", "run", "--debug", "--host=0.0.0.0"]

# Production stage - minimal and secure
FROM base as production
RUN groupadd -r app && useradd -r -g app app
COPY --chown=app:app src/ ./src/
USER app
ENV FLASK_ENV=production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "src.app:app"]
```

**Usage:**

```bash
# Development build
docker build --target=development -t app:dev .

# Production build
docker build --target=production -t app:prod .
```

### Pattern 7: Security Scanning Pattern

#### Use Case: Built-in Security Checks

```dockerfile
# Build application
FROM python:3.11-slim as builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt
COPY . .

# Security scanning stage
FROM builder as security-scan
RUN pip install bandit safety
RUN bandit -r . -f json -o bandit-report.json || true
RUN safety check --json --output safety-report.json || true
# Note: Use || true to not fail build on findings

# Final runtime (only if security passes)
FROM python:3.11-slim as runtime
COPY --from=builder /root/.local /home/app/.local
COPY --from=builder /app /app
# Copy security reports for reference
COPY --from=security-scan /*-report.json /security/
USER 1000
CMD ["python", "/app/main.py"]
```

## Optimization Strategies

### Strategy 1: Layer Sharing Between Stages

#### Maximize Base Layer Reuse

```dockerfile
FROM python:3.11-slim as base-layer
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

FROM base-layer as builder
RUN apt-get update && apt-get install -y gcc python3-dev
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM base-layer as runtime
COPY --from=builder /root/.local /home/app/.local
```

### Strategy 2: Selective File Copying

#### Copy Only What's Needed

```dockerfile
FROM node:18-alpine as frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY webpack.config.js tsconfig.json ./
COPY src/ ./src/
RUN npm run build

FROM nginx:alpine as runtime
# Only copy built assets, not source
COPY --from=frontend-builder /app/dist /usr/share/nginx/html
# Don't copy node_modules, src/, config files
```

### Strategy 3: Build Argument Optimization

#### Environment-Specific Builds

```dockerfile
ARG BUILD_ENV=production
ARG PYTHON_VERSION=3.11

FROM python:${PYTHON_VERSION}-slim as base
COPY requirements.txt .
RUN pip install -r requirements.txt

# Conditional development dependencies
FROM base as development
RUN if [ "$BUILD_ENV" = "development" ]; then \
      pip install -r requirements-dev.txt; \
    fi
COPY . .

FROM base as production
RUN groupadd -r app && useradd -r -g app app
COPY --chown=app:app src/ ./src/
USER app
```

## Performance Optimization

### Build Cache Optimization

#### Stage-Specific Caching

```dockerfile
# Cached independently - changes rarely
FROM python:3.11-slim as system-base
RUN apt-get update && apt-get install -y libpq5

# Cached independently - changes occasionally
FROM python:3.11-slim as python-deps
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Changes frequently - uses both caches
FROM system-base as runtime
COPY --from=python-deps /root/.local /home/app/.local
COPY . .
```

### Parallel Build Execution

#### BuildKit Parallel Stages

```dockerfile
# syntax=docker/dockerfile:1.4

# These stages can build in parallel
FROM alpine:3.18 as downloads
RUN wget https://example.com/file1.tar.gz

FROM node:18-alpine as frontend
# Independent of downloads stage
COPY package.json .
RUN npm install

FROM golang:1.21 as backend
# Independent of other stages
COPY go.mod .
RUN go mod download

# Final stage waits for all parallel stages
FROM alpine:3.18 as final
COPY --from=downloads /file1.tar.gz .
COPY --from=frontend /app/dist ./static/
COPY --from=backend /app/service ./
```

## Troubleshooting Common Issues

### Issue 1: Stage Not Found

#### Problem

```bash
Error: failed to build: failed to copy files: stage "builder" not found
```

#### Solution

```dockerfile
# Ensure stage name matches exactly
FROM python:3.11 as builder  # ← lowercase 'as'
...
FROM alpine:3.18
COPY --from=builder /app .   # ← matches stage name exactly
```

### Issue 2: File Not Found in Stage

#### Problem

```bash
COPY failed: file not found in build context or excluded by .dockerignore
```

#### Solution

```dockerfile
# Check file exists in source stage
FROM python:3.11 as builder
WORKDIR /app  # ← Set working directory
COPY . .
RUN pip install --user -r requirements.txt  # ← Creates /root/.local

FROM python:3.11-slim
COPY --from=builder /root/.local /home/app/.local  # ← Full path from root
```

### Issue 3: Permissions Issues

#### Problem

```bash
Permission denied when copying from build stage
```

#### Solution

```dockerfile
FROM python:3.11 as builder
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
RUN groupadd -r app && useradd -r -g app app
COPY --from=builder --chown=app:app /root/.local /home/app/.local  # ← Set ownership
USER app
```

## Best Practices Summary

### ✅ **DO's**

1. **Use descriptive stage names** - `FROM python:3.11 as python-builder`
2. **Separate concerns** - build, test, runtime stages
3. **Minimize final stage** - only runtime dependencies
4. **Copy selectively** - only necessary files and directories
5. **Set proper permissions** - use `--chown` in COPY instructions
6. **Use parallel stages** - independent builds for better performance
7. **Share base layers** - common base for related stages

### ❌ **DON'Ts**

1. **Don't copy unnecessary files** from build stages
2. **Don't include build tools** in final runtime stage
3. **Don't use generic stage names** like `stage1`, `temp`
4. **Don't forget .dockerignore** - affects all stages
5. **Don't chain too many stages** - complexity vs benefit trade-off
6. **Don't copy entire filesystems** - use specific paths

## Real-World Example: Complete Application

```dockerfile
# syntax=docker/dockerfile:1.4

# Base stage with common dependencies
FROM python:3.11-slim as base
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Build stage with development tools
FROM base as builder
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Test stage
FROM builder as test
COPY requirements-test.txt .
RUN pip install -r requirements-test.txt
COPY . .
RUN python -m pytest tests/ --cov=src/ --cov-report=term-missing

# Security scan stage
FROM test as security
RUN pip install bandit safety
RUN bandit -r src/ -f json -o /bandit-report.json
RUN safety check --json --output /safety-report.json

# Production runtime stage
FROM base as production
RUN groupadd -r app && useradd -r -g app app

# Copy Python packages from builder
COPY --from=builder --chown=app:app /root/.local /home/app/.local

# Copy application code (only if tests pass)
COPY --from=test --chown=app:app /src /app/src
COPY --from=test --chown=app:app /config /app/config

# Copy security reports for audit
COPY --from=security /bandit-report.json /security/
COPY --from=security /safety-report.json /security/

WORKDIR /app
USER app

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "src.app:app"]
```

## Conclusion

Multi-stage builds provide powerful capabilities for creating optimized, secure container images:

- **Size reduction**: 60-90% smaller final images
- **Security improvement**: No build tools in production
- **Build flexibility**: Separate concerns and parallel execution
- **Testing integration**: Built-in testing and security scanning
- **Development efficiency**: Environment-specific optimizations

The key is to separate build-time requirements from runtime needs, creating clean, minimal production images while maintaining build flexibility and developer experience.
