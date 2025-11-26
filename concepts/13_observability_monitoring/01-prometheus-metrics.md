# Prometheus: Metrics Collection & Monitoring

**Duration:** 2 hours | **Level:** Advanced

---

## 🎯 What is Prometheus?

Prometheus is an open-source time-series database and monitoring system designed for reliability and operational simplicity.

**Key Features:**
- Pull-based scraping model
- Powerful PromQL query language
- Time-series data storage
- Multi-dimensional metrics
- Built-in alerting
- Federation for scale
- Service discovery integration

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│         Applications                            │
│  ├─ /metrics endpoint (Prometheus format)      │
│  └─ Exported metrics                           │
└────────────────┬────────────────────────────────┘
                 │ (HTTP pull)
┌────────────────▼────────────────────────────────┐
│         Prometheus Server                       │
│  ├─ Service Discovery                          │
│  ├─ Scraper (pulls metrics)                    │
│  ├─ Storage Engine (TSDB)                      │
│  ├─ Query Engine (PromQL)                      │
│  └─ Alerting Rules                             │
└────────────────┬────────────────────────────────┘
         ┌───────┴────────┐
         │                │
    ┌────▼──────┐    ┌──────▼────┐
    │ Alertmanager│   │ Grafana    │
    │ Notifications│   │ Dashboards │
    └────────────┘    └────────────┘
```

---

## 📦 Installation

### Docker Compose

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

volumes:
  prometheus-data:
```

### Kubernetes

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
```

---

## 🔧 Configuration

### Basic Configuration

```yaml
global:
  scrape_interval: 15s          # How often to scrape targets
  evaluation_interval: 15s       # How often to evaluate rules
  external_labels:
    cluster: 'us-west-1'

alerting:
  alertmanagers:
  - static_configs:
    - targets: ['localhost:9093']

rule_files:
  - '/etc/prometheus/rules.yml'

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
  
  # Node exporter (system metrics)
  - job_name: 'node'
    static_configs:
    - targets: ['localhost:9100']
  
  # Application metrics
  - job_name: 'app'
    static_configs:
    - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s
```

### Kubernetes Service Discovery

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    # Only scrape pods with prometheus annotation
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: 'true'
    # Get metrics path from annotation
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    # Get port from annotation
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
      target_label: __address__
```

---

## 📊 Metrics Types

### Counter

Always increases (never decreases).

```python
from prometheus_client import Counter

requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint']
)

# Increment
requests_total.labels(method='GET', endpoint='/').inc()
```

### Gauge

Can go up or down.

```python
from prometheus_client import Gauge

memory_usage = Gauge(
    'memory_usage_bytes',
    'Memory usage in bytes'
)

# Set value
memory_usage.set(1024000)

# Increment/decrement
memory_usage.inc(100)
memory_usage.dec(50)
```

### Histogram

Distribution of values (latency, size, etc).

```python
from prometheus_client import Histogram

request_latency = Histogram(
    'request_latency_seconds',
    'Request latency',
    buckets=(0.1, 0.5, 1.0, 2.0, 5.0)
)

# Record value
request_latency.observe(0.45)
```

### Summary

Quantiles over time window.

```python
from prometheus_client import Summary

response_size = Summary(
    'response_size_bytes',
    'Response size'
)

response_size.observe(1024)
```

---

## 🔍 PromQL - Prometheus Query Language

### Basic Queries

```promql
# Fetch current metric value
http_requests_total

# Specific label values
http_requests_total{method="GET"}

# Multiple labels
http_requests_total{method="GET", status="200"}

# Label matching (regex)
http_requests_total{endpoint=~"/api/.*"}

# Not matching
http_requests_total{status!="200"}
```

### Range Vectors

```promql
# Last 5 minutes
http_requests_total[5m]

# Last 1 hour
http_requests_total[1h]

# Supported units: s, m, h, d, w, y
```

### Aggregation

```promql
# Sum across all series
sum(http_requests_total)

# Average
avg(http_requests_total)

# Group by label
sum by (method) (http_requests_total)

# Top 5 values
topk(5, http_requests_total)

# Bottom values
bottomk(3, http_requests_total)
```

### Rate & Increase

```promql
# Per-second rate over 5 minutes
rate(http_requests_total[5m])

# Total increase over 1 hour
increase(http_requests_total[1h])

# Useful for counters to calculate velocity
rate(errors_total[5m])  # Errors per second
```

### Advanced Queries

```promql
# Request success rate (%)
100 * (1 - (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])))

# P95 latency
histogram_quantile(0.95, rate(request_latency_bucket[5m]))

# CPU usage percent
100 * (1 - avg without (cpu) (rate(node_cpu_seconds_total{mode="idle"}[5m])))

# Memory available percentage
100 * (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

---

## 📝 Recording Rules

Precompute frequently used queries.

```yaml
groups:
- name: app_metrics
  interval: 30s
  rules:
  # Request rate per endpoint
  - record: app:requests:rate5m
    expr: rate(http_requests_total[5m])
  
  # Error rate
  - record: app:errors:rate5m
    expr: rate(http_requests_total{status=~"5.."}[5m])
  
  # Success rate
  - record: app:success_rate:5m
    expr: 100 * (1 - (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])))
```

---

## 🚨 Alerting Rules

```yaml
groups:
- name: alerts
  interval: 30s
  rules:
  # High error rate
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors/sec"
  
  # Low success rate
  - alert: LowSuccessRate
    expr: 100 * (1 - (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]))) < 99
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Success rate below 99%"
      description: "Current success rate: {{ $value }}%"
  
  # High latency
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(request_latency_bucket[5m])) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High request latency"
      description: "P95 latency: {{ $value }}s"
```

---

## 🔗 Remote Storage

Store metrics long-term in external systems.

```yaml
remote_write:
  - url: "http://influxdb:8086/api/v1/prom/write?db=prometheus"
    write_relabel_configs:
    - source_labels: [__name__]
      regex: 'node_.*'
      action: drop
  
  - url: "s3://my-bucket/prometheus/"
    headers:
      Authorization: "Bearer <token>"

remote_read:
  - url: "http://influxdb:8086/api/v1/prom/read?db=prometheus"
```

---

## 📱 Exporters

Convert external system metrics to Prometheus format.

### Node Exporter (System Metrics)

```bash
# Download and run
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64
./node_exporter
# Metrics at http://localhost:9100/metrics
```

### Custom Exporter (Python)

```python
from prometheus_client import start_http_server, Gauge, Counter
import time

# Define metrics
app_info = Gauge('app_info', 'Application info', ['version', 'name'])
requests_total = Counter('app_requests_total', 'Total requests')
active_connections = Gauge('app_active_connections', 'Active connections')

# Set values
app_info.labels(version='1.0.0', name='myapp').set(1)

# Start HTTP server
start_http_server(8000)

# Update metrics
while True:
    requests_total.inc()
    active_connections.set(42)
    time.sleep(10)
```

---

## 🎓 Complete Example

### Docker Compose Setup

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./rules.yml:/etc/prometheus/rules.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      PORT: 8080

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus-data:
```

### prometheus.yml Configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - '/etc/prometheus/rules.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'app'
    static_configs:
      - targets: ['app:8080']
  
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

---

## 🚀 Best Practices

1. **Use descriptive metric names**
   ```promql
   # Good
   http_requests_total{method="GET", status="200"}
   
   # Avoid
   requests
   count
   ```

2. **Include high-cardinality labels carefully**
   ```
   # Good: Low cardinality
   {environment="prod", region="us-west"}
   
   # Avoid: High cardinality
   {user_id="12345", request_id="abc123"}
   ```

3. **Set appropriate scrape intervals**
   ```
   Fast changing metrics:  5s - 10s
   Normal metrics:         15s - 30s
   Slow changing:          1m - 5m
   ```

4. **Use recording rules for frequent queries**
   ```yaml
   - record: app:requests:rate5m
     expr: rate(http_requests_total[5m])
   ```

5. **Set retention periods appropriately**
   ```
   30 days: Typical production
   7 days:  Limited storage
   90 days: Long-term analysis
   ```

---

## 📚 Key Takeaways

1. ✅ Prometheus is a pull-based metrics system
2. ✅ Time-series storage for scalability
3. ✅ PromQL for powerful queries
4. ✅ Multi-dimensional metrics with labels
5. ✅ Recording rules for optimization
6. ✅ Alerting based on thresholds
7. ✅ Exporters extend coverage

---

## 🔗 Next Steps

1. Deploy Prometheus
2. Configure scrape targets
3. Write PromQL queries
4. Create recording rules
5. Set up alerts
6. Visualize with Grafana

