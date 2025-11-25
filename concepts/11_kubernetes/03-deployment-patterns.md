# Kubernetes Deployment Patterns for Production

**Time:** 2 hours | **Prerequisites:** 01-fundamentals.md | **Level:** Advanced

Learn production-grade deployment patterns: rolling updates, blue-green, canary deployments, and more.

---

## Table of Contents

1. Rolling Updates (Default)
2. Blue-Green Deployments
3. Canary Deployments
4. Health Checks
5. Resource Management
6. High Availability Patterns

---

## 1. Rolling Updates (Default Strategy)

Rolling updates update pods one at a time, ensuring zero downtime.

### How It Works

```
Version 1: 3 replicas (pods)    ────→    Gradually replace    ────→    Version 2: 3 replicas
████ ████ ████                          ████ ▒▒▒▒ ████                ░░░░ ░░░░ ░░░░
                                        ████ ████ ▒▒▒▒
                                        ▒▒▒▒ ████ ░░░░
```

### Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Max pods above desired replicas
      maxUnavailable: 1     # Max pods below desired replicas
  
  selector:
    matchLabels:
      app: app
  
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
```

### Commands

```bash
# Trigger update
kubectl set image deployment/app app=myapp:2.0

# Watch progress
kubectl rollout status deployment/app --watch

# Check history
kubectl rollout history deployment/app

# Rollback if needed
kubectl rollout undo deployment/app

# Rollback to specific revision
kubectl rollout undo deployment/app --to-revision=2
```

### Advantages

✅ Zero-downtime updates  
✅ Automatic rollback on failure  
✅ Gradual update (catch issues early)

### Disadvantages

❌ Requires extra capacity (maxSurge)  
❌ Slower than other strategies

---

## 2. Blue-Green Deployment

Run two complete versions (blue=old, green=new), switch traffic at once.

### How It Works

```
Stage 1: Blue Running         Stage 2: Green Deployed       Stage 3: Traffic Switched
┌──────────────┐             ┌──────────────┐              ┌──────────────┐
│ v1 (ACTIVE)  │             │ v1 (ACTIVE)  │              │ v2 (ACTIVE)  │
├──────────────┤             ├──────────────┤              ├──────────────┤
│ Pod 1 ────   │             │ Pod 1 ────   │              │ Pod 1 ────   │
│ Pod 2 ────   │      +      │ Pod 2 ────   │      switch  │ Pod 2 ────   │
│ Pod 3 ────   │             │ Pod 3 ────   │      to      │ Pod 3 ────   │
└──────────────┘             └──────────────┘              └──────────────┘
                              ┌──────────────┐
                              │ v2 (inactive)│
                              ├──────────────┤
                              │ Pod 1 ----   │
                              │ Pod 2 ----   │
                              │ Pod 3 ----   │
                              └──────────────┘
```

### Implementation

```yaml
# Blue deployment (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      version: blue
  template:
    metadata:
      labels:
        app: app
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0

---

# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      version: green
  template:
    metadata:
      labels:
        app: app
        version: green
    spec:
      containers:
      - name: app
        image: myapp:2.0

---

# Service pointing to blue (production)
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: app
    version: blue    # Points to blue
  ports:
  - port: 80
    targetPort: 8080
```

### Switching Traffic

```bash
# Test green deployment
kubectl port-forward deployment/app-green 8080:8080
# Verify at http://localhost:8080

# Switch service to green
kubectl patch service app-service -p '{"spec":{"selector":{"version":"green"}}}'

# If issues, quickly switch back
kubectl patch service app-service -p '{"spec":{"selector":{"version":"blue"}}}'

# Clean up old blue deployment
kubectl delete deployment app-blue
```

### Advantages

✅ Instant switching  
✅ Quick rollback if issues  
✅ No capacity concerns  
✅ Perfect for major version changes

### Disadvantages

❌ Requires double the resources  
❌ Must test thoroughly before switch

---

## 3. Canary Deployment

Route small portion of traffic to new version, gradually increase.

### How It Works

```
Stage 1: 95% Blue, 5% Green    Stage 2: 75% Blue, 25% Green    Stage 3: 100% Green
Blue: ████████████████          Blue: ████████████              Blue: (removed)
Green: █                         Green: ████████                 Green: ████████████████████
Traffic: 95% → 5%              Traffic: 75% → 25%              Traffic: 100%
```

### Implementation Using Istio (Advanced)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
      version: v1
  template:
    metadata:
      labels:
        app: app
        version: v1
    spec:
      containers:
      - name: app
        image: myapp:1.0

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
      version: v2
  template:
    metadata:
      labels:
        app: app
        version: v2
    spec:
      containers:
      - name: app
        image: myapp:2.0

---

# Istio VirtualService for traffic splitting
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app
spec:
  hosts:
  - app
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: app
        subset: v1
      weight: 95
    - destination:
        host: app
        subset: v2
      weight: 5

---

# Istio DestinationRule
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: app
spec:
  host: app
  trafficPolicy:
    connectionPool:
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 2
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### Simple Canary (No Service Mesh)

```bash
# Deploy v1 with 3 replicas
kubectl create deployment app-v1 --image=myapp:1.0 --replicas=3

# Deploy v2 with 1 replica
kubectl create deployment app-v2 --image=myapp:2.0 --replicas=1

# Both served by same service
kubectl create service loadbalancer app --tcp=80:8080

# Monitor metrics for v2
kubectl logs deployment/app-v2

# Gradually scale v2 up, v1 down
kubectl scale deployment app-v1 --replicas=2
kubectl scale deployment app-v2 --replicas=2

kubectl scale deployment app-v1 --replicas=1
kubectl scale deployment app-v2 --replicas=3

kubectl scale deployment app-v1 --replicas=0
kubectl scale deployment app-v2 --replicas=3
```

### Advantages

✅ Gradual rollout  
✅ Low risk (errors affect few users)  
✅ Easy rollback  
✅ Real-world testing

### Disadvantages

❌ Complex to implement without service mesh  
❌ Slower rollout  
❌ Requires monitoring

---

## 4. Health Checks

Kubernetes needs to know if containers are healthy.

### Readiness Probe (Ready for traffic?)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        
        # Readiness: Is this pod ready to receive traffic?
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10    # Wait 10s before first check
          periodSeconds: 5           # Check every 5s
          timeoutSeconds: 2          # Timeout after 2s
          successThreshold: 1        # Success after 1 check
          failureThreshold: 3        # Fail after 3 failed checks
```

### Liveness Probe (Still alive?)

```yaml
        # Liveness: Is this pod alive or should it be restarted?
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15   # Wait 15s before first check
          periodSeconds: 10         # Check every 10s
          failureThreshold: 3       # Restart after 3 failures
```

### Probe Types

```yaml
# HTTP probe
httpGet:
  path: /health
  port: 8080
  httpHeaders:
  - name: Authorization
    value: Bearer token

---

# TCP probe
tcpSocket:
  port: 8080

---

# Command probe
exec:
  command:
  - /bin/sh
  - -c
  - mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'SELECT 1'
```

### Complete Example with Probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        
        # Readiness
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
          failureThreshold: 2
        
        # Liveness
        livenessProbe:
          httpGet:
            path: /alive
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
          failureThreshold: 3
        
        # Startup (for slow-starting apps)
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          failureThreshold: 30
          periodSeconds: 10
```

---

## 5. Resource Management

Specify resource requests and limits for proper scheduling.

### Resources Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        
        resources:
          # Requests: Guaranteed resources
          requests:
            memory: "128Mi"        # Minimum 128 MB RAM
            cpu: "100m"            # Minimum 0.1 CPU
          
          # Limits: Maximum resources
          limits:
            memory: "512Mi"        # Maximum 512 MB RAM
            cpu: "500m"            # Maximum 0.5 CPU
```

### CPU and Memory Units

```
CPU:
  1 = 1 core
  100m = 0.1 core (100 millicores)
  0.5 = half a core

Memory:
  1Mi = 1 Mebibyte (~1 MB)
  1Gi = 1 Gibibyte (~1 GB)
  1M = 1 Megabyte (1,000,000 bytes)
  1G = 1 Gigabyte (1,000,000,000 bytes)
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70   # Scale up when CPU > 70%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80   # Scale up when memory > 80%
```

---

## 6. High Availability Patterns

### Pod Disruption Budgets

Protect against voluntary disruptions (node maintenance, cluster upgrades).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2              # Always keep at least 2 pods
  selector:
    matchLabels:
      app: app
```

### Node Affinity

Control which nodes pods run on.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      # Pod should run on different nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - app
              topologyKey: kubernetes.io/hostname
      
      # Run on nodes with specific label
      nodeSelector:
        disktype: ssd
      
      containers:
      - name: app
        image: myapp:1.0
```

### Complete HA Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-ha
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0        # Never unavailable
  
  selector:
    matchLabels:
      app: app
  
  template:
    metadata:
      labels:
        app: app
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: app
            topologyKey: kubernetes.io/hostname
      
      containers:
      - name: app
        image: myapp:1.0
        
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

---

apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: app
```

---

## Strategy Comparison

| Pattern | Downtime | Risk | Resources | Rollback |
|---------|----------|------|-----------|----------|
| **Rolling** | None | Low | 110-120% | Automatic |
| **Blue-Green** | None | Medium | 200% | Instant |
| **Canary** | None | Very Low | 110% | Easy |

---

## Choosing a Strategy

- **Rolling Updates**: Default, safe, most situations
- **Blue-Green**: Major changes, risky versions
- **Canary**: New features for gradual rollout

---

**Outcome:** Production-ready deployment patterns  
**Time:** 2 hours of reading + hands-on practice  
**Next:** Lab 7 - Kubernetes Deployment for practical project

