# File Location: labs/lab_04_logging_dashboard/logstash/Dockerfile

FROM docker.elastic.co/logstash/logstash:8.11.0

# Install additional plugins
RUN bin/logstash-plugin install logstash-input-beats
RUN bin/logstash-plugin install logstash-filter-json
RUN bin/logstash-plugin install logstash-filter-grok
RUN bin/logstash-plugin install logstash-filter-mutate
RUN bin/logstash-plugin install logstash-output-elasticsearch

# Copy custom configuration
COPY logstash.yml /usr/share/logstash/config/logstash.yml
COPY pipelines/ /usr/share/logstash/pipeline/

# Create necessary directories
USER root
RUN mkdir -p /usr/share/logstash/pipeline \
    && mkdir -p /usr/share/logstash/data \
    && mkdir -p /var/log/logstash \
    && chown -R logstash:logstash /usr/share/logstash/pipeline \
    && chown -R logstash:logstash /usr/share/logstash/data \
    && chown -R logstash:logstash /var/log/logstash

# Switch back to logstash user
USER logstash

# Set JVM heap size for development
ENV LS_JAVA_OPTS="-Xmx1g -Xms1g"

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9600 || exit 1

EXPOSE 5044 9600

# Labels
LABEL maintainer="DockVerseHub" \
      version="8.11.0" \
      description="Logstash with custom pipelines for Lab 04"