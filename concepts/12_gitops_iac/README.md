# Module 12: GitOps & Infrastructure as Code

**Time:** 6-8 hours | **Level:** Advanced | **Prerequisites:** Module 11 (Kubernetes)

---

## 📚 Overview

GitOps and Infrastructure as Code (IaC) represent the evolution of cloud-native deployments. Instead of imperative commands (`kubectl apply`), GitOps treats your entire infrastructure as declarative code stored in Git.

This module covers:

- **GitOps Principles**: Git as single source of truth
- **ArgoCD**: Declarative GitOps for Kubernetes
- **Flux**: Continuous delivery for Kubernetes
- **Terraform**: Infrastructure as Code
- **Pulumi**: IaC with Python/TypeScript
- **Progressive Delivery**: Canary, blue-green, and flagger-based deployments
- **CI/CD Integration**: Automated infrastructure updates

---

## 🎯 Learning Path

### Quick Start (1 hour)
- [ ] Git overview and prerequisites
- [ ] GitOps principles and benefits
- [ ] ArgoCD architecture

### Core Concepts (3 hours)
- [ ] ArgoCD installation and configuration
- [ ] Flux basics and operators
- [ ] Application deployment with GitOps
- [ ] Multi-environment management

### Advanced Patterns (2-3 hours)
- [ ] Terraform for infrastructure
- [ ] Progressive delivery and canary deployments
- [ ] Secret management in GitOps
- [ ] Policy as Code (OPA/Kyverno)

### Hands-On Projects (Labs)
- [ ] Lab 07: [Kubernetes Deployment](../../labs/lab_07_kubernetes_deployment/)
- [ ] Lab 08: GitOps with ArgoCD (coming next)

---

## 📖 Learning Guides

This module includes comprehensive guides:

1. **[01-gitops-principles.md](./01-gitops-principles.md)** (1,500+ lines)
   - GitOps fundamentals and principles
   - Benefits over traditional deployment approaches
   - Implementation patterns
   - Best practices and anti-patterns

2. **[02-argocd-guide.md](./02-argocd-guide.md)** (2,000+ lines)
   - ArgoCD architecture and concepts
   - Installation and configuration
   - Application deployment examples
   - Multi-cluster management
   - Security and RBAC
   - Practical tutorials

3. **[03-flux-guide.md](./03-flux-guide.md)** (1,800+ lines)
   - Flux v2 architecture
   - Installation and setup
   - GitRepository and Kustomization resources
   - Helm integration
   - Multi-cluster deployments
   - Practical examples

4. **[04-terraform-iac.md](./04-terraform-iac.md)** (1,800+ lines)
   - Terraform fundamentals
   - Providers and resources
   - State management
   - Modules and best practices
   - Kubernetes resources with Terraform
   - AWS/GCP/Azure examples

5. **[05-progressive-delivery.md](./05-progressive-delivery.md)** (1,200+ lines)
   - Canary deployments
   - Blue-green deployments
   - Feature flags and gradual rollouts
   - Flagger integration
   - Monitoring and rollback

---

## 🛠️ Practical Resources

### Example Projects

- **[argocd-examples/](./argocd-examples/)**: ArgoCD Application examples
- **[flux-examples/](./flux-examples/)**: Flux manifests and Kustomize overlays
- **[terraform-examples/](./terraform-examples/)**: Terraform configurations
- **[gitops-workflows/](./gitops-workflows/)**: GitHub Actions workflows

### Quick Start Scripts

```bash
# Install ArgoCD
./scripts/install-argocd.sh

# Install Flux
./scripts/install-flux.sh

# Deploy example application
./scripts/deploy-application.sh
```

---

## 🔄 GitOps Workflow

```
Developer Push to Git
    ↓
CI/CD Pipeline Runs Tests
    ↓
Merge to Main Branch
    ↓
GitOps Controller Detects Change
    ↓
GitOps Syncs with Cluster
    ↓
Application Updated Automatically
    ↓
Monitoring Verifies Deployment
```

---

## 📊 Comparison: Deployment Approaches

| Aspect | Manual | CI/CD | GitOps |
|--------|--------|-------|--------|
| **Source of Truth** | Cluster state | Scripts/Pipelines | Git repository |
| **Reproducibility** | Low | Medium | High |
| **Auditability** | Difficult | Medium | Excellent |
| **Disaster Recovery** | Manual | Script-based | Git history |
| **Team Collaboration** | Low | Medium | High (Git workflows) |
| **Rollback** | Manual | Script | Git revert |
| **Multi-cluster** | Manual | Complex | Native |
| **Compliance** | Difficult | Medium | Excellent |

---

## 🎓 Key Concepts

### GitOps Principles

1. **Declarative**: Describe entire system as code
2. **Versioned**: All changes tracked in Git
3. **Pulled**: Systems pull changes from Git, not pushed
4. **Reconciled**: Continuous reconciliation of desired vs actual state

### ArgoCD

- Kubernetes native GitOps operator
- Monitors Git repositories
- Automatically syncs applications
- Health and status tracking
- Multi-cluster support

### Flux

- Push and pull-based GitOps
- Helm integration
- Kustomize overlays
- Git-native workflow
- Event-driven automation

### Terraform

- Declarative infrastructure
- Multi-cloud support
- State management
- Modules and reusability
- Environment management

### Progressive Delivery

- Canary deployments (10% → 100%)
- Blue-green deployments (switch at once)
- Feature flags (A/B testing)
- Automated rollback on errors

---

## ✅ Hands-On Exercises

### Exercise 1: ArgoCD Deployment
- [ ] Install ArgoCD on Minikube
- [ ] Create Git repository with manifests
- [ ] Connect ArgoCD to repository
- [ ] Deploy application via ArgoCD
- [ ] Trigger sync on Git push
- [ ] Perform rollback via Git revert

### Exercise 2: Flux Installation
- [ ] Bootstrap Flux in cluster
- [ ] Create Flux resources
- [ ] Deploy application with Flux
- [ ] Configure notifications
- [ ] Implement webhooks

### Exercise 3: Terraform Deployment
- [ ] Create Terraform configuration
- [ ] Deploy Kubernetes cluster (or components)
- [ ] Manage state
- [ ] Create modules
- [ ] Implement environment promotion

### Exercise 4: Multi-Environment Setup
- [ ] Create dev, staging, prod environments
- [ ] Use overlays for customization
- [ ] Implement progressive delivery
- [ ] Monitor deployments

---

## 🔗 Related Modules

- **Module 11**: Kubernetes (prerequisites)
- **Module 10**: CI/CD Integration (pipeline integration)
- **Module 07**: Logging & Monitoring (observability for deployments)

---

## 📚 External Resources

- [ArgoCD Official Docs](https://argoproj.github.io/cd/)
- [Flux Official Docs](https://fluxcd.io/)
- [Terraform Docs](https://www.terraform.io/docs)
- [GitOps Guide](https://www.weave.works/blog/gitops-operations-by-pull-request/)
- [Progressive Delivery](https://www.weave.works/blog/progressive-delivery-update-deployments-with-flagger/)

---

## 🎯 Learning Objectives

After completing this module, you'll be able to:

- ✅ Understand GitOps principles and benefits
- ✅ Deploy applications with ArgoCD
- ✅ Use Flux for continuous delivery
- ✅ Write Terraform for infrastructure
- ✅ Implement progressive delivery
- ✅ Manage multi-environment deployments
- ✅ Handle secrets in GitOps
- ✅ Set up CD pipelines
- ✅ Implement infrastructure versioning
- ✅ Collaborate effectively on infrastructure

---

## ⏱️ Time Breakdown

| Section | Time | 
|---------|------|
| GitOps Principles | 1 hour |
| ArgoCD | 2 hours |
| Flux | 1.5 hours |
| Terraform | 1.5 hours |
| Progressive Delivery | 1 hour |
| **Total** | **7 hours** |

---

## 🚀 Next Steps

1. Read [GitOps Principles](./01-gitops-principles.md)
2. Complete ArgoCD exercises
3. Deploy Lab 08 with ArgoCD
4. Explore Terraform examples
5. Implement progressive delivery

---

**Module Status:** Ready for learning  
**Difficulty:** Advanced  
**Prerequisites:** Module 11 (Kubernetes)  
**Next:** Lab 08 - GitOps with ArgoCD

