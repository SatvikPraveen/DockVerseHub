# Images vs Containers: Key Differences & Workflow

**Location: `docs/images-vs-containers.md`**

## Fundamental Differences

### Docker Images

- **Read-only templates** used to create containers
- **Layered filesystem** built incrementally
- **Immutable** - cannot be changed after creation
- **Shareable** across multiple containers
- **Stored** in registries (Docker Hub, private registries)

### Docker Containers

- **Running instances** of images
- **Writable layer** on top of image layers
- **Mutable** - can be modified during runtime
- **Isolated** from each other and host system
- **Ephemeral** - data lost when container is removed

## Visual Comparison

```
IMAGE (Template/Blueprint)
┌─────────────────────────┐
│     Read-Only Layers    │
├─────────────────────────┤
│  Application Code       │ ← Layer 3
├─────────────────────────┤
│  Dependencies           │ ← Layer 2
├─────────────────────────┤
│  Base OS                │ ← Layer 1
└─────────────────────────┘

CONTAINER (Running Instance)
┌─────────────────────────┐
│   Writable Container    │ ← New writes go here
│        Layer            │
├─────────────────────────┤
│     Read-Only Image     │
│        Layers           │ ← Shared with other containers
│     (Referenced)        │
└─────────────────────────┘
```

## Layer Architecture

### Image Layers

Each Dockerfile instruction creates a new layer:

```dockerfile
FROM ubuntu:20.04          # Layer 1: Base OS
RUN apt-get update         # Layer 2: Package updates
COPY app.py /app/          # Layer 3: Application file
RUN pip install flask      # Layer 4: Dependencies
```

### Container Layer

When a container runs, Docker adds a thin writable layer:

- **Copy-on-Write**: Files from image layers are copied to container layer when modified
- **Union Filesystem**: All layers appear as single filesystem to container
- **Efficient Storage**: Multiple containers share image layers

## Workflow Diagram

```
Development Workflow:

Source Code → Dockerfile → docker build → Image → docker run → Container
     │              │           │          │          │         │
     │              │           │          │          │         │
     ▼              ▼           ▼          ▼          ▼         ▼
┌─────────┐ ┌─────────────┐ ┌─────────┐ ┌──────┐ ┌─────────┐ ┌───────────┐
│ app.py  │ │    FROM     │ │Building │ │nginx │ │Starting │ │ Running   │
│ req.txt │ │    COPY     │ │ layers  │ │:1.0  │ │container│ │ Container │
│ config  │ │    RUN      │ │   ...   │ │      │ │   ...   │ │ Process   │
└─────────┘ └─────────────┘ └─────────┘ └──────┘ └─────────┘ └───────────┘

Registry Integration:

Local Image → docker push → Registry → docker pull → Remote Image
     │              │          │          │            │
     │              │          │          │            │
     ▼              ▼          ▼          ▼            ▼
┌──────────┐ ┌─────────────┐ ┌────────┐ ┌─────────┐ ┌───────────┐
│myapp:1.0 │ │ Uploading   │ │Docker  │ │Download │ │myapp:1.0  │
│(local)   │ │   layers    │ │ Hub    │ │ layers  │ │(remote)   │
└──────────┘ └─────────────┘ └────────┘ └─────────┘ └───────────┘
```

## Practical Examples

### Building and Running

```bash
# Create image from Dockerfile
docker build -t myapp:v1.0 .

# Create and run container from image
docker run -d --name app-container myapp:v1.0

# Multiple containers from same image
docker run -d --name app1 myapp:v1.0
docker run -d --name app2 myapp:v1.0
docker run -d --name app3 myapp:v1.0
```

### Image Inspection

```bash
# List all images
docker images

# View image layers and history
docker history myapp:v1.0

# Detailed image information
docker inspect myapp:v1.0

# Check image size breakdown
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### Container Operations

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Inspect container details
docker inspect app-container

# View container changes
docker diff app-container
```

## Storage Implications

### Shared Layers Efficiency

```bash
# All containers share image layers
$ docker run -d --name web1 nginx:alpine
$ docker run -d --name web2 nginx:alpine
$ docker run -d --name web3 nginx:alpine

# Only one copy of nginx:alpine layers stored
# Each container has its own writable layer
```

### Container Data Persistence

```bash
# Changes in container layer are ephemeral
docker exec -it web1 sh
echo "test" > /tmp/file.txt
exit

# Data lost when container removed
docker rm -f web1
# /tmp/file.txt is gone forever
```

### Volume Mounting for Persistence

```bash
# Mount host directory for persistence
docker run -v /host/data:/container/data nginx

# Named volume for managed persistence
docker run -v mydata:/app/data nginx
```

## Image Management

### Tagging Strategy

```bash
# Build with semantic versioning
docker build -t myapp:1.0.0 .
docker build -t myapp:1.0 .
docker build -t myapp:latest .

# Environment-specific tags
docker build -t myapp:dev .
docker build -t myapp:staging .
docker build -t myapp:prod .
```

### Registry Operations

```bash
# Push to registry
docker push myregistry/myapp:1.0.0

# Pull from registry
docker pull myregistry/myapp:1.0.0

# Retag image
docker tag myapp:1.0.0 myregistry/myapp:1.0.0
```

## Container Lifecycle Management

### State Transitions

```bash
# Create container (not started)
docker create --name myapp nginx

# Start existing container
docker start myapp

# Stop running container
docker stop myapp

# Restart container
docker restart myapp

# Remove stopped container
docker rm myapp

# Remove running container (force)
docker rm -f myapp
```

### Data Persistence Strategies

#### 1. Volumes (Recommended)

```bash
# Named volume
docker run -v mydata:/app/data nginx

# Anonymous volume
docker run -v /app/data nginx
```

#### 2. Bind Mounts

```bash
# Host directory mount
docker run -v /host/path:/container/path nginx
```

#### 3. tmpfs Mounts (Memory)

```bash
# Memory-only storage
docker run --tmpfs /app/temp nginx
```

## Best Practices

### Image Best Practices

1. **Use multi-stage builds** to minimize image size
2. **Pin base image versions** for consistency
3. **Minimize layers** by combining RUN commands
4. **Use .dockerignore** to exclude unnecessary files
5. **Scan images** for security vulnerabilities

### Container Best Practices

1. **One process per container** for better isolation
2. **Use meaningful names** for easy identification
3. **Set resource limits** to prevent resource exhaustion
4. **Don't store data in containers** - use volumes
5. **Use init system** for proper signal handling

### Example: Optimized Multi-stage Build

```dockerfile
# Build stage
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:16-alpine AS production
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "app.js"]
```

## Common Misconceptions

### ❌ Wrong Assumptions

- Images and containers are the same thing
- Data in containers persists after removal
- One image can only create one container
- Containers modify the original image

### ✅ Correct Understanding

- Images are templates, containers are instances
- Container data is ephemeral unless persisted
- One image can create unlimited containers
- Containers add writable layer over read-only image

## Troubleshooting

### Image Issues

```bash
# Clean up unused images
docker image prune

# Remove all images
docker rmi $(docker images -q)

# Fix "no space left on device"
docker system prune -a
```

### Container Issues

```bash
# View container logs
docker logs container_name

# Access container shell
docker exec -it container_name bash

# Check container resource usage
docker stats container_name
```

## Next Steps

- Learn [Docker Networking](./networking.md) concepts
- Understand [Volume and Storage](./volumes-storage.md) management
- Explore [Docker Compose](./docker-compose.md) for multi-container applications
- Check [Performance Optimization](./performance-optimization.md) techniques
