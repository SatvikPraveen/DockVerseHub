# Docker Security Best Practices: Scanning, Secrets & Rootless Mode

**Location: `docs/security-best-practices.md`**

## Security Fundamentals

Docker security involves multiple layers from the host system to individual containers. A comprehensive security strategy addresses image security, runtime security, network security, and secrets management.

## Image Security

### Base Image Selection

```dockerfile
# ❌ Avoid
FROM ubuntu:latest

# ✅ Recommended
FROM ubuntu:20.04-20230308  # Pinned version with date
FROM alpine:3.18.0         # Minimal base image
FROM gcr.io/distroless/java:11  # Distroless for production
```

### Distroless Images

```dockerfile
# Multi-stage build with distroless
FROM maven:3.8-openjdk-11 AS builder
COPY . /app
WORKDIR /app
RUN mvn package

FROM gcr.io/distroless/java:11
COPY --from=builder /app/target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### Image Scanning

#### Using Docker Scout (Built-in)

```bash
# Enable Docker Scout
docker scout quickview

# Scan local image
docker scout cves myapp:latest

# Scan and show recommendations
docker scout recommendations myapp:latest

# Compare images
docker scout compare myapp:v1.0 --to myapp:v2.0
```

#### Using Trivy

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

# Scan image
trivy image nginx:latest

# Scan with specific severity
trivy image --severity HIGH,CRITICAL nginx:latest

# Generate report
trivy image --format json --output report.json nginx:latest
```

#### Using Clair

```yaml
# docker-compose.yml for Clair
version: "3.8"
services:
  clair-db:
    image: postgres:13
    environment:
      POSTGRES_DB: clair
      POSTGRES_USER: clair
      POSTGRES_PASSWORD: password

  clair:
    image: quay.io/coreos/clair:latest
    depends_on:
      - clair-db
    ports:
      - "6060:6060"
      - "6061:6061"
    volumes:
      - ./clair-config.yml:/etc/clair/config.yaml
```

### Dockerfile Security Best Practices

```dockerfile
# Use specific versions
FROM node:16.20.0-alpine3.17

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Set working directory
WORKDIR /app

# Install dependencies as root, then change ownership
COPY package*.json ./
RUN npm ci --only=production && \
    chown -R nextjs:nodejs /app

# Copy application files
COPY --chown=nextjs:nodejs . .

# Switch to non-root user
USER nextjs

# Use exec form for CMD
CMD ["node", "server.js"]

# Don't expose unnecessary ports
EXPOSE 3000

# Use HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

## Runtime Security

### Running as Non-Root User

```bash
# Create user in Dockerfile
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

# Or specify user at runtime
docker run --user 1000:1000 myapp

# Docker Compose
version: '3.8'
services:
  app:
    image: myapp
    user: "1000:1000"
```

### Rootless Docker

```bash
# Install rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Set environment
export PATH=/home/user/bin:$PATH
export DOCKER_HOST=unix:///run/user/1000/docker.sock

# Start rootless daemon
systemctl --user enable docker
systemctl --user start docker
```

### Security Options

```bash
# Drop all capabilities and add only needed ones
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx

# Read-only root filesystem
docker run --read-only --tmpfs /tmp nginx

# No new privileges
docker run --security-opt=no-new-privileges nginx

# AppArmor profile
docker run --security-opt apparmor:my-profile nginx

# SELinux label
docker run --security-opt label:type:container_t nginx
```

### Resource Limits

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
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
```

## Secrets Management

### Docker Secrets (Swarm Mode)

```bash
# Create secret
echo "mysecretpassword" | docker secret create db_password -

# Or from file
docker secret create db_password ./password.txt

# Use in service
docker service create \
  --name myapp \
  --secret db_password \
  myapp:latest
```

```yaml
# docker-compose.yml (Swarm mode)
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

### Environment Variables vs Secrets

```bash
# ❌ Bad - secrets in environment
docker run -e DB_PASSWORD=secret123 myapp

# ✅ Good - secrets from file
docker run -v /secure/db_password:/run/secrets/db_password:ro myapp
```

### External Secret Management

```yaml
# HashiCorp Vault integration
version: "3.8"
services:
  app:
    image: myapp
    environment:
      - VAULT_ADDR=https://vault.example.com
      - VAULT_TOKEN_FILE=/run/secrets/vault_token
    secrets:
      - vault_token
    command: |
      sh -c '
        export VAULT_TOKEN=$(cat /run/secrets/vault_token)
        export DB_PASSWORD=$(vault kv get -field=password secret/db)
        exec myapp
      '
```

### Secret Rotation

```bash
#!/bin/bash
# rotate-secrets.sh
NEW_PASSWORD=$(openssl rand -base64 32)
echo "$NEW_PASSWORD" | docker secret create db_password_v2 -
docker service update --secret-rm db_password --secret-add db_password_v2 myapp
docker secret rm db_password
```

## Network Security

### Network Isolation

```yaml
version: "3.8"
services:
  web:
    image: nginx
    networks:
      - frontend
      - backend

  api:
    image: myapi
    networks:
      - backend

  database:
    image: postgres
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true # No external access
```

### TLS/SSL Configuration

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl:ro
    environment:
      - SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
      - SSL_KEY_PATH=/etc/nginx/ssl/key.pem
```

```nginx
# nginx.conf
server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

    location / {
        proxy_pass http://app:3000;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall Rules

```bash
# Configure host firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw deny 2376/tcp  # Docker daemon port
ufw enable

# Docker-specific rules
iptables -I DOCKER-USER -s 10.0.0.0/8 -d 172.17.0.0/16 -j DROP
```

## Container Hardening

### Read-Only Containers

```dockerfile
FROM alpine:3.18
RUN adduser -D appuser
COPY app /usr/local/bin/app
RUN chmod +x /usr/local/bin/app
USER appuser
CMD ["app"]
```

```yaml
version: "3.8"
services:
  app:
    image: myapp
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
      - /var/run:noexec,nosuid,size=50m
```

### Security Profiles

```yaml
# AppArmor profile
version: "3.8"
services:
  app:
    image: myapp
    security_opt:
      - apparmor:docker-default
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETUID
      - SETGID
```

```json
# seccomp profile (seccomp.json)
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "syscalls": [
    {
      "names": ["read", "write", "open", "close"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```bash
# Use custom seccomp profile
docker run --security-opt seccomp:seccomp.json myapp
```

## Host System Security

### Docker Daemon Security

```json
# /etc/docker/daemon.json
{
  "icc": false,
  "userland-proxy": false,
  "live-restore": true,
  "no-new-privileges": true,
  "hosts": ["unix:///var/run/docker.sock"],
  "tls": true,
  "tlscert": "/etc/docker/server-cert.pem",
  "tlskey": "/etc/docker/server-key.pem",
  "tlsverify": true,
  "tlscacert": "/etc/docker/ca.pem"
}
```

### User Namespace Remapping

```json
# /etc/docker/daemon.json
{
  "userns-remap": "default"
}
```

```bash
# Configure subuid/subgid
echo "dockremap:165536:65536" >> /etc/subuid
echo "dockremap:165536:65536" >> /etc/subgid
systemctl restart docker
```

### Resource Protection

```bash
# Limit resources system-wide
echo 'DOCKER_OPTS="--default-ulimit memlock=-1 --default-ulimit nproc=1024:2048"' >> /etc/default/docker

# Cgroup limits
echo 'docker ALL=(ALL) NOPASSWD: /usr/bin/docker' >> /etc/sudoers.d/docker
```

## Monitoring and Auditing

### Security Monitoring

```yaml
# Falco security monitoring
version: "3.8"
services:
  falco:
    image: falcosecurity/falco:latest
    privileged: true
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - /dev:/host/dev
      - /proc:/host/proc:ro
      - /boot:/host/boot:ro
      - /lib/modules:/host/lib/modules:ro
      - /usr:/host/usr:ro
      - ./falco.yaml:/etc/falco/falco.yaml
    command: falco --cri /host/var/run/docker.sock
```

### Audit Logging

```bash
# Enable Docker audit logging
echo 'DOCKER_OPTS="--log-level=info --log-driver=syslog --log-opt syslog-address=tcp://logserver:514"' >> /etc/default/docker

# Audit container events
docker events --filter type=container --format 'table {{.Time}}\t{{.Action}}\t{{.Actor.Attributes.name}}'
```

### Log Analysis

```yaml
# ELK stack for security logs
version: "3.8"
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.14.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"

  logstash:
    image: docker.elastic.co/logstash/logstash:7.14.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

  kibana:
    image: docker.elastic.co/kibana/kibana:7.14.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
```

## Compliance and Standards

### CIS Docker Benchmark

```bash
# Run CIS benchmark
docker run --rm -it --net host --pid host --userns host --cap-add audit_control \
  -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
  -v /etc:/etc:ro \
  -v /lib/systemd/system:/lib/systemd/system:ro \
  -v /usr/bin/containerd:/usr/bin/containerd:ro \
  -v /usr/bin/runc:/usr/bin/runc:ro \
  -v /usr/lib/systemd:/usr/lib/systemd:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label docker_bench_security \
  docker/docker-bench-security
```

### NIST Guidelines

```yaml
# NIST compliant configuration
version: "3.8"
services:
  app:
    image: myapp
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-default
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: "no"
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "0.25"
```

## CI/CD Security Integration

### Secure Pipeline

```yaml
# .github/workflows/security.yml
name: Security Scan
on:
  push:
  pull_request:

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: "myapp:${{ github.sha }}"
          format: "sarif"
          output: "trivy-results.sarif"

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v1
        with:
          sarif_file: "trivy-results.sarif"
```

### Image Signing

```bash
# Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker push myregistry/myapp:latest

# Cosign
cosign generate-key-pair
cosign sign --key cosign.key myregistry/myapp:latest

# Verify signature
cosign verify --key cosign.pub myregistry/myapp:latest
```

## Security Checklist

### Development Phase

- [ ] Use official base images
- [ ] Pin image versions
- [ ] Scan images for vulnerabilities
- [ ] Create non-root user
- [ ] Use multi-stage builds
- [ ] Don't store secrets in images
- [ ] Implement health checks
- [ ] Use .dockerignore

### Deployment Phase

- [ ] Enable Docker Content Trust
- [ ] Use secrets management
- [ ] Configure network isolation
- [ ] Set resource limits
- [ ] Enable read-only filesystems
- [ ] Drop unnecessary capabilities
- [ ] Use security profiles
- [ ] Enable audit logging

### Runtime Phase

- [ ] Monitor container behavior
- [ ] Regular security updates
- [ ] Rotate secrets
- [ ] Review access logs
- [ ] Backup security configs
- [ ] Test disaster recovery
- [ ] Security training for team

## Incident Response

### Security Breach Response

```bash
#!/bin/bash
# incident-response.sh

# 1. Isolate affected containers
docker network disconnect bridge compromised-container
docker pause compromised-container

# 2. Capture forensic data
docker logs compromised-container > incident-logs.txt
docker exec compromised-container ps aux > process-list.txt
docker diff compromised-container > filesystem-changes.txt

# 3. Create forensic image
docker commit compromised-container forensic-image:$(date +%Y%m%d_%H%M%S)

# 4. Remove compromised container
docker stop compromised-container
docker rm compromised-container

# 5. Deploy clean replacement
docker run -d --name clean-container myapp:latest
```

### Recovery Procedures

```yaml
# recovery-stack.yml
version: "3.8"
services:
  app:
    image: myapp:clean-version
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    networks:
      - isolated

networks:
  isolated:
    driver: bridge
    internal: true
```

## Tools and Resources

### Security Tools

- **Trivy**: Vulnerability scanner
- **Clair**: Static analysis of vulnerabilities
- **Docker Scout**: Built-in security scanning
- **Falco**: Runtime security monitoring
- **Anchore**: Container security platform
- **Twistlock/Prisma**: Enterprise security platform

### Documentation Links

- [Docker Security](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)

## Next Steps

- Learn [Monitoring and Logging](./monitoring-logging.md) for security observability
- Explore [Production Deployment](./production-deployment.md) security considerations
- Check [Troubleshooting](./troubleshooting.md) for security-related issues
- Understand [Docker Ecosystem](./docker-ecosystem.md) security tools
