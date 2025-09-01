# Docker Performance Optimization: Image Size, Build Speed & Runtime

**Location: `docs/performance-optimization.md`**

## Performance Optimization Overview

Docker performance optimization involves three key areas:

1. **Image optimization** - Reduce size and improve caching
2. **Build optimization** - Speed up build times
3. **Runtime optimization** - Improve container performance

## Image Size Optimization

### Multi-Stage Builds

```dockerfile
# ❌ Single-stage (large image)
FROM node:16
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["npm", "start"]

# ✅ Multi-stage (optimized)
FROM node:16 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:16-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./
USER node
CMD ["npm", "start"]
```

### Base Image Selection

```dockerfile
# Image size comparison
FROM ubuntu:20.04        # ~72MB
FROM node:16             # ~993MB
FROM node:16-alpine      # ~172MB
FROM node:16-slim        # ~244MB
FROM gcr.io/distroless/nodejs:16  # ~169MB

# ✅ Recommended for production
FROM node:16-alpine AS builder
# ... build steps

FROM node:16-alpine
# ... runtime setup
```

### Layer Optimization

```dockerfile
# ❌ Poor layer structure
FROM alpine:3.18
RUN apk add --no-cache curl
RUN apk add --no-cache wget
RUN apk add --no-cache bash
COPY app.js /app/
COPY package.json /app/

# ✅ Optimized layers
FROM alpine:3.18
RUN apk add --no-cache \
    curl \
    wget \
    bash
COPY package.json app.js /app/
```

### Dockerfile Best Practices

```dockerfile
FROM node:16-alpine

# Install system dependencies in single layer
RUN apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S nodejs \
    && adduser -S nextjs -u 1001

WORKDIR /app

# Copy dependency files first (better caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production \
    && npm cache clean --force

# Copy application code
COPY --chown=nextjs:nodejs . .

# Switch to non-root user
USER nextjs

# Use exec form and init system
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

### .dockerignore Optimization

```dockerignore
# .dockerignore
node_modules
npm-debug.log*
.npm
.git
.gitignore
README.md
.env
.nyc_output
coverage
.DS_Store
*.log
.vscode
.idea
dist
build
*.tar.gz
Dockerfile*
docker-compose*.yml
```

## Build Speed Optimization

### BuildKit Features

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:16-alpine

# Use cache mounts
RUN --mount=type=cache,target=/root/.npm \
    npm install

# Use secret mounts
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) \
    npm run build

# Use bind mounts for development
RUN --mount=type=bind,source=.,target=/app \
    npm run test
```

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build with secrets
echo "secret_api_key" | docker build --secret id=api_key,src=- .

# Build with cache mount
docker build \
    --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/app/node_modules \
    .
```

### Parallel Builds

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:16-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:16-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM nginx:alpine AS runtime
COPY --from=builder /app/dist /usr/share/nginx/html
```

```bash
# Build stages in parallel
docker build --target deps . &
docker build --target builder . &
wait
```

### Build Context Optimization

```bash
# Check context size
du -sh .

# Time build with context
time docker build .

# Use specific context
docker build -f docker/Dockerfile context/

# Remote context
docker build https://github.com/user/repo.git#main:docker/
```

### Registry Layer Caching

```yaml
# GitHub Actions with registry cache
- name: Build and push
  uses: docker/build-push-action@v4
  with:
    context: .
    push: true
    tags: myregistry/myapp:latest
    cache-from: type=registry,ref=myregistry/myapp:cache
    cache-to: type=registry,ref=myregistry/myapp:cache,mode=max
```

## Runtime Performance Optimization

### Resource Limits and Requests

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
        reservations:
          memory: 256M
          cpus: "0.5"
```

```bash
# Runtime resource limits
docker run \
    --memory 512m \
    --cpus 1.0 \
    --memory-swap 512m \
    --oom-kill-disable \
    myapp:latest
```

### Storage Driver Optimization

```json
# /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
```

### tmpfs for Temporary Files

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    tmpfs:
      - /tmp:size=100m,noexec,nosuid,nodev
      - /var/cache:size=50m
    volumes:
      - app_data:/app/data
```

### Memory Optimization

```dockerfile
# Java heap size optimization
FROM openjdk:11-jre-slim
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
CMD ["java", "$JAVA_OPTS", "-jar", "app.jar"]

# Node.js memory optimization
FROM node:16-alpine
ENV NODE_OPTIONS="--max-old-space-size=512"
CMD ["node", "app.js"]
```

### Network Performance

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    networks:
      - app-network
    ports:
      - "3000:3000"

networks:
  app-network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: docker-fast
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## Container Startup Optimization

### Init Systems

```dockerfile
FROM node:16-alpine

# Install dumb-init
RUN apk add --no-cache dumb-init

# Use as PID 1
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

### Health Check Optimization

```dockerfile
FROM nginx:alpine

# Lightweight health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Or custom health check script
COPY healthcheck.sh /usr/local/bin/
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh
```

### Graceful Shutdown

```javascript
// Node.js graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  server.close(() => {
    process.exit(0);
  });
});

process.on("SIGINT", () => {
  console.log("SIGINT received, shutting down gracefully");
  server.close(() => {
    process.exit(0);
  });
});
```

```python
# Python graceful shutdown
import signal
import sys
import time

def signal_handler(sig, frame):
    print('Graceful shutdown initiated')
    # Cleanup code here
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)
```

## Volume Performance

### Volume Driver Optimization

```bash
# Local volume with specific options
docker volume create \
    --driver local \
    --opt type=tmpfs \
    --opt device=tmpfs \
    --opt o=size=100m,uid=1000 \
    temp-volume

# NFS volume for shared storage
docker volume create \
    --driver local \
    --opt type=nfs \
    --opt o=addr=192.168.1.100,rw \
    --opt device=:/path/to/dir \
    nfs-volume
```

### Bind Mount vs Volume Performance

```bash
# Performance test script
#!/bin/bash

# Test volume performance
docker run --rm -v test-volume:/data alpine \
    dd if=/dev/zero of=/data/test bs=1M count=100

# Test bind mount performance
docker run --rm -v $(pwd)/data:/data alpine \
    dd if=/dev/zero of=/data/test bs=1M count=100

# Test tmpfs performance
docker run --rm --tmpfs /data alpine \
    dd if=/dev/zero of=/data/test bs=1M count=100
```

## Monitoring and Profiling

### Resource Monitoring

```bash
#!/bin/bash
# performance-monitor.sh

echo "=== Docker Performance Monitor ==="
echo "Timestamp: $(date)"

echo -e "\n=== Container Resource Usage ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

echo -e "\n=== System Resources ==="
echo "CPU: $(cat /proc/loadavg)"
echo "Memory: $(free -h | grep ^Mem)"
echo "Disk: $(df -h / | tail -1)"

echo -e "\n=== Docker System Usage ==="
docker system df

echo -e "\n=== Top Resource Consuming Containers ==="
docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}" | sort -k2 -nr | head -5
```

### Application Profiling

```python
# Python performance profiling
import cProfile
import pstats
import io
from contextlib import contextmanager

@contextmanager
def profiler():
    pr = cProfile.Profile()
    pr.enable()
    try:
        yield pr
    finally:
        pr.disable()
        s = io.StringIO()
        sortby = 'cumulative'
        ps = pstats.Stats(pr, stream=s).sort_stats(sortby)
        ps.print_stats()
        print(s.getvalue())

# Usage
with profiler():
    # Your application code here
    app.run()
```

### Build Time Analysis

```bash
# Build with timing
time docker build --no-cache .

# Detailed build analysis
docker build --no-cache --progress=plain . 2>&1 | ts

# Layer-by-layer timing
#!/bin/bash
DOCKERFILE_LINES=$(wc -l < Dockerfile)
for i in $(seq 1 $DOCKERFILE_LINES); do
    echo "Building through line $i"
    head -n $i Dockerfile | time docker build -f - .
done
```

## Performance Testing

### Load Testing Containers

```yaml
# docker-compose.test.yml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "3000:3000"

  load-test:
    image: loadimpact/k6:latest
    volumes:
      - ./tests:/scripts
    command: run /scripts/load-test.js
    environment:
      - TARGET_URL=http://app:3000
    depends_on:
      - app
```

```javascript
// load-test.js
import http from "k6/http";
import { check, sleep } from "k6";

export let options = {
  stages: [
    { duration: "2m", target: 100 },
    { duration: "5m", target: 100 },
    { duration: "2m", target: 200 },
    { duration: "5m", target: 200 },
    { duration: "2m", target: 0 },
  ],
};

export default function () {
  let response = http.get(`${__ENV.TARGET_URL}/`);
  check(response, {
    "status was 200": (r) => r.status == 200,
    "response time OK": (r) => r.timings.duration < 200,
  });
  sleep(1);
}
```

### Benchmark Script

```bash
#!/bin/bash
# container-benchmark.sh

CONTAINER_NAME=$1
DURATION=${2:-60}

echo "=== Container Benchmark ==="
echo "Container: $CONTAINER_NAME"
echo "Duration: $DURATION seconds"

# Start monitoring
docker stats $CONTAINER_NAME &
STATS_PID=$!

# CPU benchmark
echo "Running CPU benchmark..."
docker exec $CONTAINER_NAME stress --cpu 1 --timeout ${DURATION}s

# Memory benchmark
echo "Running memory benchmark..."
docker exec $CONTAINER_NAME stress --vm 1 --vm-bytes 128M --timeout ${DURATION}s

# I/O benchmark
echo "Running I/O benchmark..."
docker exec $CONTAINER_NAME dd if=/dev/zero of=/tmp/test bs=1M count=100

# Stop monitoring
kill $STATS_PID

echo "Benchmark complete"
```

## Performance Best Practices

### Development Environment

1. **Use BuildKit** for faster builds
2. **Optimize .dockerignore** to reduce context size
3. **Use multi-stage builds** for smaller images
4. **Layer caching** strategy in Dockerfiles
5. **Local registry** for frequently used images

### Production Environment

1. **Resource limits** on all containers
2. **Health checks** with appropriate timeouts
3. **Graceful shutdown** handling
4. **Storage driver** optimization
5. **Network performance** tuning
6. **Regular monitoring** and alerting

### Optimization Checklist

```
Build Optimization:
□ Enable BuildKit
□ Optimize Dockerfile layer order
□ Use .dockerignore effectively
□ Minimize build context size
□ Use multi-stage builds
□ Cache frequently used layers

Image Optimization:
□ Choose minimal base images
□ Remove unnecessary packages
□ Use distroless for production
□ Optimize layer structure
□ Regular image updates

Runtime Optimization:
□ Set appropriate resource limits
□ Use init systems (dumb-init)
□ Implement health checks
□ Use tmpfs for temporary files
□ Optimize storage drivers
□ Monitor resource usage
```

## Performance Metrics to Track

### Key Performance Indicators

```bash
# Container metrics
- CPU usage percentage
- Memory usage (actual vs limit)
- Network I/O
- Disk I/O
- Container start time
- Application response time

# Build metrics
- Build time
- Image size
- Layer count
- Cache hit ratio
- Context upload time

# System metrics
- Host CPU/Memory usage
- Disk space utilization
- Network throughput
- Container density
```

### Monitoring Script

```python
#!/usr/bin/env python3
# performance-tracker.py

import docker
import time
import json
from datetime import datetime

def track_performance(container_name, duration=300):
    client = docker.from_env()
    container = client.containers.get(container_name)

    metrics = []
    start_time = time.time()

    while time.time() - start_time < duration:
        stats = container.stats(stream=False)

        # Calculate CPU percentage
        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                   stats['precpu_stats']['cpu_usage']['total_usage']
        system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                      stats['precpu_stats']['system_cpu_usage']
        cpu_percent = (cpu_delta / system_delta) * 100.0 if system_delta > 0 else 0

        # Memory usage
        memory_usage = stats['memory_stats']['usage']
        memory_limit = stats['memory_stats']['limit']
        memory_percent = (memory_usage / memory_limit) * 100.0

        metric = {
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': cpu_percent,
            'memory_usage': memory_usage,
            'memory_percent': memory_percent,
            'network_rx': sum(net['rx_bytes'] for net in stats['networks'].values()),
            'network_tx': sum(net['tx_bytes'] for net in stats['networks'].values())
        }

        metrics.append(metric)
        time.sleep(1)

    # Save metrics
    with open(f'{container_name}_metrics.json', 'w') as f:
        json.dump(metrics, f, indent=2)

    return metrics

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python performance-tracker.py CONTAINER_NAME")
        sys.exit(1)

    track_performance(sys.argv[1])
```

## Next Steps

- Learn [Production Deployment](./production-deployment.md) for production optimization
- Check [Monitoring and Logging](./monitoring-logging.md) for performance monitoring
- Explore [Docker Ecosystem](./docker-ecosystem.md) for performance tools
- Understand [Cost Optimization](./cost-optimization.md) strategies
