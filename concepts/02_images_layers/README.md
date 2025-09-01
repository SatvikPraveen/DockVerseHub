# Docker Images and Layers

**File Location:** `concepts/02_images_layers/README.md`

## Understanding Docker Images

Docker images are the building blocks of containers. Think of them as immutable templates that contain everything needed to run an application: code, runtime, system tools, libraries, and settings.

## Image Architecture

### Layered File System

Docker images use a layered file system where each layer represents a change:

```
┌─────────────────────────────┐
│     Application Layer       │  ← Your app code
├─────────────────────────────┤
│     Dependencies Layer      │  ← npm install, pip install
├─────────────────────────────┤
│     Runtime Layer           │  ← Node.js, Python
├─────────────────────────────┤
│     Base OS Layer           │  ← Ubuntu, Alpine
└─────────────────────────────┘
```

### Layer Benefits

- **Caching**: Unchanged layers are reused
- **Efficiency**: Only modified layers are rebuilt
- **Storage**: Layers shared between images save space
- **Distribution**: Only new layers are transferred

## Image vs Container

| Image            | Container                |
| ---------------- | ------------------------ |
| Static blueprint | Running instance         |
| Immutable        | Mutable (writable layer) |
| Can be shared    | Isolated execution       |
| Template         | Active process           |

## Image Optimization Strategies

### 1. Multi-Stage Builds

Separate build dependencies from runtime:

```dockerfile
# Build stage
FROM node:16-alpine AS builder
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage
FROM node:16-alpine
COPY --from=builder /app/node_modules ./node_modules
COPY . .
CMD ["node", "app.js"]
```

### 2. Layer Optimization

- Combine RUN commands
- Use .dockerignore
- Order layers by change frequency
- Use specific image tags

### 3. Base Image Selection

- **Alpine**: Smallest (~5MB base)
- **Distroless**: No shell, package manager
- **Scratch**: Completely empty image
- **Ubuntu/Debian**: Full-featured but larger

## Image Inspection

```bash
# View image layers
docker history <image>

# Detailed image information
docker inspect <image>

# Compare image sizes
docker images --format "table {{.Repository}}\t{{.Size}}"

# Analyze layer composition
docker image inspect <image> --format '{{.RootFS.Layers}}'
```

## Registry Operations

### Local Registry

```bash
# Run local registry
docker run -d -p 5000:5000 --name registry registry:2

# Tag for local registry
docker tag myapp localhost:5000/myapp

# Push to local registry
docker push localhost:5000/myapp
```

### Remote Registry

```bash
# Login to registry
docker login docker.io

# Tag for Docker Hub
docker tag myapp username/myapp:v1.0

# Push to Docker Hub
docker push username/myapp:v1.0
```

## Caching Strategies

### Build Cache

- Layer caching based on Dockerfile instructions
- Cache invalidation on instruction changes
- BuildKit for advanced caching features

### Registry Cache

- Layer deduplication across images
- Content-addressable storage
- Efficient layer distribution

## Security Considerations

### Image Scanning

```bash
# Scan for vulnerabilities
docker scout quickview <image>

# Detailed security report
docker scout cves <image>
```

### Best Practices

- Use official base images
- Keep images updated
- Run as non-root user
- Minimize attack surface
- Sign images with Docker Content Trust

## Files in This Directory

- `Dockerfile.basic` - Naive build example
- `Dockerfile.optimized` - Multi-stage optimized build
- `Dockerfile.distroless` - Security-hardened distroless image
- `inspect_image.sh` - Layer analysis script
- `image_comparison.md` - Visual comparison of different approaches
- `caching-strategies.md` - Detailed caching guide
- `registry/` - Registry operation examples

## Key Takeaways

1. Images are composed of read-only layers
2. Layer caching dramatically improves build times
3. Multi-stage builds reduce final image size
4. Base image choice impacts security and size
5. Proper layer ordering optimizes caching
6. Registry operations enable image distribution

Ready to optimize your images? Let's explore the practical examples!
