# Docker Orchestration Overview: Swarm, Scaling & Service Management

**Location: `docs/orchestration-overview.md`**

## What is Container Orchestration?

Container orchestration automates the deployment, management, scaling, and networking of containers across a cluster of machines. It handles service discovery, load balancing, rolling updates, and failure recovery.

## Docker Swarm Overview

Docker Swarm is Docker's native orchestration solution that turns a group of Docker hosts into a single, virtual Docker host.

### Swarm Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Manager Node  │    │   Manager Node  │    │   Manager Node  │
│   (Leader)      │◄──►│                 │◄──►│                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
    ┌─────▼─────┐          ┌─────▼─────┐          ┌─────▼─────┐
    │Worker Node│          │Worker Node│          │Worker Node│
    │           │          │           │          │           │
    └───────────┘          └───────────┘          └───────────┘
```

### Key Components

- **Manager Nodes**: Control the cluster, maintain state, schedule services
- **Worker Nodes**: Run containers (services)
- **Services**: Definition of tasks to run on nodes
- **Tasks**: Individual containers running on nodes
- **Load Balancer**: Built-in routing mesh

## Swarm Setup

### Initialize Swarm

```bash
# Initialize swarm on manager node
docker swarm init --advertise-addr <MANAGER-IP>

# Get join tokens
docker swarm join-token worker
docker swarm join-token manager

# Join worker node
docker swarm join \
    --token <WORKER-TOKEN> \
    <MANAGER-IP>:2377

# Join as manager
docker swarm join \
    --token <MANAGER-TOKEN> \
    <MANAGER-IP>:2377
```

### Cluster Management

```bash
# View nodes
docker node ls

# Inspect node
docker node inspect <NODE-ID>

# Promote worker to manager
docker node promote <NODE-ID>

# Demote manager to worker
docker node demote <NODE-ID>

# Remove node
docker node rm <NODE-ID>

# Drain node (stop scheduling new tasks)
docker node update --availability drain <NODE-ID>
```

## Services Management

### Creating Services

```bash
# Basic service
docker service create --name webapp nginx

# Service with replicas
docker service create \
    --name webapp \
    --replicas 3 \
    nginx

# Service with port publishing
docker service create \
    --name webapp \
    --replicas 3 \
    --publish 80:80 \
    nginx

# Service with resource constraints
docker service create \
    --name webapp \
    --replicas 3 \
    --limit-memory 512M \
    --limit-cpu 0.5 \
    nginx
```

### Service Configuration

```bash
# Complex service example
docker service create \
    --name api-service \
    --replicas 5 \
    --network backend \
    --publish 3000:3000 \
    --env NODE_ENV=production \
    --env DB_HOST=database \
    --mount type=volume,src=api-logs,dst=/app/logs \
    --limit-memory 256M \
    --limit-cpu 0.25 \
    --constraint 'node.role == worker' \
    --update-parallelism 1 \
    --update-delay 30s \
    --restart-condition on-failure \
    --restart-max-attempts 3 \
    myapi:latest
```

### Service Management Commands

```bash
# List services
docker service ls

# Inspect service
docker service inspect webapp

# View service logs
docker service logs webapp

# Scale service
docker service scale webapp=5

# Update service
docker service update --image nginx:alpine webapp

# Remove service
docker service rm webapp

# Service tasks
docker service ps webapp
```

## Scaling Applications

### Horizontal Scaling

```bash
# Scale up
docker service scale webapp=10

# Scale multiple services
docker service scale webapp=5 api=3 worker=8

# Auto-scaling based on CPU (requires external tools)
# Example with custom script
#!/bin/bash
while true; do
    CPU_USAGE=$(docker service ls --format "{{.Name}}" | xargs -I {} \
        docker stats --no-stream --format "{{.CPUPerc}}" {})
    if [[ ${CPU_USAGE%.*} -gt 80 ]]; then
        docker service scale webapp=$(($(docker service inspect webapp --format '{{.Spec.Mode.Replicated.Replicas}}')+1))
    fi
    sleep 60
done
```

### Load Distribution

```yaml
# docker-compose.yml for Swarm
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf

  app:
    image: myapp:latest
    deploy:
      replicas: 6
      placement:
        constraints:
          - node.role == worker
        preferences:
          - spread: node.id
      update_config:
        parallelism: 2
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        max_attempts: 3

configs:
  nginx_config:
    external: true

networks:
  default:
    driver: overlay
    attachable: true
```

### Rolling Updates

```bash
# Update service image
docker service update --image myapp:v2.0 webapp

# Update with custom parameters
docker service update \
    --image myapp:v2.0 \
    --update-parallelism 2 \
    --update-delay 30s \
    --update-failure-action rollback \
    webapp

# Rollback service
docker service rollback webapp
```

## Docker Stack Deployment

### Stack Files

```yaml
# production-stack.yml
version: "3.8"
services:
  reverse-proxy:
    image: traefik:v2.9
    command:
      - "--api.insecure=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    deploy:
      placement:
        constraints:
          - node.role == manager
    networks:
      - frontend

  frontend:
    image: myapp/frontend:latest
    deploy:
      replicas: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.frontend.rule=Host(`app.example.com`)"
        - "traefik.http.services.frontend.loadbalancer.server.port=80"
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
    networks:
      - frontend
      - backend

  api:
    image: myapp/api:latest
    environment:
      - NODE_ENV=production
      - DATABASE_URL_FILE=/run/secrets/db_url
    secrets:
      - db_url
      - api_key
    deploy:
      replicas: 5
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.api.rule=Host(`api.example.com`)"
        - "traefik.http.services.api.loadbalancer.server.port=3000"
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
    networks:
      - backend

  database:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER_FILE=/run/secrets/db_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_user
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.database == true
      restart_policy:
        condition: on-failure
        max_attempts: 3
    networks:
      - backend

  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == worker
    networks:
      - backend

secrets:
  db_url:
    external: true
  db_user:
    external: true
  db_password:
    external: true
  api_key:
    external: true

networks:
  frontend:
    driver: overlay
    external: true
  backend:
    driver: overlay
    external: true

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
```

### Stack Deployment Commands

```bash
# Deploy stack
docker stack deploy -c production-stack.yml myapp

# List stacks
docker stack ls

# List stack services
docker stack services myapp

# View stack tasks
docker stack ps myapp

# Remove stack
docker stack rm myapp
```

## Service Discovery and Load Balancing

### Built-in Service Discovery

```bash
# Services can communicate by service name
# No need for service discovery tools
curl http://api-service:3000/health
curl http://database:5432
```

### Routing Mesh

```
External Traffic (Port 80)
          │
          ▼
    ┌─────────────┐
    │    Node 1   │ ──┐
    └─────────────┘   │
                      │    ┌─────────────────────┐
    ┌─────────────┐   ├───►│   Routing Mesh      │
    │    Node 2   │ ──┘    │   Load Balancer     │
    └─────────────┘        └─────────────────────┘
                                      │
    ┌─────────────┐              ┌────▼────┐
    │    Node 3   │              │Container│
    └─────────────┘              │ Tasks   │
                                 └─────────┘
```

### Custom Load Balancing

```nginx
# nginx.conf for custom load balancing
upstream api_backend {
    server api-service:3000 max_fails=3 fail_timeout=30s;
    server api-service:3000 max_fails=3 fail_timeout=30s;
    server api-service:3000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    location /api/ {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Health check
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
}
```

## High Availability Patterns

### Multi-Manager Setup

```bash
# Setup 3-manager cluster for HA
# Node 1 (Leader)
docker swarm init --advertise-addr 10.0.0.1

# Node 2 (Manager)
docker swarm join --token <MANAGER-TOKEN> 10.0.0.1:2377

# Node 3 (Manager)
docker swarm join --token <MANAGER-TOKEN> 10.0.0.1:2377

# Add workers
for i in {4..6}; do
    docker swarm join --token <WORKER-TOKEN> 10.0.0.1:2377
done
```

### Service Placement Strategies

```yaml
version: "3.8"
services:
  database:
    image: postgres:13
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.database == true
      restart_policy:
        condition: on-failure
        max_attempts: 5

  redis:
    image: redis:alpine
    deploy:
      replicas: 3
      placement:
        preferences:
          - spread: node.id # Spread across different nodes
      restart_policy:
        condition: on-failure

  api:
    image: myapi:latest
    deploy:
      replicas: 5
      placement:
        constraints:
          - node.role == worker
        preferences:
          - spread: node.labels.zone # Spread across availability zones
```

## Health Checks and Monitoring

### Service Health Checks

```dockerfile
# Dockerfile with health check
FROM nginx:alpine
COPY healthcheck.sh /usr/local/bin/
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1
```

```yaml
# Service with health check
version: "3.8"
services:
  webapp:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      replicas: 3
      update_config:
        monitor: 60s # Wait for health check after update
```

### Monitoring Stack Services

```bash
# Monitor service health
docker service ls
docker service ps webapp --no-trunc

# Check service logs
docker service logs webapp

# Service inspection
docker service inspect webapp --pretty
```

## Secrets and Configuration Management

### Creating Secrets

```bash
# Create secret from stdin
echo "mypassword" | docker secret create db_password -

# Create secret from file
docker secret create ssl_cert ./ssl_cert.pem

# List secrets
docker secret ls

# Inspect secret (metadata only)
docker secret inspect db_password
```

### Configuration Objects

```bash
# Create config
docker config create nginx_config ./nginx.conf

# List configs
docker config ls

# Remove config
docker config rm nginx_config
```

### Using Secrets and Configs

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    secrets:
      - source: db_password
        target: /run/secrets/db_password
        mode: 0400
    configs:
      - source: app_config
        target: /app/config.yml
        mode: 0444
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    external: true

configs:
  app_config:
    external: true
```

## Troubleshooting Orchestration

### Common Issues

```bash
# Service not starting
docker service ps webapp --no-trunc
docker service logs webapp

# Network connectivity
docker exec $(docker ps --filter name=webapp -q | head -1) ping database

# Resource constraints
docker node ls
docker service inspect webapp --pretty

# Manager node issues
docker node ls
docker swarm ca --rotate
```

### Debug Commands

```bash
# Check swarm status
docker system info | grep -A 10 Swarm

# Node connectivity
docker node ls
docker node inspect <NODE-ID> --pretty

# Service troubleshooting
docker service ps <SERVICE> --no-trunc --format "table {{.Node}}\t{{.CurrentState}}\t{{.Error}}"

# Network inspection
docker network ls --filter driver=overlay
docker network inspect <NETWORK>
```

## Best Practices

### Production Deployment

1. **Use odd number of managers** (3, 5, 7) for quorum
2. **Separate manager and worker roles** for better resource allocation
3. **Implement health checks** for all services
4. **Use secrets management** for sensitive data
5. **Plan for rolling updates** with appropriate strategies
6. **Monitor cluster health** continuously
7. **Regular backups** of swarm state

### Performance Optimization

1. **Resource limits** on all services
2. **Appropriate replica counts** based on load
3. **Strategic placement** of services
4. **Network optimization** with overlay networks
5. **Storage consideration** for stateful services

### Security Guidelines

1. **TLS encryption** for all communication
2. **Regular security updates** for nodes
3. **Network segmentation** between services
4. **Access control** for swarm management
5. **Regular security audits**

## Alternatives to Docker Swarm

### Kubernetes vs Docker Swarm

| Feature                 | Docker Swarm   | Kubernetes |
| ----------------------- | -------------- | ---------- |
| **Complexity**          | Simple         | Complex    |
| **Learning curve**      | Low            | High       |
| **Ecosystem**           | Docker-focused | Vast       |
| **Scaling**             | Good           | Excellent  |
| **Enterprise features** | Basic          | Advanced   |

### When to Choose Swarm

- **Simple requirements**: Basic orchestration needs
- **Docker-centric**: Already using Docker extensively
- **Small to medium scale**: < 100 nodes
- **Quick setup**: Need fast deployment
- **Team expertise**: Docker knowledge but not K8s

### When to Consider Kubernetes

- **Complex applications**: Microservices architecture
- **Large scale**: > 100 nodes
- **Advanced features**: Custom resources, operators
- **Multi-cloud**: Cloud-agnostic deployments
- **Enterprise needs**: Advanced networking, security

## Migration Strategies

### Swarm to Kubernetes Migration

```bash
# 1. Export Swarm services
docker service ls --format "table {{.Name}}\t{{.Image}}\t{{.Replicas}}"

# 2. Convert to Kubernetes manifests
kompose convert -f docker-compose.yml

# 3. Deploy to Kubernetes
kubectl apply -f converted-manifests/
```

## Next Steps

- Learn [Production Deployment](./production-deployment.md) strategies
- Explore [Troubleshooting](./troubleshooting.md) orchestration issues
- Check [Performance Optimization](./performance-optimization.md) for clusters
- Understand [Migration Strategies](./migration-strategies.md) to other platforms
