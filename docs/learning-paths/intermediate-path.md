# Docker Intermediate Learning Path (3-6 Months)

**Location: `docs/learning-paths/intermediate-path.md`**

## Learning Objectives

Build upon beginner knowledge to become proficient with:

- Advanced Docker features and optimization techniques
- Container orchestration with Docker Swarm
- Production deployment strategies
- CI/CD integration and automation
- Performance monitoring and troubleshooting
- Security hardening and compliance

## Prerequisites

Before starting this path, you should have completed the [Beginner Path](./beginner-path.md) or have equivalent experience with:

- Basic Docker commands and container operations
- Writing Dockerfiles and building images
- Docker Compose for multi-container applications
- Basic networking and volume concepts

## Phase 1: Advanced Docker Features (Weeks 1-4)

### Week 1: Advanced Image Building

**Goal**: Master BuildKit and advanced Dockerfile techniques

#### Theory (3-4 hours)

- [ ] BuildKit features and benefits
- [ ] Multi-platform builds
- [ ] Build secrets and cache mounts
- [ ] Advanced multi-stage patterns

#### Hands-on Practice

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:16-alpine AS deps
WORKDIR /app
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci --only=production

FROM node:16-alpine AS build
WORKDIR /app
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci

COPY . .
RUN npm run build

FROM node:16-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

```bash
# Multi-platform builds
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t myapp --push .

# Build with secrets
echo "secret_value" | docker build --secret id=api_key,src=- .
```

#### Weekly Project: Optimized Build Pipeline

Create a complex application with:

- Multi-stage build for different targets (dev, test, prod)
- Build cache optimization
- Multi-architecture support
- Secrets integration for API keys

### Week 2: Advanced Networking

**Goal**: Master Docker networking for complex applications

#### Theory (2-3 hours)

- [ ] Read [Networking Quick Reference](../quick-reference/networking-quick-ref.md)
- [ ] Overlay networks and encryption
- [ ] Custom network drivers
- [ ] Network troubleshooting techniques

#### Hands-on Practice

```bash
# Advanced network setup
docker network create --driver overlay --encrypted secure-net
docker network create --driver bridge --internal backend-net

# Network troubleshooting
docker exec container tcpdump -i eth0
docker exec container netstat -tupln
docker exec container ss -tupln
```

```yaml
# Complex networking in Compose
version: "3.8"
services:
  frontend:
    build: ./frontend
    networks:
      - public
    ports:
      - "80:80"

  api:
    build: ./api
    networks:
      - public
      - backend

  database:
    image: postgres:13
    networks:
      - backend
    environment:
      - POSTGRES_DB=myapp

networks:
  public:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

#### Weekly Project: Microservices Network Architecture

Design and implement a microservices architecture with:

- API Gateway pattern
- Service mesh concepts
- Network segmentation
- Load balancing strategies

### Week 3: Production Storage & Performance

**Goal**: Implement production-ready storage and optimize performance

#### Theory (2-3 hours)

- [ ] Read [Performance Optimization](../performance-optimization.md)
- [ ] Storage drivers and performance implications
- [ ] Backup and disaster recovery strategies
- [ ] Performance monitoring and profiling

#### Hands-on Practice

```bash
# Storage performance testing
docker run --rm -v test-vol:/data alpine \
  dd if=/dev/zero of=/data/test bs=1M count=100

# Custom storage driver configuration
# /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"]
}

# Volume backup automation
docker run --rm -v myvolume:/data -v $(pwd):/backup \
  busybox tar czf /backup/backup-$(date +%Y%m%d).tar.gz -C /data .
```

```python
# Performance monitoring script
import docker
import time

client = docker.from_env()

def monitor_container_performance(container_name, duration=300):
    container = client.containers.get(container_name)

    for i in range(duration):
        stats = container.stats(stream=False)

        # Extract metrics
        cpu_percent = calculate_cpu_percent(stats)
        memory_usage = stats['memory_stats']['usage']

        print(f"CPU: {cpu_percent:.2f}% Memory: {memory_usage/1024/1024:.2f}MB")
        time.sleep(1)
```

#### Weekly Project: High-Performance Application

Build an application that demonstrates:

- Optimized storage configuration
- Resource monitoring and alerting
- Automated backup strategies
- Performance benchmarking

### Week 4: Security Hardening

**Goal**: Implement advanced security practices

#### Theory (3-4 hours)

- [ ] Container runtime security
- [ ] Image signing and verification
- [ ] Security scanning integration
- [ ] Compliance frameworks (CIS, NIST)

#### Hands-on Practice

```dockerfile
# Security-hardened Dockerfile
FROM alpine:3.18 AS builder
RUN apk add --no-cache build-base
COPY . /src
WORKDIR /src
RUN make build

FROM scratch
COPY --from=builder /src/app /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 65534:65534
ENTRYPOINT ["/app"]
```

```bash
# Security scanning in CI/CD
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
docker scan --severity high myapp:latest

# Runtime security with Falco
docker run --rm -ti --privileged -v /var/run/docker.sock:/host/var/run/docker.sock \
  falcosecurity/falco:latest
```

```yaml
# Security-focused compose
version: "3.8"
services:
  app:
    build: .
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
```

#### Weekly Project: Secure Deployment

Create a security-focused deployment with:

- Distroless or scratch-based images
- Runtime security monitoring
- Automated vulnerability scanning
- Security policy enforcement

## Phase 2: Container Orchestration (Weeks 5-8)

### Week 5: Docker Swarm Fundamentals

**Goal**: Master Docker's native orchestration

#### Theory (3-4 hours)

- [ ] Read [Orchestration Overview](../orchestration-overview.md)
- [ ] Swarm architecture and concepts
- [ ] Service discovery and load balancing
- [ ] Rolling updates and rollbacks

#### Hands-on Practice

```bash
# Initialize swarm cluster
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Add worker nodes
docker swarm join-token worker
docker swarm join --token TOKEN MANAGER-IP:2377

# Create and manage services
docker service create --name web --replicas 3 --publish 80:80 nginx
docker service ls
docker service ps web
docker service logs web
```

```yaml
# Stack deployment
version: "3.8"
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      placement:
        constraints:
          - node.role == worker

  api:
    image: myapi:latest
    deploy:
      replicas: 5
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
    networks:
      - backend

networks:
  backend:
    driver: overlay
```

#### Weekly Project: Swarm Cluster

Build a production-like Swarm cluster:

- Multi-node setup (manager + workers)
- Service deployment and scaling
- Rolling updates and rollbacks
- Health monitoring and self-healing

### Week 6: Advanced Swarm Operations

**Goal**: Production-ready Swarm management

#### Theory (2-3 hours)

- [ ] Secrets and configuration management
- [ ] Service constraints and placement
- [ ] Network encryption and security
- [ ] Backup and disaster recovery

#### Hands-on Practice

```bash
# Secrets management
echo "mysecretpassword" | docker secret create db_password -
docker service create --name db --secret db_password postgres:13

# Configuration management
docker config create nginx_config nginx.conf
docker service create --name web --config source=nginx_config,target=/etc/nginx/nginx.conf nginx

# Service constraints
docker service create --name db \
  --constraint 'node.labels.storage == ssd' \
  --constraint 'node.role == worker' \
  postgres:13
```

```yaml
# Production stack with secrets
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == worker
    secrets:
      - db_password
      - api_key
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    external: true
  api_key:
    file: ./api_key.txt
```

#### Weekly Project: Production Stack

Deploy a production-ready application with:

- Secrets management
- Configuration as code
- Placement constraints
- Automated backup strategies

### Week 7: Monitoring and Observability

**Goal**: Implement comprehensive monitoring

#### Theory (3-4 hours)

- [ ] Read [Monitoring and Logging](../monitoring-logging.md)
- [ ] Prometheus and Grafana setup
- [ ] Distributed tracing concepts
- [ ] Log aggregation strategies

#### Hands-on Practice

```yaml
# Monitoring stack
version: "3.8"
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

volumes:
  grafana_data:

networks:
  monitoring:
```

#### Weekly Project: Observability Platform

Implement a complete observability solution:

- Metrics collection (Prometheus)
- Visualization (Grafana)
- Log aggregation (ELK stack)
- Alerting and notifications

### Week 8: High Availability and Disaster Recovery

**Goal**: Design resilient systems

#### Theory (2-3 hours)

- [ ] High availability patterns
- [ ] Disaster recovery planning
- [ ] Backup strategies
- [ ] Failover mechanisms

#### Hands-on Practice

```yaml
# High availability setup
version: "3.8"
services:
  haproxy:
    image: haproxy:alpine
    ports:
      - "80:80"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager

  app:
    image: myapp:latest
    deploy:
      replicas: 6
      update_config:
        parallelism: 2
        delay: 30s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        max_attempts: 3

  db-primary:
    image: postgres:13
    environment:
      - POSTGRES_REPLICATION_MODE=master
    volumes:
      - db_primary:/var/lib/postgresql/data
    deploy:
      placement:
        constraints:
          - node.labels.database == primary

  db-replica:
    image: postgres:13
    environment:
      - POSTGRES_REPLICATION_MODE=slave
    volumes:
      - db_replica:/var/lib/postgresql/data
    deploy:
      placement:
        constraints:
          - node.labels.database == replica

volumes:
  db_primary:
  db_replica:
```

#### Weekly Project: Resilient Architecture

Design and implement:

- Multi-region deployment
- Database replication
- Automated failover
- Backup and restore procedures

## Phase 3: CI/CD Integration (Weeks 9-12)

### Week 9: CI/CD Pipeline Basics

**Goal**: Integrate Docker with CI/CD systems

#### Theory (2-3 hours)

- [ ] CI/CD concepts and best practices
- [ ] Docker in build pipelines
- [ ] Registry integration
- [ ] Deployment automation

#### Hands-on Practice

```yaml
# GitHub Actions workflow
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: myapp:${{ github.sha }},myapp:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: |
          docker service update --image myapp:${{ github.sha }} production_app
```

#### Weekly Project: Complete Pipeline

Build a CI/CD pipeline that includes:

- Automated testing
- Security scanning
- Multi-stage deployments
- Rollback capabilities

### Week 10: Advanced Deployment Strategies

**Goal**: Implement blue-green and canary deployments

#### Theory (2-3 hours)

- [ ] Read [Production Deployment](../production-deployment.md)
- [ ] Blue-green deployment patterns
- [ ] Canary releases
- [ ] Feature flags and traffic splitting

#### Hands-on Practice

```bash
# Blue-green deployment script
#!/bin/bash
CURRENT=$(docker service inspect production_app --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' | grep -o 'v[0-9]*')
NEW_VERSION="v$((${CURRENT#v} + 1))"

# Deploy to green environment
docker service create --name green_app myapp:$NEW_VERSION

# Health check green environment
for i in {1..30}; do
  if curl -f http://green-app/health; then
    echo "Green environment healthy"
    break
  fi
  sleep 10
done

# Switch traffic
docker service update --image myapp:$NEW_VERSION production_app
docker service rm green_app
```

```yaml
# Canary deployment configuration
version: "3.8"
services:
  app-stable:
    image: myapp:stable
    deploy:
      replicas: 9
      labels:
        - "version=stable"

  app-canary:
    image: myapp:canary
    deploy:
      replicas: 1
      labels:
        - "version=canary"

  load-balancer:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-canary.conf:/etc/nginx/nginx.conf
```

#### Weekly Project: Deployment Automation

Implement automated deployment strategies:

- Blue-green deployment automation
- Canary release with gradual traffic shifting
- Automated rollback on failure detection
- A/B testing capabilities

### Week 11: Performance and Cost Optimization

**Goal**: Optimize for performance and cost efficiency

#### Theory (3-4 hours)

- [ ] Read [Cost Optimization](../cost-optimization.md)
- [ ] Resource allocation strategies
- [ ] Horizontal and vertical scaling
- [ ] Cost monitoring and alerting

#### Hands-on Practice

```python
# Cost optimization script
import docker
import json
from datetime import datetime

def analyze_resource_usage():
    client = docker.from_env()
    containers = client.containers.list()

    recommendations = []

    for container in containers:
        stats = container.stats(stream=False)

        # Calculate resource utilization
        cpu_usage = calculate_cpu_usage(stats)
        memory_usage = stats['memory_stats']['usage'] / stats['memory_stats']['limit']

        if cpu_usage < 20 and memory_usage < 40:
            recommendations.append({
                'container': container.name,
                'action': 'downsize',
                'current_cpu': cpu_usage,
                'current_memory': memory_usage * 100
            })

    return recommendations
```

```yaml
# Resource-optimized deployment
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 256M
          cpus: "0.25"
        reservations:
          memory: 128M
          cpus: "0.125"
      placement:
        preferences:
          - spread: node.labels.cost_tier
```

#### Weekly Project: Optimization Platform

Build a system that provides:

- Automated resource right-sizing
- Cost tracking and alerting
- Performance optimization recommendations
- Automated scaling based on cost/performance metrics

### Week 12: Advanced Troubleshooting and Debugging

**Goal**: Master complex troubleshooting scenarios

#### Theory (2-3 hours)

- [ ] Advanced debugging techniques
- [ ] Performance profiling
- [ ] Network and storage troubleshooting
- [ ] Root cause analysis

#### Hands-on Practice

```bash
# Advanced debugging toolkit
docker run --rm -it --pid container:target --network container:target \
  --cap-add SYS_PTRACE nicolaka/netshoot

# Performance profiling
docker exec container perf record -g ./myapp
docker exec container perf report

# Network troubleshooting
docker exec container tcpdump -i any -w capture.pcap
docker exec container iftop -i eth0
```

```python
# Automated issue detection
import docker
import logging

def detect_common_issues():
    client = docker.from_env()
    issues = []

    for container in client.containers.list():
        # Check for high restart count
        restart_count = container.attrs['RestartCount']
        if restart_count > 5:
            issues.append(f"{container.name}: High restart count ({restart_count})")

        # Check for OOM kills
        if container.attrs['State']['OOMKilled']:
            issues.append(f"{container.name}: OOM killed - increase memory limit")

        # Check for unhealthy containers
        health = container.attrs['State'].get('Health', {})
        if health.get('Status') == 'unhealthy':
            issues.append(f"{container.name}: Health check failing")

    return issues
```

#### Final Project: Comprehensive Docker Platform

Build a complete production platform that demonstrates all intermediate skills:

**Requirements:**

- Multi-node Docker Swarm cluster
- CI/CD pipeline with multiple environments
- Blue-green deployment automation
- Comprehensive monitoring and alerting
- Security scanning and compliance
- Cost optimization and resource management
- Automated troubleshooting and self-healing

**Deliverables:**

1. Infrastructure as Code (Docker Compose stacks)
2. CI/CD pipeline configurations
3. Monitoring and alerting setup
4. Security scanning and hardening documentation
5. Runbooks and troubleshooting guides
6. Performance and cost optimization reports

## Assessment and Certification Preparation

### Skills Assessment Checklist

**Advanced Docker:**

- [ ] Can optimize builds with BuildKit features
- [ ] Can implement multi-architecture builds
- [ ] Can troubleshoot complex networking issues
- [ ] Can implement advanced security practices

**Orchestration:**

- [ ] Can deploy and manage Swarm clusters
- [ ] Can implement service discovery and load balancing
- [ ] Can manage secrets and configurations
- [ ] Can implement high availability patterns

**Production Operations:**

- [ ] Can implement monitoring and alerting
- [ ] Can troubleshoot performance issues
- [ ] Can implement backup and disaster recovery
- [ ] Can optimize costs and resource usage

**CI/CD Integration:**

- [ ] Can integrate Docker with CI/CD pipelines
- [ ] Can implement deployment automation
- [ ] Can implement blue-green and canary deployments
- [ ] Can troubleshoot pipeline issues

### Next Steps Options

**Continue Learning:**

- Proceed to [Advanced Learning Path](./advanced-path.md)
- Explore Kubernetes orchestration
- Deep dive into cloud-native technologies

**Specialization Paths:**

- **DevOps Track**: Focus on CI/CD, infrastructure automation
- **Platform Engineering**: Build internal developer platforms
- **Security Track**: Specialize in container and cloud security
- **Site Reliability Engineering**: Focus on production operations

**Certification Preparation:**

- Docker Certified Associate (DCA)
- Cloud provider certifications (AWS, Azure, GCP)
- Kubernetes certifications (CKA, CKAD, CKS)

## Continuous Learning Resources

### Advanced Books

- "Docker Deep Dive" by Nigel Poulton
- "Container Security" by Liz Rice
- "Kubernetes Patterns" by Bilgin Ibryam

### Professional Development

- Join Docker meetups and conferences
- Contribute to open source Docker projects
- Blog about your Docker experiences
- Mentor beginners in the community

### Hands-on Platforms

- AWS/GCP/Azure container services
- Kubernetes clusters
- Production troubleshooting scenarios

The intermediate path focuses on building production-ready skills that employers value. Consistent practice with real-world scenarios is key to mastering these concepts.
