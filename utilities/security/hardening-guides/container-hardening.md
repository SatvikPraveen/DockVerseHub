# Location: utilities/security/hardening-guides/container-hardening.md

# Container Security Hardening Guide

A comprehensive guide for securing Docker containers against security vulnerabilities and attacks.

## Table of Contents

- [Base Image Security](#base-image-security)
- [User and Permissions](#user-and-permissions)
- [Capability Management](#capability-management)
- [Network Security](#network-security)
- [Filesystem Security](#filesystem-security)
- [Resource Limits](#resource-limits)
- [Secrets Management](#secrets-management)
- [Monitoring and Logging](#monitoring-and-logging)

## Base Image Security

### Use Minimal Base Images

Choose the smallest possible base image to reduce attack surface.

```dockerfile
# ❌ Large attack surface
FROM ubuntu:22.04

# ✅ Minimal attack surface
FROM alpine:3.19
FROM gcr.io/distroless/nodejs18-debian11
FROM scratch  # For static binaries
```

### Keep Base Images Updated

Regularly update base images to get security patches.

```dockerfile
# Pin to specific versions with latest patches
FROM node:18.19.0-alpine3.19
FROM python:3.11.7-slim-bullseye

# Update packages in Dockerfile
RUN apk update && apk upgrade && \
    apk add --no-cache ca-certificates && \
    rm -rf /var/cache/apk/*
```

### Verify Image Integrity

Use image digests for reproducible builds.

```dockerfile
# Use specific digest
FROM node:18-alpine@sha256:a1e07e2b873b9e72c5b6d4ffd8e616b41c1f6b95b6f0b40d8bbd3b3d8b8b8b8b

# Verify signatures
FROM gcr.io/distroless/nodejs18-debian11@sha256:verified-digest
```

## User and Permissions

### Run as Non-Root User

Never run containers as root user.

```dockerfile
# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Switch to non-root user
USER appuser:appgroup

# Alternative: Use numeric IDs
USER 1001:1001
```

### Set User in Docker Run

```bash
# Run container as specific user
docker run --user 1001:1001 myapp

# Run with current user
docker run --user $(id -u):$(id -g) myapp
```

### File Permissions

Set proper file permissions in container.

```dockerfile
# Copy with specific ownership
COPY --chown=appuser:appgroup app/ /app/

# Set directory permissions
RUN chmod 755 /app && \
    chmod 644 /app/config/* && \
    chmod 600 /app/secrets/*
```

## Capability Management

### Drop All Capabilities

Remove unnecessary Linux capabilities.

```bash
# Drop all capabilities
docker run --cap-drop=ALL myapp

# Add only required capabilities
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp

# Docker Compose
services:
  app:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      - CHOWN
```

### Common Required Capabilities

```bash
# Web servers (bind to port 80/443)
--cap-add=NET_BIND_SERVICE

# File ownership changes
--cap-add=CHOWN

# Process scheduling
--cap-add=SYS_NICE

# Time/date changes (rarely needed)
--cap-add=SYS_TIME
```

### Security Profiles

Use security profiles for additional hardening.

```yaml
# Docker Compose with security profiles
services:
  app:
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
      - seccomp:chrome.json
```

## Network Security

### Disable Privileged Network Access

```bash
# Disable host networking
docker run --network=bridge myapp  # Default, but be explicit

# ❌ Avoid host network unless absolutely necessary
docker run --network=host myapp
```

### Custom Networks

Create isolated networks for different services.

```yaml
# Docker Compose with custom networks
version: "3.8"
services:
  frontend:
    networks:
      - frontend-net
      - backend-net

  backend:
    networks:
      - backend-net
      - database-net

  database:
    networks:
      - database-net

networks:
  frontend-net:
    driver: bridge
  backend-net:
    driver: bridge
  database-net:
    driver: bridge
    internal: true # No external access
```

### Port Exposure

Minimize exposed ports and use specific bindings.

```bash
# ❌ Expose to all interfaces
docker run -p 8080:8080 myapp

# ✅ Bind to localhost only
docker run -p 127.0.0.1:8080:8080 myapp

# ✅ Use specific IP
docker run -p 192.168.1.10:8080:8080 myapp
```

## Filesystem Security

### Read-Only Root Filesystem

Make root filesystem read-only when possible.

```bash
# Read-only root filesystem
docker run --read-only --tmpfs /tmp --tmpfs /var/run myapp
```

```yaml
# Docker Compose
services:
  app:
    read_only: true
    tmpfs:
      - /tmp
      - /var/run:noexec,nosuid,size=100m
```

### Volume Security

Secure volume mounts and permissions.

```bash
# ❌ Dangerous - full filesystem access
docker run -v /:/host myapp

# ❌ Docker socket access
docker run -v /var/run/docker.sock:/var/run/docker.sock myapp

# ✅ Specific directory with read-only
docker run -v /app/data:/data:ro myapp

# ✅ Named volume with specific options
docker run -v app_data:/data:rw,Z myapp
```

### Tmpfs for Sensitive Data

Use tmpfs for temporary sensitive data.

```yaml
services:
  app:
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=100m,uid=1001,gid=1001
      - /var/cache:rw,noexec,nosuid,size=50m
```

## Resource Limits

### Memory Limits

Prevent memory-based attacks.

```bash
# Set memory limit
docker run --memory=512m --memory-swap=512m myapp

# Memory reservation
docker run --memory=512m --memory-reservation=256m myapp
```

```yaml
# Docker Compose
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### CPU Limits

Control CPU usage to prevent resource exhaustion.

```bash
# Limit CPU cores
docker run --cpus="1.5" myapp

# CPU shares (relative priority)
docker run --cpu-shares=512 myapp

# Specific CPU cores
docker run --cpuset-cpus="0,1" myapp
```

### Process Limits

Limit number of processes (fork bomb protection).

```bash
# Limit processes
docker run --pids-limit=100 myapp

# Ulimits
docker run --ulimit nproc=1024:2048 --ulimit nofile=1024:2048 myapp
```

## Secrets Management

### Never Hardcode Secrets

Don't put secrets in Dockerfiles or images.

```dockerfile
# ❌ Never do this
ENV API_KEY=secret123
ENV PASSWORD=mypassword

# ✅ Use build arguments (but still not for secrets)
ARG BUILD_VERSION
ENV VERSION=$BUILD_VERSION
```

### Use Docker Secrets

```yaml
# Docker Compose with secrets
version: "3.8"
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true
```

### External Secret Management

```bash
# HashiCorp Vault integration
docker run --rm -v vault-secrets:/secrets \
  vault:latest vault kv get -field=password secret/myapp

# AWS Secrets Manager
docker run --rm \
  -e AWS_REGION=us-west-2 \
  amazon/aws-cli secretsmanager get-secret-value \
  --secret-id prod/myapp/db
```

## Monitoring and Logging

### Enable Security Monitoring

```yaml
services:
  app:
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://logserver:514"
        syslog-facility: daemon
        tag: "{{.Name}}"

    # Security monitoring
    labels:
      - "security.scan=true"
      - "security.policy=strict"
```

### Audit Logging

Enable Docker daemon audit logging.

```bash
# Add to Docker daemon config
echo '{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "audit-log": {
    "enabled": true,
    "path": "/var/log/docker-audit.log",
    "format": "json"
  }
}' > /etc/docker/daemon.json
```

### Security Event Monitoring

```yaml
services:
  security-monitor:
    image: falco:latest
    privileged: true
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock:ro
      - /dev:/host/dev:ro
      - /proc:/host/proc:ro
      - /boot:/host/boot:ro
      - /lib/modules:/host/lib/modules:ro
      - /usr:/host/usr:ro
      - ./falco-rules:/etc/falco/rules.d:ro
```

## Security Scanning Integration

### Automated Vulnerability Scanning

```yaml
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: myapp:latest

  # Security scanner
  scanner:
    image: aquasec/trivy:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: image --severity HIGH,CRITICAL myapp:latest
    profiles:
      - security
```

### Runtime Security

```yaml
services:
  app:
    security_opt:
      - no-new-privileges:true
      - apparmor=docker-default
    sysctls:
      - kernel.shm_rmid_forced=1
      - net.ipv4.ip_forward=0
      - net.ipv6.conf.all.forwarding=0
```

## Security Checklist

### Build Time Security

- [ ] Use minimal, updated base images
- [ ] Scan images for vulnerabilities
- [ ] Don't include secrets in images
- [ ] Use multi-stage builds
- [ ] Implement proper file permissions
- [ ] Use non-root user
- [ ] Add health checks

### Runtime Security

- [ ] Run with non-root user
- [ ] Drop unnecessary capabilities
- [ ] Use read-only root filesystem
- [ ] Implement resource limits
- [ ] Use custom networks
- [ ] Enable security monitoring
- [ ] Regular security updates

### Infrastructure Security

- [ ] Secure Docker daemon
- [ ] Enable audit logging
- [ ] Use TLS for daemon communication
- [ ] Implement network segmentation
- [ ] Regular security assessments
- [ ] Incident response plan

## Advanced Security Configurations

### Container Runtime Security

```yaml
services:
  app:
    runtime: runsc  # gVisor
    # OR
    runtime: kata-runtime  # Kata Containers
```

### Security Policy as Code

```yaml
# Open Policy Agent (OPA) integration
services:
  policy-engine:
    image: openpolicyagent/opa:latest
    volumes:
      - ./policies:/policies:ro
    command:
      - run
      - --server
      - --addr=0.0.0.0:8181
      - /policies
```

### Image Signing and Verification

```bash
# Sign images with Cosign
cosign sign --key cosign.key myregistry/myapp:v1.0

# Verify signatures
cosign verify --key cosign.pub myregistry/myapp:v1.0

# Notary integration
export DOCKER_CONTENT_TRUST=1
docker push myregistry/myapp:v1.0
```

## Security Testing

### Penetration Testing

```bash
# Container escape testing
docker run --rm -it --pid=host --net=host --privileged \
  -v /:/host security-tools:latest

# Network security testing
nmap -sS -O target_container_ip

# Application security testing
docker run --rm -v $(pwd):/zap/wrk:rw \
  owasp/zap2docker-stable zap-baseline.py \
  -t http://target-app -J report.json
```

### Compliance Scanning

```bash
# CIS Docker Benchmark
docker run --rm --net host --pid host --userns host \
  -v /etc:/etc:ro -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label docker_bench_security \
  docker/docker-bench-security

# Custom compliance check
bash utilities/security/hardening-guides/compliance-check.sh
```

Following this hardening guide will significantly improve your container security posture and protect against common attack vectors. Regular security reviews and updates are essential for maintaining a secure containerized environment.
