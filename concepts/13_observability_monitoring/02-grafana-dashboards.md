# Grafana: Visualization & Dashboards

**Duration:** 1.5 hours | **Level:** Advanced

---

## 🎯 What is Grafana?

Grafana is an open-source visualization and alerting platform that works with time-series data sources like Prometheus.

**Key Features:**
- Rich dashboarding capabilities
- Multiple data source support
- Variable templating
- Alerting and notifications
- User and team management
- Provisioning and automation
- Plugin ecosystem

---

## 🏗️ Architecture

```
Data Sources          Grafana           Outputs
├─ Prometheus    →  ├─ API       →  ├─ UI/Dashboards
├─ Elasticsearch →  ├─ Database   →  ├─ Webhooks
├─ InfluxDB     →  ├─ Alert      →  ├─ Email
└─ CloudWatch  →  └─ Renderer   →  └─ Notifications
```

---

## 📦 Installation

### Docker

```bash
docker run -d \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -v grafana-storage:/var/lib/grafana \
  grafana/grafana:latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        volumeMounts:
        - name: storage
          mountPath: /var/lib/grafana
      volumes:
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
spec:
  selector:
    app: grafana
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

---

## 🔧 Configuration

### Add Prometheus Data Source

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
```

### Provisioning

```yaml
# provisioning/datasources/datasources.yaml
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus:9090
  access: proxy
  isDefault: true
  
- name: Elasticsearch
  type: elasticsearch
  url: http://elasticsearch:9200
  access: proxy
  database: logs
```

---

## 📊 Dashboard Creation

### Panel Types

1. **Graph**: Time-series visualization
2. **Stat**: Single value display
3. **Gauge**: Dial/meter display
4. **Heatmap**: 2D distribution
5. **Table**: Tabular data
6. **Text**: Static text/markdown
7. **Logs**: Log viewer
8. **Trace**: Distributed traces

### Creating a Dashboard

```json
{
  "dashboard": {
    "title": "Application Performance",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{ method }}"
          }
        ],
        "type": "graph",
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "legendFormat": "Errors"
          }
        ],
        "type": "graph",
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      },
      {
        "title": "P95 Latency",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(request_latency_bucket[5m]))",
            "legendFormat": "P95"
          }
        ],
        "type": "stat",
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 0,
          "y": 8
        }
      }
    ]
  }
}
```

---

## 🔢 Variables (Templating)

### Label Values Variable

```yaml
# Template variable for selecting environment
{
  "name": "environment",
  "type": "query",
  "datasource": "Prometheus",
  "query": "label_values(http_requests_total, environment)",
  "multi": false,
  "current": {
    "text": "prod",
    "value": "prod"
  }
}
```

### Custom Variable

```yaml
{
  "name": "time_range",
  "type": "custom",
  "options": [
    {"text": "5 minutes", "value": "5m"},
    {"text": "1 hour", "value": "1h"},
    {"text": "24 hours", "value": "24h"}
  ],
  "current": {
    "text": "1 hour",
    "value": "1h"
  }
}
```

### Using Variables in Queries

```promql
# Use $environment variable
rate(http_requests_total{environment="$environment"}[5m])

# Use $time_range variable
rate(http_requests_total[$time_range])

# Multiple values with regex
rate(http_requests_total{pod=~"$pod.*"}[5m])
```

---

## 📋 Common Dashboard Patterns

### Application Performance Dashboard

```json
{
  "panels": [
    {
      "title": "Request Rate (req/s)",
      "targets": [{
        "expr": "rate(http_requests_total[5m])"
      }]
    },
    {
      "title": "Error Rate (%)",
      "targets": [{
        "expr": "100 * rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])"
      }]
    },
    {
      "title": "P50 Latency (ms)",
      "targets": [{
        "expr": "histogram_quantile(0.50, rate(request_latency_bucket[5m])) * 1000"
      }]
    },
    {
      "title": "P95 Latency (ms)",
      "targets": [{
        "expr": "histogram_quantile(0.95, rate(request_latency_bucket[5m])) * 1000"
      }]
    },
    {
      "title": "P99 Latency (ms)",
      "targets": [{
        "expr": "histogram_quantile(0.99, rate(request_latency_bucket[5m])) * 1000"
      }]
    }
  ]
}
```

### Infrastructure Dashboard

```json
{
  "panels": [
    {
      "title": "CPU Usage (%)",
      "targets": [{
        "expr": "100 * (1 - avg without (cpu) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])))"
      }]
    },
    {
      "title": "Memory Usage (%)",
      "targets": [{
        "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))"
      }]
    },
    {
      "title": "Disk Usage (%)",
      "targets": [{
        "expr": "100 * (node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes"
      }]
    },
    {
      "title": "Network In (bytes/s)",
      "targets": [{
        "expr": "rate(node_network_receive_bytes_total[5m])"
      }]
    }
  ]
}
```

---

## 🚨 Alerting

### Create Alert in Panel

```json
{
  "alert": {
    "name": "High Error Rate",
    "conditions": [
      {
        "evaluator": {
          "params": [0.05],
          "type": "gt"
        },
        "operator": {
          "type": "and"
        },
        "query": {
          "params": ["A", "5m", "now"]
        },
        "type": "query"
      }
    ],
    "for": "5m",
    "frequency": "1m",
    "message": "Error rate is high"
  }
}
```

### Alert Notifications

```yaml
# alerting/channels.yaml
notificationChannels:
- name: Slack
  type: slack
  settings:
    url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL

- name: Email
  type: email
  settings:
    addresses:
      - ops-team@example.com

- name: PagerDuty
  type: pagerduty
  settings:
    integrationKey: YOUR_KEY
```

---

## 🔄 Provisioning

### Dashboard Provisioning

```yaml
# provisioning/dashboards/dashboards.yaml
apiVersion: 1
providers:
- name: dashboards
  type: file
  updateIntervalSeconds: 10
  allowUiUpdates: true
  options:
    path: /etc/grafana/provisioned/dashboards
```

### Complete Setup

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
data:
  app-dashboard.json: |
    {
      "dashboard": {
        "title": "Application Overview",
        "panels": [...]
      }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-provisioning
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: dashboards
      type: file
      path: /etc/grafana/provisioned/dashboards
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
```

---

## 🎨 Visualization Best Practices

### 1. Use Appropriate Chart Types

```
Time-series → Graph
Single value → Stat/Gauge
Categories → Bar chart
Distribution → Heatmap
Logs → Logs panel
Traces → Trace view
```

### 2. Color Coding

```
Success → Green
Warning → Yellow
Critical → Red
Info → Blue
Neutral → Gray
```

### 3. Units and Formatting

```
{unitFormatter: "short"}         # 1K, 1M, 1B
{unitFormatter: "percentunit"}   # 0.0 - 1.0
{unitFormatter: "bytes"}         # 1KB, 1MB, 1GB
{unitFormatter: "ms"}            # Milliseconds
{unitFormatter: "ops"}           # Operations
```

---

## 🏪 Dashboard Examples

### Simple Stat Panels

```json
{
  "panels": [
    {
      "title": "Uptime",
      "type": "stat",
      "targets": [{
        "expr": "up{job=\"app\"}"
      }],
      "options": {
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {"color": "red", "value": null},
            {"color": "green", "value": 1}
          ]
        }
      }
    }
  ]
}
```

### Multi-Series Graph

```json
{
  "panels": [
    {
      "title": "Request Rate by Status",
      "type": "graph",
      "targets": [
        {
          "expr": "rate(http_requests_total{status=\"200\"}[5m])",
          "legendFormat": "200 OK"
        },
        {
          "expr": "rate(http_requests_total{status=\"500\"}[5m])",
          "legendFormat": "500 Error"
        },
        {
          "expr": "rate(http_requests_total{status=\"404\"}[5m])",
          "legendFormat": "404 Not Found"
        }
      ]
    }
  ]
}
```

---

## 🚀 Best Practices

1. **Keep dashboards focused**
   - One dashboard = one concern
   - 5-8 panels per dashboard

2. **Use meaningful titles**
   ```
   Good: "Error Rate (%) - Last 1 Hour"
   Avoid: "Query A"
   ```

3. **Set appropriate time ranges**
   - Real-time: 5m
   - Trending: 1h - 24h
   - Long-term: 7d - 30d

4. **Use annotations for events**
   ```json
   {
     "annotations": {
       "deployment": {
         "datasource": "Prometheus",
         "expr": "changes(app_version[1m]) > 0"
       }
     }
   }
   ```

5. **Implement SLO dashboards**
   - Error budget tracking
   - SLO compliance
   - Alert thresholds

---

## 📚 Key Takeaways

1. ✅ Grafana visualizes time-series data
2. ✅ Multiple data sources supported
3. ✅ Powerful templating for reusability
4. ✅ Alerting built-in
5. ✅ Provisioning for automation
6. ✅ Rich visualization options

---

## 🔗 Next Steps

1. Deploy Grafana with Prometheus
2. Create custom dashboards
3. Set up alerting
4. Use variables for templating
5. Explore plugins

