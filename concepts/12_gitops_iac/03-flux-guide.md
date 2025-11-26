# Flux: Cloud-Native Continuous Delivery

**Duration:** 1.5 hours | **Level:** Advanced | **Prerequisites:** Module 11 (Kubernetes)

---

## 🎯 What is Flux?

Flux is a suite of tools for GitOps and continuous delivery on Kubernetes.

**Key Features:**
- Git-native approach
- Helm and Kustomize support
- Event-driven automation
- Progressive delivery with Flagger
- Multi-repository support
- Lightweight and modular

---

## 🔄 Flux vs ArgoCD

| Aspect | Flux | ArgoCD |
|--------|------|--------|
| **Approach** | Push & Pull | Pull-only |
| **Philosophy** | Git-native | Kubernetes-native |
| **UI** | Lightweight | Full dashboard |
| **Helm** | Excellent | Good |
| **Kustomize** | Excellent | Good |
| **Learning Curve** | Steeper | Easier |
| **Multi-cluster** | Good | Excellent |
| **Monitoring** | Via Prometheus | Built-in |

---

## 📦 Installation

### Quick Start

```bash
# Prerequisites
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export REPO_NAME=gitops-repo

# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify
flux --version

# Bootstrap Flux in cluster
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repo=$REPO_NAME \
  --branch=main \
  --path=./clusters/prod \
  --personal
```

### Manual Installation

```bash
# Create namespace
kubectl create namespace flux-system

# Install Flux
helm repo add fluxcd-community https://fluxcd-community.github.io/helm-charts
helm install flux fluxcd-community/flux2 -n flux-system

# Verify
kubectl get deployment -n flux-system
```

---

## 🏗️ Flux Architecture

### Components

```
┌─────────────────────────────────────────┐
│    Git Repository                       │
│  ├─ GitRepository                      │
│  ├─ Kustomization                      │
│  └─ HelmRelease                        │
└────────────────┬────────────────────────┘
                 │
                 ↓ (Source Controller polls)
┌─────────────────────────────────────────┐
│    Flux System (on Kubernetes)          │
│  ├─ Source Controller                  │
│  │  ├─ GitRepository                   │
│  │  ├─ Bucket                          │
│  │  └─ HelmRepository                  │
│  ├─ Kustomize Controller               │
│  ├─ Helm Controller                    │
│  └─ Notification Controller            │
└────────────────┬────────────────────────┘
                 │
                 ↓ (applies to cluster)
┌─────────────────────────────────────────┐
│    Kubernetes Resources                 │
│  ├─ Deployments                        │
│  ├─ Services                           │
│  └─ ConfigMaps                         │
└─────────────────────────────────────────┘
```

---

## 🔧 Core Concepts

### GitRepository

Watches Git repository for changes.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: my-app
spec:
  interval: 1m
  url: https://github.com/my-org/my-app-repo
  ref:
    branch: main
  secretRef:
    name: github-credentials
```

### Kustomization

Applies Kustomize overlays to cluster.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./kustomize
  prune: true
  wait: true
```

### HelmRelease

Manages Helm chart deployments.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
spec:
  interval: 5m
  chart:
    spec:
      chart: prometheus
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
  values:
    prometheus:
      prometheusSpec:
        retention: 7d
```

---

## 🚀 Deploying Applications

### Step 1: Initialize Repository

```bash
# Clone bootstrap repo
git clone https://github.com/$GITHUB_USER/$REPO_NAME
cd $REPO_NAME

# Flux creates flux-system namespace
kubectl get namespace flux-system
```

### Step 2: Create Application Source

```bash
# Create directory for app
mkdir -p apps/my-app

# Create Kustomization files
cat > apps/my-app/deployment.yaml << 'EOF'
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
      - name: my-app
        image: my-app:v1.0.0
EOF

cat > apps/my-app/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF

git add apps/
git commit -m "Add my-app application"
git push origin main
```

### Step 3: Create GitRepository

```bash
cat > clusters/prod/my-app-source.yaml << 'EOF'
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/$GITHUB_USER/$REPO_NAME
  ref:
    branch: main
  secretRef:
    name: git-credentials
EOF

git add clusters/prod/my-app-source.yaml
git commit -m "Add GitRepository for my-app"
git push origin main
```

### Step 4: Create Kustomization

```bash
cat > clusters/prod/my-app-kustomize.yaml << 'EOF'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./apps/my-app
  prune: true
  wait: true
EOF

git add clusters/prod/my-app-kustomize.yaml
git commit -m "Add Kustomization for my-app"
git push origin main

# Flux automatically syncs!
```

---

## 📦 Helm Integration

### Add Helm Repository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 24h
  url: https://prometheus-community.github.io/helm-charts
```

### Deploy Helm Chart

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
  namespace: monitoring
spec:
  interval: 5m
  chart:
    spec:
      chart: prometheus
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
      interval: 1m
  
  install:
    crds: Create
  upgrade:
    crds: CreateReplace
  
  values:
    prometheus:
      prometheusSpec:
        retention: 30d
```

---

## 🔐 Secrets Management

### Sealed Secrets with Flux

```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=password=secret \
  -n default \
  -o yaml > secret.yaml

# Seal secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# Commit sealed secret
git add sealed-secret.yaml
git commit -m "Add sealed secret"
git push origin main

# Flux automatically applies (unseals)
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
  namespace: default
spec:
  provider:
    vault:
      server: https://vault.example.com
      path: secret
      auth:
        kubernetes:
          mountPath: kubernetes
          role: my-app
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: my-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: my-app/password
```

---

## 🔄 Multi-Environment Setup

### Repository Structure

```
repo/
├─ apps/
│  ├─ web/
│  │  ├─ deployment.yaml
│  │  └─ kustomization.yaml
│  └─ api/
├─ infrastructure/
├─ clusters/
│  ├─ dev/
│  │  ├─ sources.yaml
│  │  └─ kustomizations.yaml
│  ├─ staging/
│  │  ├─ sources.yaml
│  │  └─ kustomizations.yaml
│  └─ prod/
│     ├─ sources.yaml
│     └─ kustomizations.yaml
└─ overlays/
   ├─ dev/
   │  └─ kustomization.yaml
   ├─ staging/
   │  └─ kustomization.yaml
   └─ prod/
      └─ kustomization.yaml
```

### Dev Environment (dev/sources.yaml)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/my-org/my-app-repo
  ref:
    branch: develop
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./overlays/dev
  prune: true
```

### Production Environment (prod/sources.yaml)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  url: https://github.com/my-org/my-app-repo
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 15m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./overlays/prod
  prune: true
  wait: true  # Wait for all resources to be ready
```

---

## 📊 Monitoring

### Check Status

```bash
# Check all Kustomizations
kubectl get kustomization -A

# Check GitRepository
kubectl get gitrepository -A

# Get detailed status
kubectl describe kustomization my-app -n flux-system

# View reconciliation status
flux get kustomization my-app
flux get source git my-app
```

### View Logs

```bash
# Kustomize controller logs
kubectl logs -f deployment/kustomize-controller -n flux-system

# Source controller logs
kubectl logs -f deployment/source-controller -n flux-system

# Helm controller logs
kubectl logs -f deployment/helm-controller -n flux-system
```

### Prometheus Metrics

```yaml
# Prometheus scrape config for Flux
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: flux
  namespace: flux-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: flux
  endpoints:
  - port: metrics
```

---

## 🔄 Notifications

### Slack Notifications

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Alert
metadata:
  name: slack-notification
  namespace: flux-system
spec:
  providerRef:
    name: slack
  suspend: false
  eventSeverity: info
  eventSources:
  - kind: Kustomization
    name: my-app
---
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  address: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### GitHub Notifications

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Provider
metadata:
  name: github
  namespace: flux-system
spec:
  type: github
  address: https://api.github.com/repos/my-org/my-app-repo
  secretRef:
    name: github-token
```

---

## 🛡️ RBAC

### Service Account for Flux

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flux-deployer
rules:
- apiGroups: [apps]
  resources: [deployments, statefulsets]
  verbs: [get, list, watch, create, update, patch, delete]
- apiGroups: [batch]
  resources: [jobs]
  verbs: [get, list, watch, create]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flux-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flux-deployer
subjects:
- kind: ServiceAccount
  name: flux
  namespace: flux-system
```

---

## 🎓 Hands-On Lab: Deploy with Flux

```bash
# 1. Bootstrap Flux
export GITHUB_TOKEN=<token>
export GITHUB_USER=<username>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repo=gitops-repo \
  --branch=main \
  --path=./clusters/prod \
  --personal

# 2. Create app directory
mkdir -p apps/demo

# 3. Create manifests
cat > apps/demo/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: demo
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# 4. Create kustomization
cat > apps/demo/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF

# 5. Create source and kustomization
cat > clusters/prod/demo-source.yaml << 'EOF'
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: demo
spec:
  interval: 1m
  url: https://github.com/$GITHUB_USER/gitops-repo
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: demo
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: demo
  path: ./apps/demo
  prune: true
EOF

# 6. Commit and push
git add .
git commit -m "Add demo app"
git push

# 7. Monitor
flux get kustomization demo
kubectl get pods
```

---

## 📋 Best Practices

1. **Use branches for environments**
   - `main` → production
   - `staging` → staging
   - `develop` → development

2. **Organize by application**
   ```
   apps/web/
   apps/api/
   apps/worker/
   ```

3. **Use overlays for customization**
   ```
   overlays/dev/
   overlays/staging/
   overlays/prod/
   ```

4. **Enable notifications**
   - Slack alerts for failures
   - GitHub status updates

5. **Monitor with Prometheus**
   - Track reconciliation metrics
   - Alert on failures

---

## 📚 Key Takeaways

1. ✅ Flux is Git-native GitOps
2. ✅ Excellent Helm and Kustomize support
3. ✅ Push and pull-based automation
4. ✅ Progressive delivery with Flagger
5. ✅ Lightweight and modular design

---

## 🔗 Next Steps

1. Install Flux CLI
2. Bootstrap cluster
3. Deploy sample application
4. Explore notifications
5. Compare with ArgoCD

