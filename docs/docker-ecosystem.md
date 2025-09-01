# Docker Ecosystem: Registry, Hub, BuildKit & Container Runtime

**Location: `docs/docker-ecosystem.md`**

## Docker Ecosystem Overview

The Docker ecosystem consists of various tools and services that extend Docker's core functionality, from image registries to advanced build systems and container runtimes.

## Docker Hub

### Using Docker Hub

```bash
# Search for images
docker search nginx
docker search --filter stars=100 nginx

# Pull official images
docker pull nginx:alpine
docker pull postgres:13

# Tag and push images
docker tag myapp:latest username/myapp:v1.0
docker push username/myapp:v1.0

# Login/logout
docker login
docker logout
```

### Docker Hub Features

- **Official Images**: Curated base images
- **Verified Publishers**: Trusted image providers
- **Automated Builds**: CI/CD integration
- **Webhooks**: Build triggers
- **Organizations**: Team management
- **Private Repositories**: Paid feature

### Repository Management

```yaml
# .github/workflows/docker-hub.yml
name: Build and Push to Docker Hub
on:
  push:
    branches: [main]
    tags: ["v*"]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: username/myapp

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

## Container Registries

### Docker Registry (Self-hosted)

```yaml
# registry-stack.yml
version: "3.8"
services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
    volumes:
      - registry_data:/var/lib/registry
      - ./auth:/auth
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  registry-ui:
    image: joxit/docker-registry-ui:latest
    ports:
      - "8080:80"
    environment:
      REGISTRY_TITLE: Private Docker Registry
      REGISTRY_URL: http://registry:5000
    depends_on:
      - registry

volumes:
  registry_data:
```

```bash
# Setup authentication
mkdir auth
docker run --entrypoint htpasswd registry:2 -Bbn admin password123 > auth/htpasswd

# Use private registry
docker tag myapp:latest localhost:5000/myapp:latest
docker push localhost:5000/myapp:latest
```

### Harbor Registry

```yaml
# harbor-stack.yml
version: "3.8"
services:
  harbor-core:
    image: goharbor/harbor-core:v2.7.0
    environment:
      CORE_SECRET: harbor-secret
      JOBSERVICE_SECRET: jobservice-secret
    volumes:
      - harbor_data:/data
    ports:
      - "80:8080"
    depends_on:
      - harbor-db
      - harbor-redis

  harbor-db:
    image: goharbor/harbor-db:v2.7.0
    environment:
      POSTGRES_PASSWORD: harbor123
    volumes:
      - harbor_db:/var/lib/postgresql/data

  harbor-redis:
    image: goharbor/redis-photon:v2.7.0
    volumes:
      - harbor_redis:/var/lib/redis

volumes:
  harbor_data:
  harbor_db:
  harbor_redis:
```

### Cloud Registries

```bash
# AWS ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
docker tag myapp:latest 123456789012.dkr.ecr.us-west-2.amazonaws.com/myapp:latest
docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/myapp:latest

# Google Container Registry
gcloud auth configure-docker
docker tag myapp:latest gcr.io/project-id/myapp:latest
docker push gcr.io/project-id/myapp:latest

# Azure Container Registry
az acr login --name myregistry
docker tag myapp:latest myregistry.azurecr.io/myapp:latest
docker push myregistry.azurecr.io/myapp:latest
```

## BuildKit

### Advanced BuildKit Features

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:16-alpine AS base
WORKDIR /app

# Cache mount for npm
FROM base AS deps
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci --only=production

FROM base AS build
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci

COPY . .
RUN npm run build

FROM base AS runtime
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json .
USER node
CMD ["npm", "start"]
```

### BuildKit Configuration

```json
# /etc/docker/daemon.json
{
  "features": {
    "buildkit": true
  },
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "20GB"
    }
  }
}
```

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Custom builder
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap

# Multi-platform builds
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest --push .
```

### BuildKit Secrets

```dockerfile
# syntax=docker/dockerfile:1.4
FROM alpine
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) \
    curl -H "Authorization: Bearer $API_KEY" https://api.example.com/data
```

```bash
echo "secret_key_value" | docker build --secret id=api_key,src=- .
```

## Container Runtimes

### containerd

```bash
# Install containerd
wget https://github.com/containerd/containerd/releases/download/v1.6.8/containerd-1.6.8-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.6.8-linux-amd64.tar.gz

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Use with Docker
# /etc/docker/daemon.json
{
  "default-runtime": "containerd"
}
```

### runc

```bash
# Install runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64
chmod +x runc.amd64
mv runc.amd64 /usr/local/bin/runc

# Create container with runc
mkdir -p mycontainer/rootfs
docker export $(docker create alpine) | tar -C mycontainer/rootfs -xvf -
cd mycontainer
runc spec
runc run mycontainer
```

### CRI-O (Kubernetes)

```bash
# Install CRI-O
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8/x86_64/cri-o-1.24.0-1.el8.x86_64.rpm -o cri-o.rpm
rpm -ivh cri-o.rpm

# Configure CRI-O
systemctl enable --now crio

# Use with Kubernetes
# /etc/kubernetes/kubelet/config.yaml
containerRuntime: remote
containerRuntimeEndpoint: unix:///var/run/crio/crio.sock
```

## Image Scanning and Security

### Trivy Scanner

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

# Scan image
trivy image nginx:latest

# CI/CD integration
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:latest
```

```yaml
# .github/workflows/security.yml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: "myapp:${{ github.sha }}"
    format: "sarif"
    output: "trivy-results.sarif"
```

### Clair Scanner

```yaml
# clair-stack.yml
version: "3.8"
services:
  clair-db:
    image: postgres:11
    environment:
      POSTGRES_DB: clair
      POSTGRES_USER: clair
      POSTGRES_PASSWORD: clair

  clair:
    image: quay.io/coreos/clair:latest
    ports:
      - "6060:6060"
    depends_on:
      - clair-db
    volumes:
      - ./clair-config.yml:/etc/clair/config.yaml
```

### Anchore Engine

```bash
# Install Anchore
pip install anchorecli

# Analyze image
anchore-cli image add nginx:latest
anchore-cli image wait nginx:latest
anchore-cli image vuln nginx:latest all
```

## Docker Extensions

### Popular Extensions

```bash
# Logs Explorer
docker extension install docker/logs-explorer-extension

# Resource Usage
docker extension install docker/resource-usage-extension

# Volumes Backup
docker extension install docker/volumes-backup-extension

# Disk Usage
docker extension install docker/disk-usage-extension
```

### Custom Extension Development

```dockerfile
# Dockerfile.extension
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

```json
{
  "icon": "icon.svg",
  "vm": {
    "image": "myextension:latest",
    "port": 3000
  },
  "ui": {
    "dashboard-tab": {
      "title": "My Extension",
      "src": "/ui"
    }
  }
}
```

## Development Tools

### Docker Compose

```yaml
# Advanced compose features
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
      target: development
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
    profiles:
      - dev

  app-prod:
    build:
      context: .
      target: production
    profiles:
      - prod

  test:
    build:
      context: .
      target: test
    command: npm test
    profiles:
      - test
```

### Docker Desktop Alternatives

```bash
# Podman
podman run -d --name nginx -p 8080:80 nginx
podman-compose up

# Rancher Desktop
# GUI-based Docker Desktop alternative

# Colima (macOS)
brew install colima
colima start
docker run hello-world
```

## Monitoring and Observability

### Prometheus Docker Monitoring

```yaml
# monitoring.yml
version: "3.8"
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

### Jaeger Tracing

```yaml
version: "3.8"
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      COLLECTOR_ZIPKIN_HOST_PORT: 9411
      COLLECTOR_OTLP_ENABLED: true
```

## CI/CD Integration

### GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

services:
  - docker:20-dind

stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

test:
  stage: test
  script:
    - docker run --rm $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA npm test

deploy:
  stage: deploy
  script:
    - docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    environment {
        REGISTRY = 'localhost:5000'
        IMAGE_NAME = 'myapp'
    }

    stages {
        stage('Build') {
            steps {
                script {
                    def image = docker.build("${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}")
                    image.push()
                    image.push("latest")
                }
            }
        }

        stage('Test') {
            steps {
                sh "docker run --rm ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} npm test"
            }
        }

        stage('Deploy') {
            steps {
                sh "docker service update --image ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} myapp"
            }
        }
    }
}
```

## Cloud Native Tools

### Kubernetes Integration

```yaml
# k8s-deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
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
          image: myapp:latest
          ports:
            - containerPort: 3000
          resources:
            limits:
              memory: "512Mi"
              cpu: "500m"
            requests:
              memory: "256Mi"
              cpu: "250m"
```

### Helm Charts

```yaml
# Chart.yaml
apiVersion: v2
name: myapp
description: My Application
type: application
version: 0.1.0
appVersion: "1.0"

# values.yaml
replicaCount: 3

image:
  repository: myapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Docker Swarm vs Kubernetes

| Feature                 | Docker Swarm | Kubernetes |
| ----------------------- | ------------ | ---------- |
| **Complexity**          | Simple       | Complex    |
| **Learning Curve**      | Low          | High       |
| **Scaling**             | Good         | Excellent  |
| **Ecosystem**           | Limited      | Extensive  |
| **Enterprise Features** | Basic        | Advanced   |
| **Community**           | Small        | Large      |

## Performance Tools

### Docker Bench Security

```bash
# Run security benchmark
docker run --rm -it --net host --pid host --userns host --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
    -v /etc:/etc:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --label docker_bench_security \
    docker/docker-bench-security
```

### Dive (Image Analysis)

```bash
# Install dive
curl -OL https://github.com/wagoodman/dive/releases/download/v0.10.0/dive_0.10.0_linux_amd64.deb
dpkg -i dive_0.10.0_linux_amd64.deb

# Analyze image
dive myapp:latest

# CI integration
dive --ci myapp:latest
```

### ctop (Container Monitoring)

```bash
# Install ctop
wget https://github.com/bcicen/ctop/releases/download/0.7.7/ctop-0.7.7-linux-amd64
chmod +x ctop-0.7.7-linux-amd64
mv ctop-0.7.7-linux-amd64 /usr/local/bin/ctop

# Monitor containers
ctop
```

## Networking Tools

### Weave Net

```bash
# Install Weave Net
curl -L git.io/weave -o /usr/local/bin/weave
chmod +x /usr/local/bin/weave

# Setup Weave network
weave launch
eval $(weave env)

# Run containers with Weave
docker run --name c1 -ti ubuntu
docker run --name c2 -ti ubuntu
```

### Calico

```yaml
# calico.yml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - blockSize: 26
        cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
```

## Storage Solutions

### Portworx

```bash
# Install Portworx
curl -fsL https://install.portworx.com/2.11 | sh

# Create storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-sc
provisioner: kubernetes.io/portworx-volume
parameters:
  repl: "3"
  io_profile: "db"
EOF
```

### Rook Ceph

```yaml
# operator.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rook-ceph-operator
  namespace: rook-ceph
spec:
  selector:
    matchLabels:
      app: rook-ceph-operator
  template:
    metadata:
      labels:
        app: rook-ceph-operator
    spec:
      containers:
        - name: rook-ceph-operator
          image: rook/ceph:v1.10.0
```

## Future Technologies

### WebAssembly (WASM)

```bash
# Docker + WASM
docker run --rm --platform wasi/wasm hello-wasm

# Spin (Fermyon)
spin new http-rust myapp
cd myapp
spin build
spin up
```

### Podman

```bash
# Podman compatibility
alias docker=podman

# Podman compose
podman-compose up -d

# Pods (Kubernetes-like)
podman pod create --name mypod -p 8080:80
podman run -d --pod mypod --name web nginx
```

### containerd with nerdctl

```bash
# Install nerdctl
wget https://github.com/containerd/nerdctl/releases/download/v0.22.2/nerdctl-0.22.2-linux-amd64.tar.gz
tar Cxzvf /usr/local/bin nerdctl-0.22.2-linux-amd64.tar.gz

# Use like Docker
nerdctl run -d --name nginx -p 80:80 nginx
nerdctl compose up
```

## Tools Summary

### Essential Tools

- **Docker Compose**: Multi-container orchestration
- **Docker Registry**: Image storage and distribution
- **BuildKit**: Advanced image building
- **Trivy**: Security scanning
- **Prometheus**: Monitoring and metrics

### Advanced Tools

- **Harbor**: Enterprise registry
- **Jaeger**: Distributed tracing
- **Weave**: Container networking
- **Portworx**: Container storage
- **Helm**: Kubernetes package manager

### Development Tools

- **dive**: Image layer analysis
- **ctop**: Container monitoring
- **docker-bench-security**: Security auditing
- **Anchore**: Vulnerability scanning
- **Docker Extensions**: Desktop enhancements

## Next Steps

- Learn [Migration Strategies](./migration-strategies.md) for platform transitions
- Check [Cost Optimization](./cost-optimization.md) for efficient resource usage
- Explore [Quick Reference](./quick-reference/) for fast lookups
- Understand [Learning Paths](./learning-paths/) for skill development
