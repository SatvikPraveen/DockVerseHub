# Docker Troubleshooting: Debugging Containers, Networks & Builds

**Location: `docs/troubleshooting.md`**

## General Troubleshooting Approach

### 1. Identify the Problem Layer

```
Application Layer    ← App code, configs, environment
Container Layer      ← Container runtime, resources
Image Layer          ← Dockerfile, build process
Docker Layer         ← Docker daemon, client
Host Layer           ← OS, hardware, networking
```

### 2. Gather Information

```bash
# System overview
docker version
docker info
docker system df
docker system events --since 1h

# Container details
docker ps -a
docker inspect CONTAINER
docker logs CONTAINER
docker stats CONTAINER
```

## Container Issues

### Container Won't Start

#### Diagnosis Commands

```bash
# Check container status
docker ps -a

# View detailed error
docker logs CONTAINER_NAME

# Inspect container configuration
docker inspect CONTAINER_NAME

# Check Docker daemon logs
journalctl -u docker.service --since "1 hour ago"
```

#### Common Causes & Solutions

**Exit Code 125: Docker daemon error**

```bash
# Usually Docker daemon issue or invalid parameter
docker info  # Check daemon status
sudo systemctl status docker
sudo systemctl restart docker
```

**Exit Code 126: Container command not executable**

```dockerfile
# ❌ Wrong
COPY script.sh /app/
CMD ["/app/script.sh"]

# ✅ Correct
COPY script.sh /app/
RUN chmod +x /app/script.sh
CMD ["/app/script.sh"]
```

**Exit Code 127: Container command not found**

```dockerfile
# ❌ Wrong path
CMD ["/usr/bin/node", "app.js"]

# ✅ Check actual path
RUN which node  # Verify location
CMD ["node", "app.js"]  # Use PATH
```

### Container Exits Immediately

#### Debug Approach

```bash
# Run interactively to see what happens
docker run -it IMAGE_NAME /bin/bash

# Check what process runs
docker run IMAGE_NAME ps aux

# Override entrypoint
docker run --entrypoint /bin/sh -it IMAGE_NAME
```

#### Common Solutions

```dockerfile
# Keep container running for debugging
CMD ["tail", "-f", "/dev/null"]

# Or use sleep
CMD ["sleep", "infinity"]

# Proper daemon process
CMD ["nginx", "-g", "daemon off;"]
```

### Resource Issues

#### Memory Problems

```bash
# Check memory limits
docker inspect CONTAINER | grep -i memory

# Monitor memory usage
docker stats CONTAINER

# Check for OOM kills
dmesg | grep -i "killed process"
journalctl -u docker --since "1 hour ago" | grep -i oom
```

#### CPU Issues

```bash
# Check CPU usage
docker stats CONTAINER

# CPU limits
docker inspect CONTAINER | grep -i cpu

# Host CPU load
top
htop
```

## Network Troubleshooting

### Container Connectivity Issues

#### Network Diagnosis

```bash
# List networks
docker network ls

# Inspect network
docker network inspect NETWORK_NAME

# Container network settings
docker inspect CONTAINER | grep -A 20 NetworkSettings

# Test connectivity from container
docker exec CONTAINER ping TARGET
docker exec CONTAINER telnet HOST PORT
docker exec CONTAINER nslookup HOSTNAME
```

#### Common Network Problems

**Container can't connect to other container**

```bash
# Check if containers are on same network
docker inspect CONTAINER1 | grep NetworkMode
docker inspect CONTAINER2 | grep NetworkMode

# Connect to same network
docker network create mynetwork
docker network connect mynetwork CONTAINER1
docker network connect mynetwork CONTAINER2
```

**DNS resolution issues**

```bash
# Test DNS inside container
docker exec CONTAINER nslookup google.com
docker exec CONTAINER cat /etc/resolv.conf

# Custom DNS
docker run --dns 8.8.8.8 IMAGE
```

**Port mapping problems**

```bash
# Check port bindings
docker port CONTAINER

# Test port accessibility
telnet localhost 8080
nmap -p 8080 localhost

# Check if port is in use
netstat -tulpn | grep 8080
ss -tulpn | grep 8080
```

### Docker Compose Network Issues

#### Troubleshooting Steps

```bash
# Check compose network
docker-compose ps
docker network ls | grep PROJECT_NAME

# Test service connectivity
docker-compose exec service1 ping service2

# View compose configuration
docker-compose config
```

## Build Issues

### Build Failures

#### Common Build Problems

```bash
# Build with detailed output
docker build --no-cache --progress=plain .

# Build specific stage
docker build --target=builder .

# Check build context size
du -sh .
ls -la .dockerignore
```

**Dockerfile syntax errors**

```dockerfile
# ❌ Wrong
FROM nginx
COPY . /app
RUN npm install  # npm not available in nginx image

# ✅ Correct
FROM node:16 AS builder
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

**Context issues**

```bash
# Large build context
echo "node_modules" >> .dockerignore
echo "*.log" >> .dockerignore
echo ".git" >> .dockerignore

# Wrong context path
docker build -f docker/Dockerfile .  # Context is current dir
```

**Layer caching issues**

```dockerfile
# ❌ Poor caching
COPY . /app
RUN npm install

# ✅ Better caching
COPY package*.json /app/
RUN npm install
COPY . /app
```

### Image Issues

#### Image Size Problems

```bash
# Check image size
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Analyze layers
docker history IMAGE_NAME

# Use dive tool
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive IMAGE_NAME
```

**Reduce image size**

```dockerfile
# Multi-stage build
FROM node:16 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
CMD ["node", "index.js"]
```

## Storage and Volume Issues

### Volume Mount Problems

#### Diagnosis

```bash
# Check volume mounts
docker inspect CONTAINER | grep -A 10 Mounts

# List volumes
docker volume ls

# Inspect volume
docker volume inspect VOLUME_NAME

# Check volume usage
docker system df -v
```

#### Common Solutions

```bash
# Permission issues
docker exec CONTAINER ls -la /mounted/path
docker run --user $(id -u):$(id -g) IMAGE

# Volume not persisting
docker run -v named-volume:/data IMAGE  # Named volume
docker run -v $(pwd)/data:/data IMAGE   # Bind mount

# Windows path issues (PowerShell)
docker run -v ${PWD}:/app IMAGE
```

### Bind Mount Issues

```bash
# SELinux context (RHEL/CentOS)
docker run -v /host/path:/container/path:Z IMAGE

# Permission mapping
docker run --user $(id -u):$(id -g) -v $(pwd):/app IMAGE

# Windows path format
docker run -v //c/Users/username/project:/app IMAGE
```

## Performance Issues

### Slow Container Performance

#### Investigation

```bash
# Resource monitoring
docker stats CONTAINER
htop
iotop

# Container processes
docker exec CONTAINER ps aux
docker top CONTAINER

# Disk I/O
docker exec CONTAINER iostat -x 1
```

#### Optimization

```bash
# Limit resources
docker run --memory 512m --cpus 1.0 IMAGE

# Use tmpfs for temp files
docker run --tmpfs /tmp:size=100m IMAGE

# Optimize storage driver
# Check in daemon.json
{
  "storage-driver": "overlay2"
}
```

### Build Performance

```dockerfile
# Optimize Dockerfile order
FROM node:16-alpine
WORKDIR /app

# Dependencies first (better caching)
COPY package*.json ./
RUN npm ci --only=production

# Source code last
COPY . .
RUN npm run build

# Use buildkit
# syntax=docker/dockerfile:1
FROM node:16-alpine
```

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1
docker build .

# Parallel builds
docker build --target stage1 . &
docker build --target stage2 . &
wait
```

## Docker Daemon Issues

### Daemon Won't Start

```bash
# Check daemon status
systemctl status docker
journalctl -u docker.service

# Start daemon manually with debug
sudo dockerd --debug

# Check daemon configuration
cat /etc/docker/daemon.json
```

### Disk Space Issues

```bash
# Check Docker disk usage
docker system df

# Clean up
docker system prune -a
docker volume prune
docker image prune -a

# Remove unused containers
docker container prune

# Automated cleanup script
#!/bin/bash
docker system prune -f
docker volume prune -f
docker image prune -a -f
```

### Registry Issues

```bash
# Login issues
docker login registry.example.com

# Push/pull failures
docker pull --disable-content-trust IMAGE
docker push --disable-content-trust IMAGE

# Insecure registry
# Add to daemon.json
{
  "insecure-registries": ["registry.example.com:5000"]
}
```

## Compose Troubleshooting

### Service Dependencies

```yaml
version: "3.8"
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Environment Variables

```bash
# Check compose environment
docker-compose config

# Debug environment issues
docker-compose run --rm app env

# Load environment files
docker-compose --env-file .env.prod up
```

### Override Files

```yaml
# docker-compose.override.yml
version: "3.8"
services:
  app:
    volumes:
      - ./src:/app/src # Development override
    environment:
      - DEBUG=true
```

## Security Troubleshooting

### Permission Issues

```bash
# Check user mapping
docker exec CONTAINER id

# Run as current user
docker run --user $(id -u):$(id -g) IMAGE

# Fix ownership
docker run --rm -v $(pwd):/data busybox chown -R $(id -u):$(id -g) /data
```

### Security Context Issues

```bash
# AppArmor (Ubuntu)
sudo aa-status
docker run --security-opt apparmor:unconfined IMAGE

# SELinux (RHEL/CentOS)
getenforce
docker run --security-opt label:disable IMAGE

# Capabilities
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE IMAGE
```

## Diagnostic Tools and Scripts

### Container Health Check Script

```bash
#!/bin/bash
# health-check.sh
CONTAINER=$1

echo "=== Container Health Check ==="
echo "Container: $CONTAINER"
echo "Status: $(docker inspect --format='{{.State.Status}}' $CONTAINER)"
echo "Health: $(docker inspect --format='{{.State.Health.Status}}' $CONTAINER 2>/dev/null || echo 'No healthcheck')"
echo "Exit Code: $(docker inspect --format='{{.State.ExitCode}}' $CONTAINER)"
echo "Started: $(docker inspect --format='{{.State.StartedAt}}' $CONTAINER)"

echo -e "\n=== Resource Usage ==="
docker stats --no-stream $CONTAINER

echo -e "\n=== Recent Logs ==="
docker logs --tail 20 $CONTAINER

echo -e "\n=== Port Mappings ==="
docker port $CONTAINER

echo -e "\n=== Network Info ==="
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' $CONTAINER
```

### Network Diagnostic Script

```bash
#!/bin/bash
# network-debug.sh
CONTAINER=$1
TARGET=$2

echo "=== Network Connectivity Test ==="
echo "From: $CONTAINER"
echo "To: $TARGET"

echo -e "\n=== DNS Resolution ==="
docker exec $CONTAINER nslookup $TARGET

echo -e "\n=== Ping Test ==="
docker exec $CONTAINER ping -c 3 $TARGET

echo -e "\n=== Port Connectivity ==="
docker exec $CONTAINER telnet $TARGET 80 <<< ""

echo -e "\n=== Network Configuration ==="
docker exec $CONTAINER cat /etc/resolv.conf
docker exec $CONTAINER ip route
```

### Log Analysis Script

```python
#!/usr/bin/env python3
# log-analyzer.py
import subprocess
import json
import sys
from datetime import datetime

def analyze_container_logs(container_name, lines=100):
    """Analyze Docker container logs for common issues"""

    try:
        # Get logs
        result = subprocess.run(['docker', 'logs', '--tail', str(lines), container_name],
                              capture_output=True, text=True)
        logs = result.stdout

        # Common error patterns
        error_patterns = {
            'out_of_memory': ['out of memory', 'oom', 'memory limit'],
            'connection_refused': ['connection refused', 'connection reset'],
            'permission_denied': ['permission denied', 'access denied'],
            'port_in_use': ['port already in use', 'address already in use'],
            'file_not_found': ['no such file', 'file not found'],
        }

        issues = {}
        for issue_type, patterns in error_patterns.items():
            count = 0
            for pattern in patterns:
                count += logs.lower().count(pattern.lower())
            if count > 0:
                issues[issue_type] = count

        # Report
        print(f"=== Log Analysis for {container_name} ===")
        if issues:
            print("Issues found:")
            for issue, count in issues.items():
                print(f"  {issue.replace('_', ' ').title()}: {count} occurrences")
        else:
            print("No common issues detected")

        # Show recent errors
        error_lines = [line for line in logs.split('\n')
                      if any(keyword in line.lower() for keyword in ['error', 'fail', 'exception'])]
        if error_lines:
            print(f"\nRecent error messages:")
            for line in error_lines[-5:]:
                print(f"  {line}")

    except Exception as e:
        print(f"Error analyzing logs: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python log-analyzer.py CONTAINER_NAME")
        sys.exit(1)

    analyze_container_logs(sys.argv[1])
```

## Common Error Patterns

### Exit Codes

```
0    - Success
1    - General errors
125  - Docker daemon error
126  - Container command not executable
127  - Container command not found
128+ - Fatal error signal (128 + signal number)
137  - SIGKILL (OOM kill)
143  - SIGTERM (graceful termination)
```

### Build Error Patterns

```bash
# Package manager errors
E: Unable to locate package  # Wrong package name/repo
Package not found            # Missing dependencies

# Copy/ADD errors
COPY failed: no such file    # File doesn't exist in context
ADD failed: bad checksum     # Download corruption

# Permission errors
Permission denied            # File permissions in context
Operation not permitted      # Container user permissions
```

### Runtime Error Patterns

```bash
# Network errors
Connection refused           # Service not running/wrong port
No route to host            # Network connectivity issue
Name resolution failed      # DNS issue

# Resource errors
Cannot allocate memory      # Memory limit exceeded
No space left on device     # Disk full
```

## Emergency Procedures

### Container Recovery

```bash
# Emergency container access
docker exec -it CONTAINER /bin/bash
docker exec -it CONTAINER /bin/sh

# Copy files from failed container
docker cp CONTAINER:/app/logs ./logs

# Create image from container
docker commit CONTAINER recovery-image

# Start container with different command
docker run -it IMAGE /bin/bash
```

### Data Recovery

```bash
# Recover from stopped container
docker start CONTAINER
docker cp CONTAINER:/data ./backup

# Mount volume to new container
docker run --rm -v VOLUME:/data busybox tar czf - -C /data . > backup.tar.gz

# Emergency volume backup
docker run --rm -v VOLUME:/source -v $(pwd):/backup busybox cp -r /source /backup
```

### System Recovery

```bash
# Clean everything (DANGEROUS)
docker system prune -a --volumes

# Reset Docker (Ubuntu/Debian)
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker

# Emergency daemon restart
sudo pkill dockerd
sudo dockerd --debug
```

## Monitoring and Alerting

### Automated Health Monitoring

```bash
#!/bin/bash
# monitor.sh
for container in $(docker ps --format "{{.Names}}"); do
    health=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null)
    status=$(docker inspect --format='{{.State.Status}}' $container)

    if [[ "$status" != "running" ]]; then
        echo "ALERT: $container is not running (status: $status)"
    elif [[ "$health" == "unhealthy" ]]; then
        echo "ALERT: $container is unhealthy"
    fi
done
```

### Log Monitoring

```bash
# Monitor for errors in real-time
docker logs -f CONTAINER | grep -i error

# Alert on specific patterns
docker logs -f CONTAINER | while read line; do
    if echo "$line" | grep -i "fatal\|critical\|emergency"; then
        echo "CRITICAL ERROR: $line" | mail -s "Container Alert" admin@example.com
    fi
done
```

## Documentation and Reporting

### Issue Report Template

```
=== Docker Issue Report ===
Date: $(date)
Docker Version: $(docker version --format '{{.Server.Version}}')
OS: $(uname -a)

Problem Description:
- What were you trying to do?
- What happened instead?
- When did this start?

Reproduction Steps:
1.
2.
3.

Error Messages:
[Paste logs here]

Environment:
- Container/Image:
- Docker Compose version:
- Network configuration:
- Volume mounts:

Attempted Solutions:
- What have you tried?
- What worked/didn't work?
```

### Troubleshooting Checklist

```
□ Check container status (docker ps -a)
□ Review container logs (docker logs)
□ Verify image exists and is correct
□ Check resource usage (docker stats)
□ Verify network connectivity
□ Check volume mounts and permissions
□ Review Docker daemon logs
□ Test with minimal configuration
□ Check for system resource issues
□ Verify Docker daemon configuration
```

## Next Steps

- Learn [Performance Optimization](./performance-optimization.md) to prevent issues
- Check [Security Best Practices](./security-best-practices.md) for security troubleshooting
- Explore [Monitoring and Logging](./monitoring-logging.md) for proactive monitoring
- Understand [Production Deployment](./production-deployment.md) best practices
