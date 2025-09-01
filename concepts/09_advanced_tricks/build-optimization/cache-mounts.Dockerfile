# 09_advanced_tricks/build-optimization/cache-mounts.Dockerfile

# syntax=docker/dockerfile:1.6-labs
# Enable BuildKit cache mount features

ARG NODE_VERSION=18
ARG PYTHON_VERSION=3.11
ARG GO_VERSION=1.21

# Node.js example with npm cache mounts
FROM node:${NODE_VERSION}-alpine AS node-cache-demo

WORKDIR /app

# Cache mount for npm global cache
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install -g npm@latest

# Copy package files
COPY package*.json ./

# Install dependencies with persistent cache
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    --mount=type=cache,target=node_modules/.cache,sharing=locked \
    npm ci --prefer-offline

# Copy source and build with cache
COPY . .

# Build with persistent cache for build artifacts
RUN --mount=type=cache,target=/app/.next/cache,sharing=locked \
    --mount=type=cache,target=/root/.npm,sharing=locked \
    npm run build

# Python example with pip cache mounts
FROM python:${PYTHON_VERSION}-alpine AS python-cache-demo

WORKDIR /app

# Install system dependencies with apk cache
RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    --mount=type=cache,target=/var/lib/apk,sharing=locked \
    apk add --no-cache \
        gcc \
        musl-dev \
        libffi-dev \
        openssl-dev

# Copy requirements
COPY requirements.txt ./

# Install Python packages with pip cache
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    pip install --upgrade pip && \
    pip install -r requirements.txt

# Alternative: More granular pip cache with wheel cache
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    --mount=type=cache,target=/tmp/pip-build-cache,sharing=locked \
    pip install --cache-dir /root/.cache/pip \
                --build /tmp/pip-build-cache \
                -r requirements.txt

# Go example with module cache mounts
FROM golang:${GO_VERSION}-alpine AS go-cache-demo

WORKDIR /src

# Install dependencies with apk cache
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache git ca-certificates

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies with module cache
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    go mod download

# Copy source code
COPY . .

# Build with build and module cache
RUN --mount=type=cache,target=/go/pkg/mod,sharing=locked \
    --mount=type=cache,target=/root/.cache/go-build,sharing=locked \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

# Multi-language build with shared cache mounts
FROM alpine:3.18 AS multi-lang-cache

# Install multiple package managers
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
        nodejs npm \
        python3 py3-pip \
        go \
        curl \
        git

WORKDIR /app

# Node.js dependencies with cache
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Python dependencies with cache
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install -r requirements.txt

# Go dependencies with cache
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Advanced cache mounting techniques
FROM ubuntu:22.04 AS advanced-cache-demo

# Multiple cache mounts with different sharing modes
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        build-essential \
        curl \
        git

# Cache mount with specific UID/GID (for non-root user)
RUN groupadd -g 1001 nodejs && \
    useradd -r -u 1001 -g nodejs nodejs

USER nodejs
WORKDIR /home/nodejs

# Cache with user ownership
RUN --mount=type=cache,target=/home/nodejs/.cache,uid=1001,gid=1001,sharing=private \
    mkdir -p /home/nodejs/.cache && \
    echo "User-specific cache initialized"

# Cache mount with size limits
USER root
RUN --mount=type=cache,target=/tmp/large-cache,size=1GB,sharing=locked \
    echo "Cache with 1GB size limit"

# Conditional cache mounts
ARG ENABLE_CACHE=true
RUN --mount=type=cache,target=/var/cache/conditional,sharing=locked \
    if [ "$ENABLE_CACHE" = "true" ]; then \
        echo "Cache enabled" > /var/cache/conditional/status; \
    else \
        echo "Cache disabled"; \
    fi

# Cache mount for temporary build files
FROM alpine:3.18 AS temp-cache-demo

WORKDIR /build

# Use cache for temporary compilation files
COPY <<EOF compile.sh
#!/bin/sh
set -e
echo "Compiling large project..."
# Simulate large compilation that benefits from cache
mkdir -p /tmp/build-cache/objects
touch /tmp/build-cache/objects/file{1..100}.o
echo "Compilation complete"
EOF

RUN chmod +x compile.sh

# Mount cache for build objects
RUN --mount=type=cache,target=/tmp/build-cache,sharing=locked \
    ./compile.sh

# Database/service cache example
FROM postgres:15-alpine AS db-cache-demo

# Cache for database initialization files
RUN --mount=type=cache,target=/var/lib/postgresql/cache,sharing=private \
    --mount=type=cache,target=/tmp/pg-build,sharing=locked \
    mkdir -p /var/lib/postgresql/cache && \
    echo "Database cache initialized"

# Web server cache example  
FROM nginx:alpine AS web-cache-demo

# Cache for web assets compilation
RUN --mount=type=cache,target=/var/cache/nginx,sharing=locked \
    --mount=type=cache,target=/tmp/web-build,sharing=locked \
    mkdir -p /var/cache/nginx/assets && \
    echo "Web cache initialized"

# Final optimized build example
FROM node:${NODE_VERSION}-alpine AS final-optimized

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

# System dependencies with cache
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache libc6-compat

# Switch to non-root user
USER nextjs

# Copy package files
COPY --chown=nextjs:nodejs package*.json ./

# Install dependencies with user-specific cache
RUN --mount=type=cache,target=/home/nextjs/.npm,uid=1001,gid=1001 \
    npm ci --only=production

# Copy application code
COPY --chown=nextjs:nodejs . .

# Build application with cache
RUN --mount=type=cache,target=/app/.next/cache,uid=1001,gid=1001 \
    --mount=type=cache,target=/home/nextjs/.npm,uid=1001,gid=1001 \
    npm run build

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

CMD ["npm", "start"]

# Build instructions with cache optimization:
#
# Basic build with cache:
# DOCKER_BUILDKIT=1 docker build -f cache-mounts.Dockerfile .
#
# Build with specific target:
# docker build --target node-cache-demo -f cache-mounts.Dockerfile .
#
# Build with cache export/import:
# docker build --cache-from type=registry,ref=myapp:cache \
#              --cache-to type=registry,ref=myapp:cache,mode=max \
#              -f cache-mounts.Dockerfile .
#
# Multi-platform build with shared cache:
# docker buildx build --platform linux/amd64,linux/arm64 \
#                     --cache-from type=registry,ref=myapp:cache \
#                     --cache-to type=registry,ref=myapp:cache,mode=max \
#                     -f cache-mounts.Dockerfile .
#
# Build with inline cache:
# docker build --cache-from myapp:latest \
#              --build-arg BUILDKIT_INLINE_CACHE=1 \
#              -t myapp:latest \
#              -f cache-mounts.Dockerfile .

# Cache mount best practices:
# 1. Use sharing=locked for concurrent builds
# 2. Set appropriate uid/gid for user-specific caches
# 3. Use size limits for large caches
# 4. Combine multiple package manager caches
# 5. Cache build artifacts and intermediate files
# 6. Use separate cache mounts for different build stages