# Docker Networking

**File Location:** `concepts/04_networking/README.md`

## Docker Networking Fundamentals

Docker networking allows containers to communicate with each other, the host system, and external networks. Understanding Docker's networking model is crucial for building scalable, secure containerized applications.

## Network Types

### Bridge Network (Default)

Docker's default network driver creates an internal private network on the host:

- Containers on same bridge can communicate
- Isolated from host network by default
- Automatic DNS resolution between containers
- Best for single-host deployments

```bash
# Default bridge behavior
docker run -d --name web nginx
docker run -d --name db postgres
# web and db can communicate via container names
```

### Host Network

Container uses the host's network stack directly:

- No network isolation
- Container ports bind directly to host
- Best performance (no NAT overhead)
- Less secure due to direct host access

```bash
# Use host networking
docker run -d --network host nginx
# nginx binds directly to host port 80
```

### None Network

Complete network isolation:

- No network interfaces except loopback
- Maximum isolation
- Useful for batch processing jobs
- Security-focused deployments

```bash
docker run --network none alpine ip addr
```

### Custom Networks

User-defined networks with advanced features:

- Built-in DNS resolution
- Network isolation
- Custom IP addressing
- Recommended for production

## Essential Network Commands

### Network Management

```bash
# List all networks
docker network ls

# Create custom network
docker network create --driver bridge myapp-network

# Create network with custom subnet
docker network create --subnet=172.20.0.0/16 custom-net

# Inspect network details
docker network inspect myapp-network

# Remove network
docker network rm myapp-network

# Clean up unused networks
docker network prune
```

### Container Network Operations

```bash
# Run container on custom network
docker run -d --network myapp-network --name web nginx

# Connect running container to network
docker network connect myapp-network existing-container

# Disconnect container from network
docker network disconnect myapp-network existing-container

# Run with multiple networks
docker run -d --network net1 nginx
docker network connect net2 <container>
```

## Container Communication

### DNS-Based Communication (Recommended)

On custom networks, containers can communicate using service names:

```bash
# Create network and containers
docker network create app-network
docker run -d --network app-network --name database postgres
docker run -d --network app-network --name web nginx

# Web container can reach database via hostname
docker exec web ping database
docker exec web curl http://database:5432
```

### IP-Based Communication

Direct IP communication (less flexible):

```bash
# Get container IP
docker inspect database --format='{{.NetworkSettings.IPAddress}}'

# Connect via IP (not recommended)
docker exec web curl http://172.17.0.2:5432
```

## Port Publishing and Exposure

### Publishing Ports to Host

```bash
# Basic port publishing (host:container)
docker run -d -p 8080:80 nginx

# Bind to specific host interface
docker run -d -p 127.0.0.1:8080:80 nginx

# Publish to random available port
docker run -d -P nginx
docker port <container> 80  # Check assigned port

# Multiple port mappings
docker run -d -p 8080:80 -p 8443:443 nginx

# UDP port publishing
docker run -d -p 5353:53/udp nginx
```

### Port Exposure in Dockerfiles

```dockerfile
# Document which ports the container uses
EXPOSE 80 443
EXPOSE 5432/tcp
EXPOSE 53/udp
```

## Network Drivers

### Bridge Driver

- Default driver for single-host networking
- Automatic subnet assignment
- Built-in load balancing
- Port mapping support

```bash
docker network create --driver bridge \
  --subnet=172.22.0.0/16 \
  --ip-range=172.22.240.0/20 \
  my-bridge-net
```

### Overlay Driver

- Multi-host networking for Docker Swarm
- Encrypted by default
- Service discovery across hosts
- Load balancing integration

```bash
# Requires Swarm mode
docker network create --driver overlay \
  --attachable \
  multi-host-net
```

### Macvlan Driver

- Assigns MAC address to containers
- Containers appear as physical devices
- Direct connection to physical network
- Advanced use cases

```bash
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 \
  macvlan-net
```

### Host Driver

- Uses host's network stack
- No network isolation
- Best performance
- Limited to single host

## Network Security

### Network Isolation

```bash
# Create isolated networks for different tiers
docker network create frontend-net
docker network create backend-net
docker network create database-net

# Web server on frontend and backend
docker run -d --network frontend-net --network backend-net web-app

# Database only on backend network
docker run -d --network database-net database
```

### Internal Networks

```bash
# Create internal-only network (no external access)
docker network create --internal backend-internal
```

## Load Balancing and Service Discovery

### Built-in Load Balancing

Docker provides automatic load balancing for services:

```bash
# Multiple containers with same name
docker run -d --network app-net --name api api-service
docker run -d --network app-net --name api api-service
docker run -d --network app-net --name api api-service

# Requests to 'api' are automatically load balanced
```

### Service Discovery

Containers automatically register DNS entries:

- Container name becomes hostname
- Service aliases for load balancing
- Network-scoped DNS resolution

## Network Troubleshooting

### Connectivity Testing

```bash
# Test connectivity between containers
docker exec container1 ping container2
docker exec container1 telnet container2 80
docker exec container1 curl http://container2/health

# Check DNS resolution
docker exec container1 nslookup container2
docker exec container1 dig container2
```

### Network Inspection

```bash
# View container network settings
docker inspect container --format='{{.NetworkSettings}}'

# Check network endpoints
docker network inspect network-name

# Monitor network traffic
docker exec container netstat -tuln
docker exec container ss -tuln
```

### Common Issues

- Port conflicts on host
- DNS resolution failures
- Network segmentation problems
- MTU size mismatches
- Firewall interference

## Performance Considerations

### Network Performance Tips

1. Use custom networks for better DNS performance
2. Avoid unnecessary port mappings
3. Consider host networking for high-performance apps
4. Use overlay networks judiciously (encryption overhead)
5. Monitor network metrics in production

### Monitoring Network Performance

```bash
# Container network statistics
docker stats --format "table {{.Container}}\t{{.NetIO}}"

# Detailed network metrics
docker exec container cat /proc/net/dev
```

## Files in This Directory

- `Dockerfile.web` - Minimal web application container
- `Dockerfile.db` - Database container with network tools
- `docker-compose.yml` - Multi-container networking example
- `inspect_network.sh` - Network analysis and debugging script
- `custom-networks/` - Advanced networking scenarios
  - `multi-network.yml` - Multiple network example
  - `overlay-demo.yml` - Swarm overlay networking
  - `ingress-routing.yml` - Ingress controller setup
- `load-balancing/` - Load balancer configurations
  - `nginx-lb.yml` - Nginx load balancer
  - `haproxy-config.cfg` - HAProxy configuration
  - `traefik-demo.yml` - Traefik reverse proxy
- `troubleshooting/` - Network debugging tools
  - `connectivity-test.sh` - Connection testing
  - `dns-resolution.sh` - DNS troubleshooting
  - `port-conflicts.md` - Port conflict resolution

## Best Practices

1. **Use custom networks** for multi-container applications
2. **Implement network segmentation** for security
3. **Use DNS names** instead of IP addresses
4. **Limit port exposure** to necessary services only
5. **Monitor network performance** in production
6. **Document network architecture** for team understanding
7. **Test network connectivity** in CI/CD pipelines
8. **Use secrets management** for sensitive network configs

## Common Patterns

### Three-Tier Architecture

```bash
# Frontend network (public-facing)
docker network create frontend

# Backend network (application tier)
docker network create backend

# Database network (data tier)
docker network create database

# Web server: frontend + backend
docker run -d --network frontend --network backend web

# API server: backend + database
docker run -d --network backend --network database api

# Database: database network only
docker run -d --network database db
```

### Microservices Communication

```bash
# Service mesh pattern
docker network create service-mesh

# Each microservice joins the mesh
docker run -d --network service-mesh --name user-service user-app
docker run -d --network service-mesh --name order-service order-app
docker run -d --network service-mesh --name payment-service payment-app
```

Understanding Docker networking is essential for building scalable, secure, and maintainable containerized applications. The examples in this directory demonstrate practical networking patterns you'll encounter in real-world deployments.
