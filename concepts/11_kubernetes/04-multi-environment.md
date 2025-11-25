# 04 - Multi-Environment Kubernetes Setup

**Time:** 1 hour | **Level:** Advanced

Deploy the same application across development, staging, and production environments using different Kubernetes clusters.

---

## Environment Strategy

```
Local Development      Staging              Production
   ↓                     ↓                      ↓
Minikube or         Kind or k3s or      EKS, GKE, or AKS
Docker Desktop      Managed K8s         (Cloud Kubernetes)
                    (Personal/team)     (Enterprise-scale)
```

---

## Development: Minikube Setup

### Installation

```bash
# macOS
brew install minikube
brew install kubectl

# Linux
curl -LO https://github.com/kubernetes/minikube/releases/download/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Windows
choco install minikube
```

### Starting Cluster

```bash
# Basic startup
minikube start

# With more resources
minikube start --cpus=4 --memory=8192

# With specific Kubernetes version
minikube start --kubernetes-version=v1.24.0

# Check status
minikube status

# Access dashboard
minikube dashboard
```

### Development Workflow

```bash
# Build image locally
eval $(minikube docker-env)  # Use Minikube's Docker
docker build -t myapp:dev .

# Deploy
kubectl apply -f manifests/deployment.yaml

# Test
minikube service myapp-service

# Debug
kubectl logs pod-name
kubectl exec -it pod-name -- /bin/bash

# Clean up
kubectl delete -f manifests/deployment.yaml
```

---

## Staging: Kind Cluster (Local Multi-Node)

Kind (Kubernetes IN Docker) creates multi-node clusters locally.

### Installation

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind version
```

### Cluster Configuration

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: staging-cluster

nodes:
# Control plane
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443

# Worker nodes
- role: worker
- role: worker
```

### Create and Use Cluster

```bash
# Create cluster
kind create cluster --config kind-config.yaml

# Switch context
kubectl config use-context kind-staging-cluster

# List clusters
kind get clusters

# Deploy applications
kubectl apply -f manifests/

# Access services
kubectl port-forward service/myapp 8080:80

# Delete cluster
kind delete cluster --name staging-cluster
```

---

## Production: Cloud Kubernetes

### Amazon EKS (Elastic Kubernetes Service)

```bash
# Install CLI tools
brew install eksctl kubectl helm

# Create cluster
eksctl create cluster \
  --name prod-cluster \
  --version 1.24 \
  --region us-east-1 \
  --nodegroup-name prod-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name prod-cluster

# Verify
kubectl get nodes

# Deploy application
kubectl apply -f manifests/

# Clean up
eksctl delete cluster --name prod-cluster
```

### Google GKE (Google Kubernetes Engine)

```bash
# Install tools
brew install gcloud
gcloud init
gcloud components install gke-gcloud-auth-plugin

# Create cluster
gcloud container clusters create prod-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-1

# Get credentials
gcloud container clusters get-credentials prod-cluster --zone us-central1-a

# Deploy application
kubectl apply -f manifests/

# Clean up
gcloud container clusters delete prod-cluster --zone us-central1-a
```

### Microsoft AKS (Azure Kubernetes Service)

```bash
# Install tools
brew install azure-cli
az login

# Create resource group
az group create --name prod-rg --location eastus

# Create cluster
az aks create \
  --resource-group prod-rg \
  --name prod-cluster \
  --node-count 3 \
  --vm-set-type VirtualMachineScaleSets

# Get credentials
az aks get-credentials --resource-group prod-rg --name prod-cluster

# Deploy application
kubectl apply -f manifests/

# Clean up
az aks delete --resource-group prod-rg --name prod-cluster
```

---

## Multi-Environment Manifest Structure

### Organize Files

```
kubernetes/
├── base/                          # Shared base manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
│
├── dev/                          # Development overrides
│   ├── kustomization.yaml
│   └── config.yaml
│
├── staging/                      # Staging overrides
│   ├── kustomization.yaml
│   ├── config.yaml
│   └── replicas.yaml
│
└── prod/                         # Production overrides
    ├── kustomization.yaml
    ├── config.yaml
    ├── replicas.yaml
    └── resources.yaml
```

### Using Kustomize for Overlays

**Base deployment (base/deployment.yaml):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 1
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
        image: myapp:latest
        env:
        - name: ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: environment
```

**Development override (dev/kustomization.yaml):**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../base

replicas:
- name: app
  count: 1

configMapGenerator:
- name: app-config
  literals:
  - environment=development
  - debug=true

images:
- name: myapp
  newTag: dev-latest
```

**Staging override (staging/kustomization.yaml):**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../base

replicas:
- name: app
  count: 2

configMapGenerator:
- name: app-config
  literals:
  - environment=staging
  - debug=false

resources:
- replicas.yaml
```

**Production override (prod/kustomization.yaml):**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../base

replicas:
- name: app
  count: 3

configMapGenerator:
- name: app-config
  literals:
  - environment=production
  - debug=false

resources:
- replicas.yaml
- resources.yaml
- pdb.yaml

patchesStrategicMerge:
- resource-limits.yaml
```

### Deploy with Kustomize

```bash
# Development
kubectl apply -k kubernetes/dev/

# Staging
kubectl apply -k kubernetes/staging/

# Production
kubectl apply -k kubernetes/prod/

# View manifests before applying
kubectl kustomize kubernetes/prod/
```

---

## Environment-Specific ConfigMaps

**dev/config.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://localhost:5432/dev"
  log_level: "DEBUG"
  cache_ttl: "60"
```

**staging/config.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://postgres-staging:5432/staging"
  log_level: "INFO"
  cache_ttl: "300"
```

**prod/config.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_url: "postgres://prod-db.example.com:5432/prod"
  log_level: "WARN"
  cache_ttl: "3600"
```

---

## CI/CD Integration

### GitHub Actions: Deploy to Multiple Environments

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Set environment
      run: |
        if [ "${{ github.ref }}" = "refs/heads/main" ]; then
          echo "ENVIRONMENT=prod" >> $GITHUB_ENV
          echo "CLUSTER=prod-cluster" >> $GITHUB_ENV
        else
          echo "ENVIRONMENT=staging" >> $GITHUB_ENV
          echo "CLUSTER=staging-cluster" >> $GITHUB_ENV
        fi
    
    - name: Build and push image
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker push myapp:${{ github.sha }}
    
    - name: Deploy to ${{ env.ENVIRONMENT }}
      run: |
        kubectl set image deployment/app \
          app=myapp:${{ github.sha }} \
          --kubeconfig=${{ secrets.KUBECONFIG_${{ env.ENVIRONMENT }} }}
```

---

## Monitoring Multi-Environment

```bash
# View current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context kind-staging-cluster
kubectl config use-context prod-cluster

# View resources in all namespaces
kubectl get pods --all-namespaces

# Check cluster info
kubectl cluster-info
kubectl get nodes
```

---

## Secrets Management Across Environments

**Development: Local secrets**
```bash
kubectl create secret generic app-secret \
  --from-literal=password=devpass
```

**Staging/Production: External secrets**

Using external secret operator or HashiCorp Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp-role"

---

apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  target:
    name: app-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: prod/app/password
```

---

## Best Practices

1. **Use version control**: Keep all manifests in Git
2. **Use Kustomize or Helm**: Template configurations
3. **Automate with CI/CD**: Deploy via pipeline
4. **Monitor all environments**: Same tooling everywhere
5. **Document differences**: Why dev != prod
6. **Use namespaces**: Isolate environments in same cluster
7. **Test locally first**: Dev → Staging → Prod
8. **Use GitOps**: Git as single source of truth

---

## Summary

- **Local Dev**: Minikube or Docker Desktop
- **Staging**: Kind for multi-node testing
- **Production**: EKS, GKE, or AKS (managed services)
- **Configuration**: Kustomize for overlays
- **Deployment**: Git + CI/CD pipeline
- **Secrets**: External vault or managed service

---

**Time:** 1 hour  
**Outcome:** Multi-environment deployment strategy  
**Next:** Lab 7 - Kubernetes Deployment for practical project

