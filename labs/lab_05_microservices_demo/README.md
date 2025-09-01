# Lab 05: Full Microservices Architecture

**File Location:** `labs/lab_05_microservices_demo/README.md`

## Overview

Complete microservices ecosystem with API Gateway, multiple services, databases, message queues, and distributed tracing.

## Architecture

```
Internet → API Gateway → [User Service, Order Service, Notification Service]
                      ↓
    [PostgreSQL, Redis, MongoDB] ← [RabbitMQ, Kafka]
                      ↓
         [Jaeger Tracing, Prometheus Monitoring]
```

## Services

- **API Gateway**: Nginx reverse proxy with rate limiting
- **User Service**: Python/Flask - User management
- **Order Service**: Go - Order processing
- **Notification Service**: Node.js - Email/SMS notifications
- **Databases**: PostgreSQL, Redis, MongoDB
- **Message Queue**: RabbitMQ + Kafka
- **Monitoring**: Jaeger, Zipkin, Prometheus

## Quick Start

```bash
# Start all services
docker-compose up -d

# Scale services
docker-compose up -d --scale user-service=3 --scale order-service=2

# Test endpoints
curl http://localhost/api/users
curl http://localhost/api/orders
curl http://localhost/api/notifications
```

## Service Endpoints

- **API Gateway**: http://localhost (port 80)
- **User Service**: http://localhost/api/users
- **Order Service**: http://localhost/api/orders
- **Notification Service**: http://localhost/api/notifications
- **Jaeger UI**: http://localhost:16686
- **RabbitMQ Management**: http://localhost:15672

## Key Features

- **Service Discovery**: Automatic service registration
- **Load Balancing**: Multiple instances per service
- **Circuit Breaker**: Fault tolerance patterns
- **Distributed Tracing**: Request flow monitoring
- **Event-Driven**: Async communication via message queues
- **Database Per Service**: Data isolation
- **API Versioning**: Backward compatibility
- **Health Checks**: Service health monitoring

## Microservices Patterns

- API Gateway pattern
- Database per service
- Event sourcing
- CQRS (Command Query Responsibility Segregation)
- Circuit breaker
- Bulkhead isolation
