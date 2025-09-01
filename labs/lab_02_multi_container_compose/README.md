# Lab 02: Multi-Container Full-Stack Application

**File Location:** `labs/lab_02_multi_container_compose/README.md`

## Overview

This lab demonstrates building a complete full-stack application using Docker Compose with multiple containers: React frontend, Python API, PostgreSQL database, Redis cache, and Nginx reverse proxy.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Nginx     │────│   Frontend   │    │   API       │
│(Port 80/443)│    │  (React)     │────│ (Python)    │
└─────────────┘    └──────────────┘    └─────────────┘
                                              │
                                       ┌─────────────┐
                                       │ PostgreSQL  │
                                       │ Database    │
                                       └─────────────┘
                                              │
                                       ┌─────────────┐
                                       │   Redis     │
                                       │   Cache     │
                                       └─────────────┘
```

## Services

- **Frontend**: React application (port 3000)
- **API**: Python Flask REST API (port 5000)
- **Database**: PostgreSQL 15 (port 5432)
- **Cache**: Redis 7 (port 6379)
- **Proxy**: Nginx reverse proxy (port 80/443)

## Quick Start

### Development Environment

```bash
# Start all services
docker-compose up

# Start in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Production Environment

```bash
# Start production stack
docker-compose -f docker-compose.prod.yml up -d

# Scale API service
docker-compose -f docker-compose.prod.yml up -d --scale api=3
```

## Service Details

### Frontend Service

- React 18 application
- Hot reload in development
- Optimized build for production
- Environment-based configuration

### API Service

- Flask REST API with PostgreSQL
- Redis caching for improved performance
- Health checks and metrics
- Database migrations

### Database Service

- PostgreSQL 15 with custom configuration
- Initialization scripts
- Volume persistence
- Backup strategies

### Cache Service

- Redis 7 for session storage and caching
- Configured for optimal performance
- Persistence enabled

### Nginx Service

- Reverse proxy configuration
- SSL termination
- Static file serving
- Load balancing for API services

## Environment Variables

Create `.env` file in the root directory:

```bash
# Database
POSTGRES_DB=fullstack_app
POSTGRES_USER=app_user
POSTGRES_PASSWORD=secure_password
DATABASE_URL=postgresql://app_user:secure_password@db:5432/fullstack_app

# Redis
REDIS_URL=redis://redis:6379/0

# API
API_SECRET_KEY=your-secret-key-here
FLASK_ENV=development

# Frontend
REACT_APP_API_URL=http://localhost:5000
```

## Available Endpoints

### API Endpoints

- `GET /api/health` - Health check
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `GET /api/users/{id}` - Get user by ID
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user

### Frontend URLs

- `http://localhost` - Main application
- `http://localhost/admin` - Admin panel
- `http://localhost/api/*` - API proxy

## Database Schema

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO users (username, email) VALUES
('john_doe', 'john@example.com'),
('jane_smith', 'jane@example.com');
```

## Development Workflow

### 1. Making Changes

```bash
# Frontend changes (hot reload automatically)
# Edit files in frontend/src/

# API changes (restart required)
docker-compose restart api

# Database changes
docker-compose exec db psql -U app_user -d fullstack_app
```

### 2. Running Tests

```bash
# API tests
docker-compose exec api python -m pytest

# Frontend tests
docker-compose exec frontend npm test
```

### 3. Database Management

```bash
# Access database
docker-compose exec db psql -U app_user -d fullstack_app

# Run migrations
docker-compose exec api python manage.py db upgrade

# Create migration
docker-compose exec api python manage.py db migrate -m "Add new table"
```

## Production Deployment

### SSL Configuration

1. Update `nginx/nginx.conf` with your domain
2. Generate SSL certificates using Let's Encrypt
3. Place certificates in `nginx/ssl/`

### Scaling Services

```bash
# Scale API horizontally
docker-compose -f docker-compose.prod.yml up -d --scale api=5

# Monitor resource usage
docker stats
```

### Backup Strategy

```bash
# Database backup
docker-compose exec db pg_dump -U app_user fullstack_app > backup.sql

# Redis backup
docker-compose exec redis redis-cli save
docker cp $(docker-compose ps -q redis):/data/dump.rdb ./redis-backup.rdb
```

## Monitoring

- **Health Checks**: All services have health check endpoints
- **Logs**: Centralized logging via Docker
- **Metrics**: Prometheus metrics available on API service

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Change port mappings in docker-compose.yml
2. **Database Connection**: Verify DATABASE_URL environment variable
3. **Frontend API Calls**: Check REACT_APP_API_URL configuration

### Debug Commands

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs api
docker-compose logs db

# Execute commands in containers
docker-compose exec api bash
docker-compose exec db psql -U app_user

# Inspect networks
docker network ls
docker network inspect lab02_default
```

## Next Steps

- Proceed to Lab 03 for image optimization techniques
- Add authentication and authorization
- Implement real-time features with WebSockets
- Add monitoring and alerting

## Performance Optimization

- Use Redis for session storage
- Implement database connection pooling
- Enable Nginx gzip compression
- Use CDN for static assets
