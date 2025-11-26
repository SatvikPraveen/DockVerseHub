# Part 5: Incident Response & Alerts

## 🎯 Objective

Respond to alerts, identify root causes, and implement fixes.

## 🚨 Alert Lifecycle

```
Metric Crosses Threshold
  ↓
Alert Triggered
  ↓
Notification Sent
  ↓
Engineer Notified
  ↓
Investigation Starts (RCA)
  ↓
Root Cause Found
  ↓
Fix Deployed
  ↓
Verified Resolved
  ↓
Post-Mortem
```

## ⚠️ Setting Up Alerts

### Prometheus Alert Rules

Create `alert-rules.yml`:

```yaml
groups:
- name: application_slos
  rules:
  # Critical: Availability breach
  - alert: AvailabilityBreach
    expr: |
      (sum(rate(app_errors_total[5m])) / sum(rate(app_requests_total[5m])))
      > 0.01
    for: 2m
    labels:
      severity: critical
      slo: availability
    annotations:
      summary: "Availability SLO breached ({{ $value | humanizePercentage }})"
      runbook: "https://wiki/runbooks/availability-breach"
  
  # Warning: High latency
  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m])) > 500
    for: 5m
    labels:
      severity: warning
      slo: latency
    annotations:
      summary: "P95 latency high ({{ $value }}ms)"
      runbook: "https://wiki/runbooks/high-latency"
  
  # Critical: Service down
  - alert: ServiceDown
    expr: up{job="app"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service is down"
      runbook: "https://wiki/runbooks/service-down"
```

## 🎓 Exercise 1: Incident Investigation

### Simulated Incident

Your application suddenly has:
- High error rate (5%+)
- Slow responses (P95 > 1s)
- Active requests stuck

### Investigation Steps

**Step 1: Verify Alert in Prometheus**
```
Alerts tab → Find active alerts
Check: AvailabilityBreach, HighLatency
```

**Step 2: Check Grafana Dashboard**
```
View metrics:
- Error rate % (should be red)
- Latency trend (should spike)
- Active requests (stuck high)
```

**Step 3: Analyze Traces in Jaeger**
```
Jaeger → Find slow/error traces
Trace timeline shows which operation failed
```

**Step 4: Root Cause Options**

Common causes:

A) **Database Issue**
   - Slow query
   - Connection pool exhausted
   - Disk space full

B) **Resource Exhaustion**
   - CPU 100%
   - Memory out
   - Network saturation

C) **Bad Deployment**
   - Bug in code
   - Configuration wrong
   - Dependency unavailable

### Determine Root Cause

Look for clues in:
- Span duration (slow operations)
- Span attributes (error messages)
- System metrics (CPU, memory)
- Recent deployments

## 📝 Exercise 2: Root Cause Analysis (RCA)

### RCA Template

```markdown
# Incident Report

## Timeline
- 14:00 - Alert triggered
- 14:02 - On-call notified
- 14:05 - Investigation started
- 14:10 - Root cause identified
- 14:15 - Fix deployed
- 14:20 - Verified resolved

## Impact
- Duration: 20 minutes
- Error budget consumed: 20/43 minutes (46%)
- Users affected: ~5,000

## Root Cause
[Describe what went wrong]

## Timeline of Events
1. ...
2. ...
3. ...

## Contributing Factors
- [Factor 1]
- [Factor 2]

## Resolution
[How was it fixed?]

## Prevention
[How to avoid next time?]
```

## 🔧 Recovery Actions

### For High Error Rate

```bash
# Check error logs
docker-compose logs api | grep -i error

# Check database
docker-compose exec redis redis-cli ping

# Restart service
docker-compose restart api
```

### For High Latency

```bash
# Check database query performance
# (Would query slow_log in real database)

# Check system resources
docker stats

# Reduce load (if needed)
# or scale out (add more instances)
```

### For Service Down

```bash
# Check if container crashed
docker-compose ps

# View logs
docker-compose logs api

# Restart
docker-compose restart api

# If it keeps crashing, investigate logs
```

## 📊 Error Budget Tracking

### Calculate Remaining Budget

For 99.9% SLO (monthly):
- Total downtime allowed: 43.2 minutes
- Incident duration: 20 minutes
- Remaining budget: 23.2 minutes

Percentage used: 20/43.2 = 46%

### Action Items

```
< 25% used: Safe to proceed with testing
25-50% used: Careful with deployments
50-75% used: Hold major changes
> 75% used: Emergency mode only
```

## 🎯 Exercise 3: Incident Simulation

### Task

Simulate and respond to an incident:

**Step 1: Trigger High Error Rate**
```bash
# Start generating errors
for i in {1..100}; do
  curl http://localhost:5000/api/error &
done
```

**Step 2: Wait for Alert**
```
Watch Prometheus Alerts tab
Should see: AvailabilityBreach alert
```

**Step 3: Investigate**
```
- Check error rate in dashboard
- Find error traces in Jaeger
- Identify operation causing errors
```

**Step 4: Find Root Cause**
```
Analysis: /api/error endpoint always returns 500
This is expected behavior (test endpoint)
```

**Step 5: Recover**
```
Stop error generation (Ctrl+C)
Wait for alert to clear (2+ minutes)
Verify error rate returns to normal
```

**Step 6: Post-Mortem**
```
What happened: Error endpoint intentionally triggered errors
Why: Lab exercise to test alerting
Impact: 1-2% error rate for 2 minutes
Prevention: Disable test endpoints in production
```

## 🎓 Incident Response Best Practices

1. **Stay calm** - Rushing causes more mistakes
2. **Document timeline** - When did events happen?
3. **Don't assume** - Verify with data
4. **Root cause** - Find why, not just what
5. **Prevention** - How to avoid next time?
6. **Post-mortem** - Team learns from incident

## 📋 SLO Compliance

Track monthly:

```
Date     | Alert | Downtime | Budget Used | Remaining
---------|-------|----------|-------------|----------
Week 1   | 0     | 0min     | 0%          | 100%
Week 2   | 1     | 10min    | 23%         | 77%
Week 3   | 2     | 20min    | 46%         | 54%
Week 4   | 0     | 0min     | 46%         | 54%
```

## ✅ Verification Steps

1. Alert rules loaded in Prometheus
2. Can view alerts in Alerts tab
3. Generated test incidents
4. Successfully investigated
5. Identified root causes
6. Documented findings

## 📋 Exercise Summary

Complete these tasks:

- [ ] Set up alert rules in Prometheus
- [ ] Simulate high error rate
- [ ] Verify alert triggered
- [ ] Investigate with Grafana
- [ ] Analyze traces in Jaeger
- [ ] Identify root cause
- [ ] Calculate error budget used
- [ ] Complete RCA document

---

## Conclusion

You've completed observability stack labs! You can now:

✅ Deploy complete observability infrastructure
✅ Collect and query metrics
✅ Build dashboards
✅ Debug with traces
✅ Respond to incidents
✅ Track SLO compliance

## Next Steps for Production

1. **Scale Prometheus** - Add persistent storage
2. **Cluster Jaeger** - Deploy for high volume
3. **Automate Alerts** - PagerDuty, Slack integration
4. **Custom Dashboards** - Build team-specific views
5. **SLO Automation** - Integrate error budgets in CI/CD

