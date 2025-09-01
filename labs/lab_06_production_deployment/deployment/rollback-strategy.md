# Rollback Strategy

**Location**: `labs/lab_06_production_deployment/deployment/rollback-strategy.md`

## 🎯 Overview

This document defines the rollback strategy for production deployments, including triggers, procedures, and decision trees for various failure scenarios.

## 📊 Rollback Decision Matrix

### Automatic Rollback Triggers

| Metric                | Threshold          | Action        | Delay     |
| --------------------- | ------------------ | ------------- | --------- |
| Error Rate            | >5% for 5 min      | Auto rollback | Immediate |
| Response Time         | P95 >2s for 10 min | Auto rollback | Immediate |
| Health Check Failures | >50% for 3 min     | Auto rollback | Immediate |
| Memory Usage          | >90% for 5 min     | Auto rollback | 30s       |
| CPU Usage             | >95% for 10 min    | Auto rollback | 60s       |

### Manual Rollback Triggers

- Security vulnerabilities discovered
- Data corruption detected
- Critical business functionality broken
- Regulatory compliance issues
- Customer-impacting bugs

## 🔄 Rollback Types

### 1. Blue-Green Rollback (Recommended)

#### Process

```bash
# Switch traffic back to blue environment
export ACTIVE_SLOT=blue
docker-compose -f deployment/blue-green.yml up -d traffic-router

# Verify blue environment health
curl -f http://traffic-router/health

# Scale down green environment
docker-compose -f deployment/blue-green.yml --profile green down
```

#### Advantages

- ✅ Instant rollback (DNS/load balancer switch)
- ✅ Zero downtime
- ✅ Full environment isolation
- ✅ Easy validation

#### Timeline: **< 2 minutes**

### 2. Canary Rollback

#### Process

```bash
# Set canary traffic to 0%
export CANARY_TRAFFIC_PERCENT=0
docker-compose -f deployment/canary-deployment.yml restart canary-router

# Stop canary services
docker-compose -f deployment/canary-deployment.yml --profile canary down

# Scale up stable services if needed
docker-compose -f deployment/canary-deployment.yml up -d --scale user-service-stable=3
```

#### Timeline: **< 5 minutes**

### 3. Rolling Rollback

#### Process

```bash
# Rollback services one by one
services=("user-service" "order-service" "notification-service")

for service in "${services[@]}"; do
    echo "Rolling back $service..."

    # Update image tag to previous version
    docker-compose -f docker-compose.prod.yml stop $service
    docker tag $service:latest $service:previous
    docker-compose -f docker-compose.prod.yml up -d $service

    # Wait for health check
    sleep 30

    # Verify service health
    if ! curl -f http://$service:8000/health; then
        echo "Rollback failed for $service"
        exit 1
    fi
done
```

#### Timeline: **5-15 minutes**

## 🚨 Emergency Rollback Procedures

### Immediate Actions (0-5 minutes)

#### 1. Incident Detection

```bash
# Automated monitoring alerts
# Manual issue reports
# Customer complaints

# Stop new deployments immediately
export DEPLOYMENT_FREEZE=true
```

#### 2. Assess Situation

```bash
# Check system health
python3 monitoring/health-checks.py

# Review recent deployments
git log --oneline -10

# Check error rates
curl "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~'5..'}[5m])"
```

#### 3. Execute Rollback

```bash
# Use fastest available method
if [[ "$DEPLOYMENT_TYPE" == "blue-green" ]]; then
    ./scripts/blue-green-rollback.sh
elif [[ "$DEPLOYMENT_TYPE" == "canary" ]]; then
    ./scripts/canary-rollback.sh
else
    ./scripts/rolling-rollback.sh
fi
```

### Communication (0-10 minutes)

#### 4. Incident Declaration

```bash
# Send automated notifications
./scripts/incident-notification.sh --severity=high --type=rollback

# Update status page
curl -X POST "https://api.statuspage.io/v1/pages/PAGE_ID/incidents" \
    -H "Authorization: OAuth ACCESS_TOKEN" \
    -d "incident[name]=Service Degradation - Rolling Back" \
    -d "incident[status]=investigating"
```

## 🛠️ Rollback Scripts

### Blue-Green Rollback Script

```bash
#!/bin/bash
# scripts/blue-green-rollback.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Get current active slot
CURRENT_SLOT=$(docker-compose -f deployment/blue-green.yml exec traffic-router printenv ACTIVE_SLOT || echo "blue")
TARGET_SLOT=$([[ "$CURRENT_SLOT" == "blue" ]] && echo "green" || echo "blue")

log "Starting rollback from $CURRENT_SLOT to $TARGET_SLOT"

# Health check target environment
log "Checking $TARGET_SLOT environment health..."
if ! curl -f "http://${TARGET_SLOT}-environment/health" --max-time 10; then
    log "ERROR: Target environment $TARGET_SLOT is not healthy"
    exit 1
fi

# Switch traffic
log "Switching traffic to $TARGET_SLOT environment"
export ACTIVE_SLOT=$TARGET_SLOT
docker-compose -f deployment/blue-green.yml up -d traffic-router

# Verify switch
sleep 10
if curl -f http://traffic-router/health --max-time 10; then
    log "SUCCESS: Rollback completed to $TARGET_SLOT"

    # Send success notification
    ./scripts/notification.sh --message "Rollback completed successfully to $TARGET_SLOT environment"

    # Scale down old environment after 5 minutes
    (sleep 300 && docker-compose -f deployment/blue-green.yml --profile $CURRENT_SLOT down) &
else
    log "ERROR: Rollback verification failed"
    exit 1
fi
```

### Database Rollback Script

```bash
#!/bin/bash
# scripts/database-rollback.sh

set -euo pipefail

ROLLBACK_POINT="$1"  # Migration version or timestamp
SERVICE="$2"         # user-service, order-service

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

case "$SERVICE" in
    "user-service")
        DATABASE="userdb"
        CONTAINER="postgres-user"
        ;;
    "order-service")
        DATABASE="orderdb"
        CONTAINER="postgres-order"
        ;;
    *)
        log "ERROR: Unknown service $SERVICE"
        exit 1
        ;;
esac

log "Rolling back $SERVICE database to $ROLLBACK_POINT"

# Stop application service
docker-compose -f docker-compose.prod.yml stop $SERVICE

# Create rollback backup
BACKUP_FILE="/tmp/${DATABASE}_rollback_backup_$(date +%Y%m%d_%H%M%S).sql"
docker-compose -f docker-compose.prod.yml exec $CONTAINER pg_dump -U ${DATABASE}_user $DATABASE > $BACKUP_FILE
log "Created rollback backup: $BACKUP_FILE"

# Execute rollback
if [[ "$ROLLBACK_POINT" =~ ^[0-9]+$ ]]; then
    # Migration version rollback
    docker-compose -f docker-compose.prod.yml exec $CONTAINER migrate -path /migrations -database postgresql://${DATABASE}_user:password@localhost/$DATABASE down $ROLLBACK_POINT
else
    # Point-in-time rollback
    log "Point-in-time rollback not implemented yet"
    exit 1
fi

# Restart service
docker-compose -f docker-compose.prod.yml start $SERVICE

# Verify service health
sleep 30
if curl -f http://$SERVICE:8000/health; then
    log "SUCCESS: Database rollback completed"
else
    log "ERROR: Service unhealthy after rollback"
    exit 1
fi
```

## 📋 Rollback Checklist

### Pre-Rollback (2-5 minutes)

- [ ] **Incident confirmed** and severity assessed
- [ ] **Rollback authorized** by on-call engineer or manager
- [ ] **Target version identified** and validated
- [ ] **Team notified** of rollback initiation
- [ ] **Status page updated** to "Investigating"

### During Rollback (5-15 minutes)

- [ ] **Stop new deployments** across all environments
- [ ] **Execute rollback procedure** per deployment type
- [ ] **Monitor key metrics** during rollback
- [ ] **Verify health checks** pass on rolled-back version
- [ ] **Test critical user journeys** (smoke tests)
- [ ] **Update status page** to "Monitoring"

### Post-Rollback (15-60 minutes)

- [ ] **Confirm system stability** for 30+ minutes
- [ ] **Run comprehensive tests** on critical functionality
- [ ] **Check data integrity** and consistency
- [ ] **Update status page** to "Resolved"
- [ ] **Send post-incident communication** to stakeholders
- [ ] **Schedule post-mortem meeting** within 24 hours

## 🔍 Rollback Validation

### Health Check Validation

```bash
#!/bin/bash
# scripts/validate-rollback.sh

services=("user-service" "order-service" "notification-service")
external_endpoints=("https://your-domain.com/health" "https://your-domain.com/api/v1/users/health")

# Check internal services
for service in "${services[@]}"; do
    if curl -f "http://$service:8000/health" --max-time 10; then
        echo "✅ $service healthy"
    else
        echo "❌ $service unhealthy"
        exit 1
    fi
done

# Check external endpoints
for endpoint in "${external_endpoints[@]}"; do
    if curl -f "$endpoint" --max-time 10; then
        echo "✅ $endpoint healthy"
    else
        echo "❌ $endpoint unhealthy"
        exit 1
    fi
done

echo "🎉 All health checks passed"
```

### Performance Validation

```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/api/v1/users

# Check error rates
CURRENT_ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~'5..'}[5m])" | jq -r '.data.result[0].value[1]')

if (( $(echo "$CURRENT_ERROR_RATE < 0.01" | bc -l) )); then
    echo "✅ Error rate acceptable: $CURRENT_ERROR_RATE"
else
    echo "❌ Error rate too high: $CURRENT_ERROR_RATE"
    exit 1
fi
```

## 📊 Rollback Metrics and KPIs

### Success Metrics

- **Rollback Time**: < 15 minutes for any deployment type
- **Success Rate**: > 99% of rollback attempts succeed
- **Detection Time**: < 5 minutes from issue to rollback initiation
- **Recovery Time**: < 30 minutes total incident duration

### Monitoring During Rollback

```bash
# Key metrics to watch
metrics=(
    "up"  # Service availability
    "rate(http_requests_total{status=~'5..'}[5m])"  # Error rate
    "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"  # Latency
    "rate(database_queries_total{status='error'}[5m])"  # Database errors
)

for metric in "${metrics[@]}"; do
    echo "Monitoring: $metric"
    # Set up alerting for significant changes
done
```

## 🚫 Rollback Limitations and Risks

### Cannot Rollback If:

- **Database schema changes** are not backward compatible
- **Data migrations** have run that cannot be reversed
- **External API integrations** have changed
- **Security patches** that cannot be undone

### Risk Mitigation:

```bash
# Always test rollback procedures in staging
./scripts/test-rollback.sh --environment=staging

# Maintain rollback compatibility for N-1 versions
./scripts/check-rollback-compatibility.sh

# Keep detailed rollback runbooks updated
./scripts/update-runbooks.sh
```

## 📞 Escalation and Communication

### Rollback Authority Matrix

| Time Since Incident | Who Can Authorize   | Notification Required |
| ------------------- | ------------------- | --------------------- |
| 0-15 minutes        | On-call Engineer    | Team Lead             |
| 15-30 minutes       | Team Lead           | Engineering Manager   |
| 30-60 minutes       | Engineering Manager | VP Engineering        |
| >60 minutes         | VP Engineering      | CEO/CTO               |

### Communication Templates

#### Initial Incident

```
🚨 INCIDENT ALERT 🚨
Severity: HIGH
Issue: [Brief description]
Impact: [User/system impact]
Action: Initiating rollback to previous stable version
ETA: 15 minutes
Updates: Every 5 minutes
```

#### Rollback Complete

```
✅ ROLLBACK COMPLETE
Issue: [Brief description]
Resolution: Rolled back to version [X.X.X]
Status: Monitoring for stability
Next: Post-incident review scheduled
```

## 📚 Post-Rollback Analysis

### Root Cause Analysis

1. **What happened?** - Timeline of events
2. **Why did it happen?** - Root cause identification
3. **How can we prevent it?** - Preventive measures
4. **How can we detect it faster?** - Monitoring improvements
5. **How can we recover faster?** - Process improvements

### Action Items Template

- [ ] Fix root cause issue
- [ ] Improve monitoring/alerting
- [ ] Update testing procedures
- [ ] Enhance deployment pipeline
- [ ] Update documentation
- [ ] Train team on lessons learned

### Rollback Post-Mortem Template

```markdown
# Post-Mortem: [Date] Production Rollback

## Summary

- **Incident Start**: [Time]
- **Rollback Initiated**: [Time]
- **Rollback Completed**: [Time]
- **Total Duration**: [Duration]
- **Impact**: [Description]

## Timeline

- [Time] - Issue detected
- [Time] - Rollback initiated
- [Time] - Rollback completed
- [Time] - System stable

## Root Cause

[Detailed analysis]

## Action Items

[List with owners and due dates]

## Lessons Learned

[Key takeaways]
```

## 🔄 Continuous Improvement

### Regular Rollback Testing

- **Monthly**: Blue-green rollback drills
- **Quarterly**: Database rollback testing
- **Annually**: Full disaster recovery simulation

### Rollback Automation Improvements

- Reduce manual steps
- Improve rollback speed
- Enhance rollback validation
- Better rollback monitoring

Remember: **The best rollback is the one you never need to execute** - invest in preventing issues through proper testing, monitoring, and gradual deployment strategies.
