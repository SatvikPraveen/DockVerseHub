# Docker Beginner Learning Path (0-3 Months)

**Location: `docs/learning-paths/beginner-path.md`**

## Learning Objectives

By the end of this path, you will be able to:

- Understand Docker fundamentals and core concepts
- Create and run containers effectively
- Write basic Dockerfiles
- Use Docker Compose for multi-container applications
- Implement basic security and best practices
- Troubleshoot common Docker issues

## Phase 1: Foundation (Weeks 1-2)

### Week 1: Docker Basics

**Goal**: Understand what Docker is and why it's useful

#### Theory (2-3 hours)

- [ ] Read [Docker Basics](../docker-basics.md)
- [ ] Read [Images vs Containers](../images-vs-containers.md)
- [ ] Watch: "Docker in 100 Seconds" (YouTube)
- [ ] Understand containerization vs virtualization

#### Hands-on Practice

```bash
# Day 1-2: Installation and first container
# Install Docker on your system
docker --version

# Run your first container
docker run hello-world
docker run -it ubuntu bash
docker run -d nginx
docker ps
docker stop CONTAINER_ID
```

```bash
# Day 3-4: Basic container operations
docker pull alpine
docker images
docker run -it alpine sh
docker run --name mycontainer alpine echo "Hello Docker"
docker logs mycontainer
docker rm mycontainer
```

```bash
# Day 5-7: Port mapping and volumes
docker run -d -p 8080:80 --name web nginx
# Visit http://localhost:8080
docker run -v /host/path:/container/path alpine
docker exec -it web bash
```

#### Weekly Project: Personal Web Server

Create a simple personal website using Nginx:

```bash
# Create index.html
echo "<h1>My First Docker Website</h1>" > index.html

# Run nginx with custom content
docker run -d -p 8080:80 -v $(pwd):/usr/share/nginx/html --name myweb nginx

# Test and modify content
# Visit http://localhost:8080
```

### Week 2: Working with Images

**Goal**: Understand Docker images and the Docker Hub

#### Theory (2-3 hours)

- [ ] Docker Hub and registries
- [ ] Image layers and caching
- [ ] Image naming and tagging
- [ ] Official vs community images

#### Hands-on Practice

```bash
# Day 1-2: Exploring Docker Hub
docker search python
docker pull python:3.9-alpine
docker pull python:3.9-slim
docker images
docker history python:3.9-alpine
```

```bash
# Day 3-4: Image operations
docker tag python:3.9-alpine my-python:latest
docker save python:3.9-alpine > python-image.tar
docker rmi python:3.9-alpine
docker load < python-image.tar
```

```bash
# Day 5-7: Registry operations
# Create Docker Hub account
docker login
docker tag my-python:latest username/my-python:v1.0
docker push username/my-python:v1.0
docker pull username/my-python:v1.0
```

#### Weekly Project: Image Exploration

Compare different base images:

- Create a simple script that shows OS info
- Run it on ubuntu, alpine, and debian containers
- Compare image sizes and startup times

## Phase 2: Building (Weeks 3-4)

### Week 3: Dockerfile Fundamentals

**Goal**: Create your own Docker images

#### Theory (2-3 hours)

- [ ] Read [Dockerfile Best Practices](../quick-reference/dockerfile-best-practices.md)
- [ ] Dockerfile instructions: FROM, RUN, COPY, CMD, ENTRYPOINT
- [ ] Layer optimization and caching
- [ ] .dockerignore files

#### Hands-on Practice

```dockerfile
# Day 1-2: First Dockerfile
FROM alpine:latest
RUN apk add --no-cache curl
COPY script.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/script.sh
CMD ["script.sh"]
```

```bash
# Build and test
docker build -t my-first-image .
docker run my-first-image
```

```dockerfile
# Day 3-4: Web application Dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

```dockerfile
# Day 5-7: Optimization
# Multi-stage build
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
CMD ["npm", "start"]
```

#### Weekly Project: Personal Application

Build a simple web application:

- Create a "Hello World" web app (Node.js, Python, or any language)
- Write a Dockerfile for it
- Build and run the container
- Push to Docker Hub

### Week 4: Volumes and Networking

**Goal**: Understand data persistence and container communication

#### Theory (2-3 hours)

- [ ] Read [Volumes and Storage](../volumes-storage.md)
- [ ] Read [Docker Networking](../networking.md)
- [ ] Volume types: bind mounts, named volumes, anonymous volumes
- [ ] Basic networking concepts

#### Hands-on Practice

```bash
# Day 1-2: Volume practice
docker volume create mydata
docker run -d -v mydata:/data --name app1 alpine sleep 3600
docker exec app1 sh -c 'echo "persistent data" > /data/file.txt'
docker rm -f app1
docker run -v mydata:/data alpine cat /data/file.txt
```

```bash
# Day 3-4: Networking basics
docker network create mynetwork
docker run -d --network mynetwork --name db alpine sleep 3600
docker run -d --network mynetwork --name app alpine sleep 3600
docker exec app ping db
```

```bash
# Day 5-7: Combined practice
docker run -d --name database -v db-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=secret mysql:8.0
docker run -d --name app --link database:db -p 8080:80 \
  my-web-app
```

#### Weekly Project: Data Persistence

Create a note-taking application:

- Simple web form that saves notes to a file
- Use volume to persist data between container restarts
- Test data persistence by stopping and restarting container

## Phase 3: Multi-Container Applications (Weeks 5-6)

### Week 5: Docker Compose Basics

**Goal**: Orchestrate multi-container applications

#### Theory (2-3 hours)

- [ ] Read [Docker Compose](../docker-compose.md)
- [ ] Read [Compose Patterns](../quick-reference/compose-patterns.md)
- [ ] YAML basics
- [ ] Service definition and dependencies

#### Hands-on Practice

```yaml
# Day 1-2: First compose file
version: "3.8"
services:
  web:
    image: nginx
    ports:
      - "8080:80"

  app:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - web
```

```bash
docker-compose up
docker-compose down
docker-compose ps
docker-compose logs app
```

```yaml
# Day 3-4: Database integration
version: "3.8"
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

```yaml
# Day 5-7: Complete web stack
version: "3.8"
services:
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app

  app:
    build: .
    expose:
      - "3000"
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
    volumes:
      - db_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine

volumes:
  db_data:
```

#### Weekly Project: Full-Stack Application

Build a complete web application:

- Frontend (static files served by Nginx)
- Backend API (your choice of language)
- Database (PostgreSQL or MySQL)
- Cache (Redis)
- All orchestrated with Docker Compose

### Week 6: Development Workflow

**Goal**: Integrate Docker into development workflow

#### Theory (1-2 hours)

- [ ] Development vs production configurations
- [ ] Environment variables and secrets
- [ ] Hot reloading in containers
- [ ] Docker for local development

#### Hands-on Practice

```yaml
# Day 1-2: Development setup
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
```

```bash
# Day 3-4: Environment management
# .env file
NODE_ENV=development
DATABASE_URL=postgresql://user:pass@localhost:5432/dev_db
DEBUG=true

# Use in compose
docker-compose --env-file .env.dev up
```

```bash
# Day 5-7: Production-like setup
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

#### Weekly Project: Development Environment

Create a development environment for a project:

- Hot reloading for code changes
- Separate development and production configurations
- Database seeding for development
- Easy setup process for new developers

## Phase 4: Best Practices and Troubleshooting (Weeks 7-8)

### Week 7: Security and Best Practices

**Goal**: Implement security best practices

#### Theory (2-3 hours)

- [ ] Read [Security Best Practices](../security-best-practices.md)
- [ ] Read [Security Checklist](../quick-reference/security-checklist.md)
- [ ] Container security fundamentals
- [ ] Running as non-root user

#### Hands-on Practice

```dockerfile
# Day 1-2: Secure Dockerfile
FROM node:16-alpine
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
WORKDIR /app
COPY --chown=nextjs:nodejs package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --chown=nextjs:nodejs . .
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

```bash
# Day 3-4: Security scanning
docker scan myapp:latest
# or use Trivy
trivy image myapp:latest
```

```bash
# Day 5-7: Security best practices
# Run with read-only filesystem
docker run --read-only --tmpfs /tmp myapp

# Drop capabilities
docker run --cap-drop ALL myapp

# Use security options
docker run --security-opt no-new-privileges:true myapp
```

#### Weekly Project: Secure Application

Take an existing application and make it secure:

- Run as non-root user
- Use minimal base image
- Implement health checks
- Scan for vulnerabilities
- Document security measures

### Week 8: Troubleshooting and Debugging

**Goal**: Debug common Docker issues

#### Theory (1-2 hours)

- [ ] Read [Troubleshooting Guide](../troubleshooting.md)
- [ ] Read [Troubleshooting Flowcharts](../quick-reference/troubleshooting-flowcharts.md)
- [ ] Common error patterns
- [ ] Debugging techniques

#### Hands-on Practice

```bash
# Day 1-2: Debug container issues
docker run -d --name broken-app broken:latest
docker logs broken-app
docker exec -it broken-app sh
docker inspect broken-app
```

```bash
# Day 3-4: Network troubleshooting
docker exec container1 ping container2
docker exec container1 nslookup container2
docker network inspect bridge
```

```bash
# Day 5-7: Performance debugging
docker stats
docker system df
docker system events
```

#### Weekly Project: Debug and Fix

Intentionally break an application in various ways:

- Container won't start
- Network connectivity issues
- Volume mounting problems
- Performance issues
  Then practice debugging and fixing each issue.

## Phase 5: Practical Application (Weeks 9-12)

### Capstone Project: Personal Portfolio Website

Build a complete portfolio website with:

**Requirements:**

- [ ] Frontend (HTML/CSS/JS or React/Vue)
- [ ] Backend API (Node.js/Python/Go)
- [ ] Database (PostgreSQL/MySQL)
- [ ] Reverse proxy (Nginx)
- [ ] All containerized with Docker Compose

**Technical Requirements:**

- [ ] Multi-stage Dockerfile builds
- [ ] Non-root user in containers
- [ ] Health checks for all services
- [ ] Persistent data storage
- [ ] Environment-based configuration
- [ ] SSL termination at proxy
- [ ] Development and production configurations

**Deliverables:**

1. GitHub repository with complete code
2. README with setup instructions
3. Docker Hub images for all custom containers
4. docker-compose files for different environments
5. Documentation of architecture and design decisions

## Assessment and Next Steps

### Self-Assessment Checklist

**Container Fundamentals:**

- [ ] Can explain difference between images and containers
- [ ] Can run containers with various options
- [ ] Can manage container lifecycle
- [ ] Can troubleshoot basic container issues

**Image Management:**

- [ ] Can create Dockerfiles
- [ ] Can build optimized images
- [ ] Can push/pull from registries
- [ ] Can use multi-stage builds

**Multi-Container Applications:**

- [ ] Can write Docker Compose files
- [ ] Can orchestrate services with dependencies
- [ ] Can manage data persistence
- [ ] Can configure networking

**Best Practices:**

- [ ] Implements security best practices
- [ ] Uses appropriate base images
- [ ] Follows Dockerfile optimization patterns
- [ ] Can debug common issues

### Recommended Next Steps

**If you want to focus on Development:**

- Continue to [Intermediate Learning Path](./intermediate-path.md)
- Learn about CI/CD integration
- Explore container orchestration (Kubernetes)

**If you want to focus on Operations:**

- Learn Docker Swarm for orchestration
- Study production deployment patterns
- Explore monitoring and logging solutions

**If you want to focus on Security:**

- Deep dive into container security
- Learn about compliance and governance
- Study security scanning and policies

## Resources for Continued Learning

### Essential Reading

- Docker Official Documentation
- "Docker Deep Dive" by Nigel Poulton
- "Docker in Action" by Jeff Nickoloff

### Practice Platforms

- Docker Playground (play-with-docker.com)
- Katacoda Docker scenarios
- Local development projects

### Communities

- Docker Community Slack
- r/docker subreddit
- Stack Overflow docker tag

### YouTube Channels

- Docker (official channel)
- TechWorld with Nana
- NetworkChuck

Remember: The key to mastering Docker is consistent hands-on practice. Try to work with Docker daily, even if just for 15-30 minutes!
