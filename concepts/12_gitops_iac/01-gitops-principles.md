# GitOps Principles: Declarative Infrastructure by Pull Request

**Duration:** 1 hour | **Level:** Advanced

---

## 🎯 What is GitOps?

GitOps is an operational framework that uses Git as the source of truth for infrastructure and applications.

**Simple Definition:**
> Infrastructure and applications are defined in Git. Any changes to Git are automatically reflected in your Kubernetes cluster.

---

## 📋 The Four GitOps Principles

### 1. Declarative

**What it means:** Infrastructure is described in code, not by imperative commands.

**Imperative (❌ Not GitOps):**
```bash
kubectl create deployment app --image=myapp:v1
kubectl set image deployment/app app=myapp:v2
kubectl scale deployment app --replicas=3
```

**Declarative (✅ GitOps):**
```yaml
# deployment.yaml
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
        image: myapp:v2
```

**Why it matters:**
- Reproducible across environments
- Version controlled
- Easy to review changes (code review)
- Self-documenting
- Testable before deployment

### 2. Versioned

**What it means:** All infrastructure changes are tracked in version control (Git).

**Example Git Workflow:**
```
Feature branch:  developer/new-feature
    ↓
Create Pull Request
    ↓
Code Review & Approval
    ↓
Merge to main
    ↓
Automatic deployment
```

**Benefits:**
- Complete audit trail
- Can revert any change with `git revert`
- Know who changed what and when
- Compliance requirements met
- Easy to detect unintended changes

### 3. Pulled

**What it means:** Systems pull changes from Git, rather than being pushed to them.

**Push Model (❌ Not ideal):**
```
Developer → Webhook → CI/CD → kubectl apply → Cluster
              (Push)
```
Issues:
- Need webhook to trigger
- Webhook failures can be missed
- Cluster must be reachable from outside
- Difficult to audit
- Hard to reconcile drift

**Pull Model (✅ GitOps):**
```
Git Repository
    ↓ (GitOps Controller polls every N seconds)
Kubernetes Cluster
    ↓ (continuously syncs)
Current State
```

Benefits:
- No webhooks needed
- Cluster doesn't need external access
- Continuous reconciliation
- Automatic drift detection
- Audit trail complete

### 4. Reconciled

**What it means:** The system constantly compares desired state (Git) with actual state (Cluster) and reconciles differences.

**What happens:**
```
Desired State (Git)     Actual State (Cluster)
    ↓                           ↓
        Reconciliation Loop
            ↓
        Are they the same?
            ↓
        If NO → Update cluster
            ↓
        If YES → No action
```

**Examples of Reconciliation:**

1. **Pod crashes:**
   ```
   Desired: 3 replicas
   Actual: 2 replicas (1 crashed)
   Action: Kubernetes starts new pod
   ```

2. **Manual kubectl command:**
   ```bash
   # Someone runs:
   kubectl set image deployment/app app=myapp:v1
   
   # GitOps detects drift:
   Desired: myapp:v2
   Actual: myapp:v1
   Action: Reverts to myapp:v2
   ```

3. **Network failure recovers:**
   ```
   Desired: Service in running state
   Actual: Service failed
   Action: Restarted service
   ```

---

## 🔄 GitOps Workflow

### Complete Example Workflow

```
1. Developer makes changes
   ↓
   ├─ Modifies deployment.yaml
   ├─ git commit
   └─ git push

2. In Git Repository
   ↓
   ├─ Creates Pull Request
   ├─ Code review
   ├─ Checks run (linting, validation)
   └─ Approved & merged to main

3. GitOps Controller Detects Change
   ↓
   ├─ Polls Git repository every 30 seconds
   ├─ Detects new commit on main
   └─ Fetches latest manifests

4. GitOps Syncs to Cluster
   ↓
   ├─ Compares Git manifests vs Cluster state
   ├─ Identifies differences
   └─ Applies changes automatically

5. Kubernetes Updates
   ↓
   ├─ Creates/updates/deletes resources
   ├─ Rolling updates for deployments
   ├─ Health checks pass
   └─ Application is live

6. Monitoring & Feedback
   ↓
   ├─ Health dashboard shows status
   ├─ Notifications sent to Slack
   ├─ Logs streamed to centralized system
   └─ Metrics collected for observability
```

---

## ✅ Benefits of GitOps

### 1. Reproducibility & Consistency

```
Developer 1 → Same Git commit → Deploy to Dev
Developer 2 → Same Git commit → Deploy to Staging
Operations   → Same Git commit → Deploy to Prod

Result: Identical environments across dev/staging/prod
```

### 2. Auditability & Compliance

GitOps provides built-in audit trail:
```bash
# Who made this change?
git log --oneline deployment.yaml

# When was it made?
git show <commit> --stat

# What changed?
git diff HEAD~1 HEAD deployment.yaml

# Can we revert?
git revert <commit>
```

### 3. Disaster Recovery

```bash
# Cluster corrupted or deleted?
# Just recreate cluster and run:

kubectl apply -f deployment.yaml

# Everything is restored from Git!
# No manual configuration needed
```

### 4. Team Collaboration

Traditional approach:
```
"Who deployed what?" - No one knows
"Why is production broken?" - Can't tell
"Can we rollback?" - Manual process
```

GitOps approach:
```
Pull Requests → Code Review → Approval → Auto Deploy
```

Benefits:
- All changes are reviewed
- Knowledge shared across team
- Easy to understand what's deployed
- Rollback is just `git revert`

### 5. Reduced Errors

```
Manual commands:
├─ kubectl apply -f ...
├─ kubectl set image ...
├─ kubectl scale ...
└─ Human error possible at each step

GitOps workflow:
├─ YAML file defines everything
├─ Code review catches mistakes
├─ Automated validation
└─ Consistent, tested deployment
```

### 6. Easier Rollback

```
❌ Manual rollback:
   - What was deployed before?
   - Need to find old command
   - Risk of human error
   - Takes time to figure out

✅ GitOps rollback:
   git revert <commit>
   git push
   → Automatic rollback within seconds
```

### 7. Multi-Cluster Management

```
# Deploy same app to 5 clusters
# Just fork Git repo and adjust region:

├─ Main repo (shared config)
├─ us-east-1 overlay
├─ us-west-2 overlay
├─ eu-west-1 overlay
├─ asia-southeast-1 overlay
└─ all sync automatically
```

---

## 🏗️ GitOps Architecture

### Component Overview

```
┌─────────────────────────────────────────────┐
│           Git Repository                    │
│  ├─ deployment.yaml                        │
│  ├─ service.yaml                           │
│  ├─ configmap.yaml                         │
│  └─ kustomization.yaml                     │
└──────────────────┬──────────────────────────┘
                   │
                   │ GitOps Controller
                   │ (polls every N seconds)
                   ↓
┌─────────────────────────────────────────────┐
│         Kubernetes Cluster                  │
│  ├─ Deployment (app)                        │
│  ├─ Service (load balancer)                 │
│  ├─ ConfigMap (config)                      │
│  └─ Running Pods (application)              │
└─────────────────────────────────────────────┘
```

### Popular GitOps Tools

1. **ArgoCD** (Most popular for Kubernetes)
   - Kubernetes-native
   - UI dashboard
   - Multi-cluster
   - RBAC & authentication

2. **Flux** (Push and pull based)
   - Git-native approach
   - Helm integration
   - Event-driven
   - Lightweight

3. **Jenkins X** (Kubernetes-first)
   - Complete CI/CD + GitOps
   - Automated promotion
   - Cloud-native

---

## 📋 GitOps Repository Structure

### Simple Structure
```
repo/
├─ deployment.yaml
├─ service.yaml
├─ configmap.yaml
├─ secret.yaml
└─ kustomization.yaml
```

### Multi-Environment Structure
```
repo/
├─ base/
│  ├─ deployment.yaml
│  ├─ service.yaml
│  └─ kustomization.yaml
├─ dev/
│  ├─ kustomization.yaml
│  └─ replicas.patch.yaml
├─ staging/
│  ├─ kustomization.yaml
│  └─ replicas.patch.yaml
└─ prod/
   ├─ kustomization.yaml
   └─ replicas.patch.yaml
```

### Complete Project Structure
```
repo/
├─ apps/
│  ├─ web/
│  ├─ api/
│  └─ worker/
├─ infrastructure/
│  ├─ networking/
│  ├─ storage/
│  └─ security/
├─ environments/
│  ├─ dev/
│  ├─ staging/
│  └─ prod/
├─ .github/
│  └─ workflows/
├─ README.md
└─ kustomization.yaml
```

---

## ⚠️ Common Pitfalls & Anti-Patterns

### ❌ Anti-Pattern 1: Manual kubectl Commands

```bash
# BAD - Creates drift
kubectl apply -f deployment.yaml
kubectl set image deployment/app app=myapp:v2
kubectl scale deployment app --replicas=5

# GitOps controller reverts these changes!
```

**Solution:** Always use Pull Requests and Git commits.

### ❌ Anti-Pattern 2: Committing Secrets

```yaml
# BAD - Never commit secrets!
apiVersion: v1
kind: Secret
data:
  password: cGFzc3dvcmQxMjM=  # base64 encoded, not encrypted!
```

**Solution:** Use external secret management (Sealed Secrets, External Secrets Operator).

### ❌ Anti-Pattern 3: Large Monolithic Manifests

```bash
# BAD - Hard to review
all-resources.yaml (5,000 lines)

# GOOD - Modular
deployment.yaml
service.yaml
configmap.yaml
```

**Solution:** Split into logical components.

### ❌ Anti-Pattern 4: Ignoring Reconciliation

```
If GitOps keeps reverting your manual changes:
- Either update Git
- Or disable GitOps temporarily

Don't fight the reconciliation loop!
```

### ❌ Anti-Pattern 5: Too Frequent Polling

```
# Every 5 seconds (too frequent)
polling_interval: 5s
→ High CPU usage
→ Increased load on Git server
→ Possible rate limiting

# Every 30-60 seconds (reasonable)
polling_interval: 30s
→ Balanced between responsiveness and efficiency
```

---

## 🔐 Security Considerations

### 1. Git Access Control

```yaml
# Restrict who can merge to main
Branch protection rules:
├─ Require reviews
├─ Require status checks
└─ Dismiss stale PRs
```

### 2. Secret Management

```yaml
# DON'T: Commit secrets
apiVersion: v1
kind: Secret
stringData:
  password: my-secret  # ❌ Bad

# DO: Use secret management
# Option 1: Sealed Secrets
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
spec:
  encryptedData:
    password: AgEdfH4lk...  # ✅ Encrypted

# Option 2: External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
spec:
  provider:
    vault:  # Reference external vault
```

### 3. RBAC for GitOps

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitops-controller
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update"]
```

### 4. Audit Logging

```bash
# Enable Kubernetes audit logs to track all changes
# Track who deployed what and when
audit_log_maxage: 30
audit_log_maxbackup: 10
```

---

## 📊 GitOps vs Traditional Deployment

### Timeline Comparison

**Traditional Deployment:**
```
15:00 → Developer writes code
15:15 → Build docker image
15:30 → Manual testing
16:00 → Deploy to staging
16:30 → Smoke tests
17:00 → Ready for prod
17:30 → Manual prod deployment
17:45 → Verification
18:00 → Deploy complete

Total: 3 hours, multiple manual steps
```

**GitOps Deployment:**
```
15:00 → Developer writes code & commits
15:05 → Tests run automatically
15:10 → Code review & approval
15:15 → Automatic merge to main
15:17 → Auto-deployed to staging
15:25 → Auto-deployed to prod
15:30 → Complete

Total: 30 minutes, fully automated
```

---

## 🎯 GitOps Best Practices

### 1. Git Workflow

```
main branch (production)
  ↑
  ├─ feature/new-service (dev branch)
  ├─ bugfix/database-issue (dev branch)
  └─ release/v1.2.0 (release branch)
```

**Best Practice:**
- Use feature branches
- Require pull requests
- Enforce code review
- Automate tests
- Merge to main only when approved

### 2. Repository Structure

```
# Clear organization
project/
├─ clusters/              # One per cluster
│  ├─ dev/
│  ├─ staging/
│  └─ prod/
├─ apps/                 # Application definitions
│  ├─ web/
│  ├─ api/
│  └─ worker/
├─ infrastructure/       # Shared infrastructure
├─ README.md
└─ kustomization.yaml
```

### 3. Commit Messages

```
# Good commit messages
commit 1a2b3c4
Author: Alice <alice@example.com>
Date:   Mon Jan 15 10:30:00 2024

    feat: scale API to 3 replicas in prod
    
    Reason: Expected 50% traffic increase this week
    PR: #1234
    Tested: Load tests passed

# vs. Bad commit messages
"update deployment"
"fix prod"
"changes"
```

### 4. Testing Before Deployment

```yaml
# .github/workflows/validate.yml
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate YAML
        run: |
          yamllint *.yaml
      - name: Kustomize build
        run: |
          kustomize build . > /tmp/manifests.yaml
      - name: Kubeval check
        run: |
          kubeval /tmp/manifests.yaml
```

### 5. Progressive Promotion

```
Git Commit
   ↓
Automatic → Dev Deployment
   ↓
Code Review Approval
   ↓
Automatic → Staging Deployment
   ↓
Manual Promotion (or timer)
   ↓
Automatic → Production Deployment
```

---

## 🚀 Getting Started with GitOps

### Step 1: Set Up Git Repository

```bash
git init gitops-repo
cd gitops-repo

# Create structure
mkdir -p {apps,infrastructure,environments/{dev,staging,prod}}

# Add manifests
git add .
git commit -m "Initial commit: GitOps structure"
git push origin main
```

### Step 2: Install GitOps Tool

```bash
# Option 1: ArgoCD (recommended for Kubernetes)
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Option 2: Flux
flux bootstrap github \
  --owner=my-github-org \
  --repo=gitops-repo \
  --branch=main \
  --path=./clusters/prod
```

### Step 3: Deploy Application

```yaml
# apps/web/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: myapp:v1.0.0
```

```bash
git add apps/web/deployment.yaml
git commit -m "feat: deploy web app v1.0.0"
git push origin main

# GitOps automatically syncs!
```

### Step 4: Update Application

```bash
# Edit image version
sed -i 's/v1.0.0/v1.1.0/g' apps/web/deployment.yaml

git add apps/web/deployment.yaml
git commit -m "feat: update web app to v1.1.0"
git push origin main

# GitOps automatically deploys v1.1.0!
```

---

## 📚 Key Takeaways

1. ✅ **GitOps uses Git as source of truth**
2. ✅ **Declarative configuration (not imperative commands)**
3. ✅ **Pull-based synchronization (not push-based)**
4. ✅ **Continuous reconciliation of desired vs actual state**
5. ✅ **Better auditability and compliance**
6. ✅ **Easier rollback and disaster recovery**
7. ✅ **Faster deployments and better collaboration**

---

## 🔗 Next Steps

- Read [ArgoCD Guide](./02-argocd-guide.md) for practical implementation
- Explore [Flux Guide](./03-flux-guide.md) for alternative approach
- Try hands-on exercises in Lab 07

