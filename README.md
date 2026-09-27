# DockVerseHub - Comprehensive Docker Learning Platform

<!-- BADGES START -->
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-2496ED?style=flat&logo=docker&logoColor=white)
![Dockerfiles](https://img.shields.io/badge/Dockerfiles-48-blue?style=flat)
![Compose Files](https://img.shields.io/badge/Compose%20Files-22-green?style=flat)
![Labs](https://img.shields.io/badge/Labs-8-orange?style=flat)
![Concepts](https://img.shields.io/badge/Concepts-13-purple?style=flat)
![Experiments](https://img.shields.io/badge/Experiments-4-teal?style=flat)
![Stars](https://img.shields.io/badge/Stars-0-yellow?style=flat)
![Forks](https://img.shields.io/badge/Forks-0-lightgrey?style=flat)
![Issues](https://img.shields.io/badge/Issues-0-green?style=flat)
![Last Updated](https://img.shields.io/badge/Last%20Updated-2026--09--27-brightgreen?style=flat)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)
<!-- BADGES END -->
[![CI](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/ci.yml/badge.svg)](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/ci.yml)
[![Research Benchmarks](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/research-benchmarks.yml/badge.svg)](https://github.com/SatvikPraveen/DockVerseHub/actions/workflows/research-benchmarks.yml)

> **Production-Ready Docker Learning Platform** with structured concepts, hands-on labs, and enterprise deployment patterns.

DockVerseHub is a comprehensive, well-tested Docker education platform designed for developers at all levels. Whether you're learning Docker fundamentals or deploying to production, this repository provides practical examples, working code, and real-world patterns.

## ✨ What Makes DockVerseHub Different

- **100% Working Code**: Every example has been tested and validated
- **Progressive Learning**: Clear progression from beginner to advanced topics
- **Hands-On Labs**: 8 complete, runnable projects with real applications
- **Production Patterns**: Enterprise-ready deployment strategies
- **Automated Testing**: CI/CD pipeline ensures everything stays working
- **Comprehensive Docs**: 50+ guides covering theory to practice

## 🚀 Quick Start

### 1. Clone & Enter Directory
```bash
git clone https://github.com/SatvikPraveen/DockVerseHub.git
cd DockVerseHub
```

### 2. Verify Docker Installation
```bash
docker --version
docker-compose --version
```

### 3. Run Your First Lab (5 minutes)
```bash
cd labs/lab_01_simple_app
docker-compose up
```

Then visit: `http://localhost:8080`

**For detailed setup instructions, see [GETTING_STARTED.md](docs/GETTING_STARTED.md) or [ENHANCEMENT_PLAN.md](docs/project-docs/ENHANCEMENT_PLAN.md) for the improvement roadmap**

## 🔬 Research: Measured, Not Asserted

Every performance claim in the curriculum is backed by a controlled experiment you can rerun. The `research/` directory contains a dependency-free benchmark harness (standard library + Docker CLI) that executes declarative experiments with warm-up rounds, seeded block-randomised trial order and an environment snapshot, then reports 95% confidence intervals, Cohen's *d*, Cliff's δ, Welch's *t* and permutation *p*-values against a declared baseline.

| Experiment | Question |
|---|---|
| `exp01_base_image_footprint` | Full vs slim vs Alpine vs distroless: size, cold build, cold start |
| `exp02_layer_cache_effectiveness` | What a source-only edit costs when deps are copied first vs last |
| `exp03_multistage_vs_single` | Runtime size saved and build time paid by multi-stage builds |
| `exp04_buildkit_cache_mount` | Rebuild time recovered by `RUN --mount=type=cache` on pip's cache |

```bash
python -m research.harness list
python -m research.harness run exp02_layer_cache_effectiveness
```

Committed results with their environment are indexed in [research/results/README.md](research/results/README.md). The protocol is in [research/METHODOLOGY.md](research/METHODOLOGY.md); sources in [research/REFERENCES.md](research/REFERENCES.md). To cite the repository use [CITATION.cff](CITATION.cff).

## 📚 Repository Structure

### Concepts (13 modules)
Core Docker learning organized progressively:

1. **01_getting_started** - Installation, CLI basics, container lifecycle
2. **02_images_layers** - Image building, layers, optimization, registry
3. **03_volumes_bindmounts** - Data persistence, backup/restore
4. **04_networking** - Container communication, custom networks, load balancing
5. **05_docker_compose** - Multi-container orchestration, profiles, scaling
6. **06_security** - Hardening, secrets, vulnerability scanning, compliance
7. **07_logging_monitoring** - ELK stack, Prometheus, Grafana, alerting
8. **08_orchestration** - Docker Swarm, service discovery, clustering
9. **09_advanced_tricks** - BuildKit, build optimization, debugging techniques
10. **10_ci_cd_integration** - GitHub Actions, GitLab CI, Jenkins, deployment strategies
11. **11_kubernetes** - Container orchestration, Kubernetes at scale, deployment patterns
12. **12_gitops_iac** - GitOps principles, ArgoCD, Flux, Terraform, progressive delivery
13. **13_observability_monitoring** - Prometheus, Grafana, Jaeger, OpenTelemetry, SLO/SLI

### Labs (8 Projects)
Working applications demonstrating real-world patterns:

| Lab | Duration | Level | Topics |
|-----|----------|-------|--------|
| Lab 01: Simple App | 15-30m | Beginner | Basic containerization, Dockerfile, Compose |
| Lab 02: Multi-Container | 30-45m | Beginner+ | Full-stack app, networking, volumes |
| Lab 03: Image Optimization | 20-30m | Intermediate | Multi-stage builds, Alpine, caching |
| Lab 04: Logging Dashboard | 45-60m | Intermediate+ | ELK, Prometheus, Grafana, monitoring |
| Lab 05: Microservices | 60-90m | Advanced | Service mesh, API gateway, distributed systems |
| Lab 06: Production Deploy | 90-120m | Advanced | SSL, backup, health checks, security |
| Lab 07: Kubernetes Deploy | 120-150m | Advanced | Multi-tier K8s app, manifests, deployments |
| Lab 08: Observability Stack | 240-300m | Advanced | Complete monitoring, tracing, incident response |

### Research (4 experiments)
Reproducible benchmarks with statistical reports in `research/` (see above).

### Documentation
Comprehensive guides in `docs/`:
- **Learning Paths**: Beginner, Intermediate, Advanced curricula
- **Quick Reference**: Cheatsheets, best practices, troubleshooting
- **Docker Basics**: Fundamental concepts and workflows
- **Production Guides**: Deployment, scaling, security, performance

## 🎯 Learning Paths

### Beginner (0-3 months)
```
Concepts:    01-05
Labs:        01, 02
Time:        40-60 hours
Skills:      Docker fundamentals, Compose, basic networking
```

### Intermediate (3-6 months)
```
Concepts:    06-07
Labs:        03, 04
Time:        50-70 hours
Skills:      Security, monitoring, optimization, troubleshooting
```

### Advanced (6-12 months)
```
Concepts:    08-10
Labs:        05, 06
Time:        80-120 hours
Skills:      Orchestration, microservices, production deployment
```

### Expert (12+ months)
```
Concepts:    11-13
Labs:        07, 08
Time:        100-150 hours
Skills:      Kubernetes, GitOps, observability, infrastructure as code
```

## 🛠️ Usage Examples

### Using Make Commands
```bash
# Show available commands
make help

# Set up development environment
make setup

# Run all validation tests
make test-all

# Unit tests and repository invariants (no Docker needed)
make test-unit

# Reproducible benchmarks
make research-validate
make research-run EXP=exp01_base_image_footprint

# Start a specific lab
make lab-01

# Stop a specific lab
make stop-lab-01

# View project statistics
make stats
```

### Manual Docker Commands
```bash
# Build and run lab 01
cd labs/lab_01_simple_app
docker build -t my-app .
docker-compose up

# Test the application
curl http://localhost:8080

# Stop containers
docker-compose down
```

### Work Through Concepts
```bash
# Read about images and layers
cat concepts/02_images_layers/README.md

# Try the examples
cd concepts/02_images_layers
./inspect_image.sh
```

## 📋 Key Features

### ✅ Validated Code
- pytest suite: harness statistics verified against published t-tables; repository invariants (links, structure, every YAML file parses, Dockerfile sanity)
- hadolint on every Dockerfile against a committed policy
- All Python scripts compile without errors
- All Dockerfiles build successfully
- All Docker Compose files have valid syntax
- Automated CI/CD pipeline catches issues immediately
- **Zero Security Vulnerabilities** - All dependencies patched and monitored

### ✅ Production Patterns
- Security hardening techniques
- SSL/TLS configuration
- Database backup strategies
- Health checks and monitoring
- Load balancing and scaling
- Disaster recovery procedures
- Runtime security and compliance

### ✅ Real-World Scenarios
- Microservices architecture
- Multi-database setup
- API gateway patterns
- Log aggregation
- Distributed tracing
- Observability stack
- Container security scanning

### ✅ Comprehensive Tooling
- Makefile for common tasks
- Automation scripts
- Docker utilities
- Performance benchmarking tools
- Security scanning templates
- Automated dependency updates (Dependabot)
- GitHub Actions CI/CD (8 workflows, including weekly research benchmarks)

## 🔍 Project Statistics

```
Dockerfiles:        48
Docker Compose:     22
Labs:               8 complete
Concepts:           13 modules
Experiments:        4 reproducible (research/)
Unit tests:         370+ (pytest)
Documentation:      40+ guides (18,700+ lines)
Scripts:            40+ utilities
Languages:          Python, Go, JavaScript, Shell
Security:           0 vulnerabilities
CI/CD Workflows:    8 automated
GitHub Commits:     60+ (tracked across phases)
```

## 🧪 Verification & Testing

All code is automatically tested:

```bash
# Run all validations locally
make test-all

# Or individual validations
make test-dockerfiles
make test-compose
make test-scripts
make test-labs
```

GitHub Actions runs on every commit to ensure:
- ✓ 370+ pytest checks pass (statistics vs published tables, runner behaviour, link integrity, every YAML file parses, Dockerfile healthcheck and parser-directive sanity)
- ✓ Python syntax is valid
- ✓ Shell scripts are executable
- ✓ YAML configurations are valid
- ✓ Project structure is intact
- ✓ All labs have required files
- ✓ Docker images build successfully

## 📖 Documentation

- **[GETTING_STARTED.md](docs/GETTING_STARTED.md)** - Complete setup and first steps guide
- **[CONTRIBUTING.md](docs/CONTRIBUTING.md)** - How to contribute improvements
- **[PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)** - Detailed directory structure
- **[docs/](docs/)** - All comprehensive guides

## 🎓 Learning Resources

### In This Repository
- 13 concept modules with explanations and examples
- 8 complete lab projects with real applications
- 4 reproducible benchmark experiments with statistical reports
- 40+ documentation files
- Quick reference guides and cheatsheets
- Troubleshooting flowcharts
- Case studies from real implementations

### External Resources
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Production Deployment Guide](docs/production-deployment.md)

## 🐛 Troubleshooting

### Docker Not Running
```bash
# macOS
open /Applications/Docker.app

# Linux
sudo systemctl start docker

# Windows
# Start Docker Desktop from Start Menu
```

### Port Already in Use
```bash
# Find what's using the port
lsof -i :8080

# Use a different port
docker-compose -e "PORT=8081" up
```

### Container Exit Issues
```bash
# Check logs
docker-compose logs

# Run container interactively
docker-compose run app /bin/bash
```

See [docs/troubleshooting.md](docs/troubleshooting.md) for more solutions.

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for:
- How to report issues
- How to suggest improvements
- How to submit pull requests
- Code and documentation standards

## 📄 License & Citation

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

If you use DockVerseHub or its benchmark harness in academic work, cite it via [CITATION.cff](CITATION.cff) (GitHub's "Cite this repository" button renders APA and BibTeX).

## 🔒 Security & Automation

### Automated Security Scanning
- **Trivy**: Container image vulnerability scanning
- **CodeQL**: Source code security analysis
- **Bandit**: Python security linting
- **Safety**: Dependency vulnerability checking
- **Dependabot**: Automated security updates (weekly)

See [SECURITY.md](.github/SECURITY.md) for complete security policy and incident response procedures.

### CI/CD Pipeline
- 8 automated GitHub Actions workflows
- Continuous validation of all code
- Automated security scanning on every commit
- Dependency updates with Dependabot
- Performance testing and reporting

**Status**: ✅ All systems operational | ✅ Zero vulnerabilities | ✅ All tests passing

## 🌟 Getting Involved

- **Report Issues**: Found a bug? [Open an issue](https://github.com/SatvikPraveen/DockVerseHub/issues)
- **Request Features**: Have ideas? [Start a discussion](https://github.com/SatvikPraveen/DockVerseHub/discussions)
- **Contribute Code**: See [CONTRIBUTING.md](docs/CONTRIBUTING.md)
- **Share Knowledge**: Submit case studies or improvements

## 📊 What You'll Learn

After completing DockVerseHub, you'll understand:

- **Fundamentals**: Docker architecture, images, containers, registries
- **Practical Skills**: Building images, running containers, using Compose
- **Advanced Topics**: Orchestration, security, monitoring, optimization
- **Production Ready**: Deployment strategies, backup/recovery, scaling
- **Best Practices**: Security hardening, efficient image building, operational excellence

## 🎯 Next Steps

1. **Clone the repository** and follow [GETTING_STARTED.md](docs/GETTING_STARTED.md)
2. **Start with Lab 01** - it takes just 15-30 minutes
3. **Read the concept modules** corresponding to your level
4. **Work through all labs** in order
5. **Apply knowledge** to your own projects
6. **Stay updated** by watching this repository

---

**Ready to master Docker?** Start with:
```bash
git clone https://github.com/SatvikPraveen/DockVerseHub.git
cd DockVerseHub
make help
```

Happy learning! 🐳
