# Docker Certification Preparation Guide

**Location: `docs/learning-paths/certification-prep.md`**

## Docker Certified Associate (DCA) Overview

The Docker Certified Associate (DCA) certification validates practical skills in Docker containerization, orchestration, security, and troubleshooting. This guide provides structured preparation for the exam.

### Exam Details

- **Duration**: 90 minutes
- **Questions**: 55 multiple choice and discrete option multiple choice (DOMC)
- **Passing Score**: 65% (36/55 questions)
- **Validity**: 3 years
- **Format**: Online proctored exam
- **Prerequisites**: None, but 6+ months Docker experience recommended

## Exam Domains and Objectives

### Domain 1: Orchestration (25% of exam)

#### 1.1 Complete the setup of a swarm mode cluster

**Key Topics:**

- Initialize a swarm cluster
- Add worker and manager nodes
- Setup swarm cluster with high availability
- Configure swarm cluster encryption

**Study Materials:**

```bash
# Initialize swarm
docker swarm init --advertise-addr <IP>

# Join as worker
docker swarm join --token <WORKER_TOKEN> <IP>:2377

# Join as manager
docker swarm join --token <MANAGER_TOKEN> <IP>:2377

# Get join tokens
docker swarm join-token worker
docker swarm join-token manager

# List nodes
docker node ls

# Promote worker to manager
docker node promote <NODE>

# Enable swarm encryption
docker network create --opt encrypted --driver overlay secure-net
```

**Practice Scenarios:**

- Set up 3-manager, 3-worker swarm cluster
- Handle node failures and recovery
- Implement certificate rotation
- Configure external certificate authority

#### 1.2 State the differences between running a container vs running a service

**Key Topics:**

- Container lifecycle vs service lifecycle
- Service replicas and scaling
- Service discovery mechanisms
- Load balancing in services

**Study Materials:**

```bash
# Container vs Service comparison
docker run nginx                    # Single container
docker service create nginx         # Service with replicas

# Service benefits
docker service create --replicas 3 --name web nginx
docker service scale web=5
docker service update --image nginx:alpine web
```

#### 1.3 Demonstrate steps to lock a swarm cluster

**Key Topics:**

- Swarm autolock feature
- Lock/unlock swarm cluster
- Rotate swarm certificates
- Backup and restore swarm cluster

**Study Materials:**

```bash
# Enable autolock
docker swarm update --autolock=true

# Unlock swarm
docker swarm unlock

# Rotate certificates
docker swarm ca --rotate

# Get unlock key
docker swarm unlock-key

# Backup swarm
docker node ls > swarm-backup.txt
```

### Domain 2: Image Creation, Management, and Registry (20% of exam)

#### 2.1 Display the contents of Dockerfile

**Key Topics:**

- Dockerfile instruction syntax
- Best practices for Dockerfile optimization
- Multi-stage builds
- Build context and .dockerignore

**Study Materials:**

```dockerfile
# Optimized Dockerfile example
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine AS runtime
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
WORKDIR /app
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --chown=nextjs:nodejs . .
USER nextjs
EXPOSE 3000
CMD ["npm", "start"]
```

#### 2.2 Describe options for sharing images

**Key Topics:**

- Docker Hub usage
- Private registry setup
- Image naming and tagging
- Registry authentication

**Study Materials:**

```bash
# Image operations
docker tag myapp:latest username/myapp:v1.0
docker push username/myapp:v1.0
docker pull username/myapp:v1.0

# Private registry
docker run -d -p 5000:5000 --name registry registry:2
docker tag myapp localhost:5000/myapp
docker push localhost:5000/myapp
```

#### 2.3 Identify the steps to perform image management

**Key Topics:**

- Image layers and caching
- Image security scanning
- Image cleanup strategies
- Registry maintenance

**Study Materials:**

```bash
# Image management
docker images
docker history myapp:latest
docker inspect myapp:latest

# Cleanup
docker image prune
docker image prune -a
docker system prune
```

### Domain 3: Installation and Configuration (15% of exam)

#### 3.1 Demonstrate the ability to upgrade the Docker engine

**Key Topics:**

- Docker installation methods
- Docker daemon configuration
- Docker engine upgrade procedures
- Troubleshooting installation issues

**Study Materials:**

```bash
# Update Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Configure Docker daemon
sudo systemctl enable docker
sudo systemctl start docker

# Daemon configuration
cat /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### 3.2 Complete setup of repo, select a storage driver, and configure logging

**Key Topics:**

- Docker repository setup
- Storage driver selection
- Logging driver configuration
- Docker daemon optimization

**Study Materials:**

```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "userland-proxy": false,
  "live-restore": true
}
```

### Domain 4: Networking (15% of exam)

#### 4.1 Create a Docker bridge network for a developer to use for containers

**Key Topics:**

- Bridge network creation
- Container network connectivity
- Custom bridge vs default bridge
- Network troubleshooting

**Study Materials:**

```bash
# Network operations
docker network create mybridge
docker network create --driver bridge --subnet 192.168.1.0/24 custom-net
docker run --network mybridge nginx
docker network connect mybridge container1
```

#### 4.2 Troubleshoot container and engine logs to understand connectivity issues

**Key Topics:**

- Log analysis for network issues
- Network debugging tools
- Container connectivity testing
- Docker daemon network configuration

**Study Materials:**

```bash
# Network troubleshooting
docker logs container_name
docker exec container ping target
docker exec container nslookup service
docker network inspect bridge
```

#### 4.3 Publish a port so that an application is accessible externally

**Key Topics:**

- Port mapping options
- Host network vs bridge network
- Load balancing across containers
- Security considerations

**Study Materials:**

```bash
# Port publishing
docker run -p 8080:80 nginx
docker run -p 127.0.0.1:8080:80 nginx
docker run --network host nginx
docker service create --publish 80:80 nginx
```

### Domain 5: Security (15% of exam)

#### 5.1 Describe security administration and tasks

**Key Topics:**

- Docker daemon security
- Image security scanning
- Runtime security practices
- Compliance considerations

**Study Materials:**

```bash
# Security practices
docker scan myapp:latest
docker run --user 1000:1000 myapp
docker run --read-only --tmpfs /tmp myapp
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE nginx
```

#### 5.2 Demonstrate that an image passes a security scan

**Key Topics:**

- Vulnerability scanning tools
- Image security best practices
- Security policy enforcement
- Remediation strategies

**Study Materials:**

```bash
# Security scanning
docker scan nginx:latest
trivy image nginx:latest
docker trust sign myimage:latest
docker trust inspect myimage:latest
```

#### 5.3 Enable Docker Content Trust

**Key Topics:**

- Content trust configuration
- Image signing and verification
- Notary server setup
- Trust delegation

**Study Materials:**

```bash
# Content trust
export DOCKER_CONTENT_TRUST=1
docker push myimage:latest
docker pull myimage:latest
```

### Domain 6: Storage and Volumes (10% of exam)

#### 6.1 State which graph driver should be used on which OS

**Key Topics:**

- Storage drivers comparison
- OS compatibility matrix
- Performance considerations
- Migration between drivers

**Study Materials:**
| OS | Recommended Driver | Alternative |
|----|-------------------|-------------|
| Ubuntu | overlay2 | aufs |
| RHEL/CentOS | overlay2 | devicemapper |
| Windows | windowsfilter | - |

#### 6.2 Demonstrate how to configure devicemapper

**Key Topics:**

- Devicemapper configuration
- Storage pool setup
- Performance tuning
- Troubleshooting storage issues

**Study Materials:**

```json
{
  "storage-driver": "devicemapper",
  "storage-opts": [
    "dm.thinpooldev=/dev/mapper/docker-thinpool",
    "dm.use_deferred_removal=true",
    "dm.use_deferred_deletion=true"
  ]
}
```

#### 6.3 Compare object storage to block storage

**Key Topics:**

- Storage types comparison
- Use cases for each type
- Performance characteristics
- Docker volume drivers

**Study Materials:**

```bash
# Volume operations
docker volume create myvolume
docker volume create --driver local --opt type=nfs myvolume
docker run -v myvolume:/data nginx
docker volume ls
docker volume inspect myvolume
```

## Study Plan (8-12 Weeks)

### Weeks 1-2: Foundation Review

- Review Docker basics and commands
- Practice container lifecycle management
- Study Dockerfile best practices
- Set up practice environment

### Weeks 3-4: Orchestration Focus

- Master Docker Swarm setup and management
- Practice service creation and scaling
- Learn cluster security and backup
- Implement high availability patterns

### Weeks 5-6: Images and Registry

- Advanced image building techniques
- Registry setup and management
- Image security and scanning
- Content trust implementation

### Weeks 7-8: Networking and Storage

- Network troubleshooting skills
- Storage driver configuration
- Volume management practices
- Performance optimization

### Weeks 9-10: Security Deep Dive

- Security scanning and remediation
- Runtime security hardening
- Compliance frameworks
- Incident response procedures

### Weeks 11-12: Practice and Review

- Full-length practice exams
- Hands-on lab scenarios
- Weak area remediation
- Final review and exam scheduling

## Hands-on Lab Scenarios

### Lab 1: Swarm Cluster Setup

**Objective:** Set up a 5-node swarm cluster with HA configuration

**Tasks:**

1. Initialize swarm with 3 managers
2. Add 2 worker nodes
3. Configure cluster encryption
4. Implement node constraints
5. Test failover scenarios

### Lab 2: Multi-Service Application

**Objective:** Deploy complex application with multiple services

**Tasks:**

1. Create overlay network
2. Deploy database with persistent storage
3. Deploy API service with secrets
4. Deploy frontend with load balancing
5. Implement rolling updates

### Lab 3: Security Hardening

**Objective:** Implement comprehensive security measures

**Tasks:**

1. Enable content trust
2. Configure user namespaces
3. Implement network policies
4. Set up vulnerability scanning
5. Create security compliance report

### Lab 4: Troubleshooting Scenario

**Objective:** Diagnose and fix common issues

**Tasks:**

1. Fix networking connectivity issues
2. Resolve storage mounting problems
3. Debug service discovery failures
4. Fix performance bottlenecks
5. Recover from node failures

## Practice Exam Questions

### Sample Questions

**Question 1:** Which command enables Docker Content Trust globally?
A. `docker trust enable`
B. `export DOCKER_CONTENT_TRUST=1`
C. `docker config set trust=true`
D. `docker daemon --enable-trust`

**Answer:** B

**Question 2:** What is the default network driver for Docker Swarm overlay networks?
A. bridge
B. overlay
C. macvlan
D. host

**Answer:** B

**Question 3:** Which storage driver is recommended for production use on Ubuntu?
A. aufs
B. overlay
C. overlay2
D. devicemapper

**Answer:** C

### Practice Resources

**Official Resources:**

- Docker Documentation (docs.docker.com)
- Docker Certification Study Guide
- Docker Desktop and Docker Hub
- Play with Docker (training.play-with-docker.com)

**Third-Party Resources:**

- A Cloud Guru Docker Certification Course
- Linux Academy Docker Deep Dive
- Udemy Docker Certification Prep
- Whizlabs Docker Practice Tests

**Books:**

- "Docker Deep Dive" by Nigel Poulton
- "Docker Certified Associate Study Guide" by Brett Fisher
- "Docker in Action" by Jeff Nickoloff

## Exam Day Strategy

### Before the Exam

- Review key commands and syntax
- Practice time management
- Set up comfortable testing environment
- Verify technical requirements

### During the Exam

- Read questions carefully
- Eliminate obviously wrong answers
- Use process of elimination
- Flag uncertain questions for review
- Manage time effectively (1.6 minutes per question)

### Common Pitfalls to Avoid

- Confusing Docker commands syntax
- Mixing up network driver capabilities
- Misunderstanding service vs container concepts
- Forgetting security best practices
- Time management issues

## Post-Certification

### Maintaining Certification

- Stay current with Docker updates
- Continue hands-on practice
- Engage with Docker community
- Consider advanced certifications

### Career Benefits

- Validates Docker expertise
- Increases job opportunities
- Higher salary potential
- Professional credibility
- Foundation for cloud certifications

### Next Steps

- Kubernetes certifications (CKA, CKAD, CKS)
- Cloud provider certifications (AWS, Azure, GCP)
- Advanced specialization areas
- Community contribution and leadership

## Additional Resources

### Command Reference Card

```bash
# Essential DCA commands
docker swarm init --advertise-addr <IP>
docker service create --replicas 3 --name web nginx
docker network create --driver overlay --encrypted secure-net
docker secret create db_password -
docker config create nginx_config nginx.conf
docker node update --availability drain <NODE>
docker service update --image nginx:alpine web
docker service rollback web
docker trust sign image:tag
export DOCKER_CONTENT_TRUST=1
```

### Troubleshooting Checklist

- [ ] Check Docker daemon status
- [ ] Verify network connectivity
- [ ] Inspect container/service logs
- [ ] Check resource constraints
- [ ] Validate configurations
- [ ] Test with minimal examples
- [ ] Review documentation

The DCA certification demonstrates practical Docker skills valued by employers. Consistent hands-on practice with real-world scenarios is key to passing the exam and building expertise.
