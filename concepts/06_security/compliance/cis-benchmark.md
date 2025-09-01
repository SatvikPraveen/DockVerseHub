# CIS Docker Benchmark

**File Location:** `concepts/06_security/compliance/cis-benchmark.md`

## CIS Docker Benchmark Guidelines

The Center for Internet Security (CIS) Docker Benchmark provides security configuration guidelines for Docker containers and hosts.

## Host Configuration

### 1.1 Ensure a separate partition for containers has been created

```bash
# Check if /var/lib/docker is on separate partition
df /var/lib/docker
```

### 1.2 Ensure only trusted users are allowed to control Docker daemon

```bash
# Check Docker group membership
getent group docker
# Only add trusted users to docker group
sudo usermod -aG docker trusted_user
```

### 1.3 Ensure auditing is configured for the Docker daemon

```bash
# Add audit rules
echo "-w /usr/bin/docker -p wa -k docker" >> /etc/audit/audit.rules
echo "-w /var/lib/docker -p wa -k docker" >> /etc/audit/audit.rules
echo "-w /etc/docker -p wa -k docker" >> /etc/audit/audit.rules
```

## Docker Daemon Configuration

### 2.1 Restrict network traffic between containers

```bash
# Enable inter-container communication control
dockerd --icc=false
```

### 2.2 Set the logging level

```bash
# Set appropriate logging level
dockerd --log-level=info
```

### 2.3 Allow Docker to make changes to iptables

```bash
# Control iptables modifications
dockerd --iptables=true
```

### 2.4 Do not use insecure registries

```bash
# Avoid insecure registries
# dockerd --insecure-registry registry.example.com  # Don't do this
```

### 2.5 Do not use the aufs storage driver

```bash
# Use supported storage drivers
dockerd --storage-driver=overlay2
```

## Docker Daemon Files and Directories

### 3.1 Verify ownership of docker.service file

```bash
stat -c %U:%G /lib/systemd/system/docker.service | grep root:root
```

### 3.2 Verify permissions on docker.service file

```bash
stat -c %a /lib/systemd/system/docker.service
# Should be 644 or more restrictive
```

### 3.3 Verify ownership of Docker socket file

```bash
stat -c %U:%G /var/run/docker.sock | grep root:docker
```

## Container Images and Build Files

### 4.1 Create a user for the container

```dockerfile
# Always create and use non-root user
FROM alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

### 4.2 Use trusted base images for containers

```dockerfile
# Use official images from Docker Hub
FROM node:16-alpine
# Verify image signatures when possible
```

### 4.3 Do not install unnecessary packages

```dockerfile
# Minimize installed packages
FROM alpine:latest
RUN apk add --no-cache python3
# Don't install: curl, wget, nano, vim unless needed
```

### 4.4 Scan and rebuild images to include security patches

```bash
# Regular vulnerability scanning
docker scout cves image:tag
trivy image image:tag

# Rebuild images regularly
docker build --no-cache -t image:new-tag .
```

### 4.5 Enable Content trust for Docker

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker push myimage:tag
```

## Container Runtime

### 5.1 Do not disable AppArmor Profile

```bash
# Don't use --security-opt apparmor=unconfined
docker run --security-opt apparmor=docker-default image
```

### 5.2 Do not disable SELinux security options

```bash
# Use appropriate SELinux labels
docker run --security-opt label=level:TopSecret image
```

### 5.3 Restrict Linux Kernel Capabilities within containers

```bash
# Drop all capabilities, add only needed
docker run --cap-drop=ALL --cap-add=NET_ADMIN image
```

### 5.4 Do not use privileged containers

```bash
# Avoid privileged mode
# docker run --privileged image  # Don't do this
docker run image  # Use normal mode
```

### 5.5 Do not mount sensitive host system directories

```bash
# Avoid mounting sensitive directories
# docker run -v /:/host image  # Don't do this
# docker run -v /boot:/boot image  # Don't do this
# docker run -v /dev:/dev image  # Don't do this
```

### 5.6 Do not run ssh within containers

```dockerfile
# Don't install SSH server in containers
# RUN apt-get install openssh-server  # Don't do this
# Use docker exec for access instead
```

### 5.7 Do not map privileged ports within containers

```bash
# Use unprivileged ports
docker run -p 8080:8080 image  # Good
# docker run -p 80:80 image  # Requires privileges
```

### 5.8 Open only needed ports on container

```dockerfile
# Only expose necessary ports
EXPOSE 8080
# Don't expose: EXPOSE 22 80 443 3306 5432 unless needed
```

### 5.9 Do not share the host's network namespace

```bash
# Use default network mode
docker run image
# Avoid: docker run --net=host image
```

### 5.10 Limit memory usage for container

```bash
# Set memory limits
docker run --memory=512m image
```

### 5.11 Set container CPU priority appropriately

```bash
# Set CPU limits
docker run --cpus=0.5 image
```

### 5.12 Mount container's root filesystem as read only

```bash
# Use read-only root filesystem
docker run --read-only --tmpfs /tmp image
```

### 5.13 Bind incoming container traffic to a specific host interface

```bash
# Bind to specific interface
docker run -p 127.0.0.1:8080:8080 image
```

### 5.14 Set the 'on-failure' container restart policy to 5

```bash
# Limit restart attempts
docker run --restart=on-failure:5 image
```

### 5.15 Do not share the host's process namespace

```bash
# Use default PID namespace
docker run image
# Avoid: docker run --pid=host image
```

### 5.16 Do not share the host's IPC namespace

```bash
# Use default IPC namespace
docker run image
# Avoid: docker run --ipc=host image
```

### 5.17 Do not directly expose host devices to containers

```bash
# Avoid exposing host devices
# docker run --device=/dev/sda image  # Only if absolutely necessary
```

### 5.18 Override default ulimits at runtime

```bash
# Set appropriate ulimits
docker run --ulimit nofile=1024:2048 image
```

### 5.19 Do not set mount propagation mode to shared

```bash
# Use default mount propagation
docker run -v /host/path:/container/path:rshared image  # Avoid 'shared'
```

### 5.20 Do not set the host's UTS namespace

```bash
# Use default UTS namespace
docker run image
# Avoid: docker run --uts=host image
```

### 5.21 Do not disable default seccomp profile

```bash
# Use default seccomp profile
docker run image
# Avoid: docker run --security-opt seccomp=unconfined image
```

## Docker Security Operations

### 6.1 Perform regular security audits

```bash
# Run automated security audit
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

### 6.2 Monitor Docker containers

```bash
# Implement monitoring
# Use tools like Falco, Sysdig, or custom monitoring
falco -r /etc/falco/rules.d/
```

### 6.3 Backup container data

```bash
# Regular data backups
docker run --rm -v container-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz /data
```

### 6.4 Avoid image sprawl

```bash
# Clean up unused images
docker image prune -a
docker system prune
```

### 6.5 Avoid container sprawl

```bash
# Remove stopped containers
docker container prune
```

## Compliance Verification Script

```bash
#!/bin/bash
# CIS Docker Benchmark verification

echo "CIS Docker Benchmark Verification"
echo "================================="

# Host configuration checks
echo "1. Host Configuration"
echo "- Docker partition: $(df /var/lib/docker | tail -1 | awk '{print $1}')"
echo "- Docker group members: $(getent group docker | cut -d: -f4)"

# Docker daemon checks
echo "2. Docker Daemon Configuration"
docker version --format 'Version: {{.Server.Version}}'
docker info --format 'Storage Driver: {{.Driver}}'

# File permissions
echo "3. File Permissions"
echo "- docker.service: $(stat -c %a /lib/systemd/system/docker.service 2>/dev/null || echo 'N/A')"
echo "- docker.sock: $(stat -c %U:%G /var/run/docker.sock 2>/dev/null || echo 'N/A')"

# Container security
echo "4. Container Security"
echo "- AppArmor profiles: $(docker info --format '{{.SecurityOptions}}' | grep apparmor || echo 'Not enabled')"
echo "- Content Trust: ${DOCKER_CONTENT_TRUST:-disabled}"

echo "Verification complete. Review findings against CIS benchmarks."
```

## Remediation Priority

### Critical (Fix Immediately)

- Running containers as root
- Using privileged mode
- Mounting sensitive host directories
- Disabling security profiles

### High (Fix Soon)

- Missing resource limits
- Exposing unnecessary ports
- Using untrusted base images
- Missing vulnerability scanning

### Medium (Plan to Fix)

- Suboptimal file permissions
- Missing audit logging
- Container/image sprawl
- Incomplete monitoring

## Automation

Integrate CIS compliance checks into CI/CD:

```yaml
# CI pipeline step
- name: CIS Compliance Check
  run: |
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      docker/docker-bench-security
```

Regular compliance monitoring ensures ongoing security posture and helps maintain certification requirements.
