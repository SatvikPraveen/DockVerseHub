# Location: utilities/performance/optimization-guides/runtime-optimization.md

# Docker Runtime Optimization Guide

Comprehensive guide for optimizing Docker container runtime performance, resource utilization, and system efficiency.

## Table of Contents

- [Resource Management](#resource-management)
- [Storage Optimization](#storage-optimization)
- [Network Performance](#network-performance)
- [Memory Optimization](#memory-optimization)
- [CPU Optimization](#cpu-optimization)
- [I/O Optimization](#i-o-optimization)
- [Monitoring & Profiling](#monitoring--profiling)

## Resource Management

### Memory Limits and Reservations

Properly configure memory limits to prevent OOM kills and resource contention.

```bash
# Set memory limit and reservation
docker run --memory=512m --memory-reservation=256m myapp

# With swap limit (prevent swap usage)
docker run --memory=512m --memory-swap=512m myapp

# OOM kill disable (use with caution)
docker run --memory=512m --oom-kill-disable myapp
```

**Docker Compose:**

```yaml
services:
  app:
    image: myapp
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### CPU Limits and Constraints

Control CPU usage to ensure fair resource allocation.

```bash
# Limit to 1.5 CPUs
docker run --cpus="1.5" myapp

# CPU shares (relative weight)
docker run --cpu-shares=512 myapp

# CPU affinity (bind to specific CPUs)
docker run --cpuset-cpus="0,1" myapp

# CPU quota and period
docker run --cpu-period=100000 --cpu-quota=50000 myapp  # 50% of one CPU
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Detailed container stats
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
```

## Storage Optimization

### Choose the Right Storage Driver

Select appropriate storage driver for your workload.

```bash
# Check current storage driver
docker info | grep "Storage Driver"

# Common drivers:
# - overlay2: Best performance for most workloads
# - btrfs: Good for development with snapshot features
# - zfs: Enterprise features with compression
```

### Volume Performance

Optimize volume usage for better I/O performance.

```yaml
services:
  database:
    image: postgres:15
    volumes:
      # Named volume for data persistence
      - postgres_data:/var/lib/postgresql/data
      # tmpfs for temporary files
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 100M
          mode: 1777

volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/postgres-data # SSD path
```

### Tmpfs for Temporary Data

Use tmpfs mounts for temporary files to avoid disk I/O.

```bash
# Mount tmpfs for logs/temp files
docker run --tmpfs /tmp:rw,noexec,nosuid,size=100m myapp

# Multiple tmpfs mounts
docker run \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /var/log:rw,noexec,nosuid,size=50m \
  myapp
```

### Storage Performance Tuning

```bash
# Check container filesystem usage
docker exec container_name df -h

# Monitor I/O stats
docker stats --format "table {{.Container}}\t{{.BlockIO}}"

# Container layer information
docker history --no-trunc image_name
```

## Network Performance

### Network Driver Selection

Choose the appropriate network driver for your use case.

```bash
# Default bridge network
docker network create --driver bridge my-bridge

# Host network (best performance, less isolation)
docker run --network host myapp

# Macvlan network (direct hardware access)
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 macvlan-net
```

### Network Optimization Settings

```yaml
services:
  app:
    image: myapp
    networks:
      - app-network
    sysctls:
      - net.core.somaxconn=65535
      - net.ipv4.tcp_tw_reuse=1
      - net.ipv4.ip_local_port_range=1024 65535

networks:
  app-network:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 9000 # Jumbo frames
```

### DNS Optimization

```bash
# Custom DNS servers
docker run --dns=8.8.8.8 --dns=1.1.1.1 myapp

# DNS search domains
docker run --dns-search=example.com myapp
```

## Memory Optimization

### Memory-Mapped Files

Optimize memory usage for file-heavy applications.

```bash
# Increase memory map limits
docker run --sysctl vm.max_map_count=262144 elasticsearch:8.11.0
```

### Swap Configuration

```bash
# Disable swap for performance-critical containers
docker run --memory=1g --memory-swap=1g myapp

# Monitor swap usage
docker exec container_name cat /proc/meminfo | grep -i swap
```

### Memory Profiling

```python
# memory-profiling.py example
import psutil
import time
import json

def profile_memory():
    """Profile container memory usage"""
    stats = {
        'timestamp': time.time(),
        'memory': {
            'total': psutil.virtual_memory().total,
            'available': psutil.virtual_memory().available,
            'percent': psutil.virtual_memory().percent,
            'used': psutil.virtual_memory().used,
            'free': psutil.virtual_memory().free
        },
        'swap': {
            'total': psutil.swap_memory().total,
            'used': psutil.swap_memory().used,
            'free': psutil.swap_memory().free,
            'percent': psutil.swap_memory().percent
        }
    }
    return stats

# Continuous monitoring
while True:
    stats = profile_memory()
    print(json.dumps(stats, indent=2))
    time.sleep(5)
```

## CPU Optimization

### CPU Affinity and Isolation

Bind containers to specific CPU cores for predictable performance.

```bash
# Bind to specific CPUs
docker run --cpuset-cpus="0-3" myapp

# Isolate CPUs for real-time applications
docker run --cpuset-cpus="4-7" --cpu-rt-runtime=95000 realtime-app
```

### CPU Scheduling

```bash
# Real-time scheduling policy
docker run --cpu-rt-runtime=95000 --cpu-rt-period=100000 myapp

# CPU bandwidth control
docker run --cpu-period=100000 --cpu-quota=200000 myapp  # 2 CPUs max
```

### CPU Profiling

```python
# cpu-profiling.py
import psutil
import time
import threading
from collections import defaultdict

class CPUProfiler:
    def __init__(self):
        self.stats = defaultdict(list)
        self.running = False

    def start_profiling(self, interval=1.0):
        self.running = True
        thread = threading.Thread(target=self._profile_loop, args=(interval,))
        thread.daemon = True
        thread.start()
        return thread

    def _profile_loop(self, interval):
        while self.running:
            # Overall CPU usage
            cpu_percent = psutil.cpu_percent(interval=None)
            self.stats['cpu_total'].append(cpu_percent)

            # Per-core usage
            cpu_per_core = psutil.cpu_percent(percpu=True, interval=None)
            for i, usage in enumerate(cpu_per_core):
                self.stats[f'cpu_core_{i}'].append(usage)

            # Load average
            load_avg = psutil.getloadavg()
            self.stats['load_1min'].append(load_avg[0])
            self.stats['load_5min'].append(load_avg[1])
            self.stats['load_15min'].append(load_avg[2])

            time.sleep(interval)

    def get_stats(self):
        return dict(self.stats)

    def stop_profiling(self):
        self.running = False

# Usage
profiler = CPUProfiler()
profiler.start_profiling(interval=1.0)
time.sleep(60)  # Profile for 1 minute
profiler.stop_profiling()
stats = profiler.get_stats()
```

## I/O Optimization

### Disk I/O Limits

Control disk I/O to prevent resource starvation.

```bash
# Limit read/write IOPS
docker run \
  --device-read-iops /dev/sda:1000 \
  --device-write-iops /dev/sda:1000 \
  myapp

# Limit bandwidth
docker run \
  --device-read-bps /dev/sda:1mb \
  --device-write-bps /dev/sda:1mb \
  myapp
```

### I/O Scheduler Optimization

```bash
# Check current I/O scheduler
cat /sys/block/sda/queue/scheduler

# Change I/O scheduler for SSD
echo noop > /sys/block/sda/queue/scheduler

# For HDD
echo deadline > /sys/block/sda/queue/scheduler
```

### Asynchronous I/O

Configure applications for better I/O performance.

```yaml
services:
  database:
    image: postgres:15
    environment:
      - POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements
    command: |
      postgres
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
```

## Monitoring & Profiling

### Container Metrics Collection

```bash
# Enable Docker metrics endpoint
dockerd --metrics-addr=0.0.0.0:9323

# Custom metrics collection
python utilities/performance/profiling/cpu-profiling.py
python utilities/performance/profiling/memory-profiling.py
```

### Performance Monitoring Stack

```yaml
version: "3.8"
services:
  app:
    image: myapp
    labels:
      - "prometheus.scrape=true"
      - "prometheus.port=8080"
      - "prometheus.path=/metrics"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

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
      - "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)"
```

### Application Performance Monitoring

```python
# application-metrics.py
import time
import psutil
import json
from datetime import datetime

class AppMetrics:
    def __init__(self):
        self.start_time = time.time()
        self.process = psutil.Process()

    def get_metrics(self):
        return {
            'timestamp': datetime.now().isoformat(),
            'uptime': time.time() - self.start_time,
            'cpu': {
                'percent': self.process.cpu_percent(),
                'times': self.process.cpu_times()._asdict(),
                'num_threads': self.process.num_threads()
            },
            'memory': {
                'rss': self.process.memory_info().rss,
                'vms': self.process.memory_info().vms,
                'percent': self.process.memory_percent(),
                'available': psutil.virtual_memory().available
            },
            'io': {
                'read_count': self.process.io_counters().read_count,
                'write_count': self.process.io_counters().write_count,
                'read_bytes': self.process.io_counters().read_bytes,
                'write_bytes': self.process.io_counters().write_bytes
            },
            'connections': len(self.process.connections())
        }

# Flask integration example
from flask import Flask, jsonify
app = Flask(__name__)
metrics = AppMetrics()

@app.route('/metrics')
def get_metrics():
    return jsonify(metrics.get_metrics())
```

## Runtime Configuration Best Practices

### Init Process

Use proper init process for signal handling.

```dockerfile
# Install tini
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["myapp"]
```

### Health Checks

Implement comprehensive health checks.

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

### Graceful Shutdown

```python
# graceful-shutdown.py
import signal
import sys
import time

class GracefulShutdown:
    def __init__(self):
        self.shutdown = False
        signal.signal(signal.SIGTERM, self._exit_handler)
        signal.signal(signal.SIGINT, self._exit_handler)

    def _exit_handler(self, signum, frame):
        print(f"Received signal {signum}, initiating graceful shutdown...")
        self.shutdown = True

    def should_shutdown(self):
        return self.shutdown

# Usage in main application loop
shutdown_handler = GracefulShutdown()
while not shutdown_handler.should_shutdown():
    # Application logic
    time.sleep(1)

print("Shutting down gracefully...")
# Cleanup code here
sys.exit(0)
```

### Log Configuration

Optimize logging for performance.

```yaml
services:
  app:
    image: myapp
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"
```

## Performance Testing

### Load Testing

```bash
# Container stress testing
docker run --rm -it progrium/stress \
  --cpu 2 --io 1 --vm 2 --vm-bytes 128M --timeout 60s

# Network performance testing
docker run --rm -it networkstatic/iperf3 -c target-host
```

### Benchmarking

```bash
# Use custom benchmarking tools
bash utilities/scripts/performance_benchmark.sh --image myapp:latest

# Container startup time analysis
python utilities/performance/benchmarks/container-startup-times.py myapp:latest
```

## Troubleshooting Performance Issues

### Common Performance Problems

1. **Memory leaks**: Monitor memory usage over time
2. **CPU hotspots**: Use profiling tools
3. **I/O bottlenecks**: Check disk and network metrics
4. **Resource contention**: Monitor system-wide resources

### Debugging Tools

```bash
# Container resource usage
docker exec container_name top
docker exec container_name iostat
docker exec container_name netstat -i

# System-level debugging
htop
iotop
nethogs
```

### Performance Optimization Checklist

- [ ] Configure appropriate resource limits
- [ ] Use tmpfs for temporary data
- [ ] Optimize network settings
- [ ] Choose correct storage driver
- [ ] Implement proper monitoring
- [ ] Use init process for signal handling
- [ ] Configure health checks
- [ ] Optimize logging configuration
- [ ] Test under realistic load
- [ ] Monitor and profile continuously

Following these runtime optimization practices will significantly improve your Docker container performance, resource utilization, and overall system efficiency.
