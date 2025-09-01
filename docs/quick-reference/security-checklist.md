# Docker Security Checklist

**Location: `docs/quick-reference/security-checklist.md`**

## Image Security

### Base Image Selection

- [ ] Use official images from trusted publishers
- [ ] Pin specific image tags/versions (avoid `latest`)
- [ ] Use minimal base images (alpine, distroless)
- [ ] Regularly update base images for security patches
- [ ] Verify image signatures when available

```bash
# Good practices
FROM node:16.20.2-alpine3.18
FROM gcr.io/distroless/java:11
FROM nginx@sha256:abc123...  # Digest pinning

# Avoid
FROM node:latest
FROM ubuntu  # Too broad, no version
```

### Image Building

- [ ] Use multi-stage builds to minimize final image size
- [ ] Don't include secrets in image layers
- [ ] Use `.dockerignore` to exclude sensitive files
- [ ] Minimize installed packages and tools
- [ ] Remove package managers in production images

```dockerfile
# Good
FROM node:alpine AS builder
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

FROM node:alpine AS production
RUN adduser -S appuser
COPY --from=builder --chown=appuser /app/dist ./dist
USER appuser
```

### Vulnerability Scanning

- [ ] Scan images before deployment
- [ ] Set up automated scanning in CI/CD
- [ ] Monitor for new vulnerabilities
- [ ] Implement security gates in build pipeline

```bash
# Scanning tools
trivy image myapp:latest
docker scan myapp:latest
anchore-cli image scan myapp:latest
```

## Runtime Security

### User and Privileges

- [ ] Run containers as non-root user
- [ ] Use read-only filesystems where possible
- [ ] Drop unnecessary capabilities
- [ ] Use security profiles (AppArmor, SELinux)
- [ ] Enable no-new-privileges flag

```bash
# Good practices
docker run --user 1000:1000 myapp
docker run --read-only myapp
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE myapp
docker run --security-opt no-new-privileges:true myapp
```

### Resource Limits

- [ ] Set memory limits to prevent DoS
- [ ] Set CPU limits for fair resource sharing
- [ ] Use process limits to prevent fork bombs
- [ ] Configure storage limits

```yaml
version: "3.8"
services:
  app:
    image: myapp
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
        reservations:
          memory: 256M
          cpus: "0.25"
    ulimits:
      nproc: 1024
      nofile: 65536
```

### Container Isolation

- [ ] Use custom networks instead of default bridge
- [ ] Implement network segmentation
- [ ] Use internal networks for backend services
- [ ] Avoid privileged containers
- [ ] Don't mount Docker socket unless absolutely necessary

```bash
# Network segmentation
docker network create --internal backend
docker network create frontend
docker run --network backend database
docker run --network frontend --network backend app
```

## Secrets Management

### Secret Handling

- [ ] Never embed secrets in images
- [ ] Use Docker secrets (Swarm) or external secret managers
- [ ] Mount secrets as files, not environment variables
- [ ] Rotate secrets regularly
- [ ] Use secret scanning tools

```yaml
# Docker Swarm secrets
version: "3.8"
services:
  app:
    image: myapp
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    external: true
  api_key:
    file: ./api_key.txt
```

### Environment Variables

- [ ] Avoid sensitive data in environment variables
- [ ] Use secret files instead of env vars for passwords
- [ ] Review environment variable exposure
- [ ] Use init containers for secret initialization

## Network Security

### Network Configuration

- [ ] Use custom networks for application isolation
- [ ] Implement proper firewall rules
- [ ] Use TLS for inter-service communication
- [ ] Limit exposed ports to minimum required
- [ ] Use network policies in orchestration

```bash
# Secure network setup
docker network create --internal secure-backend
docker run --network secure-backend --name db postgres
docker run --network secure-backend -p 443:443 app
```

### TLS/SSL

- [ ] Use HTTPS/TLS for all external communication
- [ ] Implement certificate rotation
- [ ] Use strong cipher suites
- [ ] Enable HSTS headers
- [ ] Validate certificates properly

```nginx
# Nginx TLS configuration
server {
    listen 443 ssl http2;
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    add_header Strict-Transport-Security "max-age=31536000" always;
}
```

## Host Security

### Docker Daemon

- [ ] Secure Docker daemon with TLS
- [ ] Use user namespaces
- [ ] Configure logging and audit
- [ ] Regular security updates
- [ ] Limit daemon privileges

```json
# /etc/docker/daemon.json
{
  "icc": false,
  "userland-proxy": false,
  "no-new-privileges": true,
  "live-restore": true,
  "userns-remap": "default"
}
```

### Host Hardening

- [ ] Keep host OS updated
- [ ] Use minimal host OS (Container Linux, etc.)
- [ ] Configure host firewall
- [ ] Monitor system for intrusions
- [ ] Regular security audits

```bash
# Basic firewall setup
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

## Monitoring and Logging

### Security Monitoring

- [ ] Centralized logging for all containers
- [ ] Monitor for security events
- [ ] Set up alerting for suspicious activity
- [ ] Use security scanning tools
- [ ] Implement intrusion detection

```yaml
# Security monitoring stack
version: "3.8"
services:
  falco:
    image: falcosecurity/falco
    privileged: true
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - /dev:/host/dev
      - /proc:/host/proc:ro
      - ./falco.yaml:/etc/falco/falco.yaml
```

### Audit Logging

- [ ] Enable Docker daemon audit logging
- [ ] Log all container access
- [ ] Monitor file system changes
- [ ] Track network connections
- [ ] Regular log analysis

```bash
# Enable audit logging
echo 'DOCKER_OPTS="--log-level=info"' >> /etc/default/docker
auditctl -w /var/lib/docker -p wa -k docker
```

## Compliance and Governance

### Security Standards

- [ ] Follow CIS Docker Benchmark
- [ ] Implement NIST guidelines
- [ ] Meet industry compliance requirements (SOC2, PCI-DSS)
- [ ] Regular compliance audits
- [ ] Security policy documentation

### Access Control

- [ ] Implement RBAC for Docker access
- [ ] Use multi-factor authentication
- [ ] Regular access reviews
- [ ] Principle of least privilege
- [ ] Secure credential management

## CI/CD Security

### Pipeline Security

- [ ] Secure build environments
- [ ] Image signing and verification
- [ ] Security testing in pipeline
- [ ] Artifact scanning
- [ ] Secure artifact storage

```yaml
# GitHub Actions security scanning
name: Security Scan
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .
      - name: Scan image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: "myapp:${{ github.sha }}"
          format: "sarif"
          output: "trivy-results.sarif"
      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: "trivy-results.sarif"
```

### Supply Chain Security

- [ ] Verify base image integrity
- [ ] Scan dependencies for vulnerabilities
- [ ] Use software bill of materials (SBOM)
- [ ] Implement reproducible builds
- [ ] Monitor for supply chain attacks

## Incident Response

### Preparation

- [ ] Incident response plan for containers
- [ ] Container forensics procedures
- [ ] Backup and recovery plans
- [ ] Communication protocols
- [ ] Regular incident response drills

### Response Procedures

- [ ] Container isolation procedures
- [ ] Log preservation methods
- [ ] Forensic image capture
- [ ] Evidence chain of custody
- [ ] Recovery procedures

```bash
# Incident response commands
docker pause suspicious_container
docker logs suspicious_container > incident_logs.txt
docker commit suspicious_container forensic_image:$(date +%Y%m%d_%H%M%S)
docker network disconnect bridge suspicious_container
```

## Security Tools Checklist

### Scanning Tools

- [ ] **Trivy** - Vulnerability scanner
- [ ] **Clair** - Static analysis
- [ ] **Anchore** - Container security platform
- [ ] **Snyk** - Dependency scanning
- [ ] **Docker Scout** - Built-in scanning

### Runtime Security

- [ ] **Falco** - Runtime security monitoring
- [ ] **Twistlock/Prisma** - Container security platform
- [ ] **Aqua Security** - Container security
- [ ] **Sysdig** - Runtime monitoring
- [ ] **AppArmor/SELinux** - Mandatory access control

### Compliance Tools

- [ ] **Docker Bench Security** - CIS benchmark
- [ ] **kube-bench** - Kubernetes security
- [ ] **OPA/Gatekeeper** - Policy enforcement
- [ ] **Open Policy Agent** - Policy as code

## Regular Security Tasks

### Daily Tasks

- [ ] Review security alerts
- [ ] Monitor suspicious activities
- [ ] Check for new vulnerabilities
- [ ] Validate backup integrity

### Weekly Tasks

- [ ] Update base images
- [ ] Review access logs
- [ ] Security scan all images
- [ ] Update security policies

### Monthly Tasks

- [ ] Full security audit
- [ ] Penetration testing
- [ ] Access review
- [ ] Security training updates
- [ ] Incident response plan review

### Quarterly Tasks

- [ ] Comprehensive security assessment
- [ ] Compliance audit
- [ ] Security policy review
- [ ] Third-party security review
- [ ] Disaster recovery testing

## Security Assessment Questions

### Image Security Review

- Are we using trusted base images?
- Are images scanned for vulnerabilities?
- Do images contain secrets or sensitive data?
- Are images signed and verified?
- How often are base images updated?

### Runtime Security Review

- Are containers running as root?
- What capabilities do containers have?
- Are containers using read-only filesystems?
- How are secrets managed?
- Are resource limits enforced?

### Network Security Review

- Is network traffic encrypted?
- Are services properly segmented?
- What ports are exposed externally?
- Are there unnecessary network connections?
- Is network activity monitored?

### Infrastructure Security Review

- Is the Docker daemon secure?
- Are hosts properly hardened?
- Is access properly controlled?
- Are security events monitored?
- Is incident response prepared?

Use this checklist as a comprehensive guide for maintaining Docker security across development, staging, and production environments.
