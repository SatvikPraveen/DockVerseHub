# Service Level Objectives (SLO) & Indicators

**Duration:** 1 hour | **Level:** Advanced

---

## 🎯 SLO Fundamentals

### Definitions

**Service Level Objective (SLO)**: A target level of service you want to achieve
- Example: "99.9% uptime"
- Example: "P95 latency < 100ms"

**Service Level Indicator (SLI)**: A measurement of your service's behavior
- Example: "Request success rate"
- Example: "API response time"

**Service Level Agreement (SLA)**: A contract with customers about service levels
- Legal agreement with penalties for missing SLOs

### Relationship

```
SLA (Contract)
  └─ Defines SLO targets
      └─ Measured by SLI
          └─ Monitored continuously
```

---

## 📊 SLI Categories

### 1. Availability

**Definition**: Percentage of time service is accessible

```promql
# Good requests / Total requests
rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])
```

**Target**: 99.9% (allow ~43 seconds downtime per day)

### 2. Latency

**Definition**: How fast requests are processed

```promql
# P95 latency threshold
histogram_quantile(0.95, rate(request_latency_bucket[5m])) < 0.1
```

**Target**: P95 < 100ms

### 3. Throughput

**Definition**: Request capacity

```promql
# Requests per second
rate(http_requests_total[5m])
```

**Target**: >= 1000 req/s

### 4. Durability

**Definition**: Data persistence

```promql
# Successful data writes
rate(data_write_success_total[5m]) / rate(data_write_total[5m])
```

**Target**: 99.99% write success

---

## 💰 Error Budget

### Concept

You have a "budget" of acceptable errors based on your SLO.

```
SLO: 99.9% uptime
Maximum downtime budget: 0.1% = 8.76 hours per year

Monthly breakdown:
- Available: 720 hours
- Budget: 0.72 hours (43 minutes)
- Max downtime: 43 minutes per month
```

### Calculation

```
Error budget = (1 - SLO%) * Total time period

Examples:
99.0% SLO for 30 days = 1% * 43200 min = 432 minutes
99.9% SLO for 30 days = 0.1% * 43200 min = 43.2 minutes
99.99% SLO for 30 days = 0.01% * 43200 min = 4.32 minutes
```

### Budget Tracking

```yaml
# Calculate remaining budget
budget_remaining = (1 - error_rate) * time_period - incident_duration
is_within_budget = budget_remaining > 0

# Alert when approaching exhaustion
alert: ErrorBudgetLow
  if: budget_remaining < 10%
```

---

## 🎯 SLO Definition Process

### Step 1: Identify Critical User Journeys

```yaml
user_journeys:
  - name: Signup
    critical: true
    acceptable_latency: 500ms
  
  - name: Login
    critical: true
    acceptable_latency: 200ms
  
  - name: View Dashboard
    critical: true
    acceptable_latency: 1000ms
```

### Step 2: Define SLIs

```yaml
slis:
  availability:
    definition: "Requests returning 2xx or 3xx"
    metric: http_requests_total{status=~"2|3"}
    
  latency:
    definition: "P95 response time"
    metric: request_latency_bucket
    
  error_rate:
    definition: "Requests not returning 5xx"
    metric: http_requests_total{status=~"5"}
```

### Step 3: Set SLO Targets

```yaml
slos:
  availability:
    target: 99.9%
    window: 30-day rolling
    
  latency:
    p50: 50ms
    p95: 100ms
    p99: 500ms
    window: 30-day rolling
    
  error_budget:
    monthly: 43.2 minutes of downtime
```

### Step 4: Implement Monitoring

```yaml
prometheus_rules.yaml

groups:
- name: slo
  rules:
  - record: sli:availability:rate5m
    expr: rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m])
  
  - record: sli:latency:p95
    expr: histogram_quantile(0.95, rate(request_latency_bucket[5m]))
  
  - alert: ErrorBudgetExhausted
    expr: sli:availability:rate5m < 0.999
    for: 5m
    annotations:
      summary: "Error budget exhausted"
```

---

## 📈 SLO Dashboard

### Grafana Configuration

```json
{
  "dashboard": {
    "title": "SLO Dashboard",
    "panels": [
      {
        "title": "Error Budget Remaining (%)",
        "targets": [{
          "expr": "((slo:availability:target - sli:availability:rate) / slo:availability:target) * 100"
        }],
        "type": "gauge"
      },
      {
        "title": "Availability SLI",
        "targets": [{
          "expr": "sli:availability:rate5m"
        }],
        "type": "graph"
      },
      {
        "title": "Latency SLI (P95)",
        "targets": [{
          "expr": "sli:latency:p95 * 1000"
        }],
        "type": "graph"
      },
      {
        "title": "Monthly Incidents",
        "targets": [{
          "expr": "count(incident_start_time)"
        }],
        "type": "stat"
      }
    ]
  }
}
```

---

## 🚨 Alerting Strategy

### Alert Levels

```yaml
alerts:
  # Critical: SLO breach
  - name: SLOBreach
    condition: sli:availability:rate < 0.999
    for: 5m
    severity: critical
    
  # Warning: Approaching exhaustion
  - name: ErrorBudgetLow
    condition: error_budget_remaining < 5%
    for: 10m
    severity: warning
    
  # Advisory: Trend analysis
  - name: ErrorBudgetTrend
    condition: error_budget_remaining < 10%
    for: 30m
    severity: info
```

### Multi-SLO Alert

```yaml
- alert: MultipleObjectivesBreached
  expr: |
    (sli:availability:rate < 0.999) and
    (sli:latency:p95 > 0.1) and
    (sli:error_rate > 0.01)
  for: 5m
  annotations:
    summary: "Multiple SLOs breached"
    action: "Page on-call engineer"
```

---

## 📊 Example: E-Commerce Platform

### SLO Tiers

```yaml
services:
  checkout:
    priority: critical
    availability_slo: 99.99%  # 4 minutes per month
    latency_slo_p95: 200ms
    error_rate_slo: 0.01%
    
  search:
    priority: high
    availability_slo: 99.9%   # 43 minutes per month
    latency_slo_p95: 500ms
    error_rate_slo: 0.1%
    
  recommendations:
    priority: medium
    availability_slo: 99%     # 7.2 hours per month
    latency_slo_p95: 1000ms
    error_rate_slo: 0.5%
```

### PromQL Queries

```promql
# Checkout availability
rate(checkout_requests_total{status=~"2.."}[5m]) / rate(checkout_requests_total[5m])

# Search latency
histogram_quantile(0.95, rate(search_request_duration_bucket[5m]))

# Error rate comparison
rate(api_errors_total[5m]) / rate(api_requests_total[5m])
```

---

## 🔄 Incident Response

### Error Budget Depletion Protocol

```
1. SLO Breach Detected
   ├─ Alert triggered
   ├─ On-call engineer paged
   └─ Incident started
   
2. Investigation
   ├─ Root cause analysis
   ├─ Impact assessment
   └─ Remediation planning
   
3. Mitigation
   ├─ Emergency fix deployed
   ├─ Service restored
   └─ Error budget reviewed
   
4. Post-Incident
   ├─ RCA document
   ├─ Prevention measures
   └─ SLO adjustment if needed
```

### Post-Mortem Template

```markdown
# Incident Post-Mortem

## Impact
- Duration: 15 minutes
- Error budget consumed: 15/43 minutes (35%)
- Users affected: ~10,000

## Root Cause
- Database connection pool exhausted
- Misconfigured connection timeout

## Timeline
- 14:00 - Alert triggered
- 14:02 - Engineer notified
- 14:05 - Root cause identified
- 14:10 - Fix deployed
- 14:15 - Service restored

## Preventive Actions
- Increase connection pool size
- Add connection pool monitoring
- Implement circuit breaker pattern

## Owner: On-call engineer
```

---

## 🛠️ Implementation Framework

### Prometheus Recording Rules

```yaml
groups:
- name: slo_recording
  interval: 30s
  rules:
  # Availability SLI
  - record: sli:request:availability5m
    expr: |
      sum(rate(http_requests_total{status=~"2.."}[5m]))
      /
      sum(rate(http_requests_total[5m]))
  
  # Latency SLI
  - record: sli:request:latency:p95
    expr: |
      histogram_quantile(0.95, sum(rate(request_duration_bucket[5m])) by (le))
  
  # Error rate SLI
  - record: sli:request:error_rate5m
    expr: |
      sum(rate(http_requests_total{status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total[5m]))
  
  # Error budget tracking
  - record: sli:error_budget:remaining_ratio
    expr: |
      (0.999 - sli:request:availability5m) / 0.001
```

### Alerting Rules

```yaml
groups:
- name: slo_alerting
  rules:
  - alert: SLO_Availability_Breach
    expr: sli:request:availability5m < 0.999
    for: 5m
    annotations:
      summary: "Availability SLO breach detected"
      runbook: "http://wiki/runbooks/slo-breach"
  
  - alert: SLO_Latency_Breach
    expr: sli:request:latency:p95 > 0.1
    for: 10m
    annotations:
      summary: "Latency SLO breach detected"
      runbook: "http://wiki/runbooks/latency-breach"
```

---

## 📚 Best Practices

1. **Start conservative**
   - 99% SLO initially
   - Increase after consistent compliance

2. **Align with business**
   - Different SLOs for different services
   - Match customer expectations

3. **Use error budgets**
   - Allocate for deployments
   - Use for feature development speed

4. **Monitor continuously**
   - Real-time dashboards
   - Automated alerting

5. **Review regularly**
   - Monthly SLO reviews
   - Adjust based on incidents

---

## 📚 Key Takeaways

1. ✅ SLO defines service targets
2. ✅ SLI measures actual performance
3. ✅ Error budgets quantify acceptable downtime
4. ✅ User-centric SLO definition
5. ✅ Proactive monitoring and alerting
6. ✅ Incident response processes

---

## 🔗 Next Steps

1. Define critical user journeys
2. Identify appropriate SLIs
3. Set SLO targets with stakeholders
4. Implement monitoring
5. Create dashboards and alerts
6. Review and iterate

