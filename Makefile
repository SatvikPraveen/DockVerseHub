# Location: ./Makefile

# DockVerseHub - Common Commands Automation
# ==========================================

# Variables
SHELL := /bin/bash
PROJECT_NAME := dockversehub
DOCKER_COMPOSE := docker-compose
DOCKER := docker
PYTHON := python3
PIP := pip3

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)DockVerseHub - Docker Learning Platform$(NC)"
	@echo "$(WHITE)========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  make setup        - Set up development environment"
	@echo "  make test-all     - Run all tests"
	@echo "  make labs         - List all available labs"
	@echo "  make clean-all    - Clean up everything"

# Setup and Installation
# ======================

.PHONY: setup
setup: ## Set up development environment
	@echo "$(CYAN)Setting up DockVerseHub development environment...$(NC)"
	@$(MAKE) check-docker
	@$(MAKE) install-deps
	@$(MAKE) verify-setup
	@echo "$(GREEN)✓ Setup complete!$(NC)"

.PHONY: check-docker
check-docker: ## Check Docker installation
	@echo "$(YELLOW)Checking Docker installation...$(NC)"
	@$(DOCKER) --version > /dev/null 2>&1 || (echo "$(RED)❌ Docker not found. Please install Docker first.$(NC)" && exit 1)
	@$(DOCKER_COMPOSE) --version > /dev/null 2>&1 || (echo "$(RED)❌ Docker Compose not found. Please install Docker Compose first.$(NC)" && exit 1)
	@echo "$(GREEN)✓ Docker and Docker Compose are installed$(NC)"

.PHONY: install-deps
install-deps: ## Install Python dependencies
	@echo "$(YELLOW)Installing Python dependencies...$(NC)"
	@$(PIP) install -r requirements.txt
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

.PHONY: verify-setup
verify-setup: ## Verify the setup is working
	@echo "$(YELLOW)Verifying setup...$(NC)"
	@$(DOCKER) run --rm hello-world > /dev/null 2>&1 || (echo "$(RED)❌ Docker test failed$(NC)" && exit 1)
	@echo "$(GREEN)✓ Docker is working correctly$(NC)"

# Testing and Validation
# =======================

.PHONY: test-all
test-all: ## Run all tests
	@echo "$(CYAN)Running comprehensive test suite...$(NC)"
	@$(MAKE) test-setup
	@$(MAKE) test-dockerfiles
	@$(MAKE) test-compose
	@$(MAKE) test-scripts
	@$(MAKE) test-labs
	@echo "$(GREEN)✓ All tests passed!$(NC)"

.PHONY: test-setup
test-setup: ## Test basic Docker setup
	@echo "$(YELLOW)Testing Docker setup...$(NC)"
	@$(DOCKER) run --rm hello-world > /dev/null 2>&1 && echo "$(GREEN)✓ Docker basic test passed$(NC)" || (echo "$(RED)❌ Docker test failed$(NC)" && exit 1)

.PHONY: test-dockerfiles
test-dockerfiles: ## Test all Dockerfiles build successfully
	@echo "$(YELLOW)Testing Dockerfile builds...$(NC)"
	@./utilities/scripts/build_all.sh --test-only
	@echo "$(GREEN)✓ All Dockerfiles build successfully$(NC)"

.PHONY: test-compose
test-compose: ## Validate Docker Compose files
	@echo "$(YELLOW)Validating Docker Compose files...$(NC)"
	@find . -name "docker-compose*.yml" -exec $(DOCKER_COMPOSE) -f {} config \; > /dev/null 2>&1 && echo "$(GREEN)✓ All Compose files are valid$(NC)" || (echo "$(RED)❌ Compose validation failed$(NC)" && exit 1)

.PHONY: test-scripts
test-scripts: ## Test utility scripts
	@echo "$(YELLOW)Testing utility scripts...$(NC)"
	@bash -n utilities/scripts/*.sh && echo "$(GREEN)✓ All shell scripts are valid$(NC)" || (echo "$(RED)❌ Shell script validation failed$(NC)" && exit 1)
	@$(PYTHON) -m py_compile utilities/dev-tools/*.py && echo "$(GREEN)✓ All Python scripts are valid$(NC)" || (echo "$(RED)❌ Python script validation failed$(NC)" && exit 1)

.PHONY: test-labs
test-labs: ## Test all lab environments
	@echo "$(YELLOW)Testing lab environments...$(NC)"
	@for lab in labs/lab_*; do \
		if [ -f "$$lab/scripts/test.sh" ]; then \
			echo "Testing $$lab..."; \
			cd "$$lab" && ./scripts/test.sh && cd - > /dev/null; \
		fi; \
	done
	@echo "$(GREEN)✓ All lab tests completed$(NC)"

# Lab Management
# ==============

.PHONY: labs
labs: ## List all available labs
	@echo "$(CYAN)Available Labs:$(NC)"
	@echo "$(WHITE)===============$(NC)"
	@for lab in labs/lab_*; do \
		if [ -d "$$lab" ]; then \
			echo "$(GREEN)$$(basename $$lab)$(NC): $$(head -n3 $$lab/README.md | tail -n1 | sed 's/#* *//')"; \
		fi; \
	done

.PHONY: lab-%
lab-%: ## Run a specific lab (e.g., make lab-01)
	@lab_num=$*; \
	lab_dir="labs/lab_$${lab_num}_*"; \
	if ls $$lab_dir 1> /dev/null 2>&1; then \
		lab_path=$$(ls -d $$lab_dir | head -1); \
		echo "$(CYAN)Starting Lab $$lab_num...$(NC)"; \
		cd "$$lab_path" && $(DOCKER_COMPOSE) up -d; \
		echo "$(GREEN)✓ Lab $$lab_num is running$(NC)"; \
		echo "$(YELLOW)Check README.md in $$lab_path for instructions$(NC)"; \
	else \
		echo "$(RED)❌ Lab $$lab_num not found$(NC)"; \
		$(MAKE) labs; \
	fi

.PHONY: stop-lab-%
stop-lab-%: ## Stop a specific lab (e.g., make stop-lab-01)
	@lab_num=$*; \
	lab_dir="labs/lab_$${lab_num}_*"; \
	if ls $$lab_dir 1> /dev/null 2>&1; then \
		lab_path=$$(ls -d $$lab_dir | head -1); \
		echo "$(YELLOW)Stopping Lab $$lab_num...$(NC)"; \
		cd "$$lab_path" && $(DOCKER_COMPOSE) down; \
		echo "$(GREEN)✓ Lab $$lab_num stopped$(NC)"; \
	else \
		echo "$(RED)❌ Lab $$lab_num not found$(NC)"; \
	fi

.PHONY: labs-start-all
labs-start-all: ## Start all labs
	@echo "$(CYAN)Starting all labs...$(NC)"
	@./utilities/scripts/start_compose.sh
	@echo "$(GREEN)✓ All labs started$(NC)"

.PHONY: labs-stop-all
labs-stop-all: ## Stop all running labs
	@echo "$(YELLOW)Stopping all labs...$(NC)"
	@./utilities/scripts/stop_all.sh
	@echo "$(GREEN)✓ All labs stopped$(NC)"

# Build Operations
# ================

.PHONY: build-all
build-all: ## Build all Docker images
	@echo "$(CYAN)Building all Docker images...$(NC)"
	@./utilities/scripts/build_all.sh
	@echo "$(GREEN)✓ All images built successfully$(NC)"

.PHONY: build-concept-%
build-concept-%: ## Build images for specific concept (e.g., make build-concept-01)
	@concept=$*; \
	concept_dir="concepts/$${concept}_*"; \
	if ls $$concept_dir 1> /dev/null 2>&1; then \
		concept_path=$$(ls -d $$concept_dir | head -1); \
		echo "$(CYAN)Building concept $$concept...$(NC)"; \
		find "$$concept_path" -name "Dockerfile*" -exec dirname {} \; | sort -u | while read dir; do \
			echo "Building in $$dir..."; \
			cd "$$dir" && $(DOCKER) build -t "$$(basename $$dir):latest" . && cd - > /dev/null; \
		done; \
		echo "$(GREEN)✓ Concept $$concept built$(NC)"; \
	else \
		echo "$(RED)❌ Concept $$concept not found$(NC)"; \
	fi

# Cleanup Operations
# ==================

.PHONY: clean
clean: ## Clean up unused Docker resources
	@echo "$(YELLOW)Cleaning up unused Docker resources...$(NC)"
	@$(DOCKER) system prune -f
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

.PHONY: clean-all
clean-all: ## Clean up everything (containers, images, volumes, networks)
	@echo "$(RED)WARNING: This will remove ALL Docker containers, images, volumes, and networks!$(NC)"
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		./utilities/scripts/cleanup.sh --all; \
		echo "$(GREEN)✓ Complete cleanup finished$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

.PHONY: clean-labs
clean-labs: ## Clean up lab-specific resources
	@echo "$(YELLOW)Cleaning up lab resources...$(NC)"
	@for lab in labs/lab_*; do \
		if [ -f "$$lab/docker-compose.yml" ]; then \
			cd "$$lab" && $(DOCKER_COMPOSE) down -v --remove-orphans && cd - > /dev/null; \
		fi; \
	done
	@echo "$(GREEN)✓ Lab cleanup complete$(NC)"

.PHONY: clean-images
clean-images: ## Remove all project-related Docker images
	@echo "$(YELLOW)Removing project Docker images...$(NC)"
	@$(DOCKER) images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" | grep -E "($(PROJECT_NAME)|lab_|concept_)" | awk '{print $$3}' | xargs -r $(DOCKER) rmi -f
	@echo "$(GREEN)✓ Project images removed$(NC)"

# Development and Debugging
# ==========================

.PHONY: debug-lab-%
debug-lab-%: ## Debug a specific lab with verbose output
	@lab_num=$*; \
	lab_dir="labs/lab_$${lab_num}_*"; \
	if ls $$lab_dir 1> /dev/null 2>&1; then \
		lab_path=$$(ls -d $$lab_dir | head -1); \
		echo "$(CYAN)Debugging Lab $$lab_num...$(NC)"; \
		cd "$$lab_path" && $(DOCKER_COMPOSE) config; \
		cd "$$lab_path" && $(DOCKER_COMPOSE) up --build; \
	else \
		echo "$(RED)❌ Lab $$lab_num not found$(NC)"; \
	fi

.PHONY: inspect-container-%
inspect-container-%: ## Inspect a running container
	@container=$*; \
	$(DOCKER) inspect "$$container" | jq '.[0] | {State, Config: .Config | {Image, Cmd, Env}, NetworkSettings: .NetworkSettings | {Ports, Networks}}'

.PHONY: logs-%
logs-%: ## View logs for a specific service
	@service=$*; \
	echo "$(CYAN)Logs for $$service:$(NC)"; \
	$(DOCKER) logs "$$service" --follow --tail=100

# Security and Maintenance
# =========================

.PHONY: security-scan
security-scan: ## Run security scan on all images
	@echo "$(CYAN)Running security scans...$(NC)"
	@./utilities/scripts/security_scan.sh
	@echo "$(GREEN)✓ Security scan complete$(NC)"

.PHONY: vulnerability-check
vulnerability-check: ## Check for vulnerabilities in dependencies
	@echo "$(YELLOW)Checking for vulnerabilities...$(NC)"
	@$(PYTHON) utilities/dev-tools/image-scanner.py --all
	@echo "$(GREEN)✓ Vulnerability check complete$(NC)"

.PHONY: health-check
health-check: ## Perform health check on running services
	@echo "$(CYAN)Performing health checks...$(NC)"
	@./utilities/scripts/health_check.sh
	@echo "$(GREEN)✓ Health check complete$(NC)"

.PHONY: backup-volumes
backup-volumes: ## Backup all Docker volumes
	@echo "$(YELLOW)Backing up Docker volumes...$(NC)"
	@./utilities/scripts/backup_volumes.sh
	@echo "$(GREEN)✓ Volume backup complete$(NC)"

# Documentation and Resources
# ============================

.PHONY: docs
docs: ## Generate documentation
	@echo "$(CYAN)Generating documentation...$(NC)"
	@if [ -d "website/docs" ]; then \
		cd website && npm run build; \
		echo "$(GREEN)✓ Documentation generated$(NC)"; \
	else \
		echo "$(YELLOW)No documentation site found$(NC)"; \
	fi

.PHONY: docs-serve
docs-serve: ## Serve documentation locally
	@echo "$(CYAN)Serving documentation locally...$(NC)"
	@if [ -d "website/docs" ]; then \
		cd website && npm run start; \
	else \
		echo "$(YELLOW)Starting simple HTTP server for docs...$(NC)"; \
		$(PYTHON) -m http.server 8000 -d docs; \
	fi

.PHONY: stats
stats: ## Show project statistics
	@echo "$(CYAN)DockVerseHub Statistics:$(NC)"
	@echo "$(WHITE)========================$(NC)"
	@echo "$(GREEN)Dockerfiles:$(NC) $$(find . -name "Dockerfile*" | wc -l)"
	@echo "$(GREEN)Compose files:$(NC) $$(find . -name "docker-compose*.yml" | wc -l)"
	@echo "$(GREEN)Labs:$(NC) $$(ls -d labs/lab_* 2>/dev/null | wc -l)"
	@echo "$(GREEN)Concepts:$(NC) $$(ls -d concepts/[0-9]* 2>/dev/null | wc -l)"
	@echo "$(GREEN)Scripts:$(NC) $$(find utilities/scripts -name "*.sh" | wc -l)"
	@echo "$(GREEN)Python tools:$(NC) $$(find utilities/dev-tools -name "*.py" | wc -l)"
	@echo "$(GREEN)Documentation files:$(NC) $$(find docs -name "*.md" | wc -l)"

# Performance and Optimization
# =============================

.PHONY: benchmark
benchmark: ## Run performance benchmarks
	@echo "$(CYAN)Running performance benchmarks...$(NC)"
	@./utilities/scripts/performance_benchmark.sh
	@echo "$(GREEN)✓ Benchmarks complete$(NC)"

.PHONY: optimize-images
optimize-images: ## Optimize Docker images for size and performance
	@echo "$(YELLOW)Optimizing Docker images...$(NC)"
	@./utilities/scripts/image_optimization.sh
	@echo "$(GREEN)✓ Image optimization complete$(NC)"

.PHONY: analyze-layers
analyze-layers: ## Analyze Docker image layers
	@echo "$(CYAN)Analyzing image layers...$(NC)"
	@$(PYTHON) utilities/dev-tools/dependency-analyzer.py
	@echo "$(GREEN)✓ Layer analysis complete$(NC)"

# CI/CD and Automation
# ====================

.PHONY: lint
lint: ## Lint all code and configuration files
	@echo "$(CYAN)Running linters...$(NC)"
	@$(PYTHON) utilities/dev-tools/dockerfile-linter.py
	@$(PYTHON) utilities/dev-tools/compose-validator.py
	@echo "$(GREEN)✓ Linting complete$(NC)"

.PHONY: format
format: ## Format all code files
	@echo "$(YELLOW)Formatting code files...$(NC)"
	@find . -name "*.py" -exec black {} \;
	@find . -name "*.sh" -exec shfmt -w {} \; 2>/dev/null || true
	@echo "$(GREEN)✓ Code formatting complete$(NC)"

.PHONY: pre-commit
pre-commit: ## Run pre-commit checks
	@$(MAKE) lint
	@$(MAKE) test-dockerfiles
	@$(MAKE) test-compose
	@echo "$(GREEN)✓ Pre-commit checks passed$(NC)"

# Monitoring and Logging
# =======================

.PHONY: monitor
monitor: ## Start monitoring stack
	@echo "$(CYAN)Starting monitoring stack...$(NC)"
	@cd utilities/monitoring && $(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Monitoring stack running$(NC)"
	@echo "$(YELLOW)Grafana: http://localhost:3000$(NC)"
	@echo "$(YELLOW)Prometheus: http://localhost:9090$(NC)"

.PHONY: stop-monitor
stop-monitor: ## Stop monitoring stack
	@echo "$(YELLOW)Stopping monitoring stack...$(NC)"
	@cd utilities/monitoring && $(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Monitoring stack stopped$(NC)"

.PHONY: logs-aggregate
logs-aggregate: ## Start log aggregation system
	@echo "$(CYAN)Starting log aggregation...$(NC)"
	@./utilities/scripts/log_aggregation.sh
	@echo "$(GREEN)✓ Log aggregation started$(NC)"

# Education and Assessment
# ========================

.PHONY: quiz
quiz: ## Run interactive quiz
	@echo "$(CYAN)Starting Docker knowledge quiz...$(NC)"
	@$(PYTHON) interactive/quiz/quiz_runner.py
	@echo "$(GREEN)✓ Quiz completed$(NC)"

.PHONY: challenge-%
challenge-%: ## Start a specific challenge
	@challenge=$*; \
	echo "$(CYAN)Starting challenge: $$challenge$(NC)"; \
	if [ -f "interactive/challenges/$$challenge.md" ]; then \
		cat "interactive/challenges/$$challenge.md"; \
	else \
		echo "$(RED)❌ Challenge $$challenge not found$(NC)"; \
		echo "Available challenges:"; \
		ls interactive/challenges/*.md | xargs -I {} basename {} .md; \
	fi

# Utility Targets
# ===============

.PHONY: version
version: ## Show version information
	@echo "$(CYAN)DockVerseHub Version Information:$(NC)"
	@echo "$(WHITE)==================================$(NC)"
	@cat VERSION 2>/dev/null || echo "$(GREEN)Project Version:$(NC) Development"
	@echo "$(GREEN)Docker Version:$(NC) $$($(DOCKER) --version | cut -d' ' -f3 | cut -d',' -f1)"
	@echo "$(GREEN)Docker Compose Version:$(NC) $$($(DOCKER_COMPOSE) --version | cut -d' ' -f4 | cut -d',' -f1)"
	@echo "$(GREEN)Python Version:$(NC) $$($(PYTHON) --version | cut -d' ' -f2)"

.PHONY: update
update: ## Update project dependencies and base images
	@echo "$(CYAN)Updating project dependencies...$(NC)"
	@$(PIP) install -r requirements.txt --upgrade
	@$(DOCKER) pull hello-world
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

.PHONY: backup
backup: ## Create backup of project data
	@echo "$(YELLOW)Creating project backup...$(NC)"
	@tar -czf "dockversehub-backup-$$(date +%Y%m%d-%H%M%S).tar.gz" \
		--exclude-vcs \
		--exclude="*.tar.gz" \
		--exclude="node_modules" \
		--exclude="__pycache__" \
		.
	@echo "$(GREEN)✓ Backup created$(NC)"

# Special targets for automation
.PHONY: ci
ci: check-docker install-deps test-all lint ## CI pipeline target

.PHONY: cd
cd: build-all security-scan ## CD pipeline target

# Make sure intermediate files are not deleted
.PRECIOUS: %.log

# Suppress output for some commands
.SILENT: help version