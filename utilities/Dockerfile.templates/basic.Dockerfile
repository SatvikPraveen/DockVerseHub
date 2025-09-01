# Location: utilities/Dockerfile.templates/basic.Dockerfile
# Basic Dockerfile template for simple applications

FROM ubuntu:22.04

# Install essential packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Create non-root user
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8080

# Default command
CMD ["echo", "Hello from basic Docker container"]