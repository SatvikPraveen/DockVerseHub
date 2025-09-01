# Docker Networking: Bridge, Host, Overlay & Custom Networks

**Location: `docs/networking.md`**

## Docker Networking Overview

Docker networking enables containers to communicate with each other, the host system, and external networks. Docker provides several network drivers to handle different networking requirements.

## Network Drivers

### 1. Bridge Network (Default)

- **Default network** for containers
- **Internal network** on single Docker host
- **NAT-based** communication with external networks
- **Automatic DNS** resolution between containers

```bash
# Create custom bridge network
docker network create mybridge

# Run container on custom bridge
docker run -d --network mybridge --name web nginx
docker run -d --network mybridge --name db postgres

# Containers can communicate by name
docker exec web ping db
```

### 2. Host Network

- **Direct access** to host networking stack
- **No network isolation** from host
- **Better performance** for high-throughput applications
- **Port conflicts** possible with host services

```bash
# Run container with host networking
docker run -d --network host --name webapp nginx

# Container uses host's network interface directly
# No port mapping needed, but no isolation
```

### 3. Overlay Network

- **Multi-host networking** for Docker Swarm
- **Encrypted communication** between nodes
- **Service discovery** across swarm cluster
- **Load balancing** built-in

```bash
# Create overlay network (Swarm mode)
docker network create -d overlay myoverlay

# Deploy service using overlay network
docker service create --network myoverlay --name web nginx
```

### 4. None Network

- **No networking** for container
- **Complete isolation** from all networks
- **Manual networking** configuration required

```bash
# Run container without networking
docker run -d --network none --name isolated alpine
```

### 5. Macvlan Network

- **Direct physical network** access
- **Unique MAC address** per container
- **Legacy application** compatibility

```bash
# Create macvlan network
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  mymacvlan
```

## Network Architecture

### Bridge Network Architecture

```
Host System (192.168.1.100)
┌─────────────────────────────────────┐
│                                     │
│  Docker Bridge (docker0)            │
│  ┌─────────────────────────────────┐ │
│  │     Bridge Network              │ │
│  │     (172.17.0.0/16)            │ │
│  │                                 │ │
│  │  ┌─────────────┐ ┌─────────────┐│ │
│  │  │ Container A │ │ Container B ││ │
│  │  │172.17.0.2   │ │172.17.0.3   ││ │
│  │  └─────────────┘ └─────────────┘│ │
│  └─────────────────────────────────┘ │
└─────────────────────────────────────┘
          │
          ▼
    External Network
```

### Custom Bridge Benefits

```bash
# Default bridge limitations
docker run -d --name web1 nginx
docker run -d --name web2 nginx
# Cannot communicate by name, only IP

# Custom bridge advantages
docker network create --driver bridge mynet
docker run -d --network mynet --name web1 nginx
docker run -d --network mynet --name web2 nginx
# Can communicate by container name
docker exec web1 ping web2  # ✅ Works
```

## Network Management Commands

### Basic Network Operations

```bash
# List networks
docker network ls

# Inspect network details
docker network inspect bridge

# Create custom network
docker network create [OPTIONS] NETWORK_NAME

# Remove network
docker network rm NETWORK_NAME

# Clean up unused networks
docker network prune
```

### Container Network Operations

```bash
# Run container on specific network
docker run --network NETWORK_NAME IMAGE

# Connect container to additional network
docker network connect NETWORK_NAME CONTAINER

# Disconnect container from network
docker network disconnect NETWORK_NAME CONTAINER

# Inspect container networking
docker inspect CONTAINER_NAME
```

## Port Management

### Port Publishing Options

```bash
# Publish port to host
docker run -p 8080:80 nginx              # Host:Container
docker run -p 127.0.0.1:8080:80 nginx    # Specific IP
docker run -P nginx                       # All exposed ports

# Multiple port mappings
docker run -p 80:80 -p 443:443 -p 8080:8080 nginx

# UDP port mapping
docker run -p 53:53/udp dns-server

# Random host port
docker run -p 80 nginx  # Docker assigns random host port
```

### Port Discovery

```bash
# Show port mappings
docker port CONTAINER_NAME

# Show all container ports
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Find specific port mapping
docker port CONTAINER_NAME 80
```

## Service Discovery

### DNS Resolution

```bash
# Custom bridge network provides DNS
docker network create myapp
docker run -d --network myapp --name database postgres
docker run -d --network myapp --name webapp nginx

# WebApp can reach database by name
docker exec webapp ping database  # Resolves automatically
```

### Container Aliases

```bash
# Add network alias
docker run -d --network myapp --network-alias db postgres
docker run -d --network myapp --network-alias web nginx

# Access by alias
docker exec web ping db
```

### External DNS

```bash
# Custom DNS servers
docker run --dns 8.8.8.8 --dns 8.8.4.4 nginx

# DNS search domains
docker run --dns-search example.com nginx

# DNS options
docker run --dns-option ndots:1 nginx
```

## Advanced Networking

### Multi-Network Containers

```bash
# Create multiple networks
docker network create frontend
docker network create backend

# Connect container to multiple networks
docker run -d --name app --network frontend nginx
docker network connect backend app

# App can communicate with both networks
```

### Network Isolation

```bash
# Create isolated networks
docker network create --internal internal-net

# Containers have no external access
docker run -d --network internal-net alpine
```

### Custom IP Addresses

```bash
# Create network with custom subnet
docker network create --subnet=192.168.10.0/24 customnet

# Assign specific IP to container
docker run -d --network customnet --ip 192.168.10.100 nginx
```

## Load Balancing

### Built-in Load Balancing

```bash
# Multiple containers same network alias
docker run -d --network mynet --network-alias api app:v1
docker run -d --network mynet --network-alias api app:v1
docker run -d --network mynet --network-alias api app:v1

# Requests to 'api' are load balanced across containers
```

### External Load Balancers

```bash
# Nginx load balancer configuration
upstream backend {
    server container1:8080;
    server container2:8080;
    server container3:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

## Docker Compose Networking

### Default Network

```yaml
version: "3.8"
services:
  web:
    image: nginx
    ports:
      - "80:80"

  db:
    image: postgres
    # Accessible as 'db' from web service
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

  api:
    image: myapi
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
    internal: true # No external access
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

## Security Considerations

### Network Segmentation

```bash
# Separate sensitive services
docker network create --internal secure-net
docker run -d --network secure-net --name database postgres

# Database has no internet access
```

### Firewall Rules

```bash
# Docker modifies iptables automatically
# View Docker rules
iptables -L DOCKER

# Custom firewall rules
iptables -I DOCKER-USER -s 10.0.0.0/8 -j DROP
```

### Encrypted Networks

```bash
# Swarm overlay networks are encrypted by default
docker network create --driver overlay --opt encrypted myoverlay
```

## Troubleshooting

### Network Connectivity Issues

```bash
# Test container connectivity
docker exec CONTAINER ping TARGET

# Check network configuration
docker network inspect NETWORK_NAME

# View routing table
docker exec CONTAINER ip route

# Check DNS resolution
docker exec CONTAINER nslookup TARGET
```

### Port Binding Issues

```bash
# Check port availability
netstat -tulpn | grep PORT

# View Docker port mappings
docker port CONTAINER_NAME

# Check firewall rules
ufw status verbose
```

### Performance Issues

```bash
# Network performance test
docker run --rm -it networkstatic/iperf3 -c TARGET_IP

# Monitor network usage
docker stats --no-stream CONTAINER_NAME
```

## Best Practices

### Production Networking

1. **Use custom bridge networks** instead of default bridge
2. **Implement network segmentation** for security
3. **Use overlay networks** for multi-host deployments
4. **Monitor network performance** regularly
5. **Document network architecture** clearly

### Container Communication

1. **Use container names** for service discovery
2. **Avoid hardcoded IP addresses** in applications
3. **Implement health checks** for network services
4. **Use connection pooling** for database connections
5. **Handle network failures** gracefully

### Security Best Practices

1. **Isolate sensitive services** on internal networks
2. **Use encrypted communications** (TLS/SSL)
3. **Implement proper firewall rules**
4. **Regular security audits** of network configuration
5. **Monitor network traffic** for anomalies

## Common Network Patterns

### Microservices Architecture

```yaml
version: "3.8"
services:
  gateway:
    image: nginx
    ports:
      - "80:80"
    networks:
      - frontend

  user-service:
    image: user-api
    networks:
      - frontend
      - backend

  order-service:
    image: order-api
    networks:
      - frontend
      - backend

  database:
    image: postgres
    networks:
      - backend

networks:
  frontend:
  backend:
    internal: true
```

### Development Environment

```bash
# Development network with external access
docker network create --driver bridge dev-network

# All services can reach internet and each other
docker run -d --network dev-network --name web nginx
docker run -d --network dev-network --name api node-app
docker run -d --network dev-network --name db postgres
```

## Next Steps

- Learn about [Docker Volumes and Storage](./volumes-storage.md)
- Explore [Docker Compose](./docker-compose.md) for multi-container networking
- Check [Security Best Practices](./security-best-practices.md)
- Understand [Orchestration Overview](./orchestration-overview.md) for cluster networking
