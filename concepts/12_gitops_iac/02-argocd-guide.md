# ArgoCD: Kubernetes-Native GitOps

**Duration:** 2 hours | **Level:** Advanced | **Prerequisites:** Module 11 (Kubernetes)

---

## 🎯 What is ArgoCD?

ArgoCD is a declarative, GitOps-based continuous delivery tool for Kubernetes.

**Key Features:**
- Monitor Git repositories for changes
- Automatically sync applications to Kubernetes
- Visual dashboard for status tracking
- Multi-cluster support
- RBAC and fine-grained permissions
- Automatic rollback on sync errors
- Progressive delivery support

---

## 🏗️ ArgoCD Architecture

### Components

```
┌──────────────────────────────────────────────────┐
│         ArgoCD on Kubernetes                     │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  API Server                             │   │
│  │  ├─ Serves UI/CLI                       │   │
│  │  ├─ Webhook handling                    │   │
│  │  └─ RBAC enforcement                    │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  Application Controller                 │   │
│  │  ├─ Monitors Git repos                  │   │
│  │  ├─ Detects changes                     │   │
│  │  └─ Syncs to cluster                    │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  Repository Server                      │   │
│  │  ├─ Clones Git repos                    │   │
│  │  ├─ Generates manifests                 │   │
│  │  └─ Caches for performance              │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │  Dex Server (Authentication)            │   │
│  │  ├─ OAuth2 support                      │   │
│  │  ├─ SSO integration                     │   │
│  │  └─ User management                     │   │
│  └─────────────────────────────────────────┘   │
│                                                  │
└──────────────────────────────────────────────────┘
       ↓
     Kubernetes Cluster
```

### Workflow

```
1. User commits to Git
   ↓
2. Git webhook notifies ArgoCD (optional)
   ↓
3. ArgoCD Application Controller polls Git
   ↓
4. Repository Server generates Kubernetes manifests
   ↓
5. Application Controller compares desired vs actual
   ↓
6. Applies changes to Kubernetes cluster
   ↓
7. Monitors for sync status and health
```

---

## 📦 Installation

### Prerequisites

```bash
# Kubernetes 1.19+
kubectl version

# kubectl installed
kubectl version --client

# Helm (optional, but useful)
helm version
```

### Quick Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for deployment
kubectl rollout status deployment -n argocd

# Verify installation
kubectl get all -n argocd
```

### Via Helm

```bash
# Add Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd -n argocd --create-namespace

# Check status
helm status argocd -n argocd
```

### Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward to UI (default: https://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login:
# Username: admin
# Password: <from above command>
```

---

## 🔧 Configuration

### ArgoCD Application Resource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  # Git repository containing manifests
  source:
    repoURL: https://github.com/example/my-app-repo
    targetRevision: main
    path: apps/my-app
  
  # Destination cluster and namespace
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  
  # Sync policy
  syncPolicy:
    automated:
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Sync if cluster drifts
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Simple Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/gitops-repo
    path: apps/nginx
    targetRevision: HEAD
  
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 🚀 Deploying Applications

### Step 1: Create Git Repository

```bash
# Create repo structure
mkdir -p gitops-repo/apps/my-app
cd gitops-repo

# Create deployment
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
        ports:
        - containerPort: 8080
EOF

# Create service
cat > apps/my-app/service.yaml << 'EOF'
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
  type: LoadBalancer
EOF

# Create kustomization
cat > apps/my-app/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

git add .
git commit -m "Initial app"
git push origin main
```

### Step 2: Create ArgoCD Application

```bash
# Create ArgoCD Application
kubectl apply -f - << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/gitops-repo
    targetRevision: main
    path: apps/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Verify application
kubectl get application -n argocd
argocd app list
```

### Step 3: Monitor and Sync

```bash
# Check application status
argocd app get my-app

# Manually sync (if auto-sync disabled)
argocd app sync my-app

# Watch sync progress
argocd app wait my-app

# View history
argocd app history my-app
```

---

## 🔄 Sync Policies

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true      # Delete removed resources
    selfHeal: true   # Fix drift automatically
```

**What happens:**
- Every change to Git automatically deployed
- Cluster drift auto-corrected
- Deleted resources immediately removed

### Manual Sync

```yaml
syncPolicy:
  syncOptions:
  - Validate=false
```

**What happens:**
- Changes require manual approval
- Still detects and reports drift
- Safe for production with review process

### Sync Waves

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy after wave 0
```

**Use case:** Ensure databases deploy before applications

---

## 🔑 RBAC and Security

### User Creation

```bash
# Create local user
argocd account create alice
argocd account update-password

# Create service account
kubectl create serviceaccount argocd-deployer -n argocd
```

### RBAC Policy

```bash
# View current policy
kubectl get cm argocd-rbac-cm -n argocd -o yaml

# Edit policy
kubectl edit cm argocd-rbac-cm -n argocd
```

**Example Policy:**
```yaml
policy.default: role:readonly
policy.csv: |
  p, alice, applications, get, */*, allow
  p, alice, applications, create, */*, allow
  p, alice, applications, update, */*, allow
  p, alice, applications, delete, */*, allow
  g, alice, admins
```

### Repository Access

```bash
# Add GitHub repository credentials
argocd repo add https://github.com/my-org/repo \
  --username git \
  --password <github-token>

# Add with SSH
argocd repo add git@github.com:my-org/repo \
  --ssh-private-key-path ~/.ssh/id_rsa
```

---

## 📊 Multi-Cluster Deployment

### Register Additional Clusters

```bash
# List current clusters
argocd cluster list

# Add cluster
argocd cluster add my-cluster

# Verify
kubectl get secret -n argocd | grep cluster
```

### Deploy to Multiple Clusters

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/repo
    path: apps/my-app
    targetRevision: main
  
  # Deploy to multiple clusters
  destinations:
  - server: https://cluster-1:6443
    namespace: default
  - server: https://cluster-2:6443
    namespace: default
  - server: https://kubernetes.default.svc  # Local cluster
    namespace: default
```

---

## 🔍 Monitoring and Troubleshooting

### View Application Status

```bash
# Get overview
argocd app get my-app

# Detailed status
argocd app get my-app --refresh

# Watch in real-time
watch argocd app get my-app
```

### Check Sync Status

```bash
# See what's out of sync
kubectl get application -n argocd -o wide

# View detailed sync info
argocd app diff my-app
```

### View Logs

```bash
# API server logs
kubectl logs -f deployment/argocd-server -n argocd

# Application controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Repository server logs
kubectl logs -f deployment/argocd-repo-server -n argocd
```

---

## 🔐 Secrets Management

### Sealed Secrets Integration

```bash
# Install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create secret
kubectl create secret generic my-secret \
  --from-literal=password=secret \
  -n default \
  -o yaml > secret.yaml

# Seal the secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# Commit sealed secret to Git
git add sealed-secret.yaml
git commit -m "Add sealed secret"

# ArgoCD applies sealed secret, K8s unseals it
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "my-app"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: my-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: my-app-password
```

---

## 🎓 Hands-On Lab: Deploy with ArgoCD

### Exercise: Deploy a Complete Application

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Get admin password
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

# 3. Port-forward to UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 4. Create Application
cat > app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    path: guestbook
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

kubectl apply -f app.yaml

# 5. Monitor
argocd app get guestbook
argocd app wait guestbook

# 6. Access application
kubectl port-forward svc/guestbook-ui 3000:80
# Open browser to http://localhost:3000
```

---

## 📋 Best Practices

### 1. Structure

```
repo/
├─ apps/
│  ├─ web/
│  │  ├─ kustomization.yaml
│  │  ├─ deployment.yaml
│  │  └─ service.yaml
│  └─ api/
├─ infrastructure/
└─ argocd-apps/
   ├─ app-web.yaml
   ├─ app-api.yaml
   └─ app-argocd.yaml  # Self-managing
```

### 2. Use Namespaces

```yaml
# One namespace per environment
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: prod-web
```

### 3. Progressive Sync

```yaml
syncPolicy:
  syncOptions:
  - RespectIgnoreDifferences=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
```

### 4. Notifications

```yaml
# Slack notifications
argocd account update-password --account argocd-manager
# Configure in Settings → Notifications
```

---

## 🔗 Common Patterns

### Canary Deployment

```yaml
# Deploy new version to small % of users
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-canary
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/repo
    path: apps/app
    helm:
      values: |
        canary:
          enabled: true
          weight: 10  # 10% traffic
```

### Environment Promotion

```
Dev (ArgoCD) → Git merge → Staging (ArgoCD) → Git merge → Prod (ArgoCD)
```

### App-of-Apps Pattern

```yaml
# One app manages other apps
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/my-org/repo
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
```

---

## 📚 Key Takeaways

1. ✅ ArgoCD enables GitOps for Kubernetes
2. ✅ Automatic sync with optional self-healing
3. ✅ Built-in RBAC and security
4. ✅ Multi-cluster support
5. ✅ Complete audit trail via Git
6. ✅ Easy rollback and disaster recovery

---

## 🔗 Next Steps

1. Install ArgoCD on local cluster
2. Try deploying a sample application
3. Explore multi-cluster capabilities
4. Learn about Flux as alternative
5. Review Lab 08 - GitOps with ArgoCD (coming next)

