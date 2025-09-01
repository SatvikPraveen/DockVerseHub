# Docker Compose

**File Location:** `concepts/05_docker_compose/README.md`

## What is Docker Compose?

Docker Compose is a tool for defining and running multi-container Docker applications using YAML configuration files.

## Key Features

- **Multi-container orchestration**
- **Service definitions**
- **Network management**
- **Volume management**
- **Environment configuration**

## Basic Commands

```bash
# Start services
docker-compose up -d

# View services
docker-compose ps

# Stop services
docker-compose down

# Build and start
docker-compose up --build

# Scale services
docker-compose up --scale web=3
```

## Compose File Structure

```yaml
version: "3.8"
services:
  web:
    build: .
    ports:
      - "5000:5000"
    environment:
      - DEBUG=1
    volumes:
      - .:/app
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:

networks:
  default:
    driver: bridge
```

## Profiles for Environment Management

```yaml
services:
  web:
    profiles: ["frontend"]

  db:
    profiles: ["backend", "full"]

  monitoring:
    profiles: ["dev", "monitoring"]
```

```bash
# Start specific profiles
docker-compose --profile frontend up
docker-compose --profile dev --profile backend up
```

## Files in This Directory

- `docker-compose.yml` - Multi-container app example
- `docker-compose.override.yml` - Environment overrides
- `docker-compose.prod.yml` - Production configuration
- `profiles-demo/` - Compose profiles examples
- `scaling/` - Service scaling examples
- `advanced-features/` - Advanced Compose features

## Key Benefits

1. **Simplified multi-container management**
2. **Consistent development environments**
3. **Easy service scaling**
4. **Environment-specific configurations**
5. **Integrated networking and volumes**
