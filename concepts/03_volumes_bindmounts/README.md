# Docker Volumes and Bind Mounts

**File Location:** `concepts/03_volumes_bindmounts/README.md`

## Understanding Docker Storage

Containers are ephemeral by design - when removed, all data inside is lost. Docker provides several mechanisms to persist data beyond container lifecycle.

## Storage Types

### 1. Volumes (Recommended)

- Managed by Docker
- Stored in Docker's area (`/var/lib/docker/volumes/`)
- Work on all platforms
- Can be shared between containers

### 2. Bind Mounts

- Mount host filesystem directly
- Full control over host path
- Platform dependent
- Direct access to host files

### 3. tmpfs Mounts (Linux)

- Stored in host memory
- Never written to filesystem
- Temporary data only

## Volume Operations

```bash
# Create named volume
docker volume create my-data

# List volumes
docker volume ls

# Inspect volume
docker volume inspect my-data

# Remove volume
docker volume rm my-data
```

## Using Volumes

### Named Volumes

```bash
# Create and use named volume
docker run -d -v data-vol:/app/data nginx:latest

# Share volume between containers
docker run -d -v shared-data:/data alpine:latest
docker run -d -v shared-data:/data ubuntu:latest
```

### Anonymous Volumes

```bash
# Docker creates and manages volume
docker run -d -v /app/data nginx:latest
```

## Using Bind Mounts

```bash
# Mount host directory
docker run -d -v /host/path:/container/path nginx:latest

# Mount current directory
docker run -d -v $(pwd):/app node:latest

# Read-only mount
docker run -d -v /host/data:/app/data:ro nginx:latest
```

## tmpfs Mounts

```bash
# Linux only - memory storage
docker run -d --tmpfs /app/temp nginx:latest

# With size limit
docker run -d --tmpfs /app/temp:noexec,nosuid,size=100m nginx:latest
```

## Volume Drivers

Docker supports various volume drivers:

- **local**: Default driver (host filesystem)
- **nfs**: Network file system
- **s3fs**: Amazon S3 storage
- **cifs**: Windows shares
- **glusterfs**: Distributed storage

```bash
# Use specific driver
docker volume create --driver local \
    --opt type=nfs \
    --opt o=addr=192.168.1.1,rw \
    --opt device=:/path/to/dir \
    nfs-volume
```

## Data Persistence Patterns

### Database Persistence

```bash
# PostgreSQL with named volume
docker run -d \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:13
```

### Application Logs

```bash
# Application with log persistence
docker run -d \
  -v app-logs:/app/logs \
  myapp:latest
```

### Configuration Files

```bash
# Bind mount configuration
docker run -d \
  -v /host/config:/app/config:ro \
  myapp:latest
```

## Backup and Restore

### Volume Backup

```bash
# Backup volume to tar file
docker run --rm \
  -v my-volume:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz -C /data .
```

### Volume Restore

```bash
# Restore from tar file
docker run --rm \
  -v my-volume:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/backup.tar.gz -C /data
```

## Performance Considerations

### Volume Performance

- **Named volumes**: Best performance
- **Bind mounts**: Good performance (direct access)
- **tmpfs**: Fastest (memory-based)

### Platform Differences

- **Linux**: All storage types perform well
- **macOS/Windows**: Volume performance better than bind mounts
- **WSL2**: Volumes in Linux filesystem perform best

## Security Considerations

### File Permissions

```bash
# Set ownership in Dockerfile
USER 1000:1000
VOLUME /app/data

# Or fix permissions at runtime
docker run --user 1000:1000 -v data:/app/data myapp
```

### Read-Only Mounts

```bash
# Prevent accidental writes
docker run -v /config:/app/config:ro myapp
```

## Common Use Cases

### Development Environment

```bash
# Live code reloading
docker run -d \
  -v $(pwd)/src:/app/src \
  -p 3000:3000 \
  node:latest npm run dev
```

### Database Development

```bash
# Persistent database for development
docker run -d \
  --name dev-db \
  -v dev-postgres:/var/lib/postgresql/data \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=dev \
  postgres:13
```

### Log Aggregation

```bash
# Centralized logging
docker run -d \
  -v /var/log:/host-logs:ro \
  -v log-data:/app/logs \
  logstash:latest
```

## Troubleshooting

### Permission Issues

```bash
# Check volume ownership
docker run --rm -v my-volume:/data alpine ls -la /data

# Fix permissions
docker run --rm -v my-volume:/data alpine chown -R 1000:1000 /data
```

### Volume Not Mounting

```bash
# Verify volume exists
docker volume ls

# Check mount points
docker inspect container-name | grep -A 10 "Mounts"
```

### Performance Issues

```bash
# Check volume driver
docker volume inspect my-volume

# Monitor I/O
docker stats --format "table {{.Container}}\t{{.BlockIO}}"
```

## Files in This Directory

- `Dockerfile` - Demo app persisting logs
- `docker-compose.yml` - Named volumes + bind mounts example
- `volume_demo.md` - Data persistence walkthrough
- `backup-restore/` - Data backup strategies
- `performance/` - Volume performance comparison

## Key Takeaways

1. Use **named volumes** for persistent data
2. Use **bind mounts** for development and configuration
3. Use **tmpfs** for temporary, sensitive data
4. Always backup important data
5. Consider permissions and security
6. Performance varies by platform and storage type

Ready to make your containers stateful? Explore the practical examples!
