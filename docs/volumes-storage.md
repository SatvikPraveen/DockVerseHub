# Docker Volumes & Storage: Persistence, Bind Mounts & tmpfs

**Location: `docs/volumes-storage.md`**

## Storage Overview

Docker containers are ephemeral by design - data is lost when containers are removed. Docker provides three storage mechanisms to persist data beyond container lifecycle:

1. **Volumes** (Recommended)
2. **Bind Mounts**
3. **tmpfs Mounts**

## Storage Types Comparison

| Feature         | Volumes        | Bind Mounts     | tmpfs          |
| --------------- | -------------- | --------------- | -------------- |
| **Location**    | Docker-managed | Host filesystem | Host memory    |
| **Performance** | Optimized      | Native          | Fastest        |
| **Portability** | High           | Low             | N/A            |
| **Management**  | Docker CLI     | Manual          | Automatic      |
| **Backup**      | Docker tools   | Host tools      | No persistence |
| **Security**    | Isolated       | Host access     | Memory only    |

## Docker Volumes

### Volume Advantages

- **Docker-managed**: Automatic creation and cleanup
- **Platform-independent**: Work across different OS
- **Better performance**: Optimized for containers
- **Easy backup/restore**: Built-in tools available
- **Secure**: Isolated from host filesystem

### Volume Operations

```bash
# List volumes
docker volume ls

# Create named volume
docker volume create mydata

# Inspect volume details
docker volume inspect mydata

# Remove volume
docker volume rm mydata

# Clean up unused volumes
docker volume prune
```

### Using Volumes

```bash
# Named volume
docker run -v mydata:/app/data nginx

# Anonymous volume (Docker generates name)
docker run -v /app/data nginx

# Multiple volumes
docker run -v logs:/var/log -v config:/etc/app nginx

# Read-only volume
docker run -v config:/etc/app:ro nginx
```

### Volume Drivers

```bash
# Local driver (default)
docker volume create --driver local myvolume

# Custom driver options
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.100,rw \
  --opt device=:/path/to/dir \
  nfsvolume
```

## Bind Mounts

### When to Use Bind Mounts

- **Development**: Live code reloading
- **Configuration**: Host-specific config files
- **Host integration**: Access host services
- **Legacy applications**: Existing file structure dependencies

### Bind Mount Syntax

```bash
# Full path required
docker run -v /host/path:/container/path nginx

# Current directory
docker run -v $(pwd):/app node:alpine

# Windows (PowerShell)
docker run -v ${PWD}:/app node:alpine

# Read-only bind mount
docker run -v /host/config:/app/config:ro nginx
```

### Bind Mount Examples

```bash
# Development setup
docker run -d \
  -v $(pwd)/src:/app/src \
  -v $(pwd)/config:/app/config \
  -p 3000:3000 \
  --name dev-app \
  node-app

# Log monitoring
docker run -d \
  -v /var/log:/host/logs:ro \
  --name log-monitor \
  log-analyzer

# Docker socket access (Docker-in-Docker)
docker run -v /var/run/docker.sock:/var/run/docker.sock docker:dind
```

## tmpfs Mounts

### Use Cases

- **Sensitive data**: Passwords, keys, temporary tokens
- **High-performance I/O**: Fast temporary processing
- **Cache**: Memory-based caching layer
- **Security**: Data never touches disk

### tmpfs Examples

```bash
# Basic tmpfs mount
docker run --tmpfs /app/temp nginx

# Tmpfs with size limit
docker run --tmpfs /app/cache:size=100m,uid=1000 myapp

# Multiple tmpfs mounts
docker run \
  --tmpfs /app/temp:size=50m \
  --tmpfs /app/cache:size=100m \
  myapp
```

## Docker Compose Storage

### Volume Configuration

```yaml
version: "3.8"
services:
  web:
    image: nginx
    volumes:
      - web-data:/var/www/html
      - ./config:/etc/nginx/conf.d:ro
      - /var/log/nginx:/var/log/nginx
    tmpfs:
      - /app/temp:size=100m

  db:
    image: postgres
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp

volumes:
  web-data:
    driver: local
  db-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/database
```

### External Volumes

```yaml
version: "3.8"
services:
  app:
    image: myapp
    volumes:
      - existing-volume:/app/data

volumes:
  existing-volume:
    external: true
```

## Data Persistence Patterns

### Database Persistence

```bash
# PostgreSQL
docker run -d \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=myapp \
  --name postgres \
  postgres:13

# MySQL
docker run -d \
  -v mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=secret \
  --name mysql \
  mysql:8.0

# MongoDB
docker run -d \
  -v mongo-data:/data/db \
  --name mongodb \
  mongo:latest
```

### Application Data

```yaml
version: "3.8"
services:
  app:
    build: .
    volumes:
      - app-uploads:/app/uploads
      - app-logs:/app/logs
      - ./config:/app/config:ro
    depends_on:
      - database

  database:
    image: postgres
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp

volumes:
  app-uploads:
  app-logs:
  db-data:
```

## Backup and Restore

### Volume Backup

```bash
# Backup volume to tar file
docker run --rm \
  -v mydata:/data \
  -v $(pwd):/backup \
  busybox tar czf /backup/backup.tar.gz -C /data .

# Automated backup script
#!/bin/bash
VOLUME_NAME="mydata"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

docker run --rm \
  -v ${VOLUME_NAME}:/data:ro \
  -v ${BACKUP_DIR}:/backup \
  busybox tar czf /backup/${VOLUME_NAME}_${DATE}.tar.gz -C /data .
```

### Volume Restore

```bash
# Restore from backup
docker run --rm \
  -v mydata:/data \
  -v $(pwd):/backup \
  busybox tar xzf /backup/backup.tar.gz -C /data

# Create and restore new volume
docker volume create restored-data
docker run --rm \
  -v restored-data:/data \
  -v $(pwd):/backup \
  busybox tar xzf /backup/backup.tar.gz -C /data
```

### Database Backup

```bash
# PostgreSQL backup
docker exec postgres pg_dump -U postgres mydb > backup.sql

# PostgreSQL restore
cat backup.sql | docker exec -i postgres psql -U postgres mydb

# MySQL backup
docker exec mysql mysqldump -u root -psecret mydb > backup.sql

# MySQL restore
cat backup.sql | docker exec -i mysql mysql -u root -psecret mydb
```

## Performance Considerations

### Volume Performance

```bash
# Benchmark volume performance
docker run --rm \
  -v test-volume:/data \
  ubuntu:20.04 \
  dd if=/dev/zero of=/data/test bs=1M count=100 oflag=direct
```

### Storage Drivers

Different storage drivers offer varying performance characteristics:

- **overlay2**: Default, good performance
- **aufs**: Legacy, slower than overlay2
- **devicemapper**: Block-level, good for CentOS/RHEL
- **btrfs**: Advanced features, requires btrfs filesystem
- **zfs**: Enterprise features, requires ZFS filesystem

### Performance Tips

1. **Use volumes over bind mounts** for better performance
2. **Avoid storing logs in containers** - use log drivers
3. **Use tmpfs for temporary data** requiring high I/O
4. **Consider SSD storage** for volume backends
5. **Monitor disk usage** regularly

## Security Best Practices

### Volume Security

```bash
# Run container as non-root user
docker run -u 1000:1000 -v mydata:/app/data myapp

# Read-only volumes where possible
docker run -v config:/app/config:ro myapp

# Restrict bind mount access
docker run -v /host/safe:/container/path:ro,nosuid,nodev myapp
```

### SELinux Context

```bash
# SELinux labeling for bind mounts
docker run -v /host/path:/container/path:Z myapp  # Private label
docker run -v /host/path:/container/path:z myapp  # Shared label
```

## Troubleshooting

### Common Issues

```bash
# Permission denied errors
docker exec -it CONTAINER ls -la /path/to/volume

# Check volume mount points
docker inspect CONTAINER | grep -A 10 "Mounts"

# Volume size and usage
docker system df -v

# Clean up orphaned volumes
docker volume prune
```

### Debugging Commands

```bash
# Find which containers use a volume
docker ps -a --filter volume=VOLUME_NAME

# Check volume contents
docker run --rm -v VOLUME_NAME:/data busybox ls -la /data

# Volume disk usage
docker run --rm -v VOLUME_NAME:/data busybox du -sh /data
```

## Advanced Patterns

### Multi-Container Data Sharing

```yaml
version: "3.8"
services:
  producer:
    image: data-producer
    volumes:
      - shared-data:/app/output

  consumer:
    image: data-consumer
    volumes:
      - shared-data:/app/input
    depends_on:
      - producer

  processor:
    image: data-processor
    volumes:
      - shared-data:/app/data

volumes:
  shared-data:
```

### Data Containers (Legacy Pattern)

```bash
# Create data-only container
docker create -v /data --name datastore busybox

# Use data container volumes
docker run --volumes-from datastore myapp
```

### Volume Plugins

```bash
# Install volume plugin
docker plugin install store/plugin:latest

# Create volume with plugin
docker volume create -d plugin-name myvolume

# Use plugin volume
docker run -v myvolume:/data myapp
```

## Monitoring and Maintenance

### Volume Monitoring

```bash
# Monitor volume usage
#!/bin/bash
docker system df -v | grep -E "(VOLUME|Local)"

# Alert on volume size
VOLUME_USAGE=$(docker system df | grep "Local Volumes" | awk '{print $4}')
if [[ "${VOLUME_USAGE%?}" -gt 80 ]]; then
    echo "Warning: Volume usage above 80%"
fi
```

### Cleanup Strategies

```bash
# Remove unused volumes
docker volume prune

# Remove volumes with specific pattern
docker volume ls | grep "old_" | awk '{print $2}' | xargs docker volume rm

# Automated cleanup script
#!/bin/bash
# Remove volumes older than 30 days
docker volume ls | grep -v "VOLUME NAME" | while read volume; do
    created=$(docker volume inspect $volume | grep '"CreatedAt"' | cut -d'"' -f4)
    if [[ $(date -d "$created" +%s) -lt $(date -d "30 days ago" +%s) ]]; then
        docker volume rm $volume
    fi
done
```

## Best Practices Summary

### Production Guidelines

1. **Always use named volumes** for important data
2. **Implement regular backups** for all persistent data
3. **Monitor volume usage** and set up alerts
4. **Use appropriate storage drivers** for your platform
5. **Document volume purposes** and dependencies
6. **Test backup/restore procedures** regularly
7. **Consider external storage solutions** for critical data
8. **Implement access controls** for sensitive data

### Development Tips

1. **Use bind mounts** for code during development
2. **Use volumes** for databases and generated data
3. **Use tmpfs** for temporary files and caches
4. **Clean up unused volumes** regularly
5. **Use Docker Compose** for managing complex volume setups

## Next Steps

- Learn about [Docker Compose](./docker-compose.md) for orchestrating multi-container applications
- Explore [Security Best Practices](./security-best-practices.md) for securing your data
- Check [Monitoring and Logging](./monitoring-logging.md) for observability
- Understand [Production Deployment](./production-deployment.md) strategies
