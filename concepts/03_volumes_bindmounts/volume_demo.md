# Volume Demo - Data Persistence Walkthrough

**File Location:** `concepts/03_volumes_bindmounts/volume_demo.md`

## Demo Overview

This walkthrough demonstrates different storage mechanisms in Docker and shows how data persists across container restarts and removals.

## Prerequisites

- Docker installed and running
- Basic understanding of container operations

## Demo 1: Container Without Volumes (Data Loss)

```bash
# Run container without volumes
docker run -it --name temp-container alpine:latest sh

# Inside container, create some data
echo "Important data" > /tmp/important.txt
cat /tmp/important.txt
exit

# Restart container - data still exists
docker start temp-container
docker exec temp-container cat /tmp/important.txt

# Remove container - data is lost forever
docker rm temp-container

# Try to access data - impossible
docker run --name new-container alpine:latest cat /tmp/important.txt
# File not found - data is gone!
```

## Demo 2: Named Volumes (Persistent Data)

```bash
# Create named volume
docker volume create demo-volume

# Run container with named volume
docker run -it --name persistent-container \
  -v demo-volume:/data alpine:latest sh

# Inside container, create data in volume
echo "This will persist!" > /data/persistent.txt
echo "Created on $(date)" >> /data/persistent.txt
ls -la /data/
exit

# Remove container but keep volume
docker rm persistent-container

# Create new container using same volume
docker run -it --name new-container \
  -v demo-volume:/data alpine:latest sh

# Data is still there!
cat /data/persistent.txt
ls -la /data/
exit

# Clean up
docker rm new-container
docker volume rm demo-volume
```

## Demo 3: Bind Mounts (Host Directory Access)

```bash
# Create directory on host
mkdir -p /tmp/bind-mount-demo
echo "Host file content" > /tmp/bind-mount-demo/host-file.txt

# Run container with bind mount
docker run -it --name bind-container \
  -v /tmp/bind-mount-demo:/host-data alpine:latest sh

# Inside container - can see host files
ls -la /host-data/
cat /host-data/host-file.txt

# Create file from container
echo "Created from container" > /host-data/container-file.txt
exit

# Check host filesystem - file is there
ls -la /tmp/bind-mount-demo/
cat /tmp/bind-mount-demo/container-file.txt

# Remove container - host files remain
docker rm bind-container
ls -la /tmp/bind-mount-demo/

# Clean up
rm -rf /tmp/bind-mount-demo
```

## Demo 4: Sharing Volumes Between Containers

```bash
# Create shared volume
docker volume create shared-data

# Container 1: Writer
docker run -d --name writer \
  -v shared-data:/shared alpine:latest \
  sh -c 'while true; do echo "$(date): Message from writer" >> /shared/messages.log; sleep 5; done'

# Container 2: Reader
docker run -d --name reader \
  -v shared-data:/shared alpine:latest \
  sh -c 'while true; do echo "Reading messages:"; tail -5 /shared/messages.log; sleep 10; done'

# Watch both containers
docker logs -f writer &
docker logs -f reader &

# Stop background jobs and clean up
sleep 30
jobs
kill %1 %2  # Kill background log commands
docker stop writer reader
docker rm writer reader
docker volume rm shared-data
```

## Demo 5: Database Persistence

```bash
# Run PostgreSQL with named volume
docker volume create postgres-data
docker run -d --name demo-postgres \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 postgres:13

# Wait for database to start
sleep 10

# Create database and table
docker exec -it demo-postgres psql -U postgres -c "
  CREATE DATABASE testdb;
  \c testdb;
  CREATE TABLE users (id SERIAL, name VARCHAR(50));
  INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
  SELECT * FROM users;
"

# Stop and remove container
docker stop demo-postgres
docker rm demo-postgres

# Start new container with same volume
docker run -d --name demo-postgres-2 \
  -v postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 postgres:13

sleep 10

# Data is still there!
docker exec -it demo-postgres-2 psql -U postgres -c "
  \c testdb;
  SELECT * FROM users;
"

# Clean up
docker stop demo-postgres-2
docker rm demo-postgres-2
docker volume rm postgres-data
```

## Demo 6: tmpfs Mounts (Memory Storage)

```bash
# Run container with tmpfs mount (Linux only)
docker run -it --name tmpfs-demo \
  --tmpfs /temp:size=100M,noexec alpine:latest sh

# Inside container - create data in memory
df -h /temp  # Shows tmpfs filesystem
echo "Temporary data" > /temp/temp-file.txt
echo "This exists only in RAM" >> /temp/temp-file.txt
ls -la /temp/
exit

# Restart container - tmpfs data is gone
docker start tmpfs-demo
docker exec tmpfs-demo ls -la /temp/
# Directory exists but files are gone

docker rm tmpfs-demo
```

## Demo 7: Volume Performance Comparison

```bash
# Create test volumes
docker volume create perf-volume
mkdir -p /tmp/perf-bind

# Performance test function
run_perf_test() {
  local mount_type=$1
  local mount_option=$2

  echo "Testing $mount_type performance..."
  docker run --rm $mount_option alpine:latest sh -c '
    echo "Writing 1000 files..."
    time sh -c "for i in $(seq 1 1000); do echo \"test data $i\" > /data/file$i.txt; done"
    echo "Reading 1000 files..."
    time sh -c "for i in $(seq 1 1000); do cat /data/file$i.txt > /dev/null; done"
    echo "Cleaning up files..."
    time rm /data/file*.txt
  '
}

# Test named volume
run_perf_test "Named Volume" "-v perf-volume:/data"

# Test bind mount
run_perf_test "Bind Mount" "-v /tmp/perf-bind:/data"

# Test tmpfs
run_perf_test "tmpfs" "--tmpfs /data"

# Clean up
docker volume rm perf-volume
rm -rf /tmp/perf-bind
```

## Demo 8: Volume Backup and Restore

```bash
# Create volume with data
docker volume create backup-demo
docker run --rm -v backup-demo:/data alpine:latest sh -c '
  echo "Important data 1" > /data/file1.txt
  echo "Important data 2" > /data/file2.txt
  mkdir -p /data/subdir
  echo "Nested data" > /data/subdir/nested.txt
'

# Backup volume to tar file
echo "Creating backup..."
docker run --rm \
  -v backup-demo:/data \
  -v $(pwd):/backup \
  alpine:latest tar czf /backup/volume-backup.tar.gz -C /data .

# Remove original volume
docker volume rm backup-demo

# Create new volume and restore data
docker volume create backup-demo-restored
docker run --rm \
  -v backup-demo-restored:/data \
  -v $(pwd):/backup \
  alpine:latest tar xzf /backup/volume-backup.tar.gz -C /data

# Verify restored data
docker run --rm -v backup-demo-restored:/data alpine:latest find /data -type f -exec cat {} \;

# Clean up
docker volume rm backup-demo-restored
rm -f volume-backup.tar.gz
```

## Key Observations

### Data Persistence Comparison

| Storage Type         | Persists Container Restart | Persists Container Removal | Shared Between Containers |
| -------------------- | -------------------------- | -------------------------- | ------------------------- |
| Container filesystem | ✅                         | ❌                         | ❌                        |
| Named volumes        | ✅                         | ✅                         | ✅                        |
| Bind mounts          | ✅                         | ✅                         | ✅                        |
| tmpfs mounts         | ❌                         | ❌                         | ❌                        |

### Performance Characteristics

1. **tmpfs**: Fastest (memory-based)
2. **Named volumes**: Fast (optimized by Docker)
3. **Bind mounts**: Good (direct filesystem access)

### Use Case Recommendations

- **Named volumes**: Production data, databases, application state
- **Bind mounts**: Development, configuration files, logs
- **tmpfs mounts**: Temporary data, caches, sensitive information

## Troubleshooting Common Issues

### Volume Not Mounting

```bash
# Check volume exists
docker volume ls

# Inspect volume details
docker volume inspect volume-name

# Check container mount points
docker inspect container-name | grep -A 10 "Mounts"
```

### Permission Problems

```bash
# Check file ownership in volume
docker run --rm -v my-volume:/data alpine:latest ls -la /data

# Fix permissions
docker run --rm -v my-volume:/data alpine:latest chown -R 1000:1000 /data
```

### Disk Space Issues

```bash
# Check volume disk usage
docker system df -v

# Clean up unused volumes
docker volume prune
```

## Summary

This demo showed:

- Container data is ephemeral by default
- Named volumes provide persistent storage
- Bind mounts connect to host filesystem
- Volumes can be shared between containers
- Different storage types have different performance characteristics
- Backup and restore operations preserve data across volume lifecycles

Understanding these storage mechanisms is crucial for building production-ready containerized applications.
