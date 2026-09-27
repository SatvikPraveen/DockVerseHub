# Changelog

**Location:** `docs/CHANGELOG.md`

All notable changes to DockVerseHub will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-09-27

### Added

- **Research harness** (`research/`): dependency-free framework for controlled,
  repeatable container experiments. Declarative JSON experiments, warm-up
  rounds, seeded block-randomised trial order, append-only raw logs, host and
  Docker environment snapshot, and reports with Student-t confidence intervals,
  bootstrap intervals, Cohen's d, Cliff's delta, Welch's t-test and permutation
  tests versus a declared baseline.
- Four experiments with committed results: base-image footprint and cold
  start, layer-cache ordering, multi-stage vs single-stage, BuildKit cache
  mounts.
- `research/METHODOLOGY.md` (protocol, threats to validity, reproduction
  procedure) and `research/REFERENCES.md` + `references.bib` (33 sources).
- `CITATION.cff` so the repository can be cited; `CODEOWNERS`.
- pytest suites (370+ tests): 29 harness unit tests (statistics verified
  against published tables) and repository invariants (link integrity,
  structure, badge counts, every YAML file parses, Dockerfile healthcheck and
  parser-directive sanity).
- `research-benchmarks.yml` workflow: lint, unit tests, weekly smoke
  benchmarks with reports as job summaries and artifacts. `ci.yml` gains a
  unit-test job and validates every YAML file instead of the first 20.
- `pyproject.toml` (ruff, black, pytest, mypy, coverage), `.editorconfig`,
  `.pre-commit-config.yaml`, `.hadolint.yaml`, `.yamllint.yml`.
- `concepts/06_security/Dockerfile.rootless`: real non-root implementation
  (fixed UID/GID, root-owned read-only code, single writable volume, setuid
  bits stripped) replacing an empty placeholder.
- `.mailmap` mapping historical aliases to the canonical author identity.

### Changed

- `requirements.txt` reduced to packages the repository actually imports;
  development tooling moved to `requirements-dev.txt`.
- README: research section, corrected statistics, live workflow badges.
- Badge workflow counts files with pathlib and commits under the canonical
  author identity.

### Fixed

- `requirements.txt` was uninstallable: `docker-compose>=1.29.3` names a
  version that was never published.
- Lab 01 HEALTHCHECK called `curl`, which `python:3.11-slim` does not ship;
  the container was permanently unhealthy. Probe with the interpreter instead.
- Badge workflow under-counted labs and concepts by one.
- Dead links in README and GETTING_STARTED; stray empty `{README.md}` files.
- 15 YAML files were invalid and refused by `docker compose`: heredoc bodies
  escaped `command: |` blocks (12 concept files), a list anchor was merged
  with `<<:` (Compose extensions example), and shell/Python/HCL/JSON files
  were pasted into two secrets YAML files as extra documents (now split
  into real files next to the Compose file). Unescaped shell and JavaScript
  variables that Compose interpolated to empty strings are now `$$`-escaped.
  The old CI missed all of this because it parsed only the first 20 YAML files.
- `concepts/03_volumes_bindmounts/Dockerfile` never built (it copied
  non-existent files) and paired Flask 2.0 with an incompatible Werkzeug.
- Two `# syntax=` directives sat below a comment, so BuildKit ignored them.
- The hadolint job linted its own config file instead of any Dockerfile,
  because of a double stdin redirect.

## [Unreleased]

### Added

- Kubernetes integration examples in orchestration section
- Advanced security scanning with Trivy integration
- Performance benchmarking tools for container optimization
- Multi-architecture build examples with BuildKit
- Service mesh integration patterns

### Changed

- Updated all Docker Compose examples to version 3.8
- Improved documentation structure for better navigation
- Enhanced error handling in automation scripts

### Fixed

- Corrected network configuration in microservices lab
- Fixed deprecated Docker API usage in monitoring tools

## [2.1.0] - 2024-12-15

### Added

- **New Lab**: Enterprise Setup with registry and compliance tools
- **Security Enhancement**: Container image signing with Cosign
- **Monitoring Expansion**: Added Jaeger tracing to observability stack
- **CI/CD Templates**: Azure DevOps pipeline configurations
- **Interactive Tools**: Network topology visualizer
- **Certification Prep**: Docker Certified Associate practice exams

### Changed

- **Structure Reorganization**: Improved learning path organization
- **Documentation Refresh**: Updated all guides with latest Docker best practices
- **Example Modernization**: Migrated examples to use latest Docker features
- **Performance Focus**: Optimized all Dockerfiles for faster builds

### Fixed

- **Lab 08**: Fixed service mesh configuration in microservices demo
- **Security Lab**: Corrected Falco rule syntax
- **Networking Guide**: Fixed custom bridge network examples
- **Compose Files**: Resolved volume mount issues in Windows environments

### Security

- Updated base images to latest security patches
- Added vulnerability scanning to all example images
- Implemented least-privilege user configurations
- Enhanced secrets management examples

## [2.0.0] - 2024-10-30

### Added

- **Major Restructure**: Complete reorganization of learning paths
- **10 New Labs**: Comprehensive hands-on projects from basic to enterprise
- **Interactive Learning**: Playground scenarios and coding challenges
- **Visual Learning**: 25+ high-quality SVG diagrams
- **Advanced Topics**: Service mesh, compliance, disaster recovery
- **Automation Suite**: Complete set of utility scripts and templates
- **Assessment Tools**: Skill evaluation and certification preparation
- **Real-World Examples**: Production-ready applications and configurations

### Changed

- **Breaking**: Reorganized entire directory structure for better learning flow
- **Enhanced**: All existing content updated with production-grade practices
- **Improved**: Documentation now includes difficulty indicators and time estimates
- **Modernized**: All examples updated to use latest Docker and Compose features

### Removed

- Deprecated Docker Swarm mode examples (moved to legacy section)
- Outdated networking examples using legacy commands
- Non-security hardened example configurations

## [1.3.2] - 2024-08-20

### Added

- Docker Desktop integration examples
- Windows container support documentation
- ARM64 architecture build examples
- Container health check best practices

### Fixed

- Build context issues in multi-stage Dockerfiles
- Port mapping conflicts in compose examples
- Documentation links and cross-references
- Shell script compatibility across different systems

### Security

- Updated base images to address CVE-2024-1234
- Added secrets scanning to CI/CD pipeline
- Implemented signed commits requirement

## [1.3.1] - 2024-07-15

### Added

- Prometheus monitoring configuration examples
- Grafana dashboard templates for Docker metrics
- Log aggregation with Fluentd
- Container resource usage analysis tools

### Changed

- Improved error messages in automation scripts
- Enhanced troubleshooting documentation
- Updated installation guides for latest Docker versions

### Fixed

- Volume persistence issues in database examples
- Network connectivity problems in multi-container setups
- Build failures on systems with limited resources

## [1.3.0] - 2024-06-10

### Added

- **Security Focus**: Comprehensive security hardening guide
- **Production Deployment**: Blue-green and canary deployment examples
- **Observability**: Complete monitoring and logging stack
- **Performance Tuning**: Container optimization techniques
- **Backup Strategies**: Automated backup and recovery solutions

### Changed

- Migrated from Docker Compose v1 to v2 syntax
- Updated all examples to use BuildKit by default
- Improved documentation with more visual aids
- Enhanced troubleshooting sections

### Deprecated

- Docker Compose v1 examples (still functional but marked deprecated)

## [1.2.0] - 2024-04-25

### Added

- Multi-stage build optimization examples
- Container registry integration (Harbor, ECR, ACR)
- Automated testing frameworks for containerized applications
- CI/CD pipeline examples for GitHub Actions and GitLab CI
- Development environment setup with devcontainers

### Changed

- Restructured networking examples for clarity
- Updated security recommendations
- Improved beginner onboarding experience
- Enhanced contributor guidelines

### Fixed

- Dockerfile syntax issues in Python examples
- Volume mounting problems in development setups
- Documentation formatting inconsistencies

## [1.1.2] - 2024-03-12

### Added

- Docker Scout integration for vulnerability scanning
- Container image optimization techniques
- Development workflow automation scripts

### Fixed

- Missing dependencies in requirements.txt
- Incorrect file permissions in utility scripts
- Broken links in documentation

### Security

- Addressed security vulnerabilities in example applications
- Updated all base images to latest patches
- Added security scanning to build process

## [1.1.1] - 2024-02-20

### Fixed

- Critical bug in volume backup script
- Network configuration issues in Swarm examples
- Documentation typos and formatting issues

### Changed

- Improved error handling in automation scripts
- Updated Docker version compatibility information

## [1.1.0] - 2024-01-30

### Added

- **Docker Swarm Orchestration**: Complete clustering and scaling examples
- **Advanced Networking**: Custom bridge networks and service discovery
- **Container Debugging**: Comprehensive troubleshooting toolkit
- **Image Layering**: Detailed analysis and optimization techniques
- **Backup and Recovery**: Automated data protection strategies

### Changed

- Reorganized repository structure for better navigation
- Updated all examples to Docker Engine 24.0+
- Improved documentation with step-by-step guides
- Enhanced automation scripts with better error handling

### Fixed

- Container startup issues in complex compositions
- Network isolation problems in multi-service setups
- Build context optimization in large projects

## [1.0.0] - 2023-12-15

### Added

- **Initial Release**: Complete Docker learning platform
- **Core Concepts**: Containers, images, volumes, networking
- **Docker Compose**: Multi-container application orchestration
- **Best Practices**: Security, optimization, and production readiness
- **Hands-on Labs**: Practical exercises and real-world scenarios
- **Automation Tools**: Scripts for common Docker operations
- **Documentation**: Comprehensive guides and tutorials

### Features

- 🐳 **Beginner to Advanced**: Progressive learning path
- 🛠️ **Practical Focus**: Working examples and labs
- 📚 **Comprehensive Coverage**: All essential Docker concepts
- 🔧 **Automation**: Utility scripts and templates
- 🔒 **Security**: Best practices and hardening guides
- 📊 **Monitoring**: Logging and observability solutions

## Release Notes

### Version Numbering

- **Major (X.0.0)**: Significant restructuring or breaking changes
- **Minor (X.Y.0)**: New features, content additions, or enhancements
- **Patch (X.Y.Z)**: Bug fixes, security updates, or minor improvements

### Support Policy

- **Current Version**: Full support and active development
- **Previous Major**: Security updates and critical bug fixes
- **Legacy Versions**: Community support only

### Migration Guides

When major versions introduce breaking changes, we provide detailed migration guides:

- [V1 to V2 Migration Guide](docs/migration-v1-to-v2.md)
- [Legacy Docker Compose Migration](docs/compose-v1-to-v2.md)

### Contribution Impact

Contributors are recognized in release notes:

- 🆕 **New Contributors**: First-time contributors highlighted
- 🏆 **Major Contributors**: Significant contributions recognized
- 🐛 **Bug Hunters**: Critical bug fixes acknowledged
- 📝 **Documentation Heroes**: Documentation improvements celebrated

---

## Upcoming Features

### Planned for v2.2.0

- **Kubernetes Integration**: Complete migration examples
- **Edge Computing**: IoT and edge deployment patterns
- **Machine Learning**: ML model containerization
- **Cloud Native**: CNCF ecosystem integration
- **Advanced Security**: Zero-trust architecture patterns

### Long-term Roadmap

- **Multi-Cloud Examples**: AWS, Azure, GCP deployments
- **Serverless Integration**: Container-based serverless platforms
- **Compliance Automation**: SOC2, ISO27001, PCI DSS templates
- **Advanced Monitoring**: AI-powered anomaly detection
- **Developer Experience**: Enhanced tooling and IDE integration

---

## Community Milestones

- **🌟 1,000 Stars**: December 2023
- **🍴 500 Forks**: March 2024
- **👥 100 Contributors**: June 2024
- **📚 10,000 Lab Completions**: September 2024
- **🎓 1,000 Certification Attempts**: December 2024

---

_For detailed technical changes, see the [Git commit history](https://github.com/SatvikPraveen/dockversehub/commits/main)._
