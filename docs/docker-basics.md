# Docker Basics: Containers, Images, Lifecycle & CLI

**Location: `docs/docker-basics.md`**

## What is Docker?

Docker is a containerization platform that packages applications and their dependencies into lightweight, portable containers. Think of containers as isolated environments that contain everything needed to run an application.

## Core Concepts

### Containers vs Virtual Machines

- **Containers**: Share the host OS kernel, lightweight, fast startup
- **VMs**: Include full OS, heavier resource usage, slower startup

### Docker Architecture

```
┌─────────────────┐
│   Docker CLI    │
└─────────┬───────┘
          │
┌─────────▼───────┐
│  Docker Daemon  │
└─────────┬───────┘
          │
┌─────────▼───────┐
│   Containers    │
│     Images      │
│    Networks     │
│    Volumes      │
└─────────────────┘
```

## Container Lifecycle

### 1. Created → Running → Stopped → Removed

**Key States:**

- **Created**: Container exists but not started
- **Running**: Container is active and executing
- **Paused**: Container processes are suspended
- **Stopped**: Container has exited
- **Removed**: Container is deleted

### Lifecycle Commands

```bash
# Create and start container
docker run nginx

# Start existing container
docker start container_name

# Stop running container
docker stop container_name

# Pause/unpause container
docker pause container_name
docker unpause container_name

# Remove container
docker rm container_name
```

## Images Explained

### What are Images?

Read-only templates used to create containers. Images are built in layers using a Dockerfile.

### Image Layers

```
Application Layer     ← Your app code
Dependencies Layer    ← npm install, pip install
Base OS Layer        ← ubuntu:20.04, alpine:latest
```

### Image Commands

```bash
# List images
docker images

# Pull image from registry
docker pull ubuntu:20.04

# Build image from Dockerfile
docker build -t myapp:1.0 .

# Remove image
docker rmi image_name

# Inspect image details
docker inspect image_name

# View image history
docker history image_name
```

## Essential Docker CLI Commands

### Container Management

```bash
# Run container (create + start)
docker run [OPTIONS] IMAGE [COMMAND]

# Common run options
docker run -d nginx                    # Detached mode
docker run -it ubuntu bash            # Interactive terminal
docker run -p 8080:80 nginx          # Port mapping
docker run -v /data:/app/data nginx   # Volume mount
docker run --name web nginx          # Container name
docker run --rm nginx                # Auto-remove on exit

# List containers
docker ps           # Running only
docker ps -a        # All containers

# Execute command in running container
docker exec -it container_name bash

# View container logs
docker logs container_name
docker logs -f container_name  # Follow logs

# Copy files to/from container
docker cp file.txt container_name:/path/
docker cp container_name:/path/file.txt ./
```

### System Management

```bash
# Show Docker system info
docker info
docker version

# Monitor resource usage
docker stats

# Clean up unused resources
docker system prune
docker system prune -a  # Remove all unused resources

# Show disk usage
docker system df
```

### Registry Operations

```bash
# Login to registry
docker login

# Push image to registry
docker push username/image:tag

# Search Docker Hub
docker search nginx
```

## Dockerfile Basics

### Simple Dockerfile

```dockerfile
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y nginx
COPY index.html /var/www/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Key Instructions

- **FROM**: Base image
- **RUN**: Execute commands during build
- **COPY/ADD**: Copy files into image
- **WORKDIR**: Set working directory
- **EXPOSE**: Document exposed ports
- **ENV**: Set environment variables
- **CMD**: Default command to run
- **ENTRYPOINT**: Fixed entry point

## Best Practices

### Image Building

1. Use specific tags, avoid `latest`
2. Minimize layers by combining RUN commands
3. Use multi-stage builds for smaller images
4. Use `.dockerignore` to exclude unnecessary files
5. Run as non-root user when possible

### Container Management

1. Use meaningful container names
2. Always specify resource limits
3. Use health checks for production
4. Keep containers stateless
5. One process per container

### Security

1. Don't run as root
2. Scan images for vulnerabilities
3. Use official base images
4. Keep images updated
5. Don't store secrets in images

## Common Patterns

### Development Workflow

```bash
# 1. Write Dockerfile
# 2. Build image
docker build -t myapp:dev .

# 3. Run container
docker run -p 3000:3000 -v $(pwd):/app myapp:dev

# 4. Test and iterate
docker exec -it container_name bash
```

### Production Deployment

```bash
# Build production image
docker build -t myapp:1.0 .

# Run with resource limits
docker run -d \
  --name myapp-prod \
  --restart unless-stopped \
  --memory 512m \
  --cpus 0.5 \
  -p 80:3000 \
  myapp:1.0
```

## Troubleshooting Tips

### Common Issues

1. **Port already in use**: Change port mapping
2. **Image not found**: Check image name/tag
3. **Permission denied**: Check file permissions
4. **Container exits immediately**: Check CMD/ENTRYPOINT

### Debug Commands

```bash
# Check container processes
docker top container_name

# Inspect container details
docker inspect container_name

# View resource usage
docker stats container_name

# Access container filesystem
docker exec -it container_name sh
```

## Next Steps

- Learn about [Docker Compose](./docker-compose.md)
- Understand [Docker Networking](./networking.md)
- Explore [Volumes and Storage](./volumes-storage.md)
- Check [Security Best Practices](./security-best-practices.md)
