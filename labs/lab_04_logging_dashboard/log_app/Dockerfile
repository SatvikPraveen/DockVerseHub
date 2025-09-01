# File Location: labs/lab_04_logging_dashboard/log_app/Dockerfile

FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY log_generator.py .

# Create logs directory
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Environment variables
ENV LOG_LEVEL=INFO
ENV METRICS_PORT=8081
ENV PYTHONUNBUFFERED=1

# Labels
LABEL maintainer="DockVerseHub" \
      version="1.0" \
      description="Log generation application for Lab 04"

# Run the application
CMD ["python", "app.py"]