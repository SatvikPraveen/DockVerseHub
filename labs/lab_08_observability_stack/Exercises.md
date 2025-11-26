# Hands-On Exercises for Lab 08

Complete the following exercises to solidify your observability knowledge.

## Exercise 1: Stack Verification (15 min)

**Objective:** Verify all components are working

**Task:**
1. Start docker-compose stack
2. Verify all containers running
3. Check each service endpoint
4. Generate initial metrics

**Verification:**
```bash
docker-compose ps
curl http://localhost:5000/health
curl http://localhost:9090/-/healthy
```

**Success Criteria:**
- ✅ All 5 containers running
- ✅ All endpoints return HTTP 200
- ✅ Prometheus scraping targets
- ✅ Grafana UI accessible

---

## Exercise 2: PromQL Queries (30 min)

**Objective:** Master Prometheus querying

**Task 1: Basic Metrics**
- Query total requests: `app_requests_total`
- Query request rate: `rate(app_requests_total[5m])`
- Query error count: `app_errors_total`

**Task 2: Aggregations**
- Sum all requests: `sum(rate(app_requests_total[5m]))`
- By status: `sum(rate(app_requests_total[5m])) by (status)`
- Top 5 endpoints: `topk(5, rate(app_requests_total[5m]) by (endpoint))`

**Task 3: Complex Queries**
- Success rate %: `100 * (1 - rate(app_errors_total[5m]) / rate(app_requests_total[5m]))`
- P95 latency: `histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m]))`

**Success Criteria:**
- ✅ Execute all queries without error
- ✅ Get valid results
- ✅ Understand what each query returns

**Hint:** Use Prometheus UI → Graph to test queries

---

## Exercise 3: Build Grafana Dashboard (45 min)

**Objective:** Create professional monitoring dashboard

**Task:**
1. Create new dashboard "App Monitoring"
2. Add 5 panels:
   - Request Rate (graph)
   - Error Rate % (stat)
   - P95 Latency (graph)
   - Active Requests (gauge)
   - Error Total (stat, red color)

3. Add variables:
   - time_range: 5m, 15m, 1h
   - endpoint: all available endpoints

4. Set auto-refresh to 5 seconds

5. Save dashboard

**Success Criteria:**
- ✅ Dashboard has 5 panels
- ✅ All panels show data
- ✅ Variables work
- ✅ Auto-refresh enabled
- ✅ Dashboard saved

**Tips:**
- Use consistent time ranges across panels
- Color-code critical metrics (red for errors)
- Add descriptive titles

---

## Exercise 4: Trace Analysis (30 min)

**Objective:** Debug using distributed traces

**Task 1: Explore Traces**
1. Open Jaeger UI
2. Select service: observability-demo
3. View 10 recent traces
4. Compare fast vs slow traces

**Task 2: Analyze Request Flow**
```
For GET /api/data request:
- How many spans?
- What's total duration?
- Which span took longest?
- Any span failures?
```

**Task 3: Error Analysis**
```
For GET /api/error requests:
- What error occurs?
- At which span?
- What attributes indicate error?
```

**Success Criteria:**
- ✅ Can navigate Jaeger UI
- ✅ View complete traces
- ✅ Identify slow spans
- ✅ Find error traces
- ✅ Extract span attributes

---

## Exercise 5: Load Testing & Observation (30 min)

**Objective:** See monitoring in action under load

**Task:**
1. In Terminal 1: Generate continuous load
   ```bash
   for i in {1..100}; do
     curl http://localhost:5000/api/data &
   done
   ```

2. In Terminal 2: Watch Grafana
   ```bash
   open http://localhost:3000
   ```

3. Observe dashboard changes:
   - Request rate increases
   - Latency trends
   - Error rate changes
   - Active requests spike

4. In Terminal 3: Check traces
   ```bash
   open http://localhost:16686
   ```

5. Document observations:
   - Peak request rate?
   - Max latency observed?
   - Any errors generated?

**Success Criteria:**
- ✅ Load generated successfully
- ✅ Dashboard metrics update in real-time
- ✅ Traces appear in Jaeger
- ✅ Can correlate metrics with traces

---

## Exercise 6: Alert Configuration (30 min)

**Objective:** Set up automated incident detection

**Task:**
1. Create alert rules file:
   ```yaml
   groups:
   - name: app_alerts
     rules:
     - alert: HighErrorRate
       expr: (rate(app_errors_total[5m])/rate(app_requests_total[5m])) > 0.05
       for: 2m
     - alert: HighLatency
       expr: histogram_quantile(0.95, rate(app_request_duration_ms_bucket[5m])) > 200
       for: 5m
   ```

2. Mount in docker-compose.yml
3. Reload Prometheus
4. Verify alerts show in Alerts tab
5. Trigger alert (generate load/errors)
6. Verify alert fires

**Success Criteria:**
- ✅ Alert rules created
- ✅ Rules loaded in Prometheus
- ✅ Can see in Alerts tab
- ✅ Alert fires when condition met
- ✅ Alert clears when condition resolves

---

## Exercise 7: Incident Simulation (45 min)

**Objective:** Practice incident response

**Scenario:** High error rate spike

**Task 1: Trigger Incident**
```bash
# Generate errors for 2 minutes
for i in {1..50}; do
  curl http://localhost:5000/api/error &
done
sleep 120
```

**Task 2: Detect in Monitoring**
- Alert should fire in Prometheus
- Error rate spikes in Grafana
- Error traces appear in Jaeger

**Task 3: Investigation**
- Check alert status
- View Grafana dashboard
- Analyze error traces in Jaeger
- Identify root cause

**Task 4: Document RCA**
```markdown
# Incident Report

## Detection
- Alert: HighErrorRate fired at [time]
- Error rate: [X]%

## Investigation
- Checked traces in Jaeger
- Found: [error type]
- Root cause: [analysis]

## Timeline
- 14:00 - Incident started
- 14:02 - Alert triggered
- 14:05 - Root cause identified
- 14:20 - Incident resolved

## Impact
- Duration: [X] minutes
- Error budget used: [X]%

## Prevention
- [Action 1]
- [Action 2]
```

**Success Criteria:**
- ✅ Alert fired automatically
- ✅ Dashboard showed spike
- ✅ Traces captured errors
- ✅ RCA completed
- ✅ Identified root cause
- ✅ Prevention measures noted

---

## Exercise 8: SLO Tracking (30 min)

**Objective:** Monitor SLO compliance

**Task:**
1. Define SLOs for your app:
   - Availability: 99%
   - Latency (P95): 200ms
   - Error Rate: < 1%

2. Calculate error budgets:
   ```
   For 30-day month:
   - 99% availability = 7.2 hours downtime allowed
   - If incident used 1 hour, remaining = 6.2 hours
   ```

3. Create tracking dashboard:
   - SLO status (met/breach)
   - Error budget remaining %
   - Monthly incidents count
   - Current status vs target

4. Set alert when budget low:
   ```promql
   error_budget_remaining_percent < 25
   ```

**Success Criteria:**
- ✅ SLOs defined clearly
- ✅ Error budgets calculated
- ✅ Tracking dashboard created
- ✅ Budget alert working

---

## Exercise 9: Dashboard Export & Import (20 min)

**Objective:** Share and backup dashboards

**Task:**
1. Export dashboard as JSON:
   - Dashboard menu → Export → Save as JSON

2. Document dashboard:
   - What metrics it tracks
   - Who should use it
   - How to interpret it

3. Import to different workspace:
   - Dashboards → Import
   - Select JSON file
   - Verify all panels work

**Success Criteria:**
- ✅ Dashboard exported as JSON
- ✅ JSON file valid
- ✅ Can import successfully
- ✅ All panels functional after import

---

## Exercise 10: Production Readiness Check (30 min)

**Objective:** Prepare for production deployment

**Checklist:**
- [ ] Metrics are meaningful
- [ ] Dashboards are clear
- [ ] Alerts are tuned (not too many false positives)
- [ ] Traces capture errors
- [ ] SLOs are defined
- [ ] Runbooks exist
- [ ] Team trained on tools
- [ ] Retention policies set
- [ ] Backups configured
- [ ] Disaster recovery tested

**Document:**
```markdown
# Production Readiness

## Monitoring Infrastructure
- [ ] Prometheus configured for production
- [ ] Grafana dashboards reviewed
- [ ] Jaeger storage configured
- [ ] Alert channels configured

## Data Retention
- Prometheus: [retention period]
- Jaeger traces: [retention period]
- Grafana snapshots: [retention period]

## Alerting
- [ ] Escalation policy defined
- [ ] On-call rotation set up
- [ ] Alert channels tested
- [ ] Runbooks written

## Team Readiness
- [ ] Team trained on monitoring tools
- [ ] RCA process documented
- [ ] Incident response playbook
- [ ] Post-mortem process
```

---

## Summary

After completing all exercises, you'll have:

✅ Fully functional observability stack
✅ Professional-grade dashboards
✅ Working incident detection
✅ Practical troubleshooting experience
✅ Production readiness plan

**Total Time: ~4-5 hours**

**Next Steps:**
1. Review all exercises
2. Deploy to your environment
3. Customize for your services
4. Train your team

