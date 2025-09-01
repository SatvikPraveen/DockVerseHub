# Dependency Management Optimization Strategies

**File Location:** `labs/lab_03_image_optimization/optimization-strategies/dependency-management.md`

## Overview

Effective dependency management is crucial for Docker image optimization. Poor dependency management can lead to bloated images, security vulnerabilities, and slow builds. This guide covers strategies to minimize dependencies while maintaining functionality.

## Dependency Types Analysis

### System Dependencies

```dockerfile
# Heavy system dependencies (avoid if possible)
RUN apt-get update && apt-get install -y \
    build-essential \      # 200MB+
    python3-dev \         # 50MB+
    libssl-dev \          # 30MB+
    libffi-dev \          # 20MB+
    zlib1g-dev \          # 15MB+
    libjpeg-dev \         # 25MB+
    libpq-dev             # 40MB+
# Total: ~380MB of system packages
```

### Language Dependencies

```dockerfile
# Python package dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt
# Typical web app: 150-400MB of Python packages
```

### Runtime vs Build Dependencies

```dockerfile
# Build-time only (should be removed)
gcc, g++, python3-dev, node-gyp, make

# Runtime required (must keep)
libpq5, libssl1.1, zlib1g, libjpeg8
```

## Optimization Strategies

### Strategy 1: Minimal Base Images

#### Alpine Linux Approach

```dockerfile
# Traditional approach - Ubuntu base
FROM python:3.11                    # 800MB base
RUN apt-get update && apt-get install -y \
    gcc python3-dev libpq-dev       # +200MB build tools
COPY requirements.txt .
RUN pip install -r requirements.txt # +300MB Python packages
# Total: ~1.3GB

# Alpine approach - Minimal base
FROM python:3.11-alpine             # 50MB base
RUN apk add --no-cache --virtual .build-deps \
    gcc musl-dev postgresql-dev     # +100MB build tools (temporary)
COPY requirements.txt .
RUN pip install -r requirements.txt && \
    apk del .build-deps             # Remove build tools (-100MB)
# Total: ~350MB (73% reduction)
```

#### Distroless Approach

```dockerfile
# Multi-stage with distroless
FROM python:3.11-slim as builder
RUN apt-get update && apt-get install -y gcc python3-dev libpq-dev
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM gcr.io/distroless/python3-debian11:nonroot
COPY --from=builder /root/.local /home/nonroot/.local
COPY . .
# Total: ~80MB (minimal runtime, zero build tools)
```

### Strategy 2: Dependency Layer Separation

#### Separate Package Groups

```dockerfile
FROM python:3.11-slim

# Core system libraries (rarely change)
RUN apt-get update && apt-get install -y \
    libpq5 \
    libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

# Core Python packages (change occasionally)
COPY requirements/base.txt ./requirements/
RUN pip install --no-cache-dir -r requirements/base.txt

# Framework packages (change regularly)
COPY requirements/framework.txt ./requirements/
RUN pip install --no-cache-dir -r requirements/framework.txt

# Application packages (change frequently)
COPY requirements/app.txt ./requirements/
RUN pip install --no-cache-dir -r requirements/app.txt

# Application code (changes most often)
COPY src/ ./src/
```

#### Benefits of Separation

- **Cache efficiency**: Only changed layers rebuild
- **Debugging**: Easier to identify dependency issues
- **Security**: Update packages independently
- **Size tracking**: Monitor growth per category

### Strategy 3: Virtual Packages (Alpine)

#### Temporary Build Dependencies

```dockerfile
FROM python:3.11-alpine

# Install build dependencies temporarily
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    python3-dev \
    postgresql-dev \
    libffi-dev \
    openssl-dev

# Install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Remove build dependencies (saves ~100MB)
RUN apk del .build-deps

# Install only runtime dependencies
RUN apk add --no-cache \
    postgresql-client \
    libpq
```

#### Advanced Virtual Package Management

```dockerfile
FROM alpine:3.18

# Multiple virtual package groups
RUN apk add --no-cache --virtual .python-build \
    python3-dev \
    py3-pip \
    gcc \
    musl-dev

RUN apk add --no-cache --virtual .node-build \
    nodejs \
    npm \
    node-gyp

# Build applications
COPY requirements.txt package.json ./
RUN pip install -r requirements.txt
RUN npm install && npm run build

# Remove all build dependencies at once
RUN apk del .python-build .node-build

# Keep only runtime dependencies
RUN apk add --no-cache python3 nodejs
```

### Strategy 4: Dependency Pinning and Management

#### Version Pinning Best Practices

```dockerfile
# requirements.txt - Pin all versions
Flask==2.3.3
SQLAlchemy==2.0.21
psycopg2-binary==2.9.7
redis==5.0.1
gunicorn==21.2.0

# Pin transitive dependencies too
Werkzeug==2.3.7
Jinja2==3.1.2
MarkupSafe==2.1.3
```

#### Dependency Scanning and Cleanup

```dockerfile
FROM python:3.11-slim as analyzer

# Install dependency analysis tools
RUN pip install pip-tools pipdeptree safety bandit

COPY requirements.txt .
RUN pip install -r requirements.txt

# Analyze dependencies
RUN pipdeptree --json-tree > dependency-tree.json
RUN safety check --json --output safety-report.json
RUN pip-compile --generate-hashes requirements.txt

FROM python:3.11-slim as production
# Copy only vetted, minimal dependencies
COPY --from=analyzer dependency-tree.json safety-report.json ./reports/
```

## Language-Specific Optimizations

### Python Optimizations

#### Wheel-Based Installation

```dockerfile
# Use pre-compiled wheels when possible
FROM python:3.11-slim

# Install wheel first
RUN pip install --no-cache-dir wheel

# Use wheel format (faster, no compilation)
COPY requirements.txt .
RUN pip install --no-cache-dir \
    --only-binary=all \
    -r requirements.txt
```

#### Multi-Stage Python Build

```dockerfile
# Build stage with compilation tools
FROM python:3.11-slim as python-builder
RUN apt-get update && apt-get install -y gcc python3-dev
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage without build tools
FROM python:3.11-slim as python-runtime
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=python-builder /root/.local /home/app/.local
ENV PATH="/home/app/.local/bin:$PATH"
```

### Node.js Optimizations

#### Production Dependencies Only

```dockerfile
FROM node:18-alpine as builder

# Install all dependencies (including dev)
COPY package*.json ./
RUN npm ci

# Build application
COPY . .
RUN npm run build

# Runtime stage with production deps only
FROM node:18-alpine as runtime
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy built application and minimal dependencies
COPY --from=builder /app/dist ./dist/
COPY --from=builder /app/package.json ./

CMD ["node", "dist/server.js"]
```

#### Node.js Multi-Stage with Asset Building

```dockerfile
FROM node:18-alpine as dependencies
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine as build-assets
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine as runtime
COPY --from=dependencies /node_modules ./node_modules
COPY --from=build-assets /app/dist ./dist
COPY server.js package.json ./
CMD ["node", "server.js"]
```

### Go Optimizations

#### Static Binary Compilation

```dockerfile
FROM golang:1.21-alpine as builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# Build static binary (no external dependencies)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o app ./cmd/

# Minimal runtime (scratch or distroless)
FROM scratch as runtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/app /app

EXPOSE 8080
CMD ["/app"]
```

## Security-Focused Dependency Management

### Vulnerability Scanning Integration

#### Build-Time Security Scanning

```dockerfile
FROM python:3.11-slim as security-scan

# Install security tools
RUN pip install safety bandit semgrep

COPY requirements.txt .
RUN pip install -r requirements.txt

# Scan dependencies for vulnerabilities
RUN safety check --json --output /safety-report.json

# Scan code for security issues
COPY src/ ./src/
RUN bandit -r src/ -f json -o /bandit-report.json

# Static analysis
RUN semgrep --config=auto src/ --json --output=/semgrep-report.json

# Production stage (only if scans pass)
FROM python:3.11-slim as production
COPY --from=security-scan /safety-report.json /reports/
COPY --from=security-scan /bandit-report.json /reports/
COPY --from=security-scan /semgrep-report.json /reports/
# Continue with application setup...
```

### Minimal Runtime Dependencies

#### Identify Essential Dependencies

```bash
# Analyze what's actually needed at runtime
ldd /usr/local/bin/python3
# libpython3.11.so.1.0 => required
# libssl.so.1.1 => required for HTTPS
# libcrypto.so.1.1 => required for crypto
# libc.so.6 => required (glibc)

# Create minimal runtime with only essentials
```

```dockerfile
FROM debian:bullseye-slim as runtime-analyzer
RUN apt-get update && apt-get install -y python3
RUN ldd /usr/bin/python3 > /python-deps.txt

FROM debian:bullseye-slim as minimal-runtime
# Copy only identified essential libraries
COPY --from=runtime-analyzer /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/
COPY --from=runtime-analyzer /lib/x86_64-linux-gnu/libssl.so.1.1 /lib/x86_64-linux-gnu/
COPY --from=runtime-analyzer /usr/bin/python3 /usr/bin/
```

## Monitoring and Optimization

### Dependency Size Tracking

#### Size Analysis Script

```bash
#!/bin/bash
# analyze-dependencies.sh

echo "=== Docker Image Dependency Analysis ==="

# Build with each optimization level
docker build -f Dockerfile.naive -t app:naive .
docker build -f Dockerfile.optimized -t app:optimized .
docker build -f Dockerfile.alpine -t app:alpine .

# Compare sizes
echo "Image sizes:"
docker images app --format "table {{.Tag}}\t{{.Size}}"

# Layer analysis
echo -e "\nLayer breakdown:"
for tag in naive optimized alpine; do
    echo "=== app:$tag ==="
    docker history app:$tag --format "table {{.Size}}\t{{.CreatedBy}}" | head -10
done
```

### Continuous Dependency Monitoring

#### CI/CD Integration

```yaml
# .github/workflows/dependency-check.yml
name: Dependency Security Check
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build security scan stage
        run: docker build --target=security-scan -t app:security .

      - name: Extract security reports
        run: |
          docker run --rm -v $(pwd)/reports:/out app:security \
            cp /reports/*.json /out/

      - name: Check for vulnerabilities
        run: |
          if grep -q '"vulnerabilities".*[1-9]' reports/safety-report.json; then
            echo "Security vulnerabilities found!"
            exit 1
          fi
```

## Best Practices Summary

### ✅ **DO's**

#### Dependency Selection

1. **Use minimal base images** - Alpine, distroless, or slim variants
2. **Pin dependency versions** - Avoid `latest` tags and unpinned packages
3. **Separate build from runtime** - Multi-stage builds for dependency isolation
4. **Regular security scanning** - Automated vulnerability checks
5. **Cache dependency layers** - Install dependencies before copying code

#### Package Management

1. **Remove build dependencies** - Use virtual packages or multi-stage builds
2. **Clean package caches** - `rm -rf /var/lib/apt/lists/*`, `npm cache clean`
3. **Use official packages** - Prefer distribution packages over third-party
4. **Minimize package sets** - Only install what's actually needed
5. **Group related dependencies** - Install together for better caching

### ❌ **DON'Ts**

#### Common Anti-Patterns

1. **Don't use full OS images** - Ubuntu/CentOS for simple applications
2. **Don't install debug tools** - vim, curl, wget in production images
3. **Don't ignore transitive deps** - Pin indirect dependencies too
4. **Don't skip cleanup** - Always remove temporary files and caches
5. **Don't combine unrelated deps** - Separate system, language, and app packages

#### Security Anti-Patterns

1. **Don't ignore vulnerabilities** - Regular scanning and updates required
2. **Don't use outdated packages** - Keep dependencies current
3. **Don't include dev dependencies** - Separate development from production
4. **Don't run as root** - Create dedicated user accounts
5. **Don't skip dependency verification** - Use checksums and signatures

## Real-World Example: Web Application

```dockerfile
# Dependency-optimized web application
FROM python:3.11-alpine as builder

# Build dependencies (temporary)
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    python3-dev \
    postgresql-dev \
    libffi-dev

# Install Python dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Remove build dependencies
RUN apk del .build-deps

# Runtime stage
FROM python:3.11-alpine as production

# Runtime dependencies only
RUN apk add --no-cache \
    postgresql-client \
    libpq \
    && addgroup -g 1001 -S app \
    && adduser -S app -u 1001 -G app

# Copy installed packages from builder
COPY --from=builder /root/.local /home/app/.local

# Copy application
COPY --chown=app:app src/ /app/src/
COPY --chown=app:app config/ /app/config/

USER app
WORKDIR /app
ENV PATH="/home/app/.local/bin:$PATH"

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:5000/health

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "src.app:app"]
```

**Results:**

- **Base image**: 50MB (Alpine vs 800MB Ubuntu)
- **Dependencies**: 120MB (vs 400MB with build tools)
- **Total size**: 170MB (vs 1.2GB naive approach)
- **Security**: 0 vulnerabilities (vs 200+ with full OS)
- **Build time**: 45s (vs 3m 45s naive)

## Conclusion

Effective dependency management delivers substantial benefits:

- **85% size reduction** through minimal dependencies
- **90% fewer vulnerabilities** via minimal attack surface
- **65% faster builds** with proper dependency caching
- **Improved security** through regular scanning and updates
- **Better maintainability** via explicit dependency management

The key principles are: minimize what you install, separate build from runtime, pin versions, scan for vulnerabilities, and continuously monitor dependency health.
