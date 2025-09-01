# Production Deployment: Blue-Green, Rolling Updates & Health Checks

**Location: `docs/production-deployment.md`**

## Production Deployment Overview

Production Docker deployments require careful planning for zero-downtime updates, health monitoring, scalability, and disaster recovery. This guide covers enterprise-grade deployment strategies.

## Deployment Strategies

### Blue-Green Deployment

```bash
#!/bin/bash
# blue-green-deploy.sh

BLUE_COMPOSE="docker-compose.blue.yml"
GREEN_COMPOSE="docker-compose.green.yml"
NGINX_COMPOSE="docker-compose.nginx.yml"

# Current environment
CURRENT=$(docker-compose -f $NGINX_COMPOSE exec nginx cat /etc/nginx/conf.d/upstream.conf | grep -o 'blue\|green')
NEW=$([ "$CURRENT" = "blue" ] && echo "green" || echo "blue")

echo "Current environment: $CURRENT"
echo "Deploying to: $NEW"

# Deploy to inactive environment
if [ "$NEW" = "green" ]; then
    docker-compose -f $GREEN_COMPOSE up -d --build
    TARGET_HOST="green-app:3000"
else
    docker-compose -f $BLUE_COMPOSE up -d --build
    TARGET_HOST="blue-app:3000"
fi

# Health check new environment
echo "Running health checks..."
for i in {1..30}; do
    if curl -f http://$TARGET_HOST/health; then
        echo "Health check passed"
        break
    fi
    echo "Health check $i failed, retrying..."
    sleep 5
done

# Switch traffic
echo "Switching traffic to $NEW environment"
cat > nginx/upstream.conf << EOF
upstream app_backend {
    server $TARGET_HOST;
}
EOF

docker-compose -f $NGINX_COMPOSE exec nginx nginx -s reload

# Stop old environment
if [ "$NEW" = "green" ]; then
    docker-compose -f $BLUE_COMPOSE down
else
    docker-compose -f $GREEN_COMPOSE down
fi

echo "Deployment complete"
```

### Rolling Updates (Docker Swarm)

```yaml
# production-stack.yml
version: "3.8"
services:
  app:
    image: myapp:${TAG:-latest}
    deploy:
      replicas: 6
      update_config:
        parallelism: 2 # Update 2 containers at a time
        delay: 30s # Wait 30s between batches
        failure_action: rollback
        monitor: 60s # Monitor for 60s after update
        max_failure_ratio: 0.3
        order: start-first # Start new before stopping old
      rollback_config:
        parallelism: 2
        delay: 10s
        failure_action: pause
        monitor: 30s
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
```

```bash
# Deploy rolling update
docker stack deploy -c production-stack.yml myapp

# Monitor rolling update
watch docker service ps myapp_app

# Rollback if needed
docker service rollback myapp_app
```

### Canary Deployment

```yaml
# canary-deployment.yml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    configs:
      - source: nginx_canary_config
        target: /etc/nginx/nginx.conf
    ports:
      - "80:80"

  app-stable:
    image: myapp:stable
    deploy:
      replicas: 8
      labels:
        - "version=stable"

  app-canary:
    image: myapp:canary
    deploy:
      replicas: 2 # 20% traffic
      labels:
        - "version=canary"

configs:
  nginx_canary_config:
    external: true
```

```nginx
# nginx canary configuration
upstream stable {
    server app-stable:3000 weight=8;
}

upstream canary {
    server app-canary:3000 weight=2;
}

upstream backend {
    server app-stable:3000 weight=8;
    server app-canary:3000 weight=2;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

## Health Checks and Monitoring

### Comprehensive Health Checks

```dockerfile
FROM node:16-alpine
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application
COPY . .

# Health check script
COPY healthcheck.js /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.js

# Multi-level health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node /usr/local/bin/healthcheck.js

USER node
CMD ["node", "server.js"]
```

```javascript
// healthcheck.js - Comprehensive health check
const http = require("http");
const dns = require("dns");

async function checkDatabase() {
  // Check database connectivity
  try {
    const result = await db.query("SELECT 1");
    return result ? true : false;
  } catch (error) {
    console.error("Database health check failed:", error);
    return false;
  }
}

async function checkExternalServices() {
  // Check external API dependencies
  return new Promise((resolve) => {
    const req = http.get("http://api.example.com/health", (res) => {
      resolve(res.statusCode === 200);
    });
    req.on("error", () => resolve(false));
    req.setTimeout(5000, () => {
      req.destroy();
      resolve(false);
    });
  });
}

async function checkDNS() {
  return new Promise((resolve) => {
    dns.lookup("google.com", (err) => {
      resolve(!err);
    });
  });
}

async function main() {
  const checks = [
    { name: "database", check: checkDatabase },
    { name: "external_api", check: checkExternalServices },
    { name: "dns", check: checkDNS },
  ];

  let allHealthy = true;

  for (const { name, check } of checks) {
    const healthy = await check();
    console.log(`${name}: ${healthy ? "OK" : "FAIL"}`);
    if (!healthy) allHealthy = false;
  }

  process.exit(allHealthy ? 0 : 1);
}

main().catch(console.error);
```

### External Health Monitoring

```yaml
# monitoring-stack.yml
version: "3.8"
services:
  blackbox-exporter:
    image: prom/blackbox-exporter
    ports:
      - "9115:9115"
    volumes:
      - ./blackbox.yml:/etc/blackbox_exporter/config.yml
    command:
      - "--config.file=/etc/blackbox_exporter/config.yml"

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.retention.time=30d"
```

```yaml
# blackbox.yml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: []
      method: GET
      headers:
        Host: myapp.com
      fail_if_ssl: false
      fail_if_not_ssl: false

  tcp_connect:
    prober: tcp
    timeout: 5s
```

## Load Balancing and High Availability

### Production Nginx Configuration

```nginx
# nginx.conf
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    # Upstream configuration
    upstream app_backend {
        least_conn;
        keepalive 32;
        server app1:3000 max_fails=3 fail_timeout=30s;
        server app2:3000 max_fails=3 fail_timeout=30s;
        server app3:3000 max_fails=3 fail_timeout=30s;
        server app4:3000 max_fails=3 fail_timeout=30s backup;
    }

    # Health check endpoint
    server {
        listen 80;
        server_name health.internal;

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }

    # Main server configuration
    server {
        listen 80;
        server_name myapp.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name myapp.com;

        # SSL configuration
        ssl_certificate /etc/ssl/certs/myapp.crt;
        ssl_certificate_key /etc/ssl/private/myapp.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # API routes with rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;

            proxy_pass http://app_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;

            # Timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            # Health check
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        }

        # Static assets with caching
        location /static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
            gzip_static on;
        }

        # Health check endpoint
        location /health {
            proxy_pass http://app_backend/health;
            access_log off;
        }
    }
}
```

### Traefik Load Balancer

```yaml
# traefik-stack.yml
version: "3.8"
services:
  traefik:
    image: traefik:v2.9
    command:
      - "--api.insecure=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=admin@example.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--metrics.prometheus=true"
      - "--metrics.prometheus.addEntryPointsLabels=true"
      - "--metrics.prometheus.addServicesLabels=true"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "letsencrypt:/letsencrypt"
    deploy:
      placement:
        constraints:
          - node.role == manager
    networks:
      - proxy

  app:
    image: myapp:latest
    deploy:
      replicas: 4
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.app.rule=Host(`myapp.com`)"
        - "traefik.http.routers.app.entrypoints=websecure"
        - "traefik.http.routers.app.tls.certresolver=myresolver"
        - "traefik.http.services.app.loadbalancer.server.port=3000"
        - "traefik.http.services.app.loadbalancer.healthcheck.path=/health"
        - "traefik.http.services.app.loadbalancer.healthcheck.interval=30s"
    networks:
      - proxy
      - app-network

volumes:
  letsencrypt:

networks:
  proxy:
    external: true
  app-network:
    driver: overlay
```

## Configuration Management

### Environment-Specific Configurations

```yaml
# base configuration - docker-compose.yml
version: "3.8"
services:
  app:
    image: myapp:${TAG:-latest}
    environment:
      - NODE_ENV=${NODE_ENV:-production}
      - LOG_LEVEL=${LOG_LEVEL:-info}
    secrets:
      - db_password
      - api_key
    networks:
      - app-network

secrets:
  db_password:
    external: true
  api_key:
    external: true

networks:
  app-network:
    external: true

---
# production overrides - docker-compose.prod.yml
version: "3.8"
services:
  app:
    deploy:
      replicas: 4
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
        reservations:
          memory: 256M
          cpus: "0.5"
      restart_policy:
        condition: on-failure
        max_attempts: 3
        window: 120s
      update_config:
        parallelism: 1
        delay: 30s
        failure_action: rollback
        monitor: 60s
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

---
# staging overrides - docker-compose.staging.yml
version: "3.8"
services:
  app:
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 256M
          cpus: "0.5"
    environment:
      - LOG_LEVEL=debug
      - ENABLE_PROFILING=true
```

### Secret Management

```bash
#!/bin/bash
# setup-secrets.sh

# Database secrets
echo "postgres://user:$(openssl rand -base64 32)@db:5432/myapp" | docker secret create db_url -

# API keys
kubectl get secret api-keys -o jsonpath='{.data.api-key}' | base64 -d | docker secret create api_key -

# SSL certificates
docker secret create ssl_cert /etc/ssl/certs/myapp.crt
docker secret create ssl_key /etc/ssl/private/myapp.key

# JWT signing key
openssl rand -base64 64 | docker secret create jwt_secret -
```

## Backup and Disaster Recovery

### Automated Backup Strategy

```bash
#!/bin/bash
# backup.sh - Production backup script

BACKUP_DIR="/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Starting backup at $(date)"

# Database backup
docker exec postgres pg_dump -U postgres myapp | gzip > "$BACKUP_DIR/database.sql.gz"

# Volume backups
docker run --rm \
    -v myapp_data:/data \
    -v "$BACKUP_DIR":/backup \
    busybox tar czf /backup/app_data.tar.gz -C /data .

# Configuration backup
cp -r /opt/myapp/config "$BACKUP_DIR/"
docker config ls --format "{{.Name}}" | xargs -I {} docker config inspect {} > "$BACKUP_DIR/docker_configs.json"
docker secret ls --format "{{.Name}}" > "$BACKUP_DIR/secrets_list.txt"

# Upload to S3 (optional)
aws s3 cp "$BACKUP_DIR" s3://myapp-backups/$(basename "$BACKUP_DIR")/ --recursive

# Cleanup old backups (keep 30 days)
find /backups -type d -mtime +30 -exec rm -rf {} \;

echo "Backup completed at $(date)"
```

### Disaster Recovery Plan

```bash
#!/bin/bash
# disaster-recovery.sh

BACKUP_DATE=$1
BACKUP_DIR="/backups/$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

echo "Starting disaster recovery from backup: $BACKUP_DATE"

# Stop all services
docker stack rm myapp
sleep 30

# Restore database
zcat "$BACKUP_DIR/database.sql.gz" | docker exec -i postgres psql -U postgres myapp

# Restore volumes
docker run --rm \
    -v myapp_data:/data \
    -v "$BACKUP_DIR":/backup \
    busybox tar xzf /backup/app_data.tar.gz -C /data

# Restore configurations
docker config create --label restored=true nginx_config "$BACKUP_DIR/config/nginx.conf"

# Redeploy stack
docker stack deploy -c docker-compose.prod.yml myapp

# Verify recovery
sleep 60
curl -f http://myapp.com/health || echo "Health check failed - manual intervention required"

echo "Disaster recovery completed"
```

## Monitoring and Alerting

### Production Monitoring Stack

```yaml
# monitoring-production.yml
version: "3.8"
services:
  prometheus:
    image: prom/prometheus:latest
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.console.libraries=/etc/prometheus/console_libraries"
      - "--web.console.templates=/etc/prometheus/consoles"
      - "--storage.tsdb.retention.time=30d"
      - "--web.enable-lifecycle"
      - "--web.enable-admin-api"
    volumes:
      - prometheus_data:/prometheus
      - ./prometheus:/etc/prometheus
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.monitoring == true
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_password
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SMTP_ENABLED=true
      - GF_SMTP_HOST=smtp.company.com:587
      - GF_SMTP_FROM_ADDRESS=alerts@company.com
    secrets:
      - grafana_password
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    deploy:
      replicas: 1
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yml"
      - "--storage.path=/alertmanager"
      - "--web.external-url=https://alerts.company.com"
      - "--cluster.advertise-address=0.0.0.0:9093"
    volumes:
      - alertmanager_data:/alertmanager
      - ./alertmanager:/etc/alertmanager
    deploy:
      replicas: 3
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    external: true

secrets:
  grafana_password:
    external: true
```

### Critical Alerts Configuration

```yaml
# prometheus/alerts.yml
groups:
  - name: production
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} requests per second"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container memory usage is high"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      - alert: ServiceDown
        expr: up{job="myapp"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"

      - alert: DiskSpaceHigh
        expr: (node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space usage is high"
          description: "Disk usage is {{ $value | humanizePercentage }}"
```

## Security in Production

### Production Security Hardening

```yaml
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 4
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
      - /var/run:noexec,nosuid,size=50m
    sysctls:
      - net.core.somaxconn=1024
    ulimits:
      nproc: 65535
      nofile:
        soft: 65535
        hard: 65535
```

### Network Security

```bash
# Production firewall rules
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH access
ufw allow 22/tcp

# HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Docker Swarm (internal network only)
ufw allow from 10.0.0.0/8 to any port 2377 proto tcp
ufw allow from 10.0.0.0/8 to any port 7946
ufw allow from 10.0.0.0/8 to any port 4789 proto udp

# Monitoring (internal only)
ufw allow from 10.0.0.0/8 to any port 9090,3000,9093

ufw --force enable
```

## Best Practices Checklist

### Pre-Deployment

```
□ Health checks implemented
□ Resource limits defined
□ Security scanning completed
□ Load testing performed
□ Backup strategy validated
□ Monitoring configured
□ Secrets properly managed
□ SSL certificates valid
□ DNS configuration updated
□ Rollback plan prepared
```

### Deployment Process

```
□ Blue-green or rolling update strategy
□ Database migrations applied
□ Configuration updates deployed
□ Health checks passing
□ Monitoring alerts configured
□ Performance metrics baseline
□ Security scans passed
□ Documentation updated
```

### Post-Deployment

```
□ Health monitoring active
□ Performance metrics normal
□ Error rates acceptable
□ User feedback positive
□ Logs aggregated properly
□ Backup verification
□ Security monitoring active
□ Team notification sent
```

## Next Steps

- Learn [Cost Optimization](./cost-optimization.md) for efficient resource usage
- Explore [Migration Strategies](./migration-strategies.md) for platform transitions
- Check [Docker Ecosystem](./docker-ecosystem.md) for production tools
- Understand [Troubleshooting](./troubleshooting.md) for production issues
