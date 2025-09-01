# File Location: labs/lab_04_logging_dashboard/grafana/Dockerfile

FROM grafana/grafana:10.2.0

# Switch to root to install plugins and copy files
USER root

# Install additional plugins
RUN grafana-cli plugins install grafana-clock-panel
RUN grafana-cli plugins install grafana-simple-json-datasource
RUN grafana-cli plugins install grafana-piechart-panel
RUN grafana-cli plugins install grafana-worldmap-panel

# Copy custom configuration
COPY grafana.ini /etc/grafana/grafana.ini
COPY dashboards/ /etc/grafana/provisioning/dashboards/
COPY datasources/ /etc/grafana/provisioning/datasources/

# Create necessary directories
RUN mkdir -p /var/lib/grafana/dashboards \
    && mkdir -p /etc/grafana/provisioning/dashboards \
    && mkdir -p /etc/grafana/provisioning/datasources \
    && mkdir -p /etc/grafana/provisioning/plugins

# Set ownership
RUN chown -R grafana:grafana /var/lib/grafana \
    && chown -R grafana:grafana /etc/grafana

# Switch back to grafana user
USER grafana

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/api/health || exit 1

EXPOSE 3000

# Labels
LABEL maintainer="DockVerseHub" \
      version="10.2.0" \
      description="Grafana with custom dashboards for Lab 04"

# Environment variables
ENV GF_INSTALL_PLUGINS="grafana-clock-panel,grafana-simple-json-datasource"