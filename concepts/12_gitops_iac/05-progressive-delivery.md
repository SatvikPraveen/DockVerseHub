# Progressive Delivery: Advanced Deployment Patterns

**Duration:** 1 hour | **Level:** Advanced

---

## 🎯 What is Progressive Delivery?

Progressive delivery is a set of techniques for releasing software updates safely and incrementally to end users.

**vs Traditional Deployment:**
```
Traditional:     Old Version → New Version (All at once, risky!)
Progressive:     Old Version → 10% New → 30% New → 50% New → 100% New
```

---

## 📊 Progressive Delivery Strategies

### 1. Canary Deployment

**Concept:** Gradually increase traffic to new version

```
Initial:  95% old version  |  5% new version
          ↓ (monitor metrics)
T+5min:   80% old version  |  20% new version
          ↓ (check error rates)
T+15min:  50% old version  |  50% new version
          ↓ (if all good)
T+30min:  0% old version   |  100% new version
```

**Implementation with Flagger:**

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  
  progressDeadlineSeconds: 60
  service:
    port: 80
  
  analysis:
    interval: 1m
    threshold: 5        # Allow 5% error rate
    maxWeight: 50       # Max 50% traffic to canary
    stepWeight: 10      # Increase by 10% each step
    
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
  
  # Rollback if metrics fail
  skipAnalysis: false
```

**Metrics Monitored:**
```
✓ Request success rate (should be > 99%)
✓ Request latency (should be < 500ms)
✓ CPU and memory usage
✓ Error count
```

### 2. Blue-Green Deployment

**Concept:** Run two complete versions, switch traffic at once

```
Blue (Old)   |  Green (New)
Running 100% |  Ready, 0% traffic
              ↓ (when ready)
Running 0%   |  Fully deployed 100%
              ↓ (if problems, switch back)
Running 100% |  Rolled back
```

**Implementation:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
    version: green  # Switch between 'blue' and 'green'
  ports:
  - port: 80
    targetPort: 8080
---
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: blue
  template:
    metadata:
      labels:
        app: my-app
        version: blue
    spec:
      containers:
      - name: app
        image: my-app:v1.0.0
---
# Green deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
      version: green
  template:
    metadata:
      labels:
        app: my-app
        version: green
    spec:
      containers:
      - name: app
        image: my-app:v2.0.0
```

**Switch Traffic:**
```bash
# Update service selector to point to green
kubectl patch service my-app -p '{"spec":{"selector":{"version":"green"}}}'

# If problems, switch back
kubectl patch service my-app -p '{"spec":{"selector":{"version":"blue"}}}'
```

### 3. Feature Flags

**Concept:** Enable/disable features for specific users

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  new-dashboard: "false"
  dark-mode: "true"
  experimental-api: "false"
```

**Application Usage:**

```javascript
const features = {
  newDashboard: process.env.FEATURE_NEW_DASHBOARD === 'true',
  darkMode: process.env.FEATURE_DARK_MODE === 'true',
};

if (features.newDashboard) {
  // Use new dashboard
} else {
  // Use old dashboard
}
```

**Enable for Specific Users:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  new-dashboard: |
    {
      "enabled": true,
      "percentage": 50,
      "allowlist": ["alice@example.com", "bob@example.com"],
      "blockList": ["experimental-user@example.com"]
    }
```

### 4. Shadow Traffic (Traffic Mirroring)

**Concept:** Send copies of traffic to new version without affecting users

```
User Request
    ↓
Old Version (returns response)  +  New Version (shadow, no response)
    ↓
User gets response from old version
(New version tested in production without risk)
```

**Implementation with Istio:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
  - my-app
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: my-app-v1
        port:
          number: 80
      weight: 100
    # Mirror traffic to v2
    mirror:
      host: my-app-v2
      port:
        number: 80
    mirrorPercent: 100  # Mirror 100% of traffic
```

---

## 🛠️ Flagger: GitOps Progressive Delivery

### Installation

```bash
# Install Flagger
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio

# Verify
kubectl get deployment -n flagger-system
```

### Example: Canary Deployment with Flagger

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:v1.0.0
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  
  service:
    port: 80
  
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    
    # Fail canary if metrics don't meet thresholds
    metrics:
    - name: request-success-rate
      interval: 1m
      thresholdRange:
        min: 99
    
    - name: request-duration
      interval: 1m
      thresholdRange:
        max: 500
    
    - name: error-rate
      interval: 1m
      thresholdRange:
        max: 5
```

**Monitor Canary:**
```bash
# Check canary status
kubectl describe canary my-app

# View events
kubectl get events --sort-by='.lastTimestamp'

# Follow logs
kubectl logs -f deployment/flagger -n flagger-system
```

### Update Application

```bash
# Update image
kubectl set image deployment/my-app app=my-app:v2.0.0

# Flagger automatically:
# 1. Detects new image
# 2. Creates canary pods
# 3. Routes 10% traffic to new version
# 4. Monitors metrics
# 5. Gradually increases traffic (10% → 20% → 30% ... → 100%)
# 6. Completes deployment or rollsback on errors

# Monitor progress
watch "kubectl describe canary my-app | grep -A 10 'Status'"
```

---

## 📊 Monitoring Progressive Deployments

### Metrics to Monitor

```
1. Request Success Rate
   ✓ HTTP 2xx/3xx success percentage
   ✓ Should be > 99%

2. Request Latency
   ✓ P95, P99 response times
   ✓ Should not increase significantly

3. Error Rate
   ✓ HTTP 4xx/5xx percentage
   ✓ Should remain low

4. Resource Usage
   ✓ CPU and memory
   ✓ Should not spike

5. Business Metrics
   ✓ User engagement
   ✓ Conversion rates
```

### Prometheus Queries

```promql
# Request success rate
rate(http_requests_total{status=~"2.."}[5m]) / rate(http_requests_total[5m]) * 100

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
```

---

## 🔄 Rollback Strategies

### Automatic Rollback

```yaml
spec:
  analysis:
    threshold: 5        # Fail if > 5% errors
    interval: 1m
    iterations: 10      # Check for 10 iterations
    
    metrics:
    - name: error-rate
      thresholdRange:
        max: 1
```

When threshold exceeded:
1. Stop routing traffic to new version
2. Scale down canary pods
3. All traffic back to stable version
4. Alert operations team

### Manual Rollback

```bash
# If automatic rollback hasn't occurred:
kubectl patch canary my-app -p '{"spec":{"skipAnalysis":true}}'

# Or restart with old version:
kubectl set image deployment/my-app app=my-app:v1.0.0
```

---

## 🎓 Complete Progressive Delivery Example

```yaml
---
# Initial deployment (v1)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:v1.0.0
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 3
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
# Canary configuration
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
spec:
  # Target deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  
  # Service port
  service:
    port: 80
  
  # Progressive delivery analysis
  analysis:
    interval: 1m                # Check metrics every minute
    threshold: 5                # Fail if > 5% error rate
    maxWeight: 50               # Max 50% traffic to canary
    stepWeight: 10              # Increase 10% per interval
    
    metrics:
    # Must have > 99% success rate
    - name: request-success-rate
      interval: 1m
      thresholdRange:
        min: 99
    
    # Must have < 500ms P99 latency
    - name: request-duration
      interval: 1m
      thresholdRange:
        max: 500
    
    # Must have < 1% error rate
    - name: error-rate
      interval: 1m
      thresholdRange:
        max: 1
```

**Deployment Process:**

```bash
# 1. Update image to v2.0.0
kubectl set image deployment/my-app app=my-app:v2.0.0

# 2. Flagger starts canary
# - Creates canary pods with v2.0.0
# - Routes 10% traffic to new pods
# - Monitors metrics

# 3. If metrics good (every minute):
# - Increase traffic: 10% → 20% → 30% ...

# 4. Timeline:
# T+0:  v2.0.0 canary starts (10% traffic)
# T+1m: Check metrics, increase to 20%
# T+2m: Check metrics, increase to 30%
# T+3m: Check metrics, increase to 40%
# T+4m: Check metrics, increase to 50%
# T+5m: All pods updated to v2.0.0
# T+6m: Canary completes, all 100% on v2.0.0

# 5. If any metric fails:
# - Automatically rollback to v1.0.0
# - Alert team
```

---

## 📋 Best Practices

1. **Start with canary for high-risk changes**
2. **Monitor business metrics, not just system metrics**
3. **Set conservative thresholds initially**
4. **Test rollback procedures**
5. **Automate via GitOps (Flux/ArgoCD)**
6. **Integrate with observability platform**

---

## 📚 Key Takeaways

1. ✅ Canary deployments reduce risk
2. ✅ Blue-green for instant rollback
3. ✅ Feature flags for fine-grained control
4. ✅ Progressive delivery automates safety checks
5. ✅ Flagger integrates with Kubernetes
6. ✅ Metrics-driven decisions

