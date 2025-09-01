# Exercise: Basic Docker Commands

**File Location:** `concepts/01_getting_started/exercises/basic-commands.md`

## Objective

Master essential Docker CLI commands through hands-on practice.

## Command Categories

### 1. Information Commands

```bash
# System information
docker --version          # Docker version
docker version            # Detailed version info
docker info              # System-wide information
docker system df         # Disk usage
docker system events     # Real-time events
```

**Practice:**

```bash
# Get detailed version information
docker version --format 'Client: {{.Client.Version}}, Server: {{.Server.Version}}'

# Check system resource usage
docker system df

# Monitor events in real-time (open second terminal)
docker system events &
docker run --rm hello-world
```

### 2. Image Commands

```bash
# Image management
docker images            # List images
docker pull <image>      # Download image
docker build -t <name> . # Build image
docker rmi <image>       # Remove image
docker image prune       # Remove unused images
```

**Practice:**

```bash
# Pull different image versions
docker pull ubuntu:20.04
docker pull ubuntu:22.04
docker pull ubuntu:latest

# List images with size information
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Remove specific image
docker rmi ubuntu:20.04

# Clean up unused images
docker image prune -f
```

### 3. Container Lifecycle Commands

```bash
# Container management
docker run <image>       # Create and start container
docker create <image>    # Create container (don't start)
docker start <container> # Start stopped container
docker stop <container>  # Stop running container
docker restart <container> # Restart container
docker rm <container>    # Remove container
```

**Practice:**

```bash
# Create without starting
docker create --name test-container alpine:latest

# List all containers
docker ps -a

# Start the created container
docker start test-container

# Check running containers
docker ps

# Stop and remove
docker stop test-container
docker rm test-container
```

### 4. Container Inspection Commands

```bash
# Container information
docker ps               # List running containers
docker ps -a           # List all containers
docker logs <container> # View container logs
docker inspect <container> # Detailed container info
docker stats          # Resource usage statistics
docker top <container> # Process list in container
```

**Practice:**

```bash
# Run nginx with custom name
docker run -d --name web-server nginx:latest

# View logs
docker logs web-server

# Get detailed JSON information
docker inspect web-server | grep IPAddress

# Monitor resource usage
docker stats web-server --no-stream

# View running processes
docker top web-server

# Clean up
docker stop web-server && docker rm web-server
```

### 5. Container Interaction Commands

```bash
# Interacting with containers
docker exec -it <container> <command> # Execute command in running container
docker attach <container>             # Attach to running container
docker cp <src> <dest>               # Copy files between host and container
```

**Practice:**

```bash
# Run Ubuntu container in background
docker run -d -it --name interactive-test ubuntu:latest

# Execute commands in the running container
docker exec -it interactive-test /bin/bash
# Inside container: touch /tmp/test-file && echo "Hello" > /tmp/test-file && exit

# Copy file from container to host
docker cp interactive-test:/tmp/test-file ./test-file
cat ./test-file

# Copy file from host to container
echo "Hello from host" > host-file.txt
docker cp host-file.txt interactive-test:/tmp/

# Verify the copy
docker exec interactive-test cat /tmp/host-file.txt

# Clean up
docker stop interactive-test && docker rm interactive-test
rm test-file host-file.txt
```

### 6. Network Commands

```bash
# Network management
docker network ls               # List networks
docker network create <name>   # Create network
docker network inspect <name>  # Inspect network
docker network rm <name>       # Remove network
```

**Practice:**

```bash
# List default networks
docker network ls

# Create custom network
docker network create my-network

# Run containers on custom network
docker run -d --name web1 --network my-network nginx:latest
docker run -d --name web2 --network my-network nginx:latest

# Inspect the network
docker network inspect my-network

# Test connectivity between containers
docker exec web1 ping -c 2 web2

# Clean up
docker stop web1 web2
docker rm web1 web2
docker network rm my-network
```

### 7. Volume Commands

```bash
# Volume management
docker volume ls               # List volumes
docker volume create <name>    # Create volume
docker volume inspect <name>   # Inspect volume
docker volume rm <name>        # Remove volume
docker volume prune           # Remove unused volumes
```

**Practice:**

```bash
# Create named volume
docker volume create data-volume

# Use volume in container
docker run -d -v data-volume:/data --name data-container alpine:latest sh -c "echo 'Persistent data' > /data/message.txt && sleep 3600"

# Access data from another container
docker run --rm -v data-volume:/data alpine:latest cat /data/message.txt

# Inspect volume
docker volume inspect data-volume

# Clean up
docker stop data-container && docker rm data-container
docker volume rm data-volume
```

### 8. Cleanup Commands

```bash
# System cleanup
docker container prune    # Remove stopped containers
docker image prune        # Remove unused images
docker volume prune       # Remove unused volumes
docker network prune      # Remove unused networks
docker system prune       # Remove all unused resources
docker system prune -a    # Remove all unused resources + unused images
```

**Practice:**

```bash
# Create some test resources
docker run -d --name temp1 alpine:latest sleep 3600
docker run -d --name temp2 alpine:latest sleep 3600
docker volume create temp-volume
docker network create temp-network

# Stop containers
docker stop temp1 temp2

# Clean up incrementally
docker container prune -f
docker volume prune -f
docker network prune -f

# Or clean everything at once
# docker system prune -a -f
```

## Command Chaining and Efficiency

### Multiple Container Operations

```bash
# Start multiple containers
docker run -d --name web1 nginx:latest && \
docker run -d --name web2 nginx:latest && \
docker run -d --name web3 nginx:latest

# Stop all containers with same pattern
docker stop $(docker ps -q --filter "name=web")

# Remove all containers with same pattern
docker rm $(docker ps -aq --filter "name=web")
```

### Filtering and Formatting

```bash
# List containers with custom format
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Filter containers by status
docker ps -a --filter "status=exited"

# Filter images by reference
docker images --filter "reference=ubuntu:*"
```

### Advanced Inspections

```bash
# Get specific information using Go templates
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Get container environment variables
docker inspect --format='{{.Config.Env}}' <container>

# Get image creation date
docker inspect --format='{{.Created}}' <image>
```

## Common Command Combinations

### Quick Container Testing

```bash
# One-liner for quick testing
docker run --rm -it alpine:latest sh

# Run command and auto-remove
docker run --rm alpine:latest echo "Hello World"

# Background with auto-restart
docker run -d --restart=always --name persistent-app nginx:latest
```

### Development Workflows

```bash
# Mount current directory and run development container
docker run -it --rm -v $(pwd):/workspace -w /workspace node:latest npm init

# Quick Python environment
docker run -it --rm -v $(pwd):/app -w /app python:3.9 python

# Temporary database for testing
docker run -d --rm -e MYSQL_ROOT_PASSWORD=password mysql:latest
```

## Challenge Exercises

### Challenge 1: Container Orchestration

```bash
# Create a multi-container setup manually
docker network create app-network
docker volume create app-data

docker run -d \
  --name database \
  --network app-network \
  -v app-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=secret \
  mysql:5.7

docker run -d \
  --name webapp \
  --network app-network \
  -p 8080:80 \
  nginx:latest

# Test connectivity and clean up
docker exec webapp ping database
# Clean up when done
```

### Challenge 2: Resource Management

```bash
# Run containers with resource limits
docker run -d \
  --name resource-test \
  --memory=512m \
  --cpus=0.5 \
  alpine:latest sleep 3600

# Monitor resource usage
docker stats resource-test --no-stream

# Compare with unlimited container
docker run -d --name unlimited alpine:latest sleep 3600
docker stats --no-stream
```

## Troubleshooting Common Issues

### Container Won't Start

```bash
# Check container status and logs
docker ps -a
docker logs <container_name>

# Run with different entrypoint for debugging
docker run -it --entrypoint /bin/sh <image>
```

### Port Conflicts

```bash
# Find what's using a port
netstat -tulpn | grep :8080
# Or use different port mapping
docker run -p 8081:80 nginx:latest
```

### Disk Space Issues

```bash
# Check Docker disk usage
docker system df

# Clean up aggressively
docker system prune -a --volumes

# Remove everything and start fresh
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
```

## Command Reference Quick Sheet

```bash
# Essential daily commands
docker run -it --rm <image> <command>  # Interactive temporary container
docker run -d --name <name> <image>    # Background named container
docker exec -it <container> /bin/bash  # Access running container
docker logs -f <container>             # Follow logs
docker stop <container> && docker rm <container>  # Stop and remove
docker system prune -f                 # Quick cleanup
```

## Next Steps

After mastering these commands:

1. Move to `02_images_layers` to learn about Docker images
2. Practice building your own images
3. Explore Docker Compose for multi-container applications

## Summary

You've learned:

- Essential Docker CLI commands
- Container lifecycle management
- System maintenance and cleanup
- Advanced filtering and formatting
- Troubleshooting techniques
- Efficient command combinations
