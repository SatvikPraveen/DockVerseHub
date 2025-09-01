# Docker Compose: Multi-Container Applications, Profiles & Scaling

**Location: `docs/docker-compose.md`**

## What is Docker Compose?

Docker Compose is a tool for defining and running multi-container Docker applications. Using a YAML file, you can configure all your application's services, networks, and volumes, then create and start everything with a single command.

## Core Concepts

### Compose File Structure

```yaml
version: "3.8" # Compose file format version

services: # Container definitions
  web:
    # Service configuration

networks:# Network definitions (optional)
  # Custom networks

volumes:# Volume definitions (optional)
  # Named volumes

configs:# Configuration objects (optional)
  # External configurations

secrets:# Secret objects (optional)
  # Sensitive data
```

### Service Definition

```yaml
services:
  webapp:
    build: . # Build from Dockerfile
    image: myapp:latest # Or use existing image
    container_name: webapp # Custom container name
    ports:
      - "3000:3000" # Port mapping
    environment:
      - NODE_ENV=production # Environment variables
    volumes:
      - ./data:/app/data # Volume mounts
    depends_on:
      - database # Service dependencies
    networks:
      - frontend # Network assignment
```

## Compose v1 vs v2 vs v3

### Version Differences

| Feature                  | v1         | v2     | v3          |
| ------------------------ | ---------- | ------ | ----------- |
| **Network isolation**    | ❌         | ✅     | ✅          |
| **Volume management**    | Basic      | ✅     | ✅          |
| **Service dependencies** | ❌         | ✅     | ✅          |
| **Swarm support**        | ❌         | ❌     | ✅          |
| **Secrets & Configs**    | ❌         | ❌     | ✅          |
| **Current status**       | Deprecated | Legacy | Recommended |

### Migration Example

```yaml
# v1 (Deprecated - Don't use)
web:
  build: .
  ports:
    - "5000:5000"
  links:
    - redis

redis:
  image: redis

# v3 (Recommended)
version: "3.8"
services:
  web:
    build: .
    ports:
      - "5000:5000"
    depends_on:
      - redis

  redis:
    image: redis
```

## Basic Multi-Container Setup

### Web Application Stack

```yaml
version: "3.8"

services:
  # Frontend
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - api
    environment:
      - REACT_APP_API_URL=http://localhost:5000

  # Backend API
  api:
    build: ./api
    ports:
      - "5000:5000"
    depends_on:
      - database
      - redis
    environment:
      - DATABASE_URL=postgresql://user:pass@database:5432/myapp
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./logs:/app/logs

  # Database
  database:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Cache
  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## Environment Management

### Environment Files

```bash
# .env file (development)
NODE_ENV=development
DATABASE_URL=postgresql://user:pass@localhost:5432/myapp_dev
REDIS_URL=redis://localhost:6379
API_PORT=5000
```

```yaml
# docker-compose.yml
version: "3.8"
services:
  api:
    build: .
    ports:
      - "${API_PORT}:5000"
    environment:
      - NODE_ENV=${NODE_ENV}
      - DATABASE_URL=${DATABASE_URL}
```

### Multiple Environment Files

```bash
# Development
docker-compose --env-file .env.dev up

# Staging
docker-compose --env-file .env.staging up

# Production
docker-compose --env-file .env.prod up
```

### Override Files

```yaml
# docker-compose.override.yml (automatically loaded)
version: "3.8"
services:
  api:
    volumes:
      - ./src:/app/src # Live code reloading for development
    command: npm run dev

  database:
    ports:
      - "5432:5432" # Expose DB port in development
```

```yaml
# docker-compose.prod.yml
version: "3.8"
services:
  api:
    image: myregistry/api:latest # Use built image
    restart: unless-stopped

  frontend:
    image: myregistry/frontend:latest
    restart: unless-stopped

  database:
    restart: unless-stopped
    command: postgres -c max_connections=200
```

## Profiles (Compose v2+)

### Profile Definition

```yaml
version: "3.8"
services:
  # Always runs
  api:
    image: myapi

  database:
    image: postgres

  # Development tools
  adminer:
    image: adminer
    profiles: [dev, debug]
    ports:
      - "8080:8080"

  # Testing services
  test-runner:
    build: ./tests
    profiles: [test]
    depends_on:
      - api
      - database

  # Monitoring stack
  prometheus:
    image: prom/prometheus
    profiles: [monitoring]

  grafana:
    image: grafana/grafana
    profiles: [monitoring]

  # Debug tools
  jaeger:
    image: jaegertracing/all-in-one
    profiles: [debug, monitoring]
```

### Using Profiles

```bash
# Default services only
docker-compose up

# Include development profile
docker-compose --profile dev up

# Multiple profiles
docker-compose --profile dev --profile monitoring up

# All services
docker-compose --profile "*" up
```

## Service Scaling

### Horizontal Scaling

```yaml
version: "3.8"
services:
  web:
    image: nginx
    ports:
      - "80:80"

  api:
    build: ./api
    # No host port mapping for scaling
    expose:
      - "5000"

  worker:
    build: ./worker
    # Background workers can be scaled
```

```bash
# Scale services
docker-compose up --scale api=3 --scale worker=5

# Scale specific service
docker-compose scale api=3

# View scaled services
docker-compose ps
```

### Load Balancing

```yaml
version: "3.8"
services:
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - api

  api:
    build: ./api
    expose:
      - "5000"
```

```nginx
# nginx.conf
upstream api_backend {
    server api_1:5000;
    server api_2:5000;
    server api_3:5000;
}

server {
    listen 80;
    location / {
        proxy_pass http://api_backend;
    }
}
```

## Advanced Features

### Health Checks

```yaml
version: "3.8"
services:
  api:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  database:
    image: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Service Dependencies

```yaml
version: "3.8"
services:
  api:
    build: .
    depends_on:
      database:
        condition: service_healthy
      redis:
        condition: service_started

  database:
    image: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]

  redis:
    image: redis
```

### Resource Limits

```yaml
version: "3.8"
services:
  api:
    build: .
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
        reservations:
          memory: 256M
          cpus: "0.25"
    restart: unless-stopped
```

### External Networks & Volumes

```yaml
version: "3.8"
services:
  app:
    image: myapp
    networks:
      - existing-network
    volumes:
      - existing-volume:/data

networks:
  existing-network:
    external: true

volumes:
  existing-volume:
    external: true
```

## Essential Commands

### Basic Operations

```bash
# Start services
docker-compose up

# Start in background
docker-compose up -d

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Restart services
docker-compose restart

# View service status
docker-compose ps

# View logs
docker-compose logs
docker-compose logs api  # Specific service
docker-compose logs -f   # Follow logs
```

### Build and Image Management

```bash
# Build services
docker-compose build

# Build specific service
docker-compose build api

# Force rebuild (no cache)
docker-compose build --no-cache

# Pull latest images
docker-compose pull

# Push images to registry
docker-compose push
```

### Service Management

```bash
# Run one-off command
docker-compose run api python manage.py migrate

# Execute command in running service
docker-compose exec api bash

# Scale services
docker-compose up --scale worker=3

# View service configuration
docker-compose config

# Validate compose file
docker-compose config --quiet
```

## Development Workflow

### Development Setup

```yaml
# docker-compose.dev.yml
version: "3.8"
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - ./src:/app/src
      - ./tests:/app/tests
    environment:
      - NODE_ENV=development
      - DEBUG=true
    command: npm run dev

  database:
    image: postgres:13
    ports:
      - "5432:5432" # Expose for local tools
    environment:
      - POSTGRES_PASSWORD=dev123
```

```bash
# Development commands
docker-compose -f docker-compose.dev.yml up
docker-compose -f docker-compose.dev.yml exec api npm test
docker-compose -f docker-compose.dev.yml down
```

### Testing Workflow

```yaml
# docker-compose.test.yml
version: "3.8"
services:
  test-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=testdb
      - POSTGRES_PASSWORD=test123

  api-test:
    build: .
    depends_on:
      - test-db
    environment:
      - NODE_ENV=test
      - DATABASE_URL=postgresql://postgres:test123@test-db:5432/testdb
    command: npm test
    volumes:
      - ./coverage:/app/coverage
```

```bash
# Run tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
docker-compose -f docker-compose.test.yml down -v
```

## Production Patterns

### Production Configuration

```yaml
# docker-compose.prod.yml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    restart: unless-stopped

  api:
    image: myregistry/api:${TAG:-latest}
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    secrets:
      - db_password
      - api_key
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s

  database:
    image: postgres:13
    restart: unless-stopped
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt

volumes:
  postgres_data:
    driver: local
```

### Deployment Script

```bash
#!/bin/bash
# deploy.sh

set -e

# Load environment
source .env.prod

# Build and push images
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml push

# Deploy with zero downtime
docker-compose -f docker-compose.prod.yml up -d --no-deps api
docker-compose -f docker-compose.prod.yml up -d

echo "Deployment complete"
```

## Troubleshooting

### Common Issues

```bash
# Service won't start
docker-compose logs service_name

# Network connectivity issues
docker-compose exec service_name ping other_service

# Port conflicts
docker-compose ps
netstat -tulpn | grep PORT

# Permission issues
docker-compose exec service_name ls -la /path

# DNS resolution
docker-compose exec service_name nslookup service_name
```

### Debug Commands

```bash
# View final configuration
docker-compose config

# Check service health
docker-compose ps
docker inspect $(docker-compose ps -q service_name)

# View resource usage
docker stats $(docker-compose ps -q)

# Access service shell
docker-compose exec service_name bash
```

## Best Practices

### File Organization

```
project/
├── docker-compose.yml          # Base configuration
├── docker-compose.override.yml # Development overrides
├── docker-compose.prod.yml     # Production configuration
├── docker-compose.test.yml     # Testing configuration
├── .env                        # Environment variables
├── .env.example               # Environment template
└── services/
    ├── api/
    │   └── Dockerfile
    └── frontend/
        └── Dockerfile
```

### Security Best Practices

1. **Use secrets** for sensitive data
2. **Don't expose unnecessary ports**
3. **Run services as non-root**
4. **Use read-only filesystems** where possible
5. **Regular security updates**

### Performance Optimization

1. **Use multi-stage builds** for smaller images
2. **Implement health checks** properly
3. **Set appropriate resource limits**
4. **Use caching** effectively
5. **Monitor resource usage**

### Development Guidelines

1. **Use override files** for environment-specific configs
2. **Implement proper logging**
3. **Use meaningful service names**
4. **Document dependencies** clearly
5. **Version your compose files**

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Deploy with Compose
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build and deploy
        run: |
          docker-compose -f docker-compose.prod.yml build
          docker-compose -f docker-compose.prod.yml up -d
```

### GitLab CI Example

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  script:
    - docker-compose build
    - docker-compose push

deploy:
  stage: deploy
  script:
    - docker-compose -f docker-compose.prod.yml pull
    - docker-compose -f docker-compose.prod.yml up -d
  only:
    - main
```

## Next Steps

- Learn about [Docker Networking](./networking.md) for advanced network configurations
- Explore [Security Best Practices](./security-best-practices.md) for production deployments
- Check [Monitoring and Logging](./monitoring-logging.md) for observability
- Understand [Orchestration Overview](./orchestration-overview.md) for cluster management
