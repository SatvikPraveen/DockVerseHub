# Location: utilities/Dockerfile.templates/production.Dockerfile
# Production-ready Dockerfile with security hardening

FROM alpine:3.19 AS base

# Install security updates and essential packages
RUN apk update && apk upgrade && \
    apk add --no-cache \
    ca-certificates \
    tzdata \
    tini \
    && rm -rf /var/cache/apk/*

# Build stage
FROM base AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    curl-dev \
    linux-headers

WORKDIR /build

# Copy and build application
COPY . .
RUN make build

# Final production stage
FROM base AS production

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080
ENV USER=appuser
ENV UID=1001
ENV GID=1001

# Create non-root user and group
RUN addgroup -g $GID $USER && \
    adduser -D -u $UID -G $USER -s /bin/sh $USER

# Create application directory
WORKDIR /app

# Copy built application from builder
COPY --from=builder --chown=$USER:$USER /build/dist .
COPY --from=builder --chown=$USER:$USER /build/config ./config

# Set proper permissions
RUN chmod -R 755 /app && \
    chmod -R 644 /app/config

# Remove shell access for security
RUN sed -i 's/sh/nologin/g' /etc/passwd

# Switch to non-root user
USER $USER

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:$PORT/health || exit 1

# Expose port
EXPOSE $PORT

# Use tini as init process
ENTRYPOINT ["/sbin/tini", "--"]

# Start application
CMD ["./app"]