.
├── .devcontainer
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── post-create.sh
├── .dockerignore
├── .DS_Store
├── .github
│   ├── CODE_OF_CONDUCT.md
│   ├── ISSUE_TEMPLATE
│   │   ├── bug_report.md
│   │   ├── documentation.md
│   │   ├── feature_request.md
│   │   └── question.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── SECURITY.md
│   └── workflows
│       ├── badge_update.yml
│       ├── ci.yml
│       ├── dockerfile_lint.yml
│       ├── docs-deploy.yml
│       ├── performance-test.yml
│       ├── release-automation.yml
│       └── security-scan.yml
├── .gitignore
├── case-studies
│   ├── {README.md}
│   ├── enterprise-adoption
│   │   ├── large-scale-deployment.md
│   │   ├── organizational-changes.md
│   │   └── roi-analysis.md
│   ├── README.md
│   └── startup-to-scale
│       ├── architecture-evolution.md
│       ├── lessons-learned.md
│       └── migration-story.md
├── CHANGELOG.md
├── concepts
│   ├── 01_getting_started
│   │   ├── Dockerfile
│   │   ├── Dockerfile.interactive
│   │   ├── exercises
│   │   │   ├── basic-commands.md
│   │   │   └── first-container.md
│   │   ├── installation
│   │   │   ├── macos.md
│   │   │   ├── ubuntu.md
│   │   │   ├── verification.sh
│   │   │   └── windows.md
│   │   ├── README.md
│   │   └── run_container.sh
│   ├── 02_images_layers
│   │   ├── caching-strategies.md
│   │   ├── Dockerfile.basic
│   │   ├── Dockerfile.distroless
│   │   ├── Dockerfile.optimized
│   │   ├── image_comparison.md
│   │   ├── inspect_image.sh
│   │   ├── README.md
│   │   └── registry
│   │       ├── private-registry.yml
│   │       └── push-pull-demo.sh
│   ├── 03_volumes_bindmounts
│   │   ├── backup-restore
│   │   │   ├── automated-backup.yml
│   │   │   ├── restore-demo.sh
│   │   │   └── volume-backup.sh
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── performance
│   │   │   ├── benchmark.py
│   │   │   └── results-analysis.md
│   │   ├── README.md
│   │   └── volume_demo.md
│   ├── 04_networking
│   │   ├── custom-networks
│   │   │   ├── ingress-routing.yml
│   │   │   ├── multi-network.yml
│   │   │   └── overlay-demo.yml
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile.db
│   │   ├── Dockerfile.web
│   │   ├── inspect_network.sh
│   │   ├── load-balancing
│   │   │   ├── haproxy-config.cfg
│   │   │   ├── nginx-lb.yml
│   │   │   └── traefik-demo.yml
│   │   ├── README.md
│   │   └── troubleshooting
│   │       ├── connectivity-test.sh
│   │       ├── dns-resolution.sh
│   │       └── port-conflicts.md
│   ├── 05_docker_compose
│   │   ├── advanced-features
│   │   │   ├── configs-demo.yml
│   │   │   ├── extensions.yml
│   │   │   └── secrets-demo.yml
│   │   ├── docker-compose.override.yml
│   │   ├── docker-compose.prod.yml
│   │   ├── docker-compose.yml
│   │   ├── profiles-demo
│   │   │   ├── development.yml
│   │   │   ├── staging.yml
│   │   │   └── testing.yml
│   │   ├── README.md
│   │   └── scaling
│   │       ├── horizontal-scaling.yml
│   │       └── resource-constraints.yml
│   ├── 06_security
│   │   ├── compliance
│   │   │   ├── cis-benchmark.md
│   │   │   ├── security-audit.sh
│   │   │   └── vulnerability-mgmt.md
│   │   ├── Dockerfile.hardened
│   │   ├── Dockerfile.rootless
│   │   ├── image-signing
│   │   │   ├── cosign-example.sh
│   │   │   └── notary-demo.sh
│   │   ├── README.md
│   │   ├── runtime-security
│   │   │   ├── apparmor-profiles
│   │   │   │   ├── docker-default
│   │   │   │   └── docker-hardened
│   │   │   ├── falco-rules.yml
│   │   │   └── seccomp-profiles
│   │   │       └── default-seccomp.json
│   │   ├── scan_image.sh
│   │   └── secrets_demo
│   │       ├── app.py
│   │       ├── docker-compose.yml
│   │       ├── secrets.env
│   │       └── vault-integration.yml
│   ├── 07_logging_monitoring
│   │   ├── alerting
│   │   │   ├── alertmanager-config.yml
│   │   │   ├── prometheus-rules.yml
│   │   │   └── webhook-examples
│   │   │       ├── docker-compose.yml
│   │   │       ├── email-webhook.py
│   │   │       ├── generic-webhook.py
│   │   │       ├── pagerduty-webhook.py
│   │   │       ├── requirements.txt
│   │   │       └── slack-webhook.py
│   │   ├── app.py
│   │   ├── dashboards
│   │   │   ├── application-metrics.json
│   │   │   ├── docker-stats.json
│   │   │   ├── grafana-dashboard.json
│   │   │   └── kibana-dashboard.json
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile.app
│   │   ├── log-aggregation
│   │   │   ├── filebeat.yml
│   │   │   ├── fluentbit.conf
│   │   │   └── logstash-pipeline.conf
│   │   ├── logging-drivers
│   │   │   ├── fluentd.yml
│   │   │   ├── gelf.yml
│   │   │   ├── json-file.yml
│   │   │   └── syslog.yml
│   │   ├── monitoring-stack
│   │   │   ├── alertmanager.yml
│   │   │   ├── grafana.yml
│   │   │   ├── node-exporter.yml
│   │   │   └── prometheus.yml
│   │   └── README.md
│   ├── 08_orchestration
│   │   ├── cluster-management
│   │   │   ├── backup-cluster.sh
│   │   │   ├── disaster-recovery.md
│   │   │   └── upgrade-strategy.md
│   │   ├── docker-compose.yml
│   │   ├── kubernetes-compare
│   │   │   ├── feature-comparison.md
│   │   │   ├── k8s-manifests
│   │   │   └── migration-guide.md
│   │   ├── README.md
│   │   ├── scaling_demo.md
│   │   ├── service-mesh
│   │   │   ├── consul-connect.yml
│   │   │   └── linkerd-demo.yml
│   │   ├── swarm_setup.sh
│   │   └── swarm-advanced
│   │       ├── ingress-routing.yml
│   │       ├── placement-constraints.yml
│   │       ├── rolling-updates.yml
│   │       └── stack-deploy.yml
│   ├── 09_advanced_tricks
│   │   ├── build-optimization
│   │   │   ├── buildx-multiarch.sh
│   │   │   ├── cache-mounts.Dockerfile
│   │   │   ├── parallel-builds.sh
│   │   │   └── remote-cache.yml
│   │   ├── custom-solutions
│   │   │   ├── data-processing.yml
│   │   │   ├── init-containers.yml
│   │   │   ├── job-scheduling.yml
│   │   │   └── sidecar-patterns.yml
│   │   ├── debug_container.sh
│   │   ├── debugging-tools
│   │   │   ├── container-inspection.sh
│   │   │   ├── memory-analysis.py
│   │   │   ├── network-debugging.py
│   │   │   └── performance-profiling.sh
│   │   ├── Dockerfile.buildkit
│   │   ├── Dockerfile.experimental
│   │   ├── Dockerfile.healthcheck
│   │   ├── prune_unused.sh
│   │   ├── README.md
│   │   └── resource-management
│   │       ├── benchmarking.py
│   │       ├── cpu-constraints.yml
│   │       ├── memory-limits.yml
│   │       └── storage-quotas.yml
│   └── 10_ci_cd_integration
│       ├── {README.md}
│       ├── azure-devops
│       │   ├── azure-pipelines.yml
│       │   └── container-jobs.yml
│       ├── deployment-strategies
│       │   ├── blue-green.yml
│       │   ├── canary.yml
│       │   ├── feature-flags.yml
│       │   └── rolling-update.yml
│       ├── github-actions
│       │   ├── build-push.yml
│       │   ├── multi-stage-ci.yml
│       │   ├── release-automation.yml
│       │   └── security-scan.yml
│       ├── gitlab-ci
│       │   ├── .gitlab-ci.yml
│       │   ├── docker-in-docker.yml
│       │   └── registry-integration.yml
│       ├── jenkins
│       │   ├── declarative-pipeline.groovy
│       │   ├── Jenkinsfile
│       │   └── shared-library
│       │       └── vars
│       │           └── dockerBuild.groovy
│       ├── README.md
│       └── testing-strategies
│           ├── contract-testing.yml
│           ├── e2e-testing.yml
│           ├── integration-tests.yml
│           └── unit-tests.Dockerfile
├── CONTRIBUTING.md
├── dockversehub_generator.sh
├── docs
│   ├── cost-optimization.md
│   ├── diagrams
│   │   ├── build-optimization.svg
│   │   ├── ci-cd-integration.svg
│   │   ├── docker-lifecycle.svg
│   │   ├── microservices-arch.svg
│   │   ├── networking-modes.svg
│   │   ├── orchestration-flow.svg
│   │   ├── production-topology.svg
│   │   ├── security-layers.svg
│   │   └── volumes-architecture.svg
│   ├── docker-basics.md
│   ├── docker-cheatsheet.md
│   ├── docker-compose.md
│   ├── docker-ecosystem.md
│   ├── glossary.md
│   ├── images-vs-containers.md
│   ├── learning-paths
│   │   ├── advanced-path.md
│   │   ├── beginner-path.md
│   │   ├── certification-prep.md
│   │   └── intermediate-path.md
│   ├── migration-strategies.md
│   ├── monitoring-logging.md
│   ├── networking.md
│   ├── orchestration-overview.md
│   ├── performance-optimization.md
│   ├── production-deployment.md
│   ├── quick-reference
│   │   ├── compose-patterns.md
│   │   ├── dockerfile-best-practices.md
│   │   ├── networking-quick-ref.md
│   │   ├── security-checklist.md
│   │   └── troubleshooting-flowcharts.md
│   ├── security-best-practices.md
│   ├── troubleshooting.md
│   └── volumes-storage.md
├── labs
│   ├── lab_01_simple_app
│   │   ├── app.py
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── README.md
│   │   └── requirements.txt
│   ├── lab_02_multi_container_compose
│   │   ├── api
│   │   │   ├── app.py
│   │   │   ├── Dockerfile
│   │   │   ├── requirements.txt
│   │   │   └── tests
│   │   │       └── test_app.py
│   │   ├── db
│   │   │   ├── Dockerfile
│   │   │   ├── init.sql
│   │   │   └── migrations
│   │   ├── docker-compose.prod.yml
│   │   ├── docker-compose.yml
│   │   ├── frontend
│   │   │   ├── Dockerfile
│   │   │   ├── package.json
│   │   │   ├── public
│   │   │   │   ├── favicon.ico
│   │   │   │   ├── index.html
│   │   │   │   └── manifest.json
│   │   │   └── src
│   │   │       ├── App.css
│   │   │       ├── App.js
│   │   │       ├── index.css
│   │   │       ├── index.js
│   │   │       └── reportWebVitals.js
│   │   ├── nginx
│   │   │   ├── Dockerfile
│   │   │   ├── nginx.conf
│   │   │   └── ssl
│   │   ├── README.md
│   │   └── redis
│   │       └── redis.conf
│   ├── lab_03_image_optimization
│   │   ├── app.py
│   │   ├── benchmark.sh
│   │   ├── comparison
│   │   │   ├── build-times.csv
│   │   │   ├── image-sizes.csv
│   │   │   └── runtime-performance.csv
│   │   ├── Dockerfile.alpine
│   │   ├── Dockerfile.distroless
│   │   ├── Dockerfile.naive
│   │   ├── Dockerfile.optimized
│   │   ├── optimization-strategies
│   │   │   ├── dependency-management.md
│   │   │   ├── layer-caching.md
│   │   │   └── multi-stage-patterns.md
│   │   ├── README.md
│   │   ├── requirements.txt
│   │   └── size_report.md
│   ├── lab_04_logging_dashboard
│   │   ├── docker-compose.yml
│   │   ├── elasticsearch
│   │   │   ├── Dockerfile
│   │   │   ├── elasticsearch.yml
│   │   │   └── index-templates
│   │   │       └── logo-template.json
│   │   ├── grafana
│   │   │   ├── dashboards
│   │   │   │   ├── dashboard.yml
│   │   │   │   └── observability-dashboard.json
│   │   │   ├── datasources
│   │   │   │   └── datasources.yml
│   │   │   ├── Dockerfile
│   │   │   └── grafana.ini
│   │   ├── kibana
│   │   │   ├── dashboards
│   │   │   │   └── application-overview.json
│   │   │   ├── Dockerfile
│   │   │   └── kibana.yml
│   │   ├── log_app
│   │   │   ├── app.py
│   │   │   ├── Dockerfile
│   │   │   ├── log_generator.py
│   │   │   └── requirements.txt
│   │   ├── logstash
│   │   │   ├── Dockerfile
│   │   │   ├── logstash.yml
│   │   │   └── pipelines
│   │   │       └── main.conf
│   │   ├── prometheus
│   │   │   ├── prometheus.yml
│   │   │   ├── rules
│   │   │   │   └── alerts.yml
│   │   │   └── targets
│   │   │       └── services.json
│   │   └── README.md
│   ├── lab_05_microservices_demo
│   │   ├── api-gateway
│   │   │   ├── auth-middleware.js
│   │   │   ├── Dockerfile
│   │   │   ├── nginx.conf
│   │   │   ├── package.json
│   │   │   └── rate-limiting.conf
│   │   ├── database
│   │   │   ├── mongodb
│   │   │   │   └── init-notificaiton-db.js
│   │   │   ├── postgres
│   │   │   │   ├── init-order-db.sql
│   │   │   │   └── init-user-db.sql
│   │   │   └── redis
│   │   │       └── redis.conf
│   │   ├── docker-compose.prod.yml
│   │   ├── docker-compose.yml
│   │   ├── message-queue
│   │   │   ├── kafka
│   │   │   │   ├── consumer.properties
│   │   │   │   ├── docker-compose.yml
│   │   │   │   ├── producer.properties
│   │   │   │   └── README.md
│   │   │   └── rabbitmq
│   │   │       └── rabbitmq.conf
│   │   ├── monitoring
│   │   │   ├── jaeger.yml
│   │   │   ├── prometheus.yml
│   │   │   ├── service-mesh.yml
│   │   │   └── zipkin.yml
│   │   ├── notification-service
│   │   │   ├── app.js
│   │   │   ├── Dockerfile
│   │   │   ├── package.json
│   │   │   ├── queues
│   │   │   │   └── message-handler.js
│   │   │   └── templates
│   │   │       └── email-welcome.html
│   │   ├── order-service
│   │   │   ├── app.go
│   │   │   ├── database
│   │   │   │   └── postgres.go
│   │   │   ├── Dockerfile
│   │   │   └── handlers
│   │   │       └── order_handler.go
│   │   ├── README.md
│   │   ├── testing
│   │   │   ├── contract-tests
│   │   │   │   └── user-service.test.js
│   │   │   ├── e2e-tests
│   │   │   │   └── user-order-flow.test.js
│   │   │   └── load-tests
│   │   │       └── api-gateway.test.js
│   │   └── user-service
│   │       ├── app.py
│   │       ├── Dockerfile
│   │       ├── migrations
│   │       │   └── 001_initial_schema.sql
│   │       ├── models
│   │       │   ├── profile.py
│   │       │   └── user.py
│   │       ├── requirements.txt
│   │       └── tests
│   │           └── test_user_api.py
│   └── lab_06_production_deployment
│       ├── backup-scripts
│       │   ├── automated-backup.yml
│       │   ├── database-backup.sh
│       │   ├── restore-procedures.md
│       │   └── volume-backup.sh
│       ├── deployment
│       │   ├── blue-green.yml
│       │   ├── canary-deployment.yml
│       │   └── rollback-strategy.md
│       ├── docker-compose.prod.yml
│       ├── monitoring
│       │   ├── alerting-rules.yml
│       │   ├── health-checks.py
│       │   └── production-metrics.yml
│       ├── nginx
│       │   ├── Dockerfile
│       │   ├── nginx.conf
│       │   ├── ssl
│       │   │   ├── certificates
│       │   │   │   ├── cert.pem
│       │   │   │   ├── privkey.pem
│       │   │   │   └── README.md
│       │   │   └── generate-certs.sh
│       │   └── static
│       │       ├── app.js
│       │       ├── favicon.ico
│       │       ├── index.html
│       │       └── styles.css
│       ├── README.md
│       ├── security
│       │   ├── fail2ban.yml
│       │   ├── firewall-rules.sh
│       │   └── intrusion-detection.yml
│       └── ssl
│           ├── cert-renewal.sh
│           └── letsencrypt.yml
├── LICENSE
├── Makefile
├── PROJECT_STRUCTURE.md
├── README.md
├── requirements.txt
└── utilities
    ├── automation
    │   ├── ci-cd-templates
    │   │   ├── github-actions.yml
    │   │   └── gitlab-ci.yml
    │   ├── deployment
    │   │   ├── blue-green.sh
    │   │   └── rolling-update.sh
    │   └── README.md
    ├── compose-templates
    │   ├── microservices.yml
    │   ├── monitoring.yml
    │   └── web-app.yml
    ├── dev-tools
    │   ├── container-inspector.sh
    │   ├── dockerfile-linter.py
    │   └── image-scanner.py
    ├── Dockerfile.templates
    │   ├── basic.Dockerfile
    │   ├── multi-stage.Dockerfile
    │   ├── nodejs.Dockerfile
    │   ├── production.Dockerfile
    │   └── python.Dockerfile
    ├── performance
    │   ├── benchmarks
    │   │   ├── container-startup-times.py
    │   │   └── image-build-performance.py
    │   ├── optimization-guides
    │   │   ├── dockerfile-optimization.md
    │   │   └── runtime-optimization.md
    │   └── profiling
    │       ├── cpu-profiling.py
    │       └── memory-profiling.py
    ├── scripts
    │   ├── build_all.sh
    │   ├── cleanup.sh
    │   ├── health_check.sh
    │   ├── performance_benchmark.sh
    │   └── security_scan.sh
    └── security
        ├── hardening-guides
        │   ├── container-hardening.md
        │   └── runtime-security.md
        ├── secrets-management
        │   ├── docker-secrets.yml
        │   └── vault-integration.yml
        └── vulnerability-scanning
            ├── clair-integration.yml
            └── trivy-scanning.sh

143 directories, 393 files
