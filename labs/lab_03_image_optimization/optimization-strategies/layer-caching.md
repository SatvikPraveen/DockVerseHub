# Docker Layer Caching Optimization Strategies

**File Location:** `labs/lab_03_image_optimization/optimization-strategies/layer-caching.md`

## Overview

Docker layer caching is one of the most impactful optimization techniques for reducing build times. Understanding how Docker's layer cache works and optimizing instruction order can reduce build times by 60-90% for subsequent builds.

## How Docker Layer Caching Works

### Layer Creation Process

```dockerfile
FROM python:3.11-slim     # Layer 1: Base image
COPY requirements.txt .   # Layer 2: Dependencies file
RUN pip install -r req... # Layer 3: Install dependencies
COPY . .                  # Layer 4: Application code
RUN chmod +x app.py       # Layer 5: File permissions
```

Each instruction creates a new layer. Docker caches layers based on:

- **Instruction content** (exact command)
- **Context changes** (file checksums)
- **Previous layer cache** (dependency chain)

### Cache Hit/Miss Logic

```
Layer N cache hit = (
    Instruction N identical AND
    Context N unchanged AND
    Layer N-1 cache hit
)
```

## Anti-Patterns (Cache Busters)

### ❌ **Anti-Pattern 1: Code Before Dependencies**

```dockerfile
# BAD: Code changes invalidate dependency cache
FROM python:3.11-slim
COPY . .                    # ← Code changes bust cache
RUN pip install -r requirements.txt  # ← Always re-runs
CMD ["python", "app.py"]
```

**Problem**: Any code change forces dependency reinstallation.

### ✅ **Solution: Dependencies First**

```dockerfile
# GOOD: Dependencies cached separately
FROM python:3.11-slim
COPY requirements.txt .     # ← Only changes with new deps
RUN pip install -r requirements.txt  # ← Cached until deps change
COPY . .                    # ← Code changes don't affect deps
CMD ["python", "app.py"]
```

### ❌ **Anti-Pattern 2: Combined Operations**

```dockerfile
# BAD: One change invalidates everything
RUN apt-get update && \
    apt-get install -y python3 curl && \
    pip install flask && \
    useradd app && \
    mkdir /app
```

**Problem**: Adding one package rebuilds entire layer.

### ✅ **Solution: Separate Concerns**

```dockerfile
# System packages (rarely change)
RUN apt-get update && apt-get install -y python3 curl && rm -rf /var/lib/apt/lists/*

# Python packages (change more often)
RUN pip install flask

# User and directories (rarely change)
RUN useradd app && mkdir /app
```

### ❌ **Anti-Pattern 3: Timestamp-based Invalidation**

```dockerfile
# BAD: Always creates new layer
RUN echo "Built on $(date)" > /build-info.txt
COPY requirements.txt .
```

**Problem**: Timestamp changes on every build.

### ✅ **Solution: Deterministic Content**

```dockerfile
# GOOD: Use build args for timestamps
ARG BUILD_DATE
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN echo "Built on ${BUILD_DATE}" > /build-info.txt
```

## Optimization Strategies

### Strategy 1: Dependency Layers First

#### Order by Change Frequency

```dockerfile
# Rarely changes (cached longest)
FROM python:3.11-slim

# Changes occasionally (system dependencies)
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Changes regularly (Python dependencies)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Changes frequently (application code)
COPY src/ ./src/
COPY config/ ./config/

# Changes most often (build artifacts)
RUN python -m compileall src/
```

### Strategy 2: Multi-Stage Caching

#### Separate Build and Runtime Caches

```dockerfile
# Build stage - cached independently
FROM python:3.11-slim as builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Runtime stage - uses build cache
FROM python:3.11-slim as runtime
COPY --from=builder /root/.local /home/app/.local
COPY src/ ./src/
```

**Benefits:**

- Build dependencies cached separately
- Runtime image stays clean
- Parallel cache utilization

### Strategy 3: Layer Splitting

#### Fine-grained Dependency Management

```dockerfile
# Split by dependency groups
COPY requirements/base.txt ./requirements/
RUN pip install -r requirements/base.txt

COPY requirements/dev.txt ./requirements/
RUN pip install -r requirements/dev.txt

COPY requirements/prod.txt ./requirements/
RUN pip install -r requirements/prod.txt
```

### Strategy 4: BuildKit Cache Mounts

#### External Cache Management

```dockerfile
# Enable BuildKit cache mounts
# syntax=docker/dockerfile:1.4

FROM python:3.11-slim

# Cache pip downloads across builds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Cache apt packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y python3-dev
```

## Advanced Caching Techniques

### Technique 1: Conditional Layers

#### Environment-Specific Caching

```dockerfile
FROM python:3.11-slim

# Always install base requirements
COPY requirements/base.txt ./requirements/
RUN pip install -r requirements/base.txt

# Conditionally install dev requirements
ARG ENVIRONMENT=production
COPY requirements/dev.txt ./requirements/
RUN if [ "$ENVIRONMENT" = "development" ]; then \
      pip install -r requirements/dev.txt; \
    fi
```

### Technique 2: Checksum-Based Invalidation

#### Smart Cache Invalidation

```dockerfile
# Copy only files that affect dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Separate layer for source code
COPY src/ ./src/
COPY public/ ./public/
```

### Technique 3: Parallel Build Stages

#### Independent Cache Chains

```dockerfile
# Stage 1: Python dependencies
FROM python:3.11-slim as python-deps
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Node.js assets (parallel to stage 1)
FROM node:18-alpine as node-assets
COPY package.json .
RUN npm install
COPY webpack.config.js .
COPY src/assets/ ./src/assets/
RUN npm run build

# Final stage: Combine both
FROM python:3.11-slim
COPY --from=python-deps /root/.local /home/app/.local
COPY --from=node-assets /app/dist ./static/
```

## Cache Performance Measurement

### Build Time Analysis

```bash
#!/bin/bash
# Cache performance test script

echo "=== Docker Layer Cache Performance Test ==="

# Clear all cache
docker system prune -af
echo "1. Clean build (no cache):"
time docker build -t app:nocache .

echo "2. Cached build (no changes):"
time docker build -t app:fullcache .

echo "3. Code change only:"
touch src/app.py
time docker build -t app:codecache .

echo "4. Dependency change:"
echo "requests==2.28.0" >> requirements.txt
time docker build -t app:depcache .
```

### Cache Hit Rate Monitoring

```bash
# Enable BuildKit verbose output
export DOCKER_BUILDKIT=1
docker build --progress=plain . 2>&1 | grep -E "(CACHED|RUN)"
```

## Best Practices Summary

### ✅ **DO's**

1. **Order by change frequency** - least changing instructions first
2. **Separate dependencies from code** - cache deps independently
3. **Use multi-stage builds** - isolate build vs runtime
4. **Leverage BuildKit cache mounts** - persistent cache across builds
5. **Split dependency groups** - fine-grained cache invalidation
6. **Use specific base image tags** - avoid `latest` tag cache issues

### ❌ **DON'Ts**

1. **Don't combine unrelated operations** in single RUN
2. **Don't use timestamps or random data** in early layers
3. **Don't copy entire context** before installing dependencies
4. **Don't use `ADD` for URLs** - not cacheable
5. **Don't ignore `.dockerignore`** - affects COPY context
6. **Don't use `apt-get upgrade`** - unpredictable cache behavior

## Monitoring and Debugging

### Cache Analysis Tools

```bash
# Analyze layer sizes and caching
docker history <image> --no-trunc

# Show cache usage in build
docker build --progress=plain --no-cache .

# Inspect layer content
docker run --rm -it <image> sh
```

### Cache Debugging

```bash
# Force rebuild specific stage
docker build --target=builder --no-cache .

# Check cache mount usage (BuildKit)
docker system df -v
```

## Real-World Example

### Before Optimization

```dockerfile
FROM python:3.11-slim
COPY . .
RUN pip install -r requirements.txt
RUN apt-get update && apt-get install -y curl
CMD ["python", "app.py"]
```

**Result**: Every code change = full rebuild (3+ minutes)

### After Optimization

```dockerfile
FROM python:3.11-slim

# System packages (rarely change)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Python dependencies (change occasionally)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code (changes frequently)
COPY src/ ./src/
COPY config/ ./config/

CMD ["python", "src/app.py"]
```

**Result**: Code changes = 10-30 second rebuilds (90% faster)

## Conclusion

Effective layer caching can reduce build times by 60-90% through:

- Strategic instruction ordering by change frequency
- Separation of dependencies from application code
- Multi-stage builds for cache isolation
- BuildKit cache mounts for persistent caching
- Fine-grained dependency management

The key insight: **Docker caches entire instruction chains**, so placing stable instructions early maximizes cache reuse across builds.
