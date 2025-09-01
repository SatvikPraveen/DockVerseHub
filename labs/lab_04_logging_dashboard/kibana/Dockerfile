# File Location: labs/lab_04_logging_dashboard/kibana/Dockerfile

FROM docker.elastic.co/kibana/kibana:8.11.0

# Copy custom configuration
COPY kibana.yml /usr/share/kibana/config/kibana.yml

# Copy custom dashboards
COPY dashboards/ /usr/share/kibana/dashboards/

# Install additional plugins (if needed)
# RUN bin/kibana-plugin install plugin-name

# Create necessary directories
USER root
RUN mkdir -p /usr/share/kibana/dashboards \
    && mkdir -p /usr/share/kibana/config/certs \
    && chown -R kibana:kibana /usr/share/kibana/dashboards \
    && chown -R kibana:kibana /usr/share/kibana/config

# Switch back to kibana user
USER kibana

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:5601/api/status || exit 1

EXPOSE 5601

# Labels
LABEL maintainer="DockVerseHub" \
      version="8.11.0" \
      description="Kibana with custom dashboards for Lab 04"

# Set environment variables
ENV NODE_OPTIONS="--max-old-space-size=1800"