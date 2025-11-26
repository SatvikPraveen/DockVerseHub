# Part 2: Prometheus Metrics Collection

## 🎯 Objective

Learn to collect, query, and analyze metrics using Prometheus.

## 📊 Understanding Prometheus Architecture

Prometheus works in these steps:
1. **Scrape** - Collect metrics from targets
2. **Store** - Save time-series data
3. **Query** - Search using PromQL
4. **Alert** - Trigger on conditions

## 🔧 Configure Prometheus

### View Current Configuration

```bash
# Access Prometheus UI
open http://localhost:9090

# Go to: Status → Configuration
# You'll see all scrape targets
```

### Key Metrics from Application

The API exports these metrics:
- `app_requests_total` - Total requests
- `app_request_duration_ms` - Latency histogram
- `app_active_requests` - Currently processing
- `app_errors_total` - Error count

## 📈 PromQL Queries

### Exercise 1: Basic Queries

Access Prometheus UI → Graph

1. **Current Request Rate**
   ```promql
   rate(app_requests_total[5m])
   ```
   - Shows requests per second over last 5 minutes

2. **Total Requests Since Start**
   ```promql
   app_requests_total
   ```
   - Shows cumulative count

3. **Error Rate**
   ```promql
   rate(app_errors_total[5m])
   ```
   - Errors per second

4. **Active Requests**
   ```promql
   app_active_requests
   ```
   - Currently processing requests

### Exercise 2: Advanced Queries

1. **Success Percentage**
   ```promql
   100 * (1 - rate(app_errors_total[5m]) / rate(app_requests_total[5m]))
   ```

2. **P95 Latency**
   ```promql
   histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m]))
   ```

3. **Top 3 Slowest Endpoints**
   ```promql
   topk(3, rate(app_request_duration_ms_bucket{le="+Inf"}[5m]))
   ```

4. **Error Budget Remaining** (99% SLO)
   ```promql
   (99 - (rate(app_errors_total[5m]) / rate(app_requests_total[5m]) * 100))
   ```

## 🔄 Generate Test Load

```bash
# Terminal 1: Generate continuous load
while true; do
  curl http://localhost:5000/api/data
  curl http://localhost:5000/api/slow
  sleep 1
done

# Terminal 2: Generate some errors
while true; do
  curl http://localhost:5000/api/error
  sleep 2
done

# Terminal 3: Query metrics
curl 'http://localhost:9090/api/v1/query?query=rate(app_requests_total[5m])'
```

## 📝 Hands-On Exercise

### Exercise 3: Create Recording Rules

Recording rules pre-compute frequently used queries.

Create file `prometheus-recording-rules.yml`:

```yaml
groups:
- name: observability_demo
  interval: 30s
  rules:
  # Availability
  - record: sli:availability:rate5m
    expr: |
      sum(rate(app_requests_total{status="200"}[5m]))
      /
      sum(rate(app_requests_total[5m]))
  
  # P95 Latency
  - record: sli:latency:p95
    expr: histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m]))
  
  # Error Rate
  - record: sli:error_rate:5m
    expr: |
      sum(rate(app_errors_total[5m]))
      /
      sum(rate(app_requests_total[5m]))
```

Mount in docker-compose.yml and verify rules are loaded:
- Prometheus UI → Alerts → Rules

## 🚨 Alerting Rules

Create `prometheus-alert-rules.yml`:

```yaml
groups:
- name: observability_alerts
  rules:
  - alert: HighErrorRate
    expr: sli:error_rate:5m > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Error rate is high"
      description: "Error rate {{ $value | humanizePercentage }} > 5%"
  
  - alert: HighLatency
    expr: sli:latency:p95 > 500
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "P95 latency is high"
      description: "P95 latency {{ $value }}ms > 500ms"
  
  - alert: LowAvailability
    expr: sli:availability:rate5m < 0.99
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Availability SLO breach"
      description: "Availability {{ $value | humanizePercentage }} < 99%"
```

## ✅ Verification Steps

1. Access Prometheus: http://localhost:9090
2. Go to Graph tab
3. Enter query: `rate(app_requests_total[5m])`
4. Switch to Graph view
5. See metrics plotted over time

## 📋 Exercise Summary

Complete these tasks:

- [ ] Execute basic PromQL queries
- [ ] Calculate success rate percentage
- [ ] Find P95 latency
- [ ] Generate test load
- [ ] Create recording rules
- [ ] Create alert rules
- [ ] Verify data in graph view

---

## Next Steps

Proceed to **Part 3: Grafana Dashboards**

