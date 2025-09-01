# Docker Security

**File Location:** `concepts/06_security/README.md`

## Container Security Fundamentals

Docker security involves multiple layers: image security, container runtime security, host security, and network security. A comprehensive security strategy addresses each layer with appropriate controls and monitoring.

## Security Principles

### Defense in Depth

Multiple security layers provide redundancy:

- Secure base images
- Vulnerability scanning
- Runtime security monitoring
- Network segmentation
- Access controls

### Least Privilege

Minimize attack surface by:

- Running as non-root users
- Dropping unnecessary capabilities
- Using read-only filesystems
- Restricting network access

### Secure by Default

Build security into the development process:

- Secure base images
- Automated security scanning
- Policy enforcement
- Security-first configurations

## Image Security

### Base Image Selection

Choose secure, minimal base images:

```dockerfile
# Prefer official images
FROM node:16-alpine

# Or distroless for production
FROM gcr.io/distroless/nodejs

# Avoid using 'latest' tags
FROM ubuntu:20.04  # Not ubuntu:latest
```

### Multi-Stage Builds for Security

Separate build dependencies from runtime:

```dockerfile
# Build stage with development tools
FROM node:16 AS builder
RUN npm install && npm run build

# Production stage with minimal runtime
FROM node:16-alpine AS production
COPY --from=builder /app/dist ./dist
USER 1000
CMD ["node", "dist/app.js"]
```

### Image Vulnerability Scanning

Regular scanning catches known vulnerabilities:

```bash
# Scan with Docker Scout
docker scout cves myimage:latest

# Scan with Trivy
trivy image myimage:latest

# Automated scanning in CI/CD
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image myimage:latest
```

## Container Runtime Security

### Non-Root Users

Always run containers as non-root:

```dockerfile
# Create and use non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser

# Or use numeric UID
USER 1000:1000
```

### Security Options

Harden container runtime:

```bash
# Drop all capabilities, add only needed ones
docker run --cap-drop=ALL --cap-add=NET_ADMIN app

# Read-only root filesystem
docker run --read-only --tmpfs /tmp app

# No new privileges
docker run --security-opt=no-new-privileges app

# Custom seccomp profile
docker run --security-opt seccomp=profile.json app
```

### Resource Limits

Prevent resource exhaustion:

```bash
# Memory and CPU limits
docker run --memory=512m --cpus=0.5 app

# PID limits
docker run --pids-limit=100 app
```

## Secret Management

### Docker Secrets (Swarm Mode)

```yaml
version: "3.8"
services:
  app:
    image: myapp
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    external: true
  api_key:
    file: ./api_key.txt
```

### Environment Variable Security

Avoid secrets in environment variables:

```bash
# Bad - visible in process lists
docker run -e PASSWORD=secret app

# Good - use secrets or files
docker run -v /host/secret:/run/secrets/password:ro app
```

### External Secret Management

Integration with secret management systems:

- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Kubernetes Secrets

## Network Security

### Network Isolation

```bash
# Create isolated networks
docker network create --internal backend-net
docker network create frontend-net

# Place services on appropriate networks
docker run --network backend-net database
docker run --network frontend-net --network backend-net webapp
```

### Firewall and Port Management

```bash
# Bind to specific interfaces
docker run -p 127.0.0.1:8080:80 app  # localhost only
docker run -p 192.168.1.10:8080:80 app  # specific IP

# Use unprivileged ports
docker run -p 8080:8080 app  # Not port 80
```

## Image Signing and Trust

### Docker Content Trust

```bash
# Enable Content Trust
export DOCKER_CONTENT_TRUST=1

# Sign and push images
docker push myrepo/myapp:v1.0

# Verification happens automatically on pull
docker pull myrepo/myapp:v1.0
```

### Cosign Integration

```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myrepo/myapp:v1.0

# Verify signature
cosign verify --key cosign.pub myrepo/myapp:v1.0
```

## Runtime Security Monitoring

### Falco Integration

Real-time threat detection:

```yaml
# Falco rules for container monitoring
- rule: Unexpected network connection
  desc: Detect unexpected network connections
  condition: >
    spawned_process and container and
    fd.type=ipv4 and not expected_network_connections
  output: >
    Unexpected network connection (user=%user.name command=%proc.cmdline
    connection=%fd.name)
  priority: WARNING
```

### Security Benchmarks

Follow industry standards:

- CIS Docker Benchmark
- NIST Container Security Guidelines
- PCI DSS for payment applications

## Compliance and Auditing

### Automated Compliance Checking

```bash
# Docker Bench Security
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

### Audit Logging

```bash
# Enable Docker daemon audit logging
dockerd --log-level=info --log-driver=json-file \
  --log-opt audit=true
```

## Security Scanning Integration

### CI/CD Pipeline Integration

```yaml
# Example GitHub Actions
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: "${{ env.IMAGE }}"
    format: "sarif"
    output: "trivy-results.sarif"

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: "trivy-results.sarif"
```

## Files in This Directory

- `Dockerfile.rootless` - Non-root container implementation
- `Dockerfile.hardened` - Security-hardened container example
- `scan_image.sh` - Comprehensive vulnerability scanning script
- `secrets_demo/` - Secure secret handling examples
  - `docker-compose.yml` - Docker secrets demonstration
  - `secrets.env` - Environment secret file
  - `app.py` - Application with secure secret handling
  - `vault-integration.yml` - HashiCorp Vault integration
- `image-signing/` - Image signing and verification
  - `notary-demo.sh` - Docker Content Trust demo
  - `cosign-example.sh` - Cosign signing workflow
- `runtime-security/` - Runtime security monitoring
  - `falco-rules.yml` - Falco security rules
  - `apparmor-profiles/` - AppArmor security profiles
  - `seccomp-profiles/` - Seccomp security profiles
- `compliance/` - Security compliance tools
  - `cis-benchmark.md` - CIS Docker Benchmark guide
  - `security-audit.sh` - Automated security audit script
  - `vulnerability-mgmt.md` - Vulnerability management process

## Security Best Practices

1. **Use minimal base images** (Alpine, distroless)
2. **Run as non-root users** always
3. **Scan images regularly** for vulnerabilities
4. **Keep base images updated** with security patches
5. **Use secrets management** never hardcode secrets
6. **Enable Docker Content Trust** for image verification
7. **Implement network segmentation** isolate services
8. **Monitor runtime security** with tools like Falco
9. **Follow security benchmarks** (CIS, NIST)
10. **Automate security testing** in CI/CD pipelines
11. **Use read-only filesystems** when possible
12. **Implement proper logging** for security auditing
13. **Regular security audits** and penetration testing
14. **Security training** for development teams

## Threat Model

### Common Container Threats

- Container escape
- Privileged escalation
- Resource exhaustion
- Network attacks
- Supply chain attacks
- Data exfiltration

### Mitigation Strategies

- Defense in depth
- Least privilege access
- Network isolation
- Runtime monitoring
- Incident response plans

Security is not a one-time setup but an ongoing process requiring continuous monitoring, updating, and improvement.
