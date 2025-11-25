# Lab 07: Kubernetes Deployment - Multi-Tier Application

**Difficulty:** Advanced | **Time:** 2-3 hours | **Prerequisites:** Labs 1-6, Concepts 11 (Kubernetes)

Deploy a complete multi-tier application to Kubernetes with database, backend API, and frontend services.

---

## 📋 Lab Overview

In this lab, you'll:

1. **Set up a local Kubernetes cluster** (Minikube)
2. **Deploy a multi-tier application** (Frontend, API, Database)
3. **Configure networking** (Services, ingress)
4. **Implement configuration management** (ConfigMaps, Secrets)
5. **Practice scaling and updates** (Rolling deployments)
6. **Monitor and debug** (Logs, port-forwarding)

---

## 🎯 Learning Objectives

After completing this lab, you'll be able to:

- ✅ Create and manage Kubernetes Deployments
- ✅ Expose services using Services and LoadBalancers
- ✅ Manage configuration with ConfigMaps and Secrets
- ✅ Perform rolling updates and rollbacks
- ✅ Scale applications horizontally
- ✅ Debug issues in Kubernetes
- ✅ Use kubectl effectively

---

## 📁 Lab Structure

```
lab_07_kubernetes_deployment/
├── README.md                          # This guide
├── docker-compose.yml                 # Local development (optional)
├── kubernetes/
│   ├── namespace.yaml                # Create namespace
│   ├── configmap.yaml                # App configuration
│   ├── secret.yaml                   # Sensitive data
│   ├── postgres-pvc.yaml            # Database persistence
│   ├── postgres-deployment.yaml      # PostgreSQL
│   ├── postgres-service.yaml         # Database service
│   ├── api-deployment.yaml           # Backend API
│   ├── api-service.yaml              # API service
│   ├── frontend-deployment.yaml      # React frontend
│   ├── frontend-service.yaml         # Frontend service
│   └── deploy-all.sh                 # Deploy everything
└── app/
    ├── api/
    │   ├── Dockerfile
    │   ├── package.json
    │   ├── app.js
    │   └── healthcheck.js
    └── frontend/
        ├── Dockerfile
        ├── package.json
        └── src/
            ├── App.js
            └── App.css
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Check you have the tools
kubectl version --client
docker version
minikube version
```

### Step 1: Start Minikube Cluster

```bash
# Start a cluster with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Verify
minikube status
kubectl cluster-info
```

### Step 2: Create Namespace

```bash
# Create a namespace for this lab
kubectl apply -f kubernetes/namespace.yaml

# Verify
kubectl get namespaces
```

### Step 3: Create Configuration

```bash
# Create ConfigMap
kubectl apply -f kubernetes/configmap.yaml -n lab-07

# Create Secret
kubectl apply -f kubernetes/secret.yaml -n lab-07

# Verify
kubectl get configmap -n lab-07
kubectl get secret -n lab-07
```

### Step 4: Deploy Database

```bash
# Create persistence claim
kubectl apply -f kubernetes/postgres-pvc.yaml -n lab-07

# Deploy PostgreSQL
kubectl apply -f kubernetes/postgres-deployment.yaml -n lab-07
kubectl apply -f kubernetes/postgres-service.yaml -n lab-07

# Verify
kubectl get deployment -n lab-07
kubectl get pods -n lab-07
kubectl logs deployment/postgres -n lab-07
```

### Step 5: Deploy Backend API

```bash
# Deploy API
kubectl apply -f kubernetes/api-deployment.yaml -n lab-07
kubectl apply -f kubernetes/api-service.yaml -n lab-07

# Verify
kubectl get pods -n lab-07
kubectl logs deployment/api -n lab-07
```

### Step 6: Deploy Frontend

```bash
# Deploy frontend
kubectl apply -f kubernetes/frontend-deployment.yaml -n lab-07
kubectl apply -f kubernetes/frontend-service.yaml -n lab-07

# Verify
kubectl get services -n lab-07
```

### Step 7: Access the Application

```bash
# Get service info
kubectl get services -n lab-07

# Port-forward to frontend
kubectl port-forward service/frontend 3000:80 -n lab-07

# In another terminal, access:
# http://localhost:3000
```

---

## 🔧 Kubernetes Manifests Explained

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lab-07
```

Provides isolation for lab resources. All resources deployed to this namespace.

### ConfigMap (Configuration)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: lab-07
data:
  DATABASE_URL: "postgres://postgres:5432/lab07"
  API_BASE_URL: "http://api-service:5000"
  NODE_ENV: "production"
```

Stores non-secret configuration that pods can reference.

### Secret (Sensitive Data)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: lab-07
type: Opaque
stringData:
  DATABASE_PASSWORD: "postgres-password-123"
  JWT_SECRET: "jwt-secret-key-here"
```

Stores sensitive data (passwords, keys) securely.

### PersistentVolumeClaim (Storage)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: lab-07
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Requests persistent storage for database.

### Deployment (Application)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: lab-07
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: lab-07-api:latest
        ports:
        - containerPort: 5000
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DATABASE_PASSWORD
```

Defines the application deployment (manages pods).

### Service (Network Access)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: lab-07
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
  - port: 5000
    targetPort: 5000
```

Exposes application through network interface (load balancer).

---

## 🎓 Hands-On Exercises

### Exercise 1: View Logs

```bash
# View API logs
kubectl logs deployment/api -n lab-07

# View specific pod logs
kubectl logs pod/<pod-name> -n lab-07

# Follow logs in real-time
kubectl logs -f deployment/api -n lab-07
```

### Exercise 2: Connect to Database

```bash
# Get database pod name
kubectl get pods -n lab-07

# Connect to PostgreSQL
kubectl exec -it pod/postgres-xxxxx -n lab-07 -- psql -U postgres

# Inside psql:
\l                  # List databases
\c lab07            # Connect to database
\dt                 # List tables
SELECT * FROM ...   # Query data
\q                  # Exit
```

### Exercise 3: Scale the API

```bash
# Scale API to 3 replicas
kubectl scale deployment api --replicas=3 -n lab-07

# Watch scaling
kubectl get pods -n lab-07 --watch

# Scale back down
kubectl scale deployment api --replicas=2 -n lab-07
```

### Exercise 4: Update Application

```bash
# Update image to new version
kubectl set image deployment/api api=lab-07-api:v2.0 -n lab-07

# Watch rolling update
kubectl rollout status deployment/api -n lab-07

# View update history
kubectl rollout history deployment/api -n lab-07

# Rollback if needed
kubectl rollout undo deployment/api -n lab-07
```

### Exercise 5: Port-Forward and Test API

```bash
# Forward API port
kubectl port-forward service/api-service 5000:5000 -n lab-07

# In another terminal, test API:
curl http://localhost:5000/health
curl http://localhost:5000/api/users
```

### Exercise 6: Edit ConfigMap

```bash
# Edit configuration
kubectl edit configmap app-config -n lab-07

# Pods won't automatically reload - need to restart deployment:
kubectl rollout restart deployment/api -n lab-07
kubectl rollout restart deployment/frontend -n lab-07
```

### Exercise 7: Check Resource Usage

```bash
# View pod resource usage (requires metrics-server)
kubectl top pods -n lab-07
kubectl top nodes

# View pod resource requests/limits
kubectl describe pod <pod-name> -n lab-07
```

### Exercise 8: Describe Resources

```bash
# Get detailed info about deployment
kubectl describe deployment api -n lab-07

# Get detailed info about pod
kubectl describe pod <pod-name> -n lab-07

# Get detailed info about service
kubectl describe service api-service -n lab-07
```

---

## 🐛 Troubleshooting

### Pod Stuck in Pending

```bash
# Check pod status
kubectl describe pod <pod-name> -n lab-07

# Check node resources
kubectl top nodes

# Solution: Likely out of resources
# Scale back, or allocate more resources to Minikube
```

### Pod in CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n lab-07

# Solution: Fix the application error, rebuild image, update deployment
```

### Service Not Accessible

```bash
# Check service
kubectl get service api-service -n lab-07
kubectl describe service api-service -n lab-07

# Check endpoints
kubectl get endpoints api-service -n lab-07

# Solution: Ensure pods are running and healthy
```

### Database Connection Error

```bash
# Check PostgreSQL is running
kubectl get pods -n lab-07 | grep postgres

# Connect to test
kubectl port-forward service/postgres-service 5432:5432 -n lab-07
psql -h localhost -U postgres

# Solution: Check credentials, check DATABASE_URL configuration
```

---

## 📊 What You'll Learn

### Kubernetes Concepts

- ✅ Namespace isolation
- ✅ Pod lifecycle
- ✅ Deployment strategies
- ✅ Service networking
- ✅ ConfigMaps and Secrets
- ✅ Persistent storage
- ✅ Health checks
- ✅ Scaling

### Practical Skills

- ✅ kubectl commands
- ✅ YAML manifest creation
- ✅ Debugging techniques
- ✅ Monitoring and logging
- ✅ Rolling updates and rollbacks
- ✅ Port-forwarding
- ✅ Resource management

---

## 🔗 Related Resources

- **Concepts 11**: Kubernetes Module (theory)
- **Lab 06**: Docker Compose (prerequisite)
- **Concepts 10**: CI/CD Integration (automate deployments)

---

## ✅ Completion Checklist

- [ ] Minikube cluster running
- [ ] Namespace created
- [ ] PostgreSQL deployed and running
- [ ] API deployed and healthy
- [ ] Frontend deployed and accessible
- [ ] Can scale deployments
- [ ] Can perform rolling updates
- [ ] Can access application at http://localhost:3000
- [ ] Can debug issues using kubectl logs and describe
- [ ] Understand YAML manifest structure
- [ ] Can rollback deployments
- [ ] Can edit ConfigMaps and restart deployments

---

## 🎉 Next Steps

1. **Add health checks** to deployment manifests
2. **Implement auto-scaling** with HorizontalPodAutoscaler
3. **Add resource limits** to prevent node overload
4. **Deploy to cloud Kubernetes** (EKS, GKE, AKS)
5. **Set up CI/CD** to automate deployments
6. **Learn service mesh** (Istio) for advanced routing

---

## 📞 Getting Help

If you get stuck:

1. Check pod logs: `kubectl logs pod-name -n lab-07`
2. Describe resource: `kubectl describe pod pod-name -n lab-07`
3. Check events: `kubectl get events -n lab-07`
4. Review manifests: `kubectl get deployment -o yaml -n lab-07`

---

**Lab Duration:** 2-3 hours  
**Difficulty:** Advanced  
**Outcome:** Fully operational multi-tier Kubernetes application  
**Status:** Ready to deploy to cloud Kubernetes platforms

