# 11_kubernetes - Container Orchestration at Scale

**Complexity:** Advanced | **Time:** 8+ hours | **Prerequisites:** Docker Compose mastery recommended

This module covers Kubernetes (K8s) fundamentals, comparing it with Docker Swarm, and provides practical examples for deploying containerized applications.

---

## 📚 Overview

Kubernetes is a production-grade container orchestration platform that automates deployment, scaling, and management of containerized applications. Unlike Docker Compose (for local development), Kubernetes is designed for:

- **Multi-machine deployments** (across many servers)
- **High availability** (automatic restarts, load balancing)
- **Auto-scaling** (scale up/down based on demand)
- **Rolling updates** (zero-downtime deployments)
- **Self-healing** (replace failed containers)
- **Resource management** (CPU, memory allocation)
- **Storage orchestration** (persistent volumes)
- **Service discovery** (automatic load balancing)

---

## 🎯 Module Goals

After completing this module, you'll understand:

1. **Kubernetes Architecture** - How K8s components work together
2. **Core Concepts** - Pods, Services, Deployments, ConfigMaps, Secrets
3. **Deployment Strategies** - How to deploy applications to Kubernetes
4. **Scaling & Updates** - Rolling updates, scaling, resource management
5. **Practical Setup** - Minikube for local development
6. **Real Deployments** - Multi-environment setup

---

## 📖 Learning Structure

### Part 1: Kubernetes Fundamentals (3 hours)

**Topics Covered:**
- Architecture: Master/control plane, worker nodes, kubelet
- Core objects: Pods, Services, Deployments
- Namespaces and labels
- Declarative vs imperative deployment
- YAML manifests

**Hands-on:**
- Start Minikube cluster
- Deploy first pod imperatively
- Create declarative manifests
- Verify deployment

**Time:** 3 hours | **Files:** `01-fundamentals.md`, `example-manifests/`

---

### Part 2: Docker Compose to Kubernetes (2 hours)

**Topics Covered:**
- Translate Compose services to K8s Deployments
- Expose services with Service manifests
- Environment variables → ConfigMaps
- Secrets handling
- Multi-container pods vs separate deployments
- Networking differences

**Hands-on:**
- Convert Docker Compose to Kubernetes
- Deploy to Minikube
- Compare behavior

**Time:** 2 hours | **Files:** `02-compose-to-k8s.md`, `docker-compose-examples/`

---

### Part 3: Production Deployment Patterns (2 hours)

**Topics Covered:**
- Rolling updates and rollbacks
- Blue-green deployments
- Canary deployments
- Health checks and auto-restart
- Resource requests and limits
- Node affinity and pod disruption budgets

**Hands-on:**
- Configure rolling updates
- Test rollbacks
- Implement health checks
- Set resource limits

**Time:** 2 hours | **Files:** `03-deployment-patterns.md`, `deployment-strategies/`

---

### Part 4: Multi-environment Setup (1 hour)

**Topics Covered:**
- Development (Minikube)
- Staging (kind, k3s, or cloud K8s)
- Production (managed Kubernetes: EKS, GKE, AKS)
- Environment-specific configurations
- CI/CD integration

**Time:** 1 hour | **Files:** `04-multi-environment.md`

---

## 🏗️ Directory Structure

```
11_kubernetes/
├── README.md                          # This comprehensive guide
├── 01-fundamentals.md                 # K8s basics and architecture
├── 02-compose-to-k8s.md              # Translating Docker Compose
├── 03-deployment-patterns.md          # Production patterns
├── 04-multi-environment.md            # Multi-environment setup
├── example-manifests/                 # Basic K8s manifests
│   ├── pod-simple.yaml               # Simple pod definition
│   ├── deployment-nginx.yaml         # Deployment manifest
│   ├── service-loadbalancer.yaml     # Service manifest
│   ├── configmap-example.yaml        # ConfigMap example
│   ├── secret-example.yaml           # Secret example
│   └── namespace-setup.yaml          # Namespace organization
├── docker-compose-examples/           # Docker Compose to compare
│   ├── docker-compose.yml            # Original Compose file
│   ├── docker-compose-prod.yml       # Production variant
│   └── MIGRATION_GUIDE.md            # How to convert
├── deployment-strategies/             # Advanced patterns
│   ├── rolling-update.yaml           # Rolling update configuration
│   ├── blue-green.yaml               # Blue-green deployment
│   ├── canary.yaml                   # Canary deployment
│   ├── health-checks.yaml            # Liveness and readiness probes
│   ├── resource-limits.yaml          # CPU/memory management
│   └── pod-disruption-budget.yaml    # High availability
├── minikube-setup.sh                 # Minikube installation script
├── kind-setup.sh                     # Kind cluster setup script
└── verify-setup.sh                   # Cluster verification script
```

---

## 🚀 Quick Start

### Option 1: Local Development (Minikube)

```bash
# 1. Install Minikube (if not installed)
./minikube-setup.sh

# 2. Start Minikube cluster
minikube start --cpus=4 --memory=8192

# 3. Verify cluster
./verify-setup.sh

# 4. Deploy example
kubectl apply -f example-manifests/deployment-nginx.yaml

# 5. Access service
minikube service example-nginx
```

### Option 2: Docker for Desktop (Built-in K8s)

```bash
# 1. Enable Kubernetes in Docker Desktop settings
# 2. Verify: kubectl cluster-info

# 3. Deploy example
kubectl apply -f example-manifests/deployment-nginx.yaml

# 4. Check status
kubectl get pods
kubectl get services
```

### Option 3: Cloud Kubernetes (EKS, GKE, AKS)

See `04-multi-environment.md` for cloud setup instructions.

---

## 📊 Kubernetes vs Docker Swarm vs Docker Compose

| Feature | Docker Compose | Docker Swarm | Kubernetes |
|---------|---|---|---|
| **Scope** | Local development | Small clusters | Enterprise-scale |
| **Setup** | Pre-installed with Docker | `docker swarm init` | Separate installation |
| **Deployment** | Single machine or basic | Up to hundreds of nodes | Thousands of nodes |
| **Learning Curve** | Very Easy | Easy | Steep |
| **Configuration** | YAML (simple) | YAML (moderate) | YAML (complex) |
| **Auto-scaling** | No | Limited | Advanced |
| **Health Checks** | Basic | Good | Excellent |
| **Storage** | Volumes | Services | Persistent Volumes |
| **Networking** | Bridge networks | Overlay networks | Advanced networking |
| **Load Balancing** | Service ports | Virtual IPs | Services + Ingress |
| **Use Case** | Development | Small production | Large production |
| **Production Ready** | Not recommended | Limited | Yes, enterprise |

---

## 🎓 Learning Paths

### Path 1: Docker Developer → Kubernetes (Recommended Order)

1. **Quick Overview** (30 min)
   - Read this README's quick start
   - Compare Docker Compose vs K8s chart

2. **Kubernetes Fundamentals** (2 hours)
   - Read `01-fundamentals.md`
   - Follow Minikube setup
   - Deploy first example

3. **Convert Your Knowledge** (1.5 hours)
   - Read `02-compose-to-k8s.md`
   - Convert a Docker Compose file
   - Deploy and compare

4. **Production Patterns** (2 hours)
   - Read `03-deployment-patterns.md`
   - Implement health checks
   - Test rolling updates

5. **Multi-environment** (1 hour)
   - Read `04-multi-environment.md`
   - Plan your deployment strategy

**Total Time:** 6.5-8 hours

### Path 2: Advanced DevOps (Deep Dive)

1. All of Path 1
2. Kubernetes architecture deep dive
3. Advanced networking (service mesh)
4. Advanced storage (StatefulSets, PersistentVolumes)
5. Security (RBAC, network policies)
6. Monitoring and logging
7. GitOps workflows

**Total Time:** 20+ hours

### Path 3: Quick Reference (30 minutes)

- Skip theory, jump to examples
- Copy examples and modify
- Learn by doing

---

## 🔑 Key Concepts

### Pods

Smallest deployable unit in Kubernetes. A pod typically contains one container but can have multiple (rarely used).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

### Deployments

Manages replica sets of pods. Provides rolling updates, rollbacks, and scaling.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
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
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

### Services

Exposes pods through a network interface. Provides load balancing and service discovery.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer  # or ClusterIP, NodePort
```

### ConfigMaps & Secrets

Store configuration and sensitive data.

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  ENV: production
  DEBUG: "false"

---

# Secret
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  PASSWORD: base64-encoded-value
```

---

## 📋 Step-by-Step: First Deployment

### Step 1: Install and Start Minikube

```bash
# One-time setup
./minikube-setup.sh

# Start cluster
minikube start --cpus=4 --memory=8192

# Verify
kubectl cluster-info
kubectl get nodes
```

### Step 2: Create Your First Deployment

```bash
# Apply manifest
kubectl apply -f example-manifests/deployment-nginx.yaml

# Check status
kubectl get deployments
kubectl get pods
kubectl get services
```

### Step 3: Verify the Deployment

```bash
# Check pod logs
kubectl logs <pod-name>

# Describe pod
kubectl describe pod <pod-name>

# Port-forward to test
kubectl port-forward service/example-nginx 8080:80

# Visit http://localhost:8080
```

### Step 4: Scale Up

```bash
# Scale to 5 replicas
kubectl scale deployment example-nginx --replicas=5

# Watch scaling happen
kubectl get pods --watch
```

### Step 5: Update

```bash
# Update image version
kubectl set image deployment/example-nginx nginx=nginx:1.21

# Watch rolling update
kubectl rollout status deployment/example-nginx
```

### Step 6: Rollback

```bash
# See history
kubectl rollout history deployment/example-nginx

# Rollback to previous
kubectl rollout undo deployment/example-nginx

# Verify
kubectl get pods
```

---

## 🛠️ Useful kubectl Commands

```bash
# Get information
kubectl get pods                    # List pods
kubectl get services               # List services
kubectl get deployments            # List deployments
kubectl describe pod <name>        # Detailed pod info
kubectl logs <pod-name>           # View pod logs
kubectl logs <pod-name> -f        # Follow logs

# Create and deploy
kubectl apply -f manifest.yaml    # Create from manifest
kubectl create deployment <name> --image=<image>
kubectl expose deployment <name> --port=80 --target-port=8080

# Interact with pods
kubectl exec -it <pod-name> -- /bin/bash    # Shell into pod
kubectl port-forward pod/<name> 8080:80     # Port forward

# Manage resources
kubectl scale deployment <name> --replicas=5
kubectl set image deployment/<name> <container>=<image>:<tag>

# Update and rollback
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>

# Delete resources
kubectl delete pod <name>
kubectl delete deployment <name>
kubectl delete service <name>
```

---

## 🔗 Related Topics

- **Lab 7 - Kubernetes Deployment**: Practical hands-on Kubernetes project
- **Concepts 10 - CI/CD Integration**: Deploy K8s applications via CI/CD
- **Concepts 08 - Orchestration Overview**: Container orchestration theory

---

## 📚 Resources

- **Official Kubernetes Documentation**: https://kubernetes.io/docs/
- **Kubernetes Cheatsheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Minikube Documentation**: https://minikube.sigs.k8s.io/
- **Play with Kubernetes**: https://labs.play-with-k8s.com/

---

## ✅ Module Checklist

Before moving to the next module, verify:

- [ ] Kubernetes architecture understood (master, nodes, kubelet)
- [ ] Local K8s cluster running (Minikube or Docker Desktop)
- [ ] Can deploy a pod with kubectl
- [ ] Can expose a service and access it
- [ ] Can scale deployments up and down
- [ ] Can perform rolling updates and rollbacks
- [ ] Understand ConfigMaps and Secrets
- [ ] Can read and understand Deployment YAML manifests
- [ ] Docker Compose → Kubernetes translation understood
- [ ] Lab 7 hands-on project completed (next step)

---

## 🎯 Next Steps

1. **Follow the Learning Paths** above
2. **Complete Lab 7** - Practical Kubernetes deployment project
3. **Explore Advanced Topics**:
   - Service mesh (Istio)
   - Persistent storage (StatefulSets)
   - RBAC and security
   - Helm package manager
4. **Deploy to production** - EKS, GKE, or AKS

---

**Module Version:** 1.0  
**Last Updated:** November 2024  
**Status:** ✅ Production-Ready

