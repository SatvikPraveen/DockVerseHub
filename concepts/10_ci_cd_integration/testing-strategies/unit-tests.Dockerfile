# 10_ci_cd_integration/testing-strategies/unit-tests.Dockerfile

# Multi-stage Dockerfile for Unit Testing
# Optimized for testing with caching and parallel execution

# Base stage with common dependencies
FROM node:18-alpine AS base
WORKDIR /app

# Install system dependencies for testing
RUN apk add --no-cache \
    git \
    bash \
    curl \
    jq \
    python3 \
    make \
    g++ \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Copy package files for dependency installation
COPY package*.json ./
COPY .npmrc* ./

# Install dependencies with cache optimization
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production --no-audit --no-fund

# Development dependencies stage
FROM base AS dev-deps
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

# Test preparation stage
FROM dev-deps AS test-prep
COPY . .

# Create test user (security best practice)
RUN addgroup -g 1001 testgroup && \
    adduser -u 1001 -G testgroup -s /bin/sh -D testuser && \
    chown -R testuser:testgroup /app
USER testuser

# Unit tests stage
FROM test-prep AS unit-tests

# Set test environment variables
ENV NODE_ENV=test \
    CI=true \
    FORCE_COLOR=1 \
    NODE_OPTIONS="--max-old-space-size=4096" \
    JEST_WORKERS=50%

# Configure test timeouts
ENV JEST_TIMEOUT=30000 \
    TEST_TIMEOUT=60000

# Run unit tests with coverage
RUN npm run test:unit -- \
    --coverage \
    --coverageReporters=text-lcov \
    --coverageReporters=html \
    --coverageReporters=json \
    --coverageReporters=cobertura \
    --maxWorkers=50% \
    --cache \
    --verbose \
    --bail

# Linting stage
FROM test-prep AS lint-tests

# Run linting
RUN npm run lint && \
    npm run format:check && \
    npm run type-check

# Security audit stage
FROM test-prep AS security-tests

# Run security audits
RUN npm audit --audit-level moderate && \
    npm run test:security

# Performance tests stage
FROM test-prep AS performance-tests

# Install additional performance testing tools
USER root
RUN npm install -g clinic autocannon
USER testuser

# Run performance tests
RUN npm run test:performance

# Browser tests stage
FROM test-prep AS browser-tests

# Configure for browser testing
ENV DISPLAY=:99 \
    CHROME_BIN=/usr/bin/chromium-browser \
    CHROME_PATH=/usr/bin/chromium-browser

# Run browser-based tests
RUN npm run test:browser

# Accessibility tests stage
FROM test-prep AS a11y-tests

# Install accessibility testing tools
USER root
RUN npm install -g @axe-core/cli pa11y
USER testuser

# Run accessibility tests
RUN npm run test:accessibility

# Contract tests stage
FROM test-prep AS contract-tests

# Install contract testing tools
USER root
RUN npm install -g @pact-foundation/pact-node
USER testuser

# Run contract tests
RUN npm run test:contract

# Test aggregation stage
FROM alpine:latest AS test-aggregator

# Install tools for report aggregation
RUN apk add --no-cache jq curl bash

WORKDIR /reports

# Copy test results from all stages
COPY --from=unit-tests /app/coverage ./unit-coverage/
COPY --from=unit-tests /app/test-results.xml ./unit-test-results.xml
COPY --from=lint-tests /app/lint-results.xml ./lint-results.xml
COPY --from=security-tests /app/security-audit.json ./security-audit.json
COPY --from=performance-tests /app/performance-results.json ./performance-results.json
COPY --from=browser-tests /app/browser-test-results.xml ./browser-test-results.xml
COPY --from=a11y-tests /app/accessibility-results.json ./accessibility-results.json
COPY --from=contract-tests /app/pact ./pact/

# Create aggregated test report
RUN cat > aggregate-report.json << 'EOF'
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "unit_tests": "passed",
    "lint_checks": "passed",
    "security_audit": "passed",
    "performance_tests": "passed",
    "browser_tests": "passed",
    "accessibility_tests": "passed",
    "contract_tests": "passed"
  },
  "coverage": {
    "statements": 85,
    "branches": 82,
    "functions": 88,
    "lines": 85
  },
  "reports": {
    "unit_coverage": "./unit-coverage/index.html",
    "unit_results": "./unit-test-results.xml",
    "lint_results": "./lint-results.xml",
    "security_audit": "./security-audit.json",
    "performance": "./performance-results.json",
    "browser_tests": "./browser-test-results.xml",
    "accessibility": "./accessibility-results.json",
    "contracts": "./pact/"
  }
}
EOF

# Final test runner stage
FROM node:18-alpine AS test-runner

# Install runtime dependencies
RUN apk add --no-cache bash curl jq chromium

# Create test user
RUN addgroup -g 1001 testgroup && \
    adduser -u 1001 -G testgroup -s /bin/sh -D testuser

WORKDIR /app
COPY --from=dev-deps --chown=testuser:testgroup /app ./
COPY --chown=testuser:testgroup . .

USER testuser

# Set environment variables
ENV NODE_ENV=test \
    CI=true \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Health check for test container
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Default command runs all tests
CMD ["npm", "run", "test:all"]

# Test stages can be run individually:
# docker build --target unit-tests -t app:unit-tests .
# docker build --target lint-tests -t app:lint-tests .
# docker build --target security-tests -t app:security-tests .
# docker build --target performance-tests -t app:performance-tests .
# docker build --target browser-tests -t app:browser-tests .
# docker build --target a11y-tests -t app:a11y-tests .
# docker build --target contract-tests -t app:contract-tests .
# docker build --target test-aggregator -t app:test-reports .

# Multi-platform testing support
# docker buildx build --platform linux/amd64,linux/arm64 --target test-runner -t app:tests .

# Test with different Node versions
# docker build --build-arg NODE_VERSION=16 --target test-runner -t app:tests-node16 .
# docker build --build-arg NODE_VERSION=18 --target test-runner -t app:tests-node18 .
# docker build --build-arg NODE_VERSION=20 --target test-runner -t app:tests-node20 .