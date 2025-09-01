# Port Conflicts Troubleshooting

**File Location:** `concepts/04_networking/troubleshooting/port-conflicts.md`

## Common Port Conflict Issues

Port conflicts occur when multiple services try to bind to the same port on the host system.

## Identifying Port Conflicts

### Check What's Using a Port

```bash
# Linux/macOS
netstat -tulpn | grep :8080
lsof -i :8080

# Windows
netstat -ano | findstr :8080

# Docker specific
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### Find Available Ports

```bash
# Check port availability
nc -z localhost 8080 && echo "Port in use" || echo "Port available"

# Find next available port
for port in {8080..8090}; do
  nc -z localhost $port || (echo "Port $port is available"; break)
done
```

## Common Scenarios

### Scenario 1: Docker Container Port Already in Use

**Error:**

```
docker: Error response from daemon: driver failed programming external connectivity on endpoint web (abc123): Bind for 0.0.0.0:8080 failed: port is already allocated.
```

**Solutions:**

1. **Use Different Port:**

```bash
# Change host port
docker run -p 8081:80 nginx
```

2. **Stop Conflicting Service:**

```bash
# Find process using port
sudo lsof -i :8080
sudo kill <PID>

# Then restart container
docker run -p 8080:80 nginx
```

3. **Use Random Port:**

```bash
# Let Docker assign random port
docker run -P nginx
docker port <container_name>
```

### Scenario 2: Multiple Containers Same Port

**Problem:**

```bash
docker run -d -p 8080:80 --name web1 nginx
docker run -d -p 8080:80 --name web2 nginx  # This fails
```

**Solutions:**

1. **Use Different Host Ports:**

```bash
docker run -d -p 8080:80 --name web1 nginx
docker run -d -p 8081:80 --name web2 nginx
```

2. **Use Load Balancer:**

```yaml
version: "3.8"
services:
  nginx-lb:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web1
      - web2

  web1:
    image: nginx:alpine
    # No port mapping - internal only

  web2:
    image: nginx:alpine
    # No port mapping - internal only
```

### Scenario 3: Host Service Conflicts

**Common Conflicting Services:**

- Apache/Nginx on port 80
- Development servers on 3000, 8000, 8080
- Database services (MySQL: 3306, PostgreSQL: 5432)

**Solutions:**

1. **Stop Host Service:**

```bash
# Ubuntu/Debian
sudo systemctl stop apache2
sudo systemctl stop nginx

# macOS
sudo brew services stop nginx

# Windows
net stop "Apache2.4"
```

2. **Change Container Port:**

```bash
# Use non-conflicting port
docker run -p 8080:80 nginx  # Instead of 80:80
```

3. **Bind to Specific Interface:**

```bash
# Bind only to localhost
docker run -p 127.0.0.1:80:80 nginx

# Bind to specific IP
docker run -p 192.168.1.100:80:80 nginx
```

## Docker Compose Port Conflicts

### Problem Configuration:

```yaml
version: "3.8"
services:
  web1:
    image: nginx
    ports:
      - "8080:80"

  web2:
    image: nginx
    ports:
      - "8080:80" # Conflict!
```

### Solutions:

1. **Use Different Ports:**

```yaml
version: "3.8"
services:
  web1:
    image: nginx
    ports:
      - "8080:80"

  web2:
    image: nginx
    ports:
      - "8081:80"
```

2. **Use Profiles:**

```yaml
version: "3.8"
services:
  web1:
    image: nginx
    ports:
      - "8080:80"
    profiles: ["dev"]

  web2:
    image: nginx
    ports:
      - "8080:80"
    profiles: ["prod"]
```

3. **Scale with Dynamic Ports:**

```yaml
version: "3.8"
services:
  web:
    image: nginx
    ports:
      - "8080-8085:80" # Range of ports
```

## Prevention Strategies

### 1. Port Management Policy

```bash
# Document port assignments
# Development: 3000-3099
# Web services: 8000-8099
# Databases: 5000-5099
# Monitoring: 9000-9099
```

### 2. Environment-Specific Ports

```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    image: nginx
    ports:
      - "${WEB_PORT:-8080}:80"

# .env.development
WEB_PORT=8080

# .env.production
WEB_PORT=80
```

### 3. Dynamic Port Assignment

```bash
# Use Docker's dynamic port assignment
docker run -P nginx

# Get assigned port
docker port <container> 80
```

## Advanced Solutions

### Using nginx as Reverse Proxy

```nginx
# /etc/nginx/sites-available/docker-proxy
server {
    listen 80;
    server_name app1.local;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}

server {
    listen 80;
    server_name app2.local;

    location / {
        proxy_pass http://127.0.0.1:8081;
    }
}
```

### Using Traefik for Dynamic Routing

```yaml
version: "3.8"
services:
  traefik:
    image: traefik:v2.9
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  web1:
    image: nginx
    labels:
      - "traefik.http.routers.web1.rule=Host(`web1.local`)"
    # No port mapping needed

  web2:
    image: nginx
    labels:
      - "traefik.http.routers.web2.rule=Host(`web2.local`)"
    # No port mapping needed
```

## Debugging Scripts

### Port Conflict Checker

```bash
#!/bin/bash
# check-ports.sh

PORTS=(80 443 3000 5432 3306 6379 9090)

echo "Checking common ports for conflicts..."

for port in "${PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null; then
        echo "Port $port: IN USE"
        lsof -Pi :$port -sTCP:LISTEN
    else
        echo "Port $port: AVAILABLE"
    fi
    echo ""
done
```

### Container Port Mapper

```bash
#!/bin/bash
# map-container-ports.sh

echo "Container Port Mappings:"
echo "========================"

for container in $(docker ps --format "{{.Names}}"); do
    echo "Container: $container"
    docker port "$container" 2>/dev/null || echo "  No port mappings"
    echo ""
done
```

## Best Practices

1. **Use non-privileged ports** (>1024) for development
2. **Document port assignments** in your project README
3. **Use environment variables** for port configuration
4. **Implement health checks** on custom ports
5. **Use reverse proxies** for complex routing needs
6. **Reserve port ranges** for different environments
7. **Monitor port usage** in production environments

These strategies will help you avoid and resolve port conflicts in Docker deployments.
