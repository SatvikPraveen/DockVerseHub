#!/bin/bash

# ===========================================================
# 🚀 DockVerseHub Project Structure Creator
# Description : Generates the full skeleton for DockVerseHub
# Author      : Satvik Praveen
# ===========================================================

PROJECT="DockVerseHub"
echo "📂 Creating project: $PROJECT ..."
mkdir -p "$PROJECT"
cd "$PROJECT" || exit 1

# -----------------------------------------------------------
# Top-level files
# -----------------------------------------------------------
echo "📝 Creating top-level files..."
cat <<EOF > README.md
# DockVerseHub 🚢
A comprehensive, portfolio-grade project to **master Docker** concepts from basics to advanced, with real-world labs, diagrams, and utilities.
EOF

cat <<EOF > .gitignore
# Ignore unnecessary files
node_modules/
__pycache__/
*.log
*.tmp
.env
.DS_Store
build/
dist/
.pytest_cache/
coverage/
EOF

cat <<EOF > .dockerignore
# Ignore build artifacts
.git
.gitignore
README.md
__pycache__/
*.log
*.tmp
.env
.DS_Store
node_modules/
build/
dist/
coverage/
EOF

touch CONTRIBUTING.md CHANGELOG.md LICENSE Makefile requirements.txt

# -----------------------------------------------------------
# Docs Section
# -----------------------------------------------------------
echo "📚 Setting up docs..."
mkdir -p docs/{quick-reference,learning-paths,diagrams}
touch docs/{docker-basics.md,images-vs-containers.md,networking.md,volumes-storage.md,docker-compose.md,security-best-practices.md,monitoring-logging.md,orchestration-overview.md,troubleshooting.md,performance-optimization.md,production-deployment.md,docker-ecosystem.md,migration-strategies.md,cost-optimization.md,glossary.md,docker-commands-cheatsheet.pdf}
touch docs/quick-reference/{dockerfile-best-practices.md,compose-patterns.md,networking-quick-ref.md,security-checklist.md,troubleshooting-flowcharts.md}
touch docs/learning-paths/{beginner-path.md,intermediate-path.md,advanced-path.md,certification-prep.md}
touch docs/diagrams/{docker-lifecycle.svg,networking-modes.svg,volumes-architecture.svg,orchestration-flow.svg,security-layers.svg,build-optimization.svg,ci-cd-integration.svg,microservices-arch.svg,production-topology.svg}

# -----------------------------------------------------------
# Concepts Section
# -----------------------------------------------------------
echo "📦 Creating concepts..."

# 01 Getting Started
mkdir -p concepts/01_getting_started/{installation,exercises}
touch concepts/01_getting_started/{README.md,Dockerfile,Dockerfile.interactive,run_container.sh}
touch concepts/01_getting_started/installation/{ubuntu.md,windows.md,macos.md,verification.sh}
touch concepts/01_getting_started/exercises/{first-container.md,basic-commands.md}

# 02 Images & Layers
mkdir -p concepts/02_images_layers/registry
touch concepts/02_images_layers/{README.md,Dockerfile.basic,Dockerfile.optimized,Dockerfile.distroless,inspect_image.sh,image_comparison.md,caching-strategies.md}
touch concepts/02_images_layers/registry/{push-pull-demo.sh,private-registry.yml}

# 03 Volumes & Bind Mounts
mkdir -p concepts/03_volumes_bindmounts/{backup-restore,performance}
touch concepts/03_volumes_bindmounts/{README.md,Dockerfile,docker-compose.yml,volume_demo.md}
touch concepts/03_volumes_bindmounts/backup-restore/{volume-backup.sh,restore-demo.sh,automated-backup.yml}
touch concepts/03_volumes_bindmounts/performance/{benchmark.py,results-analysis.md}

# 04 Networking
mkdir -p concepts/04_networking/{custom-networks,load-balancing,troubleshooting}
touch concepts/04_networking/{README.md,Dockerfile.web,Dockerfile.db,docker-compose.yml,inspect_network.sh}
touch concepts/04_networking/custom-networks/{multi-network.yml,overlay-demo.yml,ingress-routing.yml}
touch concepts/04_networking/load-balancing/{nginx-lb.yml,haproxy-config.cfg,traefik-demo.yml}
touch concepts/04_networking/troubleshooting/{connectivity-test.sh,dns-resolution.sh,port-conflicts.md}

# 05 Docker Compose
mkdir -p concepts/05_docker_compose/{profiles-demo,scaling,advanced-features}
touch concepts/05_docker_compose/{README.md,docker-compose.yml,docker-compose.override.yml,docker-compose.prod.yml}
touch concepts/05_docker_compose/profiles-demo/{development.yml,testing.yml,staging.yml}
touch concepts/05_docker_compose/scaling/{horizontal-scaling.yml,resource-constraints.yml}
touch concepts/05_docker_compose/advanced-features/{secrets-demo.yml,configs-demo.yml,extensions.yml}

# 06 Security
mkdir -p concepts/06_security/{secrets_demo,image-signing,runtime-security,compliance}
mkdir -p concepts/06_security/runtime-security/{apparmor-profiles,seccomp-profiles}
touch concepts/06_security/{README.md,Dockerfile.rootless,Dockerfile.hardened,scan_image.sh}
touch concepts/06_security/secrets_demo/{docker-compose.yml,secrets.env,app.py,vault-integration.yml}
touch concepts/06_security/image-signing/{notary-demo.sh,cosign-example.sh}
touch concepts/06_security/runtime-security/falco-rules.yml
touch concepts/06_security/compliance/{cis-benchmark.md,security-audit.sh,vulnerability-mgmt.md}

# 07 Logging & Monitoring
mkdir -p concepts/07_logging_monitoring/{logging-drivers,monitoring-stack,dashboards,log-aggregation,alerting}
touch concepts/07_logging_monitoring/{README.md,Dockerfile.app,docker-compose.yml}
touch concepts/07_logging_monitoring/logging-drivers/{json-file.yml,syslog.yml,fluentd.yml,gelf.yml}
touch concepts/07_logging_monitoring/monitoring-stack/{prometheus.yml,grafana.yml,alertmanager.yml,node-exporter.yml}
touch concepts/07_logging_monitoring/dashboards/{kibana-dashboard.json,grafana-dashboard.json,docker-stats.json,application-metrics.json}
touch concepts/07_logging_monitoring/log-aggregation/{logstash-pipeline.conf,filebeat.yml,fluentbit.conf}
touch concepts/07_logging_monitoring/alerting/{prometheus-rules.yml,alertmanager-config.yml}

# 08 Orchestration
mkdir -p concepts/08_orchestration/{swarm-advanced,service-mesh,kubernetes-compare,cluster-management}
mkdir -p concepts/08_orchestration/kubernetes-compare/k8s-manifests
touch concepts/08_orchestration/{README.md,docker-compose.yml,swarm_setup.sh,scaling_demo.md}
touch concepts/08_orchestration/swarm-advanced/{stack-deploy.yml,rolling-updates.yml,placement-constraints.yml,ingress-routing.yml}
touch concepts/08_orchestration/service-mesh/{consul-connect.yml,linkerd-demo.yml}
touch concepts/08_orchestration/kubernetes-compare/{feature-comparison.md,migration-guide.md}
touch concepts/08_orchestration/cluster-management/{backup-cluster.sh,disaster-recovery.md,upgrade-strategy.md}

# 09 Advanced Tricks
mkdir -p concepts/09_advanced_tricks/{build-optimization,resource-management,debugging-tools,custom-solutions}
touch concepts/09_advanced_tricks/{README.md,Dockerfile.healthcheck,Dockerfile.buildkit,Dockerfile.experimental,debug_container.sh,prune_unused.sh}
touch concepts/09_advanced_tricks/build-optimization/{cache-mounts.Dockerfile,parallel-builds.sh,buildx-multiarch.sh,remote-cache.yml}
touch concepts/09_advanced_tricks/resource-management/{memory-limits.yml,cpu-constraints.yml,storage-quotas.yml,benchmarking.py}
touch concepts/09_advanced_tricks/debugging-tools/{container-inspection.sh,network-debugging.py,performance-profiling.sh,memory-analysis.py}
touch concepts/09_advanced_tricks/custom-solutions/{init-containers.yml,sidecar-patterns.yml,job-scheduling.yml,data-processing.yml}

# 10 CI/CD Integration
mkdir -p concepts/10_ci_cd_integration/{github-actions,gitlab-ci,jenkins,azure-devops,deployment-strategies,testing-strategies}
mkdir -p concepts/10_ci_cd_integration/jenkins/shared-library
touch concepts/10_ci_cd_integration/{README.md}
touch concepts/10_ci_cd_integration/github-actions/{build-push.yml,multi-stage-ci.yml,security-scan.yml,release-automation.yml}
touch concepts/10_ci_cd_integration/gitlab-ci/{.gitlab-ci.yml,docker-in-docker.yml,registry-integration.yml}
touch concepts/10_ci_cd_integration/jenkins/{Jenkinsfile,declarative-pipeline.groovy}
touch concepts/10_ci_cd_integration/azure-devops/{azure-pipelines.yml,container-jobs.yml}
touch concepts/10_ci_cd_integration/deployment-strategies/{blue-green.yml,canary.yml,rolling-update.yml,feature-flags.yml}
touch concepts/10_ci_cd_integration/testing-strategies/{unit-tests.Dockerfile,integration-tests.yml,e2e-testing.yml,contract-testing.yml}

# -----------------------------------------------------------
# Labs Section - 6 Sequential Labs
# -----------------------------------------------------------
echo "🧪 Setting up labs..."

# Lab 01 - Simple App
mkdir -p labs/lab_01_simple_app
touch labs/lab_01_simple_app/{README.md,Dockerfile,app.py,requirements.txt,docker-compose.yml}

# Lab 02 - Multi-Container Compose
mkdir -p labs/lab_02_multi_container_compose/{api,db,frontend,nginx,redis}
mkdir -p labs/lab_02_multi_container_compose/api/tests
mkdir -p labs/lab_02_multi_container_compose/db/migrations
mkdir -p labs/lab_02_multi_container_compose/frontend/{src,public}
mkdir -p labs/lab_02_multi_container_compose/nginx/ssl
touch labs/lab_02_multi_container_compose/{README.md,docker-compose.yml,docker-compose.prod.yml}
touch labs/lab_02_multi_container_compose/api/{Dockerfile,app.py,requirements.txt}
touch labs/lab_02_multi_container_compose/db/{Dockerfile,init.sql}
touch labs/lab_02_multi_container_compose/frontend/{Dockerfile,package.json}
touch labs/lab_02_multi_container_compose/nginx/{Dockerfile,nginx.conf}
touch labs/lab_02_multi_container_compose/redis/redis.conf

# Lab 03 - Image Optimization
mkdir -p labs/lab_03_image_optimization/{optimization-strategies,comparison}
touch labs/lab_03_image_optimization/{README.md,Dockerfile.naive,Dockerfile.optimized,Dockerfile.distroless,Dockerfile.alpine,size_report.md,benchmark.sh}
touch labs/lab_03_image_optimization/optimization-strategies/{layer-caching.md,multi-stage-patterns.md,dependency-management.md}
touch labs/lab_03_image_optimization/comparison/{build-times.csv,image-sizes.csv,runtime-performance.csv}

# Lab 04 - Logging Dashboard
mkdir -p labs/lab_04_logging_dashboard/{elasticsearch,kibana,logstash,log_app,grafana,prometheus}
mkdir -p labs/lab_04_logging_dashboard/elasticsearch/index-templates
mkdir -p labs/lab_04_logging_dashboard/kibana/dashboards
mkdir -p labs/lab_04_logging_dashboard/logstash/pipelines
mkdir -p labs/lab_04_logging_dashboard/grafana/{dashboards,datasources}
mkdir -p labs/lab_04_logging_dashboard/prometheus/{rules,targets}
touch labs/lab_04_logging_dashboard/{README.md,docker-compose.yml}
touch labs/lab_04_logging_dashboard/elasticsearch/{Dockerfile,elasticsearch.yml}
touch labs/lab_04_logging_dashboard/kibana/{Dockerfile,kibana.yml}
touch labs/lab_04_logging_dashboard/logstash/{Dockerfile,logstash.yml}
touch labs/lab_04_logging_dashboard/log_app/{Dockerfile,app.py,log_generator.py}
touch labs/lab_04_logging_dashboard/grafana/{Dockerfile,grafana.ini}
touch labs/lab_04_logging_dashboard/prometheus/prometheus.yml

# Lab 05 - Microservices Demo
mkdir -p labs/lab_05_microservices_demo/{api-gateway,user-service,order-service,notification-service,database,message-queue,monitoring,testing}
mkdir -p labs/lab_05_microservices_demo/user-service/{models,tests,migrations}
mkdir -p labs/lab_05_microservices_demo/order-service/{handlers,database}
mkdir -p labs/lab_05_microservices_demo/notification-service/{queues,templates}
mkdir -p labs/lab_05_microservices_demo/database/{postgres,redis,mongodb}
mkdir -p labs/lab_05_microservices_demo/message-queue/{rabbitmq,kafka}
mkdir -p labs/lab_05_microservices_demo/testing/{contract-tests,load-tests,e2e-tests}
touch labs/lab_05_microservices_demo/{README.md,docker-compose.yml,docker-compose.prod.yml}
touch labs/lab_05_microservices_demo/api-gateway/{Dockerfile,nginx.conf,auth-middleware.js,rate-limiting.conf}
touch labs/lab_05_microservices_demo/user-service/{Dockerfile,app.py}
touch labs/lab_05_microservices_demo/order-service/{Dockerfile,app.go}
touch labs/lab_05_microservices_demo/notification-service/{Dockerfile,app.js}
touch labs/lab_05_microservices_demo/monitoring/{jaeger.yml,zipkin.yml,service-mesh.yml}

# Lab 06 - Production Deployment
mkdir -p labs/lab_06_production_deployment/{nginx,ssl,backup-scripts,security,deployment,monitoring}
mkdir -p labs/lab_06_production_deployment/nginx/ssl/certificates
mkdir -p labs/lab_06_production_deployment/nginx/static
touch labs/lab_06_production_deployment/{README.md,docker-compose.prod.yml}
touch labs/lab_06_production_deployment/nginx/{Dockerfile,nginx.conf}
touch labs/lab_06_production_deployment/nginx/ssl/generate-certs.sh
touch labs/lab_06_production_deployment/ssl/{letsencrypt.yml,cert-renewal.sh}
touch labs/lab_06_production_deployment/backup-scripts/{database-backup.sh,volume-backup.sh,automated-backup.yml,restore-procedures.md}
touch labs/lab_06_production_deployment/security/{fail2ban.yml,firewall-rules.sh,intrusion-detection.yml}
touch labs/lab_06_production_deployment/deployment/{blue-green.yml,canary-deployment.yml,rollback-strategy.md}
touch labs/lab_06_production_deployment/monitoring/{production-metrics.yml,alerting-rules.yml,health-checks.py}

# -----------------------------------------------------------
# Utilities Section - Simplified Structure
# -----------------------------------------------------------
echo "🛠️ Creating utilities..."

# Dockerfile Templates
mkdir -p utilities/Dockerfile.templates
touch utilities/Dockerfile.templates/{basic.Dockerfile,multi-stage.Dockerfile,production.Dockerfile,nodejs.Dockerfile,python.Dockerfile}

# Compose Templates
mkdir -p utilities/compose-templates
touch utilities/compose-templates/{web-app.yml,microservices.yml,monitoring.yml}

# Scripts
mkdir -p utilities/scripts
touch utilities/scripts/{cleanup.sh,build_all.sh,health_check.sh,security_scan.sh,performance_benchmark.sh}

# Monitoring
mkdir -p utilities/monitoring/{exporters,alerting}
touch utilities/monitoring/{prometheus.yml,grafana-dashboards.json}
touch utilities/monitoring/exporters/{node-exporter.yml,docker-exporter.yml}
touch utilities/monitoring/alerting/{alert-rules.yml,notification-channels.yml}

# Dev Tools
mkdir -p utilities/dev-tools
touch utilities/dev-tools/{container-inspector.sh,dockerfile-linter.py,image-scanner.py}

# Automation
mkdir -p utilities/automation/{ci-cd-templates,deployment}
touch utilities/automation/README.md
touch utilities/automation/ci-cd-templates/{github-actions.yml,gitlab-ci.yml}
touch utilities/automation/deployment/{blue-green.sh,rolling-update.sh}

# Performance (integrated into utilities)
mkdir -p utilities/performance/{benchmarks,optimization-guides,profiling}
touch utilities/performance/benchmarks/{container-startup-times.py,image-build-performance.py}
touch utilities/performance/optimization-guides/{dockerfile-optimization.md,runtime-optimization.md}
touch utilities/performance/profiling/{cpu-profiling.py,memory-profiling.py}

# Security (integrated into utilities)
mkdir -p utilities/security/{vulnerability-scanning,hardening-guides,secrets-management}
touch utilities/security/vulnerability-scanning/{trivy-scanning.sh,clair-integration.yml}
touch utilities/security/hardening-guides/{container-hardening.md,runtime-security.md}
touch utilities/security/secrets-management/{vault-integration.yml,docker-secrets.yml}

# -----------------------------------------------------------
# Case Studies
# -----------------------------------------------------------
echo "📖 Creating case-studies..."
mkdir -p case-studies/{startup-to-scale,enterprise-adoption}
touch case-studies/README.md
touch case-studies/startup-to-scale/{migration-story.md,architecture-evolution.md,lessons-learned.md}
touch case-studies/enterprise-adoption/{large-scale-deployment.md,organizational-changes.md,roi-analysis.md}

# -----------------------------------------------------------
# GitHub Workflows
# -----------------------------------------------------------
echo "🔄 Setting up GitHub workflows..."
mkdir -p .github/{workflows,ISSUE_TEMPLATE}
touch .github/workflows/{ci.yml,dockerfile_lint.yml,security-scan.yml,performance-test.yml,badge_update.yml,release-automation.yml,docs-deploy.yml}
touch .github/ISSUE_TEMPLATE/{bug_report.md,feature_request.md,documentation.md,question.md}
touch .github/{PULL_REQUEST_TEMPLATE.md,SECURITY.md,CODE_OF_CONDUCT.md}

# -----------------------------------------------------------
# Dev Container
# -----------------------------------------------------------
echo "🐳 Creating .devcontainer..."
mkdir -p .devcontainer
touch .devcontainer/{devcontainer.json,Dockerfile,docker-compose.yml}

# -----------------------------------------------------------
# Summary
# -----------------------------------------------------------
echo "✅ DockVerseHub structure created successfully!"
echo "📂 Total directories: $(find . -type d | wc -l)"
echo "📄 Total files: $(find . -type f | wc -l)"
echo ""
echo "🎯 Next steps:"
echo "   1. Initialize git: git init"
echo "   2. Start with README.md and core concept files"
echo "   3. Begin implementing concepts and labs"