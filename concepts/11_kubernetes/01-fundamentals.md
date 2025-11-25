# Kubernetes Fundamentals

**Time:** 3 hours | **Prerequisites:** Docker Compose knowledge | **Level:** Advanced

This guide covers the core concepts of Kubernetes necessary to understand and deploy containerized applications.

---

## Table of Contents

1. Architecture Overview
2. Core Concepts
3. Your First Deployment
4. Practical Examples
5. Troubleshooting

---

## 1. Architecture Overview

### Kubernetes Cluster Structure

```
Kubernetes Cluster
├── Control Plane (Master)
│   ├── API Server          - REST API endpoint
│   ├── Scheduler           - Assign pods to nodes
│   ├── Controller Manager  - Manage resources
│   └── etcd               - Data storage
├── Worker Node 1
│   ├── kubelet            - Node agent
│   ├── Container Runtime  - Docker/containerd
│   └── kube-proxy         - Networking
├── Worker Node 2
│   ├── kubelet
│   ├── Container Runtime
│   └── kube-proxy
└── Worker Node N
    └── (same as above)
```

### Component Responsibilities

**Control Plane (Runs once per cluster)**
- **API Server**: Accept and process all requests
- **Scheduler**: Watch for new pods, assign to nodes
- **Controller Manager**: Run controllers (deployment, replicaset, etc.)
- **etcd**: Distributed key-value store for all cluster data

**Worker Nodes (Run on each machine)**
- **kubelet**: Node agent, ensures containers run in pods
- **Container Runtime**: Runs containers (Docker, containerd, etc.)
- **kube-proxy**: Network proxy, handles service networking

---

## 2. Core Concepts

### Pods (Smallest Unit)

A pod is the smallest deployable unit in Kubernetes. It usually contains one container but can have multiple (advanced use case).

```yaml
# Simple pod with one container
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: default
spec:
  containers:
  - name: my-container
    image: nginx:1.14
    ports:
    - containerPort: 80
```

**Key Properties:**
- Containers in a pod share network namespace (same IP address, ports)
- Can share storage via volumes
- Usually one container per pod (most common)
- Pods are ephemeral - they can be created and destroyed

### Deployments (Manage Pods)

A deployment manages replica sets of pods. Provides rolling updates, scaling, and declarative updates.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3  # Run 3 copies
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14
        ports:
        - containerPort: 80
```

**Key Features:**
- Declarative: Define desired state, K8s makes it happen
- Auto-restart: Replace failed pods automatically
- Rolling updates: Update all pods without downtime
- Rollback: Quickly revert to previous versions
- Scaling: `kubectl scale deployment --replicas=5`

### Services (Network Access)

A service provides stable network access to pods. Acts as a load balancer.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer  # or ClusterIP, NodePort
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80           # External port
    targetPort: 80     # Pod port
```

**Service Types:**
- **ClusterIP** (default): Internal only, accessible from within cluster
- **NodePort**: External access via node IP and port
- **LoadBalancer**: External load balancer (on cloud platforms)
- **ExternalName**: Maps to external DNS name

### ConfigMaps (Non-Secret Configuration)

Store configuration data separately from code.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://localhost:5432/mydb"
  environment: "production"
  debug: "false"
```

**Usage in Pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DATABASE_URL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database_url
```

### Secrets (Sensitive Data)

Store passwords, API keys, and certificates securely.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:  # Plain text (converted to base64)
  password: "super-secret-password"
  api_key: "sk-1234567890abcdef"
```

**Best Practices:**
- Use external secret management (HashiCorp Vault, AWS Secrets Manager)
- Don't commit secrets to version control
- Rotate secrets regularly
- Use RBAC to control access

### Namespaces (Isolation)

Logical grouping of resources within a cluster.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production

---

# Resources in namespace
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: production
spec:
  containers:
  - name: my-container
    image: nginx:1.14
```

**Common Namespaces:**
- `default`: Default namespace
- `kube-system`: Kubernetes system components
- `kube-public`: Public resources
- Custom namespaces: Production, staging, development

---

## 3. Your First Deployment

### Prerequisites

```bash
# Check kubectl is installed
kubectl version --client

# Check cluster is accessible
kubectl cluster-info
kubectl get nodes
```

### Step 1: Create a Deployment

```bash
# Imperative (quick, for learning)
kubectl create deployment my-app --image=nginx:1.14

# Declarative (preferred, reproducible)
# Save this as deployment.yaml:
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.14
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f deployment.yaml
```

### Step 2: Verify Deployment

```bash
# Check deployment
kubectl get deployment my-app

# Check pods
kubectl get pods
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Step 3: Create a Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

```bash
kubectl apply -f service.yaml
kubectl get service my-app-service
```

### Step 4: Access the Application

```bash
# For Minikube
minikube service my-app-service

# For local K8s (Docker Desktop)
kubectl port-forward service/my-app-service 8080:80
# Visit http://localhost:8080

# For cloud K8s
kubectl get service my-app-service
# Use EXTERNAL-IP
```

### Step 5: Update (Rolling Deployment)

```bash
# Change image
kubectl set image deployment/my-app nginx=nginx:1.21

# Watch update progress
kubectl rollout status deployment/my-app

# Check history
kubectl rollout history deployment/my-app
```

### Step 6: Rollback

```bash
# Rollback to previous
kubectl rollout undo deployment/my-app

# Verify
kubectl get pods
```

---

## 4. Practical Examples

### Example 1: Multi-Tier Application

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "myapp"

---

# Database Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_NAME

---

# Database Service
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432

---

# App Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_HOST

---

# App Service
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

**Deploy:**
```bash
kubectl apply -f multi-tier.yaml
```

### Example 2: Health Checks

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: healthy-app
  template:
    metadata:
      labels:
        app: healthy-app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        
        # Readiness: Is container ready to accept traffic?
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        
        # Liveness: Is container alive or should it be restarted?
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
        
        # Resource limits
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

---

## 5. Troubleshooting

### Pod Not Running

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events

# Check node resources
kubectl top nodes
kubectl top pods
```

### Service Not Accessible

```bash
# Check service
kubectl get service <service-name>
kubectl describe service <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Test connectivity inside cluster
kubectl run debug-pod --image=busybox -it -- sh
# Inside: wget -O- http://service-name:port
```

### Common Issues

**ImagePullBackOff**: Image can't be pulled
```bash
# Check image name and registry
kubectl describe pod <pod-name>
# Solution: Fix image name or add image pull secret
```

**CrashLoopBackOff**: Container keeps crashing
```bash
# Check logs
kubectl logs <pod-name>
# Fix the application issue
```

**Pending**: Pod waiting for resources
```bash
# Check node resources
kubectl describe nodes
# Solution: Add more nodes or reduce resource requests
```

---

## 🎓 Next Steps

1. Complete the practical examples above
2. Deploy a multi-container application
3. Implement health checks and resource limits
4. Practice rolling updates and rollbacks
5. Move to **Lab 7 - Kubernetes Deployment** for a full project

---

**Time Investment:** 3 hours for understanding + hands-on practice  
**Outcome:** Ready to deploy applications to Kubernetes  
**Next Module:** Lab 7 - Kubernetes Deployment (practical project)

