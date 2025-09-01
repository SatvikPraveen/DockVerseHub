# Docker Compose Common Patterns

**Location: `docs/quick-reference/compose-patterns.md`**

## Web Application Stack

### LAMP Stack

```yaml
version: "3.8"
services:
  web:
    image: httpd:2.4-alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/local/apache2/htdocs/
      - ./apache2.conf:/usr/local/apache2/conf/httpd.conf
    depends_on:
      - php

  php:
    image: php:8.1-fpm-alpine
    volumes:
      - ./html:/var/www/html
    depends_on:
      - mysql

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: webapp
      MYSQL_USER: webuser
      MYSQL_PASSWORD: webpass
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

### MEAN Stack

```yaml
version: "3.8"
services:
  angular:
    build: ./frontend
    ports:
      - "4200:4200"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    depends_on:
      - api

  api:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: development
      MONGODB_URI: mongodb://mongo:27017/meanapp
    volumes:
      - ./backend:/app
      - /app/node_modules
    depends_on:
      - mongo

  mongo:
    image: mongo:5.0
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

volumes:
  mongo_data:
```

### Django + PostgreSQL

```yaml
version: "3.8"
services:
  web:
    build: .
    command: python manage.py runserver 0.0.0.0:8000
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      DEBUG: 1
      DATABASE_URL: postgresql://postgres:postgres@db:5432/django_db
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: django_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  celery:
    build: .
    command: celery -A myproject worker -l info
    volumes:
      - .:/app
    environment:
      DATABASE_URL: postgresql://postgres:postgres@db:5432/django_db
      CELERY_BROKER_URL: redis://redis:6379
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
```

## Microservices Patterns

### API Gateway + Services

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - user-service
      - order-service
    networks:
      - frontend

  user-service:
    build: ./user-service
    environment:
      DATABASE_URL: postgresql://postgres:postgres@user-db:5432/users
    networks:
      - frontend
      - backend
    depends_on:
      - user-db

  order-service:
    build: ./order-service
    environment:
      DATABASE_URL: postgresql://postgres:postgres@order-db:5432/orders
      USER_SERVICE_URL: http://user-service:3000
    networks:
      - frontend
      - backend
    depends_on:
      - order-db

  user-db:
    image: postgres:13
    environment:
      POSTGRES_DB: users
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - user_db_data:/var/lib/postgresql/data
    networks:
      - backend

  order-db:
    image: postgres:13
    environment:
      POSTGRES_DB: orders
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - order_db_data:/var/lib/postgresql/data
    networks:
      - backend

networks:
  frontend:
  backend:
    internal: true

volumes:
  user_db_data:
  order_db_data:
```

### Event-Driven Architecture

```yaml
version: "3.8"
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.2.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.2.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
    depends_on:
      - zookeeper

  producer-service:
    build: ./producer
    environment:
      KAFKA_BROKERS: kafka:29092
    depends_on:
      - kafka

  consumer-service:
    build: ./consumer
    environment:
      KAFKA_BROKERS: kafka:29092
      DATABASE_URL: postgresql://postgres:postgres@db:5432/events
    depends_on:
      - kafka
      - db

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: events
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - event_data:/var/lib/postgresql/data

volumes:
  event_data:
```

## Development Patterns

### Multi-Environment Configuration

```yaml
version: "3.8"
services:
  app:
    build:
      context: .
      target: ${BUILD_TARGET:-development}
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      NODE_ENV: ${NODE_ENV:-development}
      LOG_LEVEL: ${LOG_LEVEL:-debug}
    volumes:
      - .:/app
      - /app/node_modules
    profiles:
      - dev
      - staging

  app-prod:
    build:
      context: .
      target: production
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      LOG_LEVEL: info
    profiles:
      - prod

  database:
    image: postgres:13
    environment:
      POSTGRES_DB: ${DB_NAME:-myapp}
      POSTGRES_USER: ${DB_USER:-developer}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-devpass}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

### Testing Environment

```yaml
version: "3.8"
services:
  app:
    build: .
    environment:
      NODE_ENV: test
      DATABASE_URL: postgresql://postgres:testpass@test-db:5432/testdb
    depends_on:
      test-db:
        condition: service_healthy

  test-db:
    image: postgres:13
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: testpass
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  test-runner:
    build: .
    command: npm test
    environment:
      NODE_ENV: test
      DATABASE_URL: postgresql://postgres:testpass@test-db:5432/testdb
    depends_on:
      test-db:
        condition: service_healthy
    profiles:
      - test
```

## Monitoring and Logging

### ELK Stack

```yaml
version: "3.8"
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      discovery.type: single-node
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
      xpack.security.enabled: false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    ports:
      - "5000:5000/tcp"
      - "5000:5000/udp"
    environment:
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"
    volumes:
      - ./logstash/config:/usr/share/logstash/config
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch

  app:
    build: .
    logging:
      driver: "gelf"
      options:
        gelf-address: "udp://localhost:5000"
        tag: "myapp"
    depends_on:
      - logstash

volumes:
  elasticsearch_data:
```

### Prometheus + Grafana

```yaml
version: "3.8"
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=30d"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin123
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.rootfs=/rootfs"
      - "--path.sysfs=/host/sys"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

volumes:
  prometheus_data:
  grafana_data:
```

## Development Tools

### Code Quality Stack

```yaml
version: "3.8"
services:
  sonarqube:
    image: sonarqube:community
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonar-db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    depends_on:
      - sonar-db

  sonar-db:
    image: postgres:13
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonar_postgresql:/var/lib/postgresql/data

  app:
    build: .
    volumes:
      - .:/app
      - /app/node_modules
    profiles:
      - dev

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  sonar_postgresql:
```

### CI/CD Pipeline

```yaml
version: "3.8"
services:
  jenkins:
    image: jenkins/jenkins:lts
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      JAVA_OPTS: "-Djenkins.install.runSetupWizard=false"

  nexus:
    image: sonatype/nexus3:latest
    ports:
      - "8081:8081"
    volumes:
      - nexus_data:/nexus-data

  registry:
    image: registry:2
    ports:
      - "5000:5000"
    volumes:
      - registry_data:/var/lib/registry

volumes:
  jenkins_data:
  nexus_data:
  registry_data:
```

## Production Patterns

### Load Balanced Web App

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app

  app:
    build: .
    deploy:
      replicas: 3
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://postgres:postgres@db:5432/production
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      placement:
        constraints:
          - node.role == manager

  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### High Availability Setup

```yaml
version: "3.8"
services:
  haproxy:
    image: haproxy:alpine
    ports:
      - "80:80"
      - "8404:8404" # Stats
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - app

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db-primary:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_REPLICATION_MODE: master
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: ${REPL_PASSWORD}
    volumes:
      - db_primary_data:/var/lib/postgresql/data

  db-replica:
    image: postgres:13
    environment:
      PGUSER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_MASTER_SERVICE: db-primary
      POSTGRES_REPLICATION_MODE: slave
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: ${REPL_PASSWORD}
    volumes:
      - db_replica_data:/var/lib/postgresql/data
    depends_on:
      - db-primary

volumes:
  db_primary_data:
  db_replica_data:
```

## Override Patterns

### Environment-Specific Overrides

```yaml
# docker-compose.override.yml (development)
version: "3.8"
services:
  app:
    build:
      target: development
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - DEBUG=true
    ports:
      - "3000:3000"
      - "9229:9229" # Debug port

  db:
    ports:
      - "5432:5432" # Expose for local tools
```

```yaml
# docker-compose.prod.yml (production)
version: "3.8"
services:
  app:
    image: myapp:${TAG:-latest}
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]

  db:
    deploy:
      placement:
        constraints:
          - node.labels.database == true
    command: postgres -c max_connections=200
```

## Common Use Cases

### Development with Hot Reload

```yaml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - ./frontend/src:/app/src
      - ./frontend/public:/app/public
    environment:
      - CHOKIDAR_USEPOLLING=true

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
```

### Multi-Stage Testing

```yaml
version: "3.8"
services:
  test-unit:
    build: .
    command: npm run test:unit
    environment:
      NODE_ENV: test
    profiles:
      - test

  test-integration:
    build: .
    command: npm run test:integration
    environment:
      NODE_ENV: test
      DATABASE_URL: postgresql://postgres:testpass@test-db:5432/integration
    depends_on:
      - test-db
    profiles:
      - test

  test-e2e:
    build: .
    command: npm run test:e2e
    environment:
      NODE_ENV: test
      BASE_URL: http://app:3000
    depends_on:
      - app
    profiles:
      - test
```

### Secret Management

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    external: true
  api_key:
    file: ./secrets/api_key.txt
```

This reference provides battle-tested patterns for common Docker Compose scenarios.
