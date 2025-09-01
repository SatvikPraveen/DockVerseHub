# Docker Networking Quick Reference

**Location: `docs/quick-reference/networking-quick-ref.md`**

## Network Drivers Overview

| Driver      | Use Case             | Scope        | External Access       | Container Communication                  |
| ----------- | -------------------- | ------------ | --------------------- | ---------------------------------------- |
| **bridge**  | Single-host          | Local        | Via port mapping      | By IP or container name (custom bridges) |
| **host**    | Performance critical | Local        | Direct host network   | Via localhost                            |
| **overlay** | Multi-host swarm     | Swarm        | Via ingress           | By service name                          |
| **macvlan** | Legacy integration   | Local/Remote | Direct network access | By IP address                            |
| **none**    | Isolation            | Container    | No network            | No communication                         |

## Essential Commands

### Network Management

```bash
# List networks
docker network ls

# Create networks
docker network create mynetwork                    # Bridge (default)
docker network create -d overlay myoverlay         # Overlay
docker network create -d macvlan mymacvlan        # Macvlan

# Network details
docker network inspect bridge
docker network inspect mynetwork

# Connect/disconnect containers
docker network connect mynetwork container1
docker network disconnect mynetwork container1

# Remove networks
docker network rm mynetwork
docker network prune                               # Remove unused
```

### Container Network Configuration

```bash
# Run with specific network
docker run --network mynetwork nginx
docker run --network host nginx                    # Host networking
docker run --network none alpine                   # No networking

# Port mapping
docker run -p 8080:80 nginx                       # Host:Container
docker run -p 127.0.0.1:8080:80 nginx            # Bind to specific IP
docker run -P nginx                                # Map all exposed ports

# Network aliases
docker run --network mynetwork --network-alias web nginx
docker run --network mynetwork --network-alias api myapi
```

## Network Types Deep Dive

### Bridge Networks

```bash
# Default bridge (legacy)
docker run nginx                                   # Connects to default bridge
docker run --link container1:c1 container2        # Legacy linking (deprecated)

# Custom bridge (recommended)
docker network create --driver bridge mybridge
docker run --network mybridge --name web nginx
docker run --network mybridge --name app myapp
# Containers can communicate by name: curl http://web/
```

### Host Networks

```bash
# Direct host network access
docker run --network host nginx                   # nginx accessible on host:80
docker run --network host --name app myapp       # No port mapping needed
```

### Overlay Networks (Swarm)

```bash
# Create overlay network
docker network create -d overlay --attachable myoverlay

# Deploy service with overlay
docker service create --network myoverlay --name web nginx

# Attach standalone container to overlay
docker run -d --network myoverlay --name standalone alpine sleep 3600
```

### Macvlan Networks

```bash
# Create macvlan network
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  mymacvlan

# Run container with macvlan
docker run -d --network mymacvlan --ip=192.168.1.100 nginx
```

## Common Networking Scenarios

### Multi-Container Application

```bash
# Create custom network
docker network create app-network

# Database container
docker run -d --name database \
  --network app-network \
  -e POSTGRES_DB=myapp \
  -e POSTGRES_PASSWORD=secret \
  postgres:13

# Application container
docker run -d --name app \
  --network app-network \
  -p 3000:3000 \
  -e DATABASE_URL=postgresql://postgres:secret@database:5432/myapp \
  myapp:latest

# Web server container
docker run -d --name nginx \
  --network app-network \
  -p 80:80 \
  nginx:alpine
```

### Load Balancer Setup

```bash
# Create network
docker network create lb-network

# Backend services
docker run -d --name app1 --network lb-network myapp
docker run -d --name app2 --network lb-network myapp
docker run -d --name app3 --network lb-network myapp

# Load balancer
docker run -d --name lb \
  --network lb-network \
  -p 80:80 \
  -v ./nginx.conf:/etc/nginx/nginx.conf \
  nginx:alpine
```

### Service Discovery

```bash
# Create network with DNS
docker network create --driver bridge servicenet

# Service with alias
docker run -d --name database \
  --network servicenet \
  --network-alias db \
  --network-alias postgres \
  postgres:13

# Application can connect to database via any alias
docker run -d --name app \
  --network servicenet \
  -e DB_HOST=db \
  myapp
```

## Port Management

### Port Mapping Patterns

```bash
# Basic port mapping
docker run -p 8080:80 nginx                       # External:Internal

# Multiple ports
docker run -p 80:80 -p 443:443 nginx             # HTTP & HTTPS

# Specific interface
docker run -p 127.0.0.1:8080:80 nginx            # Localhost only

# Random host port
docker run -p 80 nginx                            # Docker assigns random port

# UDP ports
docker run -p 53:53/udp dns-server                # UDP mapping

# Port ranges
docker run -p 3000-3005:3000-3005 myapp          # Range mapping
```

### Port Discovery

```bash
# Show port mappings
docker port container_name
docker port container_name 80                     # Specific port

# List all container ports
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Check port availability
netstat -tulpn | grep :8080
ss -tulpn | grep :8080
```

## DNS and Service Discovery

### Container Name Resolution

```bash
# Custom bridge networks provide automatic DNS
docker network create mynet
docker run -d --name web --network mynet nginx
docker run --network mynet alpine ping web        # Works!

# Default bridge requires links (deprecated)
docker run --name web nginx
docker run --link web:webserver alpine ping webserver
```

### External DNS Configuration

```bash
# Custom DNS servers
docker run --dns 8.8.8.8 --dns 1.1.1.1 alpine

# DNS search domains
docker run --dns-search company.local alpine

# DNS options
docker run --dns-option ndots:1 alpine

# Disable DNS
docker run --dns 127.0.0.1 --dns-option ndots:0 alpine
```

## Network Security

### Network Isolation

```bash
# Internal network (no external access)
docker network create --internal internal-net
docker run -d --network internal-net database
docker run -d --network internal-net app

# Multiple networks for segmentation
docker network create frontend
docker network create backend

# Web server on both networks
docker run -d --name web \
  --network frontend \
  -p 80:80 \
  nginx

docker network connect backend web

# App only on backend
docker run -d --name app --network backend myapp
```

### Network Policies

```bash
# Create isolated environments
docker network create --internal dev-network
docker network create --internal prod-network

# Development containers
docker run -d --network dev-network --name dev-app myapp:dev
docker run -d --network dev-network --name dev-db postgres:13

# Production containers (separate network)
docker run -d --network prod-network --name prod-app myapp:prod
docker run -d --network prod-network --name prod-db postgres:13
```

## Troubleshooting Commands

### Network Diagnostics

```bash
# Test connectivity between containers
docker exec container1 ping container2
docker exec container1 nc -zv container2 80       # Port test
docker exec container1 nslookup container2        # DNS test

# Network inspection
docker network inspect bridge                     # Network details
docker inspect container_name | grep -A 10 NetworkSettings

# Container network config
docker exec container ip addr show                # Interface info
docker exec container ip route                    # Routing table
docker exec container netstat -tulpn             # Listening ports
docker exec container ss -tulpn                  # Socket statistics
```

### Common Issues & Solutions

#### Container Can't Connect to External Network

```bash
# Check DNS
docker exec container nslookup google.com

# Test with custom DNS
docker run --dns 8.8.8.8 alpine nslookup google.com

# Check routing
docker exec container ip route
```

#### Port Already in Use

```bash
# Find process using port
lsof -i :8080
netstat -tulpn | grep :8080

# Use different port
docker run -p 8081:80 nginx
```

#### Container Name Resolution Fails

```bash
# Check network
docker network ls
docker network inspect network_name

# Ensure containers on same custom network
docker network connect mynetwork container1
docker network connect mynetwork container2
```

## Docker Compose Networking

### Default Networking

```yaml
version: "3.8"
services:
  web:
    image: nginx
    ports:
      - "80:80"

  app:
    image: myapp
    # Automatically can reach 'web' service
```

### Custom Networks

```yaml
version: "3.8"
services:
  web:
    image: nginx
    networks:
      - frontend
      - backend
    ports:
      - "80:80"

  app:
    image: myapp
    networks:
      - backend

  db:
    image: postgres
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

### External Networks

```yaml
version: "3.8"
services:
  app:
    image: myapp
    networks:
      - existing-network

networks:
  existing-network:
    external: true
```

## Performance Considerations

### Network Performance Tips

```bash
# Use host networking for high-performance applications
docker run --network host high-performance-app

# Enable IPv6 if needed
docker network create --ipv6 --subnet 2001:db8::/64 ipv6net

# Optimize for container-to-container communication
docker network create --opt com.docker.network.bridge.enable_icc=true optimized
```

### Monitoring Network Performance

```bash
# Network statistics
docker exec container ss -i                       # Interface stats
docker exec container iftop                       # Network usage
docker stats container_name                       # Including network I/O

# Test network bandwidth between containers
docker exec container1 iperf3 -s                  # Server
docker exec container2 iperf3 -c container1       # Client
```

## Quick Network Setups

### Development Environment

```bash
# Quick dev network setup
docker network create dev
docker run -d --name redis --network dev redis:alpine
docker run -d --name postgres --network dev -e POSTGRES_PASSWORD=dev postgres
docker run -d --name app --network dev -p 3000:3000 myapp
```

### Production-like Setup

```bash
# Frontend network
docker network create frontend
# Backend network
docker network create --internal backend

# Load balancer
docker run -d --name lb --network frontend -p 80:80 nginx

# Application servers
docker run -d --name app1 --network backend myapp
docker run -d --name app2 --network backend myapp

# Connect load balancer to backend
docker network connect backend lb

# Database
docker run -d --name db --network backend postgres
```

This reference covers the most common Docker networking scenarios and commands for quick problem-solving and setup.
