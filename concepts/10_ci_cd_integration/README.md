# 10_ci_cd_integration/README.md

# CI/CD Integration with Docker

This directory contains comprehensive CI/CD pipeline examples and best practices for Docker-based applications across multiple platforms and deployment strategies.

## 📋 Overview

Modern CI/CD pipelines with Docker provide:

- **Consistent Build Environments**: Same environment from development to production
- **Multi-Platform Support**: Build for different architectures (AMD64, ARM64)
- **Security Integration**: Automated vulnerability scanning and compliance checks
- **Quality Gates**: Automated testing and validation at every stage
- **Deployment Automation**: Zero-downtime deployments with rollback capabilities

## 🏗️ Directory Structure

```
10_ci_cd_integration/
├── README.md                    # This comprehensive guide
├── github-actions/              # GitHub Actions workflows
│   ├── build-push.yml          # Docker build and registry push
│   ├── multi-stage-ci.yml      # Multi-stage CI pipeline
│   ├── security-scan.yml       # Security scanning workflow
│   └── release-automation.yml  # Automated release management
├── gitlab-ci/                   # GitLab CI/CD pipelines
│   ├── .gitlab-ci.yml          # Main GitLab pipeline
│   ├── docker-in-docker.yml    # DinD configuration
│   └── registry-integration.yml # Registry integration
├── jenkins/                     # Jenkins pipeline examples
│   ├── Jenkinsfile             # Declarative pipeline
│   ├── declarative-pipeline.groovy
│   └── shared-library/         # Reusable pipeline components
├── azure-devops/               # Azure DevOps pipelines
│   ├── azure-pipelines.yml     # Main pipeline configuration
│   └── container-jobs.yml      # Container-based jobs
├── deployment-strategies/       # Deployment patterns
│   ├── blue-green.yml          # Blue-green deployments
│   ├── canary.yml              # Canary releases
│   ├── rolling-update.yml      # Rolling updates
│   └── feature-flags.yml       # Feature flag deployments
└── testing-strategies/         # Testing approaches
    ├── unit-tests.Dockerfile   # Containerized unit tests
    ├── integration-tests.yml   # Integration testing
    ├── e2e-testing.yml         # End-to-end testing
    └── contract-testing.yml    # API contract testing
```

## 🚀 Quick Start

### GitHub Actions Setup

1. **Basic Build Pipeline**:

   ```bash
   cp github-actions/build-push.yml .github/workflows/
   ```

2. **Configure Registry Secrets**:

   ```bash
   # Set in GitHub repository secrets
   GITHUB_TOKEN          # Automatically provided
   SNYK_TOKEN            # For security scanning
   SLACK_WEBHOOK_URL     # For notifications
   ```

3. **Multi-Stage Pipeline**:
   ```bash
   cp github-actions/multi-stage-ci.yml .github/workflows/
   ```

### GitLab CI Setup

1. **Basic Configuration**:

   ```bash
   cp gitlab-ci/.gitlab-ci.yml ./
   ```

2. **Enable Docker-in-Docker**:
   ```bash
   # Add to .gitlab-ci.yml
   services:
     - docker:dind
   ```

## 🔧 Platform-Specific Configurations

### GitHub Actions

**Key Features:**

- Multi-platform builds (AMD64, ARM64)
- Comprehensive security scanning
- SBOM generation and container signing
- Automated release management
- Integration with GitHub Packages

**Essential Workflows:**

```yaml
# Basic build and push
name: Build and Push
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
```

### GitLab CI/CD

**Key Features:**

- Docker-in-Docker support
- Built-in container registry
- Auto DevOps capabilities
- GitLab Security Dashboard integration

**Pipeline Stages:**

```yaml
stages:
  - build
  - test
  - security
  - deploy
```

### Jenkins

**Key Features:**

- Pipeline as Code with Groovy
- Extensive plugin ecosystem
- Shared libraries for reusability
- Blue Ocean UI

**Pipeline Structure:**

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("app:${env.BUILD_ID}")
                }
            }
        }
    }
}
```

### Azure DevOps

**Key Features:**

- YAML pipelines
- Azure Container Registry integration
- Multi-stage approvals
- Azure Kubernetes Service deployment

## 🛡️ Security Integration

### Vulnerability Scanning

**Tools Integrated:**

- **Trivy**: Container vulnerability scanning
- **Snyk**: Dependency and container scanning
- **Grype**: Vulnerability scanner by Anchore
- **Docker Scout**: Docker's native security scanning

**Example Security Pipeline:**

```yaml
security-scan:
  steps:
    - name: Run Trivy scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: "myapp:latest"
        format: "sarif"
        output: "trivy-results.sarif"
```

### Code Quality

**Static Analysis:**

- **SonarCloud**: Code quality and security
- **CodeQL**: GitHub's semantic analysis
- **Semgrep**: Static analysis rules
- **ESLint Security**: JavaScript security rules

### Secret Management

**Best Practices:**

- Use platform secret management (GitHub Secrets, GitLab Variables)
- Scan for exposed secrets (GitLeaks, TruffleHog)
- Rotate secrets regularly
- Use short-lived tokens where possible

## 🧪 Testing Strategies

### Unit Tests in Containers

```dockerfile
# unit-tests.Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "test"]
```

### Integration Testing

```yaml
# Integration test with services
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: test
  redis:
    image: redis:7-alpine

steps:
  - name: Run integration tests
    run: |
      docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

### End-to-End Testing

**Tools:**

- **Playwright**: Modern web testing
- **Cypress**: JavaScript E2E testing
- **Testcontainers**: Integration testing with Docker
- **Newman**: Postman API testing

## 🚀 Deployment Strategies

### Blue-Green Deployment

```yaml
# Blue-Green strategy
deploy-blue:
  script:
    - docker service update --image myapp:new myapp-blue

switch-traffic:
  script:
    -  # Switch load balancer to blue environment

cleanup-green:
  script:
    - docker service rm myapp-green
```

### Canary Deployment

```yaml
# Canary with traffic splitting
deploy-canary:
  script:
    - kubectl set image deployment/app app=myapp:new
    - kubectl patch deployment app -p '{"spec":{"replicas":1}}'

validate-canary:
  script:
    -  # Run validation tests against canary

promote-canary:
  script:
    - kubectl scale deployment app --replicas=3
```

### Rolling Updates

```yaml
# Kubernetes rolling update
deploy-rolling:
  script:
    - kubectl set image deployment/app app=myapp:new
    - kubectl rollout status deployment/app
    - kubectl rollout history deployment/app
```

## 📊 Monitoring and Observability

### Build Metrics

**Key Metrics to Track:**

- Build success rate
- Build duration trends
- Test coverage changes
- Security vulnerability trends
- Deployment frequency

### Pipeline Observability

**Tools:**

- **Grafana**: Metrics visualization
- **Prometheus**: Metrics collection
- **Jaeger**: Distributed tracing
- **ELK Stack**: Log aggregation

### Notifications

**Integration Options:**

- **Slack**: Team notifications
- **Microsoft Teams**: Enterprise communication
- **Email**: Traditional notifications
- **PagerDuty**: Incident management
- **Jira**: Issue tracking integration

## 🔄 Best Practices

### Docker Best Practices in CI/CD

1. **Multi-stage Builds**:

   ```dockerfile
   FROM node:18 AS builder
   # Build stage

   FROM node:18-alpine AS production
   # Production stage with minimal footprint
   ```

2. **Layer Caching**:

   ```yaml
   - uses: docker/build-push-action@v5
     with:
       cache-from: type=gha
       cache-to: type=gha,mode=max
   ```

3. **Security Scanning**:
   ```yaml
   # Fail build on critical vulnerabilities
   - uses: aquasecurity/trivy-action@master
     with:
       exit-code: "1"
       severity: "CRITICAL,HIGH"
   ```

### Pipeline Optimization

1. **Parallel Execution**:

   ```yaml
   strategy:
     matrix:
       platform: [linux/amd64, linux/arm64]
   ```

2. **Conditional Execution**:

   ```yaml
   if: github.ref == 'refs/heads/main'
   ```

3. **Artifact Caching**:
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.npm
       key: npm-${{ hashFiles('package-lock.json') }}
   ```

### Environment Management

1. **Environment Parity**:

   - Use identical images across environments
   - Environment-specific configuration via environment variables
   - Infrastructure as Code (IaC)

2. **Progressive Deployment**:

   - Development → Staging → Production
   - Automated promotion with quality gates
   - Manual approval for production

3. **Rollback Strategy**:
   ```yaml
   rollback:
     when: manual
     script:
       - kubectl rollout undo deployment/app
   ```

## 🛠️ Troubleshooting

### Common Issues

1. **Build Failures**:

   ```bash
   # Check build logs
   docker build --no-cache .

   # Debug multi-stage builds
   docker build --target=debug .
   ```

2. **Registry Issues**:

   ```bash
   # Test registry connectivity
   docker login ghcr.io

   # Check image manifest
   docker manifest inspect myimage:tag
   ```

3. **Performance Issues**:

   ```bash
   # Analyze build context
   docker build --progress=plain .

   # Check layer sizes
   docker history myimage:tag
   ```

### Debugging Pipelines

1. **Enable Debug Logging**:

   ```yaml
   env:
     ACTIONS_STEP_DEBUG: true
     ACTIONS_RUNNER_DEBUG: true
   ```

2. **SSH into Runners** (if available):

   ```yaml
   - uses: mxschmitt/action-tmate@v3
   ```

3. **Local Pipeline Testing**:

   ```bash
   # GitHub Actions
   act -j build

   # GitLab CI
   gitlab-runner exec docker build-job
   ```

## 📚 Advanced Topics

### Custom Actions/Steps

Create reusable pipeline components:

```yaml
# .github/actions/docker-build/action.yml
name: "Docker Build and Push"
description: "Build and push Docker image with caching"
inputs:
  image-name:
    description: "Docker image name"
    required: true
runs:
  using: "composite"
  steps:
    - uses: docker/build-push-action@v5
      with:
        tags: ${{ inputs.image-name }}
```

### Pipeline Templates

Create organization-wide templates for consistency.

### Compliance and Governance

- Implement approval workflows
- Audit trail maintenance
- Compliance reporting
- Access control and permissions

## 🔗 Integration Examples

### Monitoring Integration

```yaml
post-deploy:
  script:
    - |
      curl -X POST $DATADOG_WEBHOOK \
        -d "service=myapp&version=$CI_COMMIT_SHA&environment=production"
```

### Notification Integration

```yaml
notify:
  script:
    - |
      slack-notification.sh \
        "#deployments" \
        "🚀 Deployed myapp:$VERSION to production"
```

This comprehensive CI/CD integration guide provides enterprise-ready pipelines with security, testing, and deployment best practices across all major platforms.
