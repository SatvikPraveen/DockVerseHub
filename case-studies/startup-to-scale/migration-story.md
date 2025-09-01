# From VMs to Containers: A Complete Migration Journey

**File Location:** `case-studies/startup-to-scale/migration-story.md`

## Company Profile

- **Industry:** E-commerce SaaS
- **Team Size:** 15 → 45 developers over 18 months
- **Infrastructure:** AWS-based, previously VM-centric
- **Timeline:** 18-month migration period

## The Starting Point: VM-Based Monolith

### Original Architecture (2022)

- **Monolithic Ruby on Rails application**
- **3 AWS EC2 instances** (load balancer + 2 app servers)
- **Single PostgreSQL RDS instance**
- **Redis ElastiCache for sessions**
- **Manual deployments taking 45+ minutes**

### Pain Points

```yaml
Deployment Issues:
  - Manual deployment process
  - 45-60 minute deployment windows
  - Rollbacks required full re-deployment
  - Environment inconsistencies between staging/prod

Scaling Problems:
  - Vertical scaling only (larger EC2 instances)
  - Resource waste during low traffic periods
  - Difficult to scale individual components
  - Database became bottleneck quickly

Developer Experience:
  - Local environment setup took 2-3 days for new devs
  - "Works on my machine" syndrome
  - Difficult to test infrastructure changes locally
  - Long feedback loops for testing
```

## Phase 1: Containerizing the Monolith (Months 1-3)

### Initial Dockerization

**First Dockerfile:**

```dockerfile
FROM ruby:3.1-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    yarn \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

**Initial docker-compose.yml:**

```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/app_production
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: app_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Early Wins

- **Local development setup**: Reduced from 2-3 days to 15 minutes
- **Environment consistency**: Eliminated "works on my machine" issues
- **Developer onboarding**: New team members productive on day 1

### Challenges Encountered

```bash
# Image size was initially 2.3GB
docker images
# REPOSITORY  TAG     SIZE
# app         latest  2.3GB

# Build times were slow (8-12 minutes)
time docker build -t app .
# real    11m34.521s

# Secrets management was ad-hoc
# Environment variables in plain text docker-compose files
```

## Phase 2: Optimization and CI/CD (Months 4-6)

### Multi-Stage Dockerfile Optimization

```dockerfile
# Build stage
FROM ruby:3.1-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    yarn \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY Gemfile Gemfile.lock package.json yarn.lock ./

# Install dependencies
RUN bundle config --global frozen 1 && \
    bundle install --without development test && \
    yarn install --frozen-lockfile

# Copy source code
COPY . .

# Build assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

# Runtime stage
FROM ruby:3.1-slim as runtime

WORKDIR /app

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash app

# Copy from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

USER app

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

### Results After Optimization

```yaml
Improvements:
  Image Size: 2.3GB → 420MB (82% reduction)
  Build Time: 11 minutes → 3 minutes (with layer caching)
  Security: Non-root user, minimal attack surface
  Health Checks: Automated container health monitoring
```

### GitHub Actions CI/CD Pipeline

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build and push Docker image
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ secrets.ECR_REGISTRY }}/app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Deploy to production
        run: |
          docker service update --image ${{ secrets.ECR_REGISTRY }}/app:${{ github.sha }} production_web
```

### Deployment Time Improvement

```bash
# Before: Manual deployment
# Time: 45-60 minutes
# Steps: SSH to servers, pull code, bundle install, migrate, restart, health check

# After: Automated container deployment
# Time: 3-5 minutes
# Steps: Push to main branch → automatic build → rolling deployment
```

## Phase 3: Microservices Extraction (Months 7-12)

### Service Extraction Strategy

```yaml
Extraction Order (by business value and independence):
  1. Authentication Service (JWT token management)
  2. Notification Service (email/SMS sending)
  3. Payment Processing Service
  4. User Profile Service
  5. Product Catalog Service
  6. Order Management Service
```

### Authentication Service Example

**New Service Structure:**

```
auth-service/
├── Dockerfile
├── docker-compose.yml
├── src/
│   ├── main.go
│   ├── handlers/
│   ├── middleware/
│   └── models/
└── migrations/
```

**Service docker-compose.yml:**

```yaml
version: "3.8"
services:
  auth-service:
    build: .
    environment:
      - DATABASE_URL=postgresql://postgres:password@auth-db:5432/auth
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_URL=redis://redis:6379
    depends_on:
      - auth-db
      - redis
    networks:
      - auth-network
      - shared-network

  auth-db:
    image: postgres:14
    environment:
      POSTGRES_DB: auth
      POSTGRES_PASSWORD: password
    volumes:
      - auth_postgres_data:/var/lib/postgresql/data
    networks:
      - auth-network

networks:
  auth-network:
    internal: true
  shared-network:
    external: true

volumes:
  auth_postgres_data:
```

### Service Discovery and Communication

```yaml
# API Gateway (nginx) configuration
upstream auth_service {
server auth-service:3001;
}

upstream main_app {
server web:3000;
}

location /api/auth/ {
proxy_pass http://auth_service/;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
}

location / {
proxy_pass http://main_app/;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
}
```

## Phase 4: Production Deployment and Monitoring (Months 13-18)

### Docker Swarm Setup

```bash
# Initialize swarm on manager node
docker swarm init --advertise-addr <manager-ip>

# Join worker nodes
docker swarm join --token <worker-token> <manager-ip>:2377

# Deploy stack
docker stack deploy -c docker-compose.prod.yml ecommerce
```

**Production docker-compose.prod.yml:**

```yaml
version: "3.8"
services:
  web:
    image: ${ECR_REGISTRY}/app:${IMAGE_TAG}
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    networks:
      - frontend
      - backend
    secrets:
      - database_password
      - jwt_secret

  nginx:
    image: ${ECR_REGISTRY}/nginx:${IMAGE_TAG}
    ports:
      - "80:80"
      - "443:443"
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
    networks:
      - frontend

secrets:
  database_password:
    external: true
  jwt_secret:
    external: true

networks:
  frontend:
  backend:
```

### Monitoring Stack

```yaml
# Monitoring services added to stack
prometheus:
  image: prom/prometheus:latest
  command:
    - "--config.file=/etc/prometheus/prometheus.yml"
    - "--storage.tsdb.path=/prometheus"
  volumes:
    - prometheus_data:/prometheus
  networks:
    - monitoring

grafana:
  image: grafana/grafana:latest
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  volumes:
    - grafana_data:/var/lib/grafana
  networks:
    - monitoring
    - frontend

node-exporter:
  image: prom/node-exporter:latest
  deploy:
    mode: global
  volumes:
    - "/proc:/host/proc:ro"
    - "/sys:/host/sys:ro"
    - "/:/rootfs:ro"
```

## Final Results and Metrics

### Infrastructure Metrics

```yaml
Performance Improvements:
  Deployment Time: 45 minutes → 3 minutes (93% reduction)
  Rollback Time: 45 minutes → 30 seconds (99% reduction)
  Environment Setup: 2-3 days → 15 minutes (99.5% reduction)

Reliability Improvements:
  Uptime: 99.5% → 99.9%
  Mean Time to Recovery: 2 hours → 5 minutes
  Failed Deployments: 15% → 2%

Cost Optimizations:
  Infrastructure Costs: 40% reduction
  Developer Productivity: 35% increase
  Support Incidents: 60% reduction
```

### Resource Utilization

```bash
# Before (3 EC2 t3.large instances)
CPU Average: 25%
Memory Average: 60%
Monthly Cost: $185

# After (Docker Swarm cluster)
CPU Average: 70%
Memory Average: 75%
Monthly Cost: $110
Auto-scaling: Yes
```

## Key Success Factors

### Technical Decisions

1. **Incremental Migration** - Started with monolith containerization before microservices
2. **Developer Experience First** - Prioritized local development improvements early
3. **Automated Testing** - Container image security scanning and automated tests
4. **Infrastructure as Code** - All configurations version-controlled

### Team Practices

1. **Training Investment** - 40 hours of Docker training per developer
2. **Documentation** - Comprehensive runbooks for common scenarios
3. **Monitoring First** - Implemented observability before microservices extraction
4. **Gradual Rollout** - Feature flags and canary deployments

## Lessons Learned

### What Worked Well

- **Container-first development** eliminated environment inconsistencies
- **Multi-stage builds** dramatically reduced image sizes and build times
- **Health checks** enabled reliable automated deployments
- **Service extraction** was easier with containers than anticipated

### Challenges and Solutions

```yaml
Challenge: Service discovery complexity
Solution: API Gateway pattern with nginx load balancer

Challenge: Database migration coordination
Solution: Database-per-service with event-driven synchronization

Challenge: Monitoring distributed services
Solution: Centralized logging with ELK stack + Prometheus metrics

Challenge: Secret management across services
Solution: Docker secrets + AWS Parameter Store integration
```

### Mistakes to Avoid

1. **Don't** start with microservices - containerize monolith first
2. **Don't** ignore image optimization - it affects deployment speed significantly
3. **Don't** skip health checks - they're critical for reliable deployments
4. **Don't** underestimate networking complexity in production

## Next Steps

The migration established a solid foundation for:

- **Kubernetes adoption** for more advanced orchestration features
- **Service mesh implementation** for sophisticated traffic management
- **GitOps workflows** for infrastructure management
- **Multi-region deployments** for global availability

---

**Total Migration Timeline:** 18 months  
**Team Growth During Migration:** 15 → 45 developers  
**Overall Success Rating:** ⭐⭐⭐⭐⭐ (5/5)

_This case study demonstrates how a systematic, phased approach to containerization can transform both infrastructure efficiency and developer productivity at scale._
