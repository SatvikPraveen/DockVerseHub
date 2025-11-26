# Part 3: Grafana Dashboards & Alerts

## 🎯 Objective

Build custom dashboards in Grafana to visualize application metrics.

## 🔑 Grafana Basics

### Login

- URL: http://localhost:3000
- Username: admin
- Password: admin

### Create Data Source

1. Go to: Configuration → Data Sources
2. Click: "Add data source"
3. Select: Prometheus
4. URL: `http://prometheus:9090`
5. Click: "Save & Test"

## 📊 Build Dashboard

### Step 1: Create New Dashboard

1. Dashboards → New Dashboard
2. Click: "Add new panel"
3. Select: Prometheus data source

### Step 2: Add Panels

Create these panels:

**Panel 1: Request Rate**
- Title: "Requests per Second"
- Query: `rate(app_requests_total[5m])`
- Panel Type: Graph
- Y-Axis Label: "Requests/sec"

**Panel 2: Error Rate**
- Title: "Error Rate (%)"
- Query: `rate(app_errors_total[5m]) / rate(app_requests_total[5m]) * 100`
- Panel Type: Stat
- Thresholds: Warning 1%, Critical 5%

**Panel 3: Latency Percentiles**
- Title: "Response Latency"
- Queries:
  ```promql
  # P50
  histogram_quantile(0.50, rate(app_request_duration_ms_bucket[5m]))
  
  # P95
  histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m]))
  
  # P99
  histogram_quantile(0.99, rate(app_request_duration_ms_bucket[5m]))
  ```
- Panel Type: Graph
- Y-Axis Label: "Latency (ms)"

**Panel 4: Active Requests**
- Title: "Active Requests"
- Query: `app_active_requests`
- Panel Type: Gauge
- Max: 100

**Panel 5: Error Count**
- Title: "Total Errors"
- Query: `increase(app_errors_total[5m])`
- Panel Type: Stat
- Color Scheme: Red for > 0

### Step 3: Add Variables (Templating)

Variables allow filtering dashboards dynamically.

1. Dashboard Settings → Variables → Add Variable
2. Name: `time_range`
3. Type: Interval
4. Values: 5m, 15m, 1h, 6h

Use in queries:
```promql
rate(app_requests_total[$time_range])
```

## 🚨 Alerting Setup

### Add Alert to Panel

1. Edit Panel → Alert tab
2. Alert Conditions:
   ```
   WHEN: last() OF query (A)
   IS ABOVE: 5
   FOR: 5m
   ```
3. Click: "Create Alert"

### Configure Alert Channels

1. Alerting → Notification channels
2. New channel:
   - Type: Email
   - Email: your@email.com
3. Click: "Send Test"

## 📝 Exercise: Build Performance Dashboard

### Task

Create a comprehensive performance dashboard with:

1. **Row 1: Overview**
   - Current request rate
   - Current error count
   - Current active connections

2. **Row 2: Performance**
   - P50, P95, P99 latency
   - Histogram of response times

3. **Row 3: Health**
   - Error rate percentage
   - Success rate gauge
   - Uptime calculation

### Sample Dashboard JSON

Save as `dashboard.json`:

```json
{
  "dashboard": {
    "title": "Application Performance",
    "timezone": "browser",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [{"expr": "rate(app_requests_total[5m])"}],
        "type": "graph",
        "gridPos": {"x": 0, "y": 0, "w": 8, "h": 8}
      },
      {
        "title": "Error Rate %",
        "targets": [{"expr": "rate(app_errors_total[5m])/rate(app_requests_total[5m])*100"}],
        "type": "stat",
        "gridPos": {"x": 8, "y": 0, "w": 8, "h": 8}
      }
    ]
  },
  "overwrite": true
}
```

Import:
1. Dashboards → Import
2. Paste JSON
3. Select Prometheus data source
4. Click: Import

## 📈 Dashboard Best Practices

1. **Organize by concern**
   - Row 1: Traffic
   - Row 2: Performance
   - Row 3: Errors

2. **Use consistent time ranges**
   - Use variables for flexibility
   - 5m for real-time, 1h for trends

3. **Color coding**
   - Green: OK
   - Yellow: Warning
   - Red: Critical

4. **Units matter**
   - ms for latency
   - bytes for memory
   - % for rates

## ✅ Verification Steps

1. Access: http://localhost:3000/d/observability
2. Verify all panels display data
3. Change time range - should update
4. Check threshold colors (red when critical)

## 🧪 Load Testing & Observation

Generate load to see dashboard update:

```bash
# Terminal 1: Continuous normal traffic
bash scripts/demo.sh 120

# Terminal 2: Watch dashboard
open http://localhost:3000
```

Watch metrics change in real-time!

## 📋 Exercise Summary

Complete these tasks:

- [ ] Login to Grafana (admin/admin)
- [ ] Add Prometheus data source
- [ ] Create 5-panel dashboard
- [ ] Add variables for time range
- [ ] Create alert on error rate
- [ ] Test alert notification
- [ ] Set dashboard to auto-refresh

---

## Next Steps

Proceed to **Part 4: Distributed Tracing with Jaeger**

