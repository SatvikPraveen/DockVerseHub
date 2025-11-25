# File Location: labs/lab_02_multi_container_compose/db/Dockerfile

FROM postgres:15-alpine

# Install additional packages
RUN apk add --no-cache \
    curl \
    postgresql-contrib

# Create directory for custom scripts
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy initialization scripts
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

# Create necessary directories
RUN mkdir -p /migrations /etc/postgresql

# Set permissions
RUN chmod +x /docker-entrypoint-initdb.d/*.sql

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} || exit 1

# Expose port
EXPOSE 5432

# Labels
LABEL maintainer="DockVerseHub"
LABEL version="1.0"
LABEL description="PostgreSQL database with custom configuration"