# Getting Started with DockVerseHub

Welcome to DockVerseHub! This guide will help you get up and running with the Docker learning platform.

## Prerequisites

Before you start, ensure you have the following installed:

### Required
- **Docker**: Version 20.10 or later
  - [Install Docker Desktop](https://www.docker.com/products/docker-desktop) (includes Docker Compose)
  - Verify: `docker --version`

- **Docker Compose**: Version 2.0 or later (included with Docker Desktop)
  - Verify: `docker-compose --version`

- **Git**: For cloning and version control
  - Verify: `git --version`

### Optional but Recommended
- **Python 3.9+**: For running utility scripts
  - Verify: `python3 --version`
- **Make**: For using Makefile commands (pre-installed on macOS/Linux)
  - Verify: `make --version`

## Quick Start (5 minutes)

### 1. Clone the Repository

```bash
git clone https://github.com/SatvikPraveen/DockVerseHub.git
cd DockVerseHub
```

### 2. Verify Docker Installation

```bash
make check-docker
# Or manually:
docker run --rm hello-world
```

You should see a welcome message from Docker if everything is working correctly.

### 3. Run Your First Lab

#### Option A: Using Make (Recommended)

```bash
# List all available labs
make labs

# Start lab 01 (simple app)
make lab-01

# Access the application
curl http://localhost:8080
# or open in browser: http://localhost:8080

# Stop the lab
make stop-lab-01
```

#### Option B: Manual Docker Commands

```bash
cd labs/lab_01_simple_app

# Build the image
docker build -t simple-app .

# Run with docker-compose
docker-compose up

# In another terminal, test it:
curl http://localhost:8080

# Stop it:
docker-compose down
```

## Project Structure

```
DockVerseHub/
├── concepts/              # 10 core Docker concepts with examples
│   ├── 01_getting_started/
│   ├── 02_images_layers/
│   ├── 03_volumes_bindmounts/
│   ├── 04_networking/
│   ├── 05_docker_compose/
│   ├── 06_security/
│   ├── 07_logging_monitoring/
│   ├── 08_orchestration/
│   ├── 09_advanced_tricks/
│   └── 10_ci_cd_integration/
│
├── labs/                  # 6 hands-on laboratory projects
│   ├── lab_01_simple_app/
│   ├── lab_02_multi_container_compose/
│   ├── lab_03_image_optimization/
│   ├── lab_04_logging_dashboard/
│   ├── lab_05_microservices_demo/
│   └── lab_06_production_deployment/
│
├── docs/                  # Comprehensive guides and references
│   ├── docker-basics.md
│   ├── docker-cheatsheet.md
│   ├── learning-paths/
│   └── quick-reference/
│
├── utilities/             # Tools, scripts, and templates
│   ├── scripts/           # Automation scripts
│   ├── dev-tools/         # Development utilities
│   └── Dockerfile.templates/
│
└── case-studies/          # Real-world implementation examples
```

## Common Tasks

### View Available Makefile Commands

```bash
make help
```

### Set Up Development Environment

```bash
# Install all Python dependencies
make setup

# This will:
# - Verify Docker installation
# - Install Python packages from requirements.txt
# - Run a Docker test
```

### Run All Tests

```bash
make test-all

# This runs:
# - Docker setup tests
# - Dockerfile validation
# - Docker Compose validation
# - Shell script validation
# - Lab environment tests
```

### Work Through Learning Paths

#### Beginner Path (0-3 months)
1. Read: `docs/learning-paths/beginner-path.md`
2. Concept modules: 01 - 05
3. Lab 01: Simple App
4. Lab 02: Multi-container Compose

#### Intermediate Path (3-6 months)
1. Read: `docs/learning-paths/intermediate-path.md`
2. Concept modules: 06 - 07
3. Lab 03: Image Optimization
4. Lab 04: Logging Dashboard

#### Advanced Path (6-12 months)
1. Read: `docs/learning-paths/advanced-path.md`
2. Concept modules: 08 - 10
3. Lab 05: Microservices Demo
4. Lab 06: Production Deployment

### Work Through a Specific Concept

```bash
cd concepts/02_images_layers
cat README.md

# Run examples in the directory
docker build -f Dockerfile.basic -t my-image .
```

### Check Project Statistics

```bash
make stats

# Shows:
# - Number of Dockerfiles
# - Number of Docker Compose files
# - Number of labs and concepts
# - Number of utility scripts
# - Number of documentation files
```

## Lab Details

### Lab 01: Simple Containerized Application
**Time:** 15-30 minutes | **Level:** Beginner

A basic Flask web application in a Docker container. Covers:
- Writing Dockerfiles
- Building and running containers
- Port mapping
- Docker Compose basics

```bash
cd labs/lab_01_simple_app
docker-compose up
curl http://localhost:8080
```

### Lab 02: Multi-Container Compose
**Time:** 30-45 minutes | **Level:** Beginner-Intermediate

Full-stack application with API, database, and frontend. Covers:
- Multi-service orchestration
- Service networking
- Volume usage
- Environment configuration

```bash
cd labs/lab_02_multi_container_compose
docker-compose up
# Visit http://localhost:3000 (frontend)
# API at http://localhost:5000
```

### Lab 03: Image Optimization
**Time:** 20-30 minutes | **Level:** Intermediate

Build and compare different Docker image optimization approaches. Covers:
- Multi-stage builds
- Alpine Linux
- Layer caching
- Image size reduction

```bash
cd labs/lab_03_image_optimization
./benchmark.sh
# Compares image sizes and build times
```

### Lab 04: Logging Dashboard
**Time:** 45-60 minutes | **Level:** Intermediate-Advanced

Complete observability stack with ELK and Prometheus. Covers:
- Log aggregation
- Metrics collection
- Dashboard visualization
- Alerting setup

```bash
cd labs/lab_04_logging_dashboard
docker-compose up
# Grafana: http://localhost:3000 (admin/admin)
# Kibana: http://localhost:5601
```

### Lab 05: Microservices Demo
**Time:** 60-90 minutes | **Level:** Advanced

Distributed microservices architecture with multiple services. Covers:
- Service discovery
- API gateway
- Database per service
- Inter-service communication

```bash
cd labs/lab_05_microservices_demo
docker-compose up
# API Gateway: http://localhost:8000
```

### Lab 06: Production Deployment
**Time:** 90-120 minutes | **Level:** Advanced

Enterprise-grade deployment setup. Covers:
- SSL/TLS configuration
- Backup strategies
- Health checks
- Security hardening

```bash
cd labs/lab_06_production_deployment
docker-compose -f docker-compose.prod.yml up
```

## Troubleshooting

### "Docker daemon is not running"

**Solution:** Start Docker Desktop or Docker daemon:
```bash
# macOS
open /Applications/Docker.app

# Linux
sudo systemctl start docker

# Windows
# Open Docker Desktop from Start menu
```

### "Port already in use"

**Solution:** Use a different port:
```bash
# Find what's using the port
lsof -i :8080

# Use a different port
docker-compose -e "PORT=8081" up
```

### "Docker Compose version error"

**Solution:** Ensure you have Docker Compose v2:
```bash
docker-compose --version
# Should show something like "Docker Compose version 2.x.x"

# If not, update Docker Desktop
```

### Container exits immediately

**Solution:** Check logs:
```bash
docker-compose logs

# Or for a specific service:
docker-compose logs service_name
```

### Volume permission issues

**Solution:** Fix permissions or run as appropriate user:
```bash
# Check current user
whoami

# Fix volume ownership
sudo chown -R $USER:$USER volume_directory
```

## Next Steps

1. **Complete Lab 01** to build confidence with Docker basics
2. **Read the concepts** modules corresponding to your learning level
3. **Work through labs** in order - each builds on previous knowledge
4. **Explore documentation** in `docs/` directory for deeper understanding
5. **Check case studies** for real-world patterns and practices

## Resources

### Documentation
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Best Practices](docs/quick-reference/dockerfile-best-practices.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

### In This Repository
- `CHANGELOG.md` - Version history and updates
- `CONTRIBUTING.md` - How to contribute
- `docs/` - Comprehensive guides
- `concepts/*/README.md` - Individual concept explanations

## Getting Help

### If Something Doesn't Work

1. **Check the logs:**
   ```bash
   docker-compose logs
   make test-all
   ```

2. **Review the README in each lab directory**

3. **Check troubleshooting guide:**
   ```bash
   cat docs/troubleshooting.md
   ```

4. **Run health checks:**
   ```bash
   make health-check
   ```

### Community

- GitHub Issues: Report bugs or request features
- GitHub Discussions: Ask questions and share knowledge
- Contributing: See `CONTRIBUTING.md` for guidelines

## Tips for Success

1. **Follow the learning path** - Don't skip to advanced topics
2. **Read the README** in each concept and lab directory
3. **Type commands** don't just copy-paste to build muscle memory
4. **Experiment** - Change values, try different approaches
5. **Clean up** between labs to avoid port and resource conflicts:
   ```bash
   make clean-all
   ```
6. **Save your work** - Create your own images and repositories based on these examples

## Performance Tips

- Use `--no-cache` flag to rebuild images from scratch: `docker build --no-cache -t image .`
- Clean up old images and containers regularly: `docker system prune`
- Monitor resource usage: `docker stats`
- Use `.dockerignore` to exclude unnecessary files

## What to Do With This Knowledge

After completing DockVerseHub:

1. **Containerize your own projects** - Apply Docker to your applications
2. **Set up CI/CD** - Automate your deployment pipeline
3. **Deploy to production** - Use Docker in real environments
4. **Learn orchestration** - Explore Kubernetes after mastering Docker
5. **Teach others** - Share your Docker knowledge

---

**Happy learning!** 🐳 Start with `make lab-01` or `make help` for more options.
