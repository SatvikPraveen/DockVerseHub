# File Location: labs/lab_04_logging_dashboard/elasticsearch/Dockerfile

FROM docker.elastic.co/elasticsearch/elasticsearch:8.11.0

# Install additional plugins
RUN bin/elasticsearch-plugin install --batch analysis-icu
RUN bin/elasticsearch-plugin install --batch ingest-attachment

# Copy custom configuration
COPY elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY index-templates/ /usr/share/elasticsearch/config/index-templates/

# Create custom directories
USER root
RUN mkdir -p /usr/share/elasticsearch/config/certs \
    && mkdir -p /usr/share/elasticsearch/config/index-templates \
    && chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/config

# Switch back to elasticsearch user
USER elasticsearch

# Set JVM options for development
ENV ES_JAVA_OPTS="-Xms1g -Xmx1g"

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9200/_cluster/health || exit 1

EXPOSE 9200 9300

# Labels
LABEL maintainer="DockVerseHub" \
      version="8.11.0" \
      description="Elasticsearch with custom configuration for Lab 04"