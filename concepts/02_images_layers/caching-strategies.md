# Docker Build Caching Strategies

**File Location:** `concepts/02_images_layers/caching-strategies.md`

## Understanding Layer Caching

Docker caches each layer based on the instruction and its context. Cache hits occur when:

- Same instruction (FROM, RUN, COPY, etc.)
- Same arguments/content
- Same context (for COPY/ADD)

## Caching Best Practices

### 1. Layer Ordering by Change Frequency

Place less frequently changing instructions first:

```dockerfile
# Rarely changes - cache friendly
FROM python:3.9-slim

# Occasionally changes - dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Frequently changes - application code
COPY src/ ./src/
COPY app.py .
```

### 2. Separate Package Installation

```dockerfile
# ❌ Poor caching - code changes invalidate dependency cache
COPY . .
RUN npm install

# ✅ Good caching - dependencies cached separately
COPY package*.json .
RUN npm install
COPY src/ ./src/
```

### 3. Multi-Stage Build Caching

```dockerfile
# Build stage cached separately from runtime
FROM node:16 AS builder
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine AS production
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
```

### 4. BuildKit Advanced Caching

Enable BuildKit for advanced features:

```bash
export DOCKER_BUILDKIT=1
docker build --cache-from myapp:latest .
```

#### Cache Mounts

```dockerfile
# Cache package managers
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y python3

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

#### Secret Mounts

```dockerfile
# Don't leak secrets in layers
RUN --mount=type=secret,id=mypassword \
    curl -u user:$(cat /run/secrets/mypassword) https://api.example.com
```

### 5. .dockerignore Optimization

```bash
# .dockerignore
node_modules/
.git/
*.log
.DS_Store
Dockerfile*
README.md
.env
coverage/
.nyc_output
```

## Cache Invalidation Scenarios

### Instruction Changes

```dockerfile
# This change invalidates all subsequent layers
RUN apt-get update && apt-get install -y python3 curl vim  # Added vim
```

### Context Changes

```dockerfile
# Any file change in src/ invalidates this layer
COPY src/ ./src/
```

### Dockerfile Changes

```dockerfile
# Adding/removing/modifying any instruction invalidates subsequent layers
ENV NODE_ENV=production  # New ENV instruction
```

## Registry Cache Strategies

### Pull-Through Cache

```bash
# Use registry as cache source
docker build --cache-from myregistry/myapp:cache-stage1 .
```

### Multi-Stage Cache Export

```bash
# Export intermediate stages
docker build --target builder --tag myapp:builder .
docker push myapp:builder

# Use in later builds
docker build --cache-from myapp:builder .
```

## BuildKit Cache Backends

### Inline Cache

```bash
docker build --cache-from myapp:latest --cache-to type=inline .
```

### Registry Cache

```bash
docker build \
  --cache-from type=registry,ref=myregistry/myapp:cache \
  --cache-to type=registry,ref=myregistry/myapp:cache,mode=max .
```

### Local Cache

```bash
docker build \
  --cache-from type=local,src=/tmp/cache \
  --cache-to type=local,dest=/tmp/cache .
```

## Optimization Examples

### Python Application

```dockerfile
FROM python:3.9-slim

# System packages (rarely change)
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies (change occasionally)
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Application code (changes frequently)
COPY src/ ./src/
COPY app.py .
```

### Node.js Application

```dockerfile
FROM node:16-alpine

WORKDIR /app

# Dependencies first
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

# Source code last
COPY src/ ./src/
COPY public/ ./public/
```

### Go Application

```dockerfile
FROM golang:1.19-alpine AS builder

WORKDIR /app

# Modules first for better caching
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Source code
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o main .
```

## Cache Inspection

### View Build Cache

```bash
# List build cache
docker system df -v

# Prune build cache
docker builder prune

# Prune all cache
docker system prune -a
```

### Analyze Cache Usage

```bash
# Build with cache stats
docker build --progress=plain .

# BuildKit cache analysis
docker buildx du
```

## Performance Metrics

### Typical Cache Hit Rates

- Fresh build: 0% cache hits
- Code change only: 70-90% cache hits
- Dependency change: 30-50% cache hits
- Dockerfile change: 10-30% cache hits

### Build Time Improvements

- No cache: 5-10 minutes
- Good cache strategy: 30 seconds - 2 minutes
- Optimal cache: 10-30 seconds

## Anti-Patterns to Avoid

### Frequent Cache Busters

```dockerfile
# ❌ Timestamp breaks cache every build
RUN echo "Built at $(date)" > /build-time.txt

# ❌ Random values break cache
RUN apt-get update && apt-get install -y python3 && echo $RANDOM
```

### Poor Layer Ordering

```dockerfile
# ❌ Code copied before dependencies
COPY . .
RUN pip install -r requirements.txt  # Rebuilds on every code change
```

### Unnecessary Context

```dockerfile
# ❌ Large context with no .dockerignore
COPY . .  # Includes node_modules/, .git/, logs/
```

## Monitoring and Debugging

### Build Analysis

```bash
# Detailed build output
docker build --progress=plain --no-cache .

# Timing information
time docker build .
```

### Cache Debugging

```bash
# Force rebuild without cache
docker build --no-cache .

# Rebuild from specific stage
docker build --target stage-name .
```

## Summary

Effective caching strategies:

1. Order layers by change frequency
2. Separate dependencies from application code
3. Use .dockerignore to minimize context
4. Leverage BuildKit advanced features
5. Monitor cache hit rates and build times

Proper caching can reduce build times from minutes to seconds while improving developer productivity and CI/CD pipeline efficiency.
