# Docker Commands Cheat Sheet

**Location: `docs/docker-cheatsheet.md`**

## Container Management

### Basic Container Operations

```bash
# Run a container
docker run [OPTIONS] IMAGE [COMMAND]
docker run -d nginx                    # Detached mode
docker run -it ubuntu bash             # Interactive terminal
docker run --rm alpine echo "hello"    # Remove after exit
docker run --name myapp nginx          # Named container

# Common run options
docker run -p 8080:80 nginx            # Port mapping
docker run -v /data:/app/data nginx    # Volume mount
docker run -e ENV_VAR=value nginx      # Environment variable
docker run --restart unless-stopped nginx  # Restart policy
docker run --memory 512m --cpus 0.5 nginx  # Resource limits

# Start/Stop containers
docker start CONTAINER                 # Start stopped container
docker stop CONTAINER                  # Graceful stop
docker restart CONTAINER               # Restart container
docker kill CONTAINER                  # Force kill
docker pause CONTAINER                 # Pause processes
docker unpause CONTAINER               # Resume processes

# List containers
docker ps                              # Running containers
docker ps -a                          # All containers
docker ps -q                          # Container IDs only
docker ps --filter "status=running"    # Filter by status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Container Information & Logs

```bash
# Container details
docker inspect CONTAINER              # Full container info
docker logs CONTAINER                 # View logs
docker logs -f CONTAINER              # Follow logs
docker logs --tail 100 CONTAINER      # Last 100 lines
docker logs --since 1h CONTAINER      # Logs from last hour

# Process information
docker top CONTAINER                  # Running processes
docker stats                          # Resource usage (live)
docker stats CONTAINER                # Specific container stats
docker port CONTAINER                 # Port mappings

# Execute commands in container
docker exec -it CONTAINER bash        # Interactive shell
docker exec CONTAINER ls /app         # Run command
docker exec -u root CONTAINER bash    # Execute as root
```

### Container Cleanup

```bash
# Remove containers
docker rm CONTAINER                   # Remove stopped container
docker rm -f CONTAINER                # Force remove (running)
docker rm $(docker ps -aq)            # Remove all containers

# Cleanup commands
docker container prune                 # Remove stopped containers
docker container prune -f             # Force cleanup
docker system prune                   # Remove unused objects
docker system prune -a                # Remove all unused objects
```

## Image Management

### Image Operations

```bash
# Pull/Push images
docker pull IMAGE[:TAG]               # Download image
docker push IMAGE[:TAG]               # Upload image
docker pull --all-tags nginx         # Pull all tags

# List and inspect images
docker images                         # List local images
docker images -q                      # Image IDs only
docker images --filter "dangling=true"  # Unused images
docker inspect IMAGE                  # Image details
docker history IMAGE                  # Image layers

# Tag images
docker tag SOURCE TARGET              # Create new tag
docker tag myapp:latest myapp:v1.0   # Version tagging
docker tag myapp user/myapp:latest   # Registry tagging
```

### Image Building

```bash
# Build images
docker build .                        # Build from current directory
docker build -t myapp:latest .       # Build with tag
docker build -f Dockerfile.prod .    # Use specific Dockerfile
docker build --no-cache .            # Build without cache
docker build --target production .   # Multi-stage build target

# BuildKit features
export DOCKER_BUILDKIT=1              # Enable BuildKit
docker build --platform linux/amd64,linux/arm64 .  # Multi-platform
docker build --secret id=mysecret,src=./secret.txt .  # Build secrets
```

### Image Cleanup

```bash
# Remove images
docker rmi IMAGE                      # Remove image
docker rmi -f IMAGE                   # Force remove
docker rmi $(docker images -q)       # Remove all images

# Cleanup unused images
docker image prune                    # Remove dangling images
docker image prune -a                # Remove unused images
docker image prune --filter "until=24h"  # Remove old images
```

## Volume Management

### Volume Operations

```bash
# Create and manage volumes
docker volume create VOLUME           # Create named volume
docker volume ls                      # List volumes
docker volume inspect VOLUME          # Volume details
docker volume rm VOLUME               # Remove volume
docker volume prune                   # Remove unused volumes

# Use volumes
docker run -v VOLUME:/path IMAGE      # Named volume
docker run -v /host/path:/path IMAGE  # Bind mount
docker run -v /path IMAGE             # Anonymous volume
docker run --mount type=volume,src=VOLUME,dst=/path IMAGE  # Mount syntax
```

### Volume Backup & Restore

```bash
# Backup volume
docker run --rm -v VOLUME:/data -v $(pwd):/backup busybox \
  tar czf /backup/backup.tar.gz -C /data .

# Restore volume
docker run --rm -v VOLUME:/data -v $(pwd):/backup busybox \
  tar xzf /backup/backup.tar.gz -C /data

# Copy files to/from containers
docker cp file.txt CONTAINER:/path/   # Copy to container
docker cp CONTAINER:/path/file.txt .  # Copy from container
```

## Network Management

### Network Operations

```bash
# Create and manage networks
docker network create NETWORK         # Create bridge network
docker network create --driver overlay NETWORK  # Overlay network
docker network ls                     # List networks
docker network inspect NETWORK        # Network details
docker network rm NETWORK             # Remove network
docker network prune                  # Remove unused networks

# Connect containers to networks
docker network connect NETWORK CONTAINER    # Connect container
docker network disconnect NETWORK CONTAINER # Disconnect container

# Run container on specific network
docker run --network NETWORK IMAGE    # Use custom network
docker run --network host IMAGE       # Use host network
docker run --network none IMAGE       # No networking
```

## Docker Compose

### Compose Commands

```bash
# Start services
docker-compose up                     # Start all services
docker-compose up -d                  # Start in background
docker-compose up --build            # Rebuild images
docker-compose up SERVICE             # Start specific service

# Stop services
docker-compose down                   # Stop and remove
docker-compose down -v               # Stop and remove volumes
docker-compose stop                   # Stop services only
docker-compose restart               # Restart services

# Service management
docker-compose ps                     # List services
docker-compose logs                   # View logs
docker-compose logs -f SERVICE       # Follow service logs
docker-compose exec SERVICE bash     # Execute in service
docker-compose run SERVICE COMMAND   # Run one-off command

# Scaling and building
docker-compose scale SERVICE=3       # Scale service
docker-compose build                 # Build services
docker-compose pull                  # Pull service images
```

### Compose File Management

```bash
# Multiple compose files
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
docker-compose --profile dev up      # Use specific profile
docker-compose config                # Validate and view config
docker-compose config --services     # List services
```

## Docker Swarm

### Swarm Management

```bash
# Initialize swarm
docker swarm init                     # Initialize swarm
docker swarm init --advertise-addr IP  # With specific IP
docker swarm join-token worker        # Get worker token
docker swarm join-token manager       # Get manager token

# Node management
docker node ls                        # List nodes
docker node inspect NODE             # Node details
docker node rm NODE                  # Remove node
docker node update --availability drain NODE  # Drain node
```

### Service Management

```bash
# Create and manage services
docker service create --name web nginx        # Create service
docker service create --replicas 3 nginx     # With replicas
docker service ls                             # List services
docker service inspect SERVICE                # Service details
docker service ps SERVICE                     # Service tasks

# Update services
docker service update --image nginx:alpine SERVICE  # Update image
docker service scale SERVICE=5               # Scale service
docker service rollback SERVICE              # Rollback update

# Remove services
docker service rm SERVICE                    # Remove service
```

### Stack Deployment

```bash
# Deploy stacks
docker stack deploy -c docker-compose.yml STACK  # Deploy stack
docker stack ls                              # List stacks
docker stack services STACK                  # Stack services
docker stack ps STACK                        # Stack tasks
docker stack rm STACK                        # Remove stack
```

## System Information

### System Commands

```bash
# System information
docker version                        # Docker version
docker info                          # System information
docker system df                     # Disk usage
docker system events                 # System events
docker system events --since 1h     # Recent events

# Resource usage
docker stats                         # Live resource usage
docker stats --no-stream            # One-time stats
docker system df -v                 # Detailed disk usage
```

### Registry Operations

```bash
# Login/logout
docker login                         # Login to Docker Hub
docker login registry.example.com   # Login to private registry
docker logout                       # Logout

# Search and pull
docker search nginx                  # Search Docker Hub
docker search --limit 5 nginx      # Limit results
```

## Debugging & Troubleshooting

### Debug Commands

```bash
# Container debugging
docker logs --details CONTAINER      # Detailed logs
docker exec -it CONTAINER sh        # Access container shell
docker run --rm -it IMAGE sh        # Debug image

# Process inspection
docker top CONTAINER                 # Container processes
docker diff CONTAINER               # Filesystem changes
docker export CONTAINER > container.tar  # Export container

# Network debugging
docker network ls                    # List networks
docker network inspect bridge       # Network details
docker port CONTAINER               # Port mappings
docker exec CONTAINER netstat -tulpn  # Network connections
```

### Performance Analysis

```bash
# Resource monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
docker system df                     # Storage usage
docker image ls --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# System cleanup
docker system prune --volumes       # Clean everything
docker builder prune               # Clean build cache
docker buildx prune                # Clean buildx cache
```

## Advanced Operations

### Multi-Platform & BuildKit

```bash
# BuildKit features
docker buildx create --use           # Create buildx instance
docker buildx build --platform linux/amd64,linux/arm64 -t myapp --push .
docker buildx imagetools inspect myapp:latest  # Multi-arch info

# Experimental features
export DOCKER_CLI_EXPERIMENTAL=enabled
docker manifest create myapp:latest myapp:amd64 myapp:arm64
docker manifest push myapp:latest
```

### Security & Scanning

```bash
# Security scanning
docker scan IMAGE                    # Vulnerability scan
docker trust sign IMAGE              # Sign image
docker trust inspect IMAGE           # Verify signatures

# Content trust
export DOCKER_CONTENT_TRUST=1        # Enable content trust
docker push myapp:latest             # Signed push
```

## Environment Variables & Configuration

### Useful Environment Variables

```bash
# Docker configuration
export DOCKER_HOST=tcp://docker.example.com:2376  # Remote Docker
export DOCKER_TLS_VERIFY=1                        # Use TLS
export DOCKER_CERT_PATH=/path/to/certs            # TLS certificates
export DOCKER_BUILDKIT=1                          # Enable BuildKit
export DOCKER_CLI_EXPERIMENTAL=enabled             # Experimental features
export DOCKER_CONTENT_TRUST=1                     # Content trust

# Compose configuration
export COMPOSE_PROJECT_NAME=myproject              # Project name
export COMPOSE_FILE=docker-compose.prod.yml       # Compose file
export COMPOSE_HTTP_TIMEOUT=120                   # HTTP timeout
```

## Quick Reference Patterns

### Dockerfile Patterns

```bash
# Multi-stage build pattern
FROM node:alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

### Docker Compose Patterns

```yaml
# Basic web app pattern
version: "3.8"
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

### Common Run Patterns

```bash
# Development container with volume
docker run -it --rm -v $(pwd):/app -w /app node:alpine sh

# Temporary container for testing
docker run --rm -p 8080:80 nginx:alpine

# Container with environment file
docker run --env-file .env myapp:latest

# Container with custom network
docker run --network mynetwork --name webapp nginx
```

## Useful Aliases

### Bash Aliases

```bash
# Add to ~/.bashrc or ~/.bash_profile
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dsp='docker system prune -f'
alias dip='docker image prune -f'
alias dvp='docker volume prune -f'
alias dnp='docker network prune -f'
alias dlog='docker logs -f'
alias dex='docker exec -it'
alias drm='docker rm -f'
alias dri='docker rmi'
alias dbu='docker build'
alias dpu='docker push'
alias dpl='docker pull'
```

### PowerShell Aliases (Windows)

```powershell
# Add to PowerShell profile
Set-Alias d docker
Set-Alias dc docker-compose
function dps { docker ps }
function dpsa { docker ps -a }
function di { docker images }
function dsp { docker system prune -f }
```

## Performance Tips

### Optimization Commands

```bash
# Optimize Docker daemon
echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}' | sudo tee /etc/docker/daemon.json

# Clean up regularly
docker system prune --volumes --filter "until=168h"  # Clean week-old resources
docker image prune --filter "until=48h"              # Clean old images

# Monitor resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
```

This cheat sheet provides quick access to the most commonly used Docker commands and patterns for daily development and operations work.
