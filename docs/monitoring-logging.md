# Docker Monitoring & Logging: Metrics, Dashboards & Centralized Logs

**Location: `docs/monitoring-logging.md`**

## Monitoring Overview

Effective Docker monitoring involves tracking container performance, resource usage, application metrics, and system health across your infrastructure.

## Container Resource Monitoring

### Docker Stats

```bash
# Real-time resource usage
docker stats

# Specific containers
docker stats container1 container2

# All containers (including stopped)
docker stats --all

# Format output
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# No streaming (single snapshot)
docker stats --no-stream
```

### System Information

```bash
# Docker system info
docker system info
docker system df
docker system events

# Container inspection
docker inspect container_name
docker top container_name
```

## Logging Strategies

### Docker Logging Drivers

#### JSON File (Default)

```bash
# Configure JSON logging
docker run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 nginx

# View logs
docker logs container_name
docker logs -f --tail 100 container_name
```

#### Syslog Driver

```bash
# Send logs to syslog
docker run --log-driver syslog --log-opt syslog-address=tcp://192.168.0.42:123 nginx

# Local syslog
docker run --log-driver syslog nginx
```

#### Journald Driver

```bash
# Use systemd journal
docker run --log-driver journald nginx

# View with journalctl
journalctl -u docker.service
journalctl CONTAINER_NAME=container_name
```

### Centralized Logging with ELK Stack

#### Complete ELK Setup

```yaml
# docker-compose.yml
version: "3.8"
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    ports:
      - "5000:5000/tcp"
      - "5000:5000/udp"
      - "9600:9600"
    environment:
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"
    volumes:
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    networks:
      - elk
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    networks:
      - elk
    depends_on:
      - elasticsearch

  # Application with logging
  app:
    image: nginx:alpine
    ports:
      - "80:80"
    logging:
      driver: gelf
      options:
        gelf-address: udp://localhost:12201
        tag: nginx
    depends_on:
      - logstash
    networks:
      - elk

  # Log shipper
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.8.0
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - elk
    depends_on:
      - elasticsearch

networks:
  elk:
    driver: bridge

volumes:
  elasticsearch_data:
```

#### Logstash Configuration

```yaml
# logstash/config/logstash.yml
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]

# logstash/pipeline/logstash.conf
input {
  gelf {
    port => 12201
  }
  beats {
    port => 5044
  }
}

filter {
  if [docker][container][name] {
    mutate {
      add_field => { "container_name" => "%{[docker][container][name]}" }
    }
  }

  if [fields][logtype] == "nginx" {
    grok {
      match => { "message" => "%{NGINXACCESS}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "docker-logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
```

#### Filebeat Configuration

```yaml
# filebeat/filebeat.yml
filebeat.inputs:
  - type: container
    paths:
      - "/var/lib/docker/containers/*/*.log"

processors:
  - add_docker_metadata:
      host: "unix:///var/run/docker.sock"

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
```

## Prometheus Monitoring Stack

### Complete Monitoring Setup

```yaml
# monitoring-stack.yml
version: "3.8"
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.console.libraries=/etc/prometheus/console_libraries"
      - "--web.console.templates=/etc/prometheus/consoles"
      - "--storage.tsdb.retention.time=200h"
      - "--web.enable-lifecycle"
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - monitoring

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
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

  # Sample application
  app:
    image: nginx:alpine
    ports:
      - "80:80"
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=9113"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
```

### Prometheus Configuration

```yaml
# prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]

  - job_name: "docker"
    static_configs:
      - targets: ["host.docker.internal:9323"]

  # Docker service discovery
  - job_name: "docker-containers"
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ["__meta_docker_container_label_prometheus_io_scrape"]
        action: keep
        regex: true
      - source_labels: ["__meta_docker_container_label_prometheus_io_port"]
        action: replace
        regex: (.+)
        target_label: __address__
        replacement: "$1"
```

### Alerting Rules

```yaml
# prometheus/alert_rules.yml
groups:
  - name: docker
    rules:
      - alert: ContainerKilled
        expr: time() - container_last_seen > 60
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: Container killed (instance {{ $labels.instance }})
          description: "A container has disappeared"

      - alert: ContainerCpuUsage
        expr: (sum(rate(container_cpu_usage_seconds_total[3m])) BY (instance, name) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Container CPU usage (instance {{ $labels.instance }})
          description: "Container CPU usage is above 80%"

      - alert: ContainerMemoryUsage
        expr: (sum(container_memory_working_set_bytes) BY (instance, name) / sum(container_spec_memory_limit_bytes > 0) BY (instance, name) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Container Memory usage (instance {{ $labels.instance }})
          description: "Container Memory usage is above 80%"

      - alert: ContainerVolumeUsage
        expr: (1 - (sum(container_fs_inodes_free) BY (instance) / sum(container_fs_inodes_total) BY (instance))) * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Container Volume usage (instance {{ $labels.instance }})
          description: "Container Volume usage is above 80%"
```

### Alertmanager Configuration

```yaml
# alertmanager/alertmanager.yml
global:
  smtp_smarthost: "localhost:587"
  smtp_from: "alerts@company.com"

route:
  group_by: ["alertname"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: "web.hook"

receivers:
  - name: "web.hook"
    email_configs:
      - to: "admin@company.com"
        subject: "Docker Alert: {{ .GroupLabels.alertname }}"
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}: {{ .Value }}{{ end }}
          {{ end }}

    slack_configs:
      - api_url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
        channel: "#alerts"
        title: "Docker Alert"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"

inhibit_rules:
  - source_match:
      severity: "critical"
    target_match:
      severity: "warning"
    equal: ["alertname", "dev", "instance"]
```

## Application Metrics

### Custom Metrics in Applications

```python
# Python Flask app with Prometheus metrics
from flask import Flask
from prometheus_client import Counter, Histogram, generate_latest
import time

app = Flask(__name__)

# Metrics
REQUEST_COUNT = Counter('requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('request_duration_seconds', 'Request latency')

@app.route('/')
@REQUEST_LATENCY.time()
def hello():
    REQUEST_COUNT.labels(method='GET', endpoint='/').inc()
    return 'Hello World!'

@app.route('/metrics')
def metrics():
    return generate_latest()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

```dockerfile
# Dockerfile
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
```

### Node.js Express Metrics

```javascript
// app.js
const express = require("express");
const promClient = require("prom-client");

const app = express();

// Create a Registry
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new promClient.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

const httpRequestDuration = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });

  next();
});

app.get("/", (req, res) => {
  res.send("Hello World!");
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});
```

## Docker Compose Logging Configuration

### Comprehensive Logging Setup

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: nginx.access
    labels:
      - "logging=true"

  api:
    build: ./api
    ports:
      - "3000:3000"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    environment:
      - LOG_LEVEL=info
    labels:
      - "logging=true"

  worker:
    build: ./worker
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://log-server:514"
        tag: "worker"
    labels:
      - "logging=true"

  database:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    logging:
      driver: "journald"
      options:
        tag: "postgres"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Log Analysis and Alerting

### Log-based Alerting

```yaml
# elastalert rules
es_host: elasticsearch
es_port: 9200

name: Docker Container Error Rate
type: frequency
index: docker-logs-*
num_events: 10
timeframe:
  minutes: 5

filter:
  - terms:
      level: ["error", "fatal"]

alert:
  - "email"
  - "slack"

email:
  - "ops@company.com"

slack:
webhook_url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
slack_channel_override: "#alerts"
```

### Custom Log Processing

```python
#!/usr/bin/env python3
# log_processor.py
import json
import re
from datetime import datetime

def process_docker_logs(log_line):
    """Process Docker JSON logs"""
    try:
        log_data = json.loads(log_line)
        timestamp = datetime.fromisoformat(log_data['time'].replace('Z', '+00:00'))
        message = log_data['log'].strip()

        # Extract error patterns
        error_patterns = [
            r'ERROR',
            r'FATAL',
            r'Exception',
            r'Failed',
        ]

        for pattern in error_patterns:
            if re.search(pattern, message, re.IGNORECASE):
                return {
                    'timestamp': timestamp,
                    'level': 'ERROR',
                    'message': message,
                    'container': log_data.get('attrs', {}).get('tag', 'unknown')
                }

        return {
            'timestamp': timestamp,
            'level': 'INFO',
            'message': message,
            'container': log_data.get('attrs', {}).get('tag', 'unknown')
        }

    except Exception as e:
        return None

# Usage
with open('/var/log/docker/container.log') as f:
    for line in f:
        processed = process_docker_logs(line)
        if processed and processed['level'] == 'ERROR':
            print(f"ERROR DETECTED: {processed}")
```

## Health Monitoring

### Health Check Implementation

```dockerfile
# Dockerfile with health check
FROM nginx:alpine

# Install curl for health check
RUN apk add --no-cache curl

# Copy health check script
COPY healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh
```

```bash
#!/bin/bash
# healthcheck.sh
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/health)
if [ "$response" = "200" ]; then
    exit 0
else
    exit 1
fi
```

### Docker Compose Health Monitoring

```yaml
version: "3.8"
services:
  web:
    build: .
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    depends_on:
      database:
        condition: service_healthy

  database:
    image: postgres:13
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=secret
```

## Performance Monitoring

### Resource Usage Tracking

```bash
#!/bin/bash
# monitor.sh - Resource monitoring script

echo "Container Resource Monitor - $(date)"
echo "========================================"

# Get container resource usage
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

echo -e "\nTop CPU consuming containers:"
docker stats --no-stream --format "{{.Container}}\t{{.CPUPerc}}" | sort -k2 -nr | head -5

echo -e "\nTop Memory consuming containers:"
docker stats --no-stream --format "{{.Container}}\t{{.MemPerc}}" | sort -k2 -nr | head -5

# Alert if any container uses > 80% memory
docker stats --no-stream --format "{{.Container}}\t{{.MemPerc}}" | while read container mem; do
    mem_num=$(echo $mem | sed 's/%//')
    if (( $(echo "$mem_num > 80" | bc -l) )); then
        echo "ALERT: $container using $mem memory"
    fi
done
```

### Performance Benchmarking

```python
#!/usr/bin/env python3
# benchmark.py
import docker
import time
import psutil
import json

def benchmark_container(container_name, duration=60):
    client = docker.from_env()
    container = client.containers.get(container_name)

    metrics = {
        'cpu_usage': [],
        'memory_usage': [],
        'network_io': [],
        'disk_io': []
    }

    start_time = time.time()
    while time.time() - start_time < duration:
        stats = container.stats(stream=False)

        # CPU usage
        cpu_usage = calculate_cpu_percent(stats)
        metrics['cpu_usage'].append(cpu_usage)

        # Memory usage
        memory_usage = stats['memory_stats']['usage']
        metrics['memory_usage'].append(memory_usage)

        # Network IO
        network_io = sum(stats['networks'][iface]['rx_bytes'] + stats['networks'][iface]['tx_bytes']
                        for iface in stats['networks'])
        metrics['network_io'].append(network_io)

        time.sleep(1)

    return metrics

def calculate_cpu_percent(stats):
    cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                stats['precpu_stats']['cpu_usage']['total_usage']
    system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                   stats['precpu_stats']['system_cpu_usage']

    if system_delta > 0:
        return (cpu_delta / system_delta) * len(stats['cpu_stats']['cpu_usage']['percpu_usage']) * 100.0
    return 0.0

if __name__ == "__main__":
    container_name = "myapp"
    results = benchmark_container(container_name)

    with open(f'{container_name}_benchmark.json', 'w') as f:
        json.dump(results, f, indent=2)

    print(f"Benchmark complete for {container_name}")
```

## Best Practices

### Monitoring Strategy

1. **Layer monitoring**: Infrastructure → Container → Application
2. **Use structured logging**: JSON format for better parsing
3. **Implement health checks**: Container and application level
4. **Set up alerting**: Proactive issue detection
5. **Monitor trends**: Not just current state
6. **Regular reviews**: Adjust thresholds and metrics

### Logging Best Practices

1. **Centralized logging**: All logs in one place
2. **Log rotation**: Prevent disk space issues
3. **Structured data**: Include metadata and context
4. **Security**: Sanitize sensitive information
5. **Performance**: Avoid excessive logging
6. **Retention**: Define log retention policies

## Troubleshooting

### Common Monitoring Issues

```bash
# High resource usage investigation
docker stats $(docker ps --format {{.Names}})
docker top container_name
docker exec container_name ps aux

# Log issues
docker logs container_name --details
journalctl -u docker.service
tail -f /var/log/docker.log

# Network monitoring
docker exec container_name netstat -tulpn
docker network ls
```

## Next Steps

- Learn [Orchestration Overview](./orchestration-overview.md) for cluster monitoring
- Explore [Production Deployment](./production-deployment.md) monitoring strategies
- Check [Troubleshooting](./troubleshooting.md) for debugging techniques
- Understand [Performance Optimization](./performance-optimization.md) based on monitoring data
