# Lab 04: Complete Observability Stack

**File Location:** `labs/lab_04_logging_dashboard/README.md`

## Overview

Complete logging, monitoring, and observability stack using ELK (Elasticsearch, Logstash, Kibana) + Grafana + Prometheus for comprehensive application monitoring.

## Architecture

```
Application Logs → Logstash → Elasticsearch → Kibana
Application Metrics → Prometheus → Grafana
```

## Services

- **Elasticsearch**: Log storage and search engine
- **Logstash**: Log processing pipeline
- **Kibana**: Log visualization and dashboards
- **Grafana**: Metrics dashboards
- **Prometheus**: Metrics collection
- **Log App**: Sample application generating logs

## Quick Start

```bash
# Start entire stack
docker-compose up -d

# Access dashboards
# Kibana: http://localhost:5601
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090

# Generate sample logs
curl -X POST http://localhost:8080/generate-logs
```

## Dashboard URLs

- **Kibana**: http://localhost:5601
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090
- **Log Generator**: http://localhost:8080

## Sample Log Patterns

The stack captures various log types:

- Application logs (INFO, ERROR, DEBUG)
- HTTP access logs
- System metrics
- Custom business events
- Security events

## Key Features

- **Real-time log streaming**
- **Advanced log parsing**
- **Custom dashboards**
- **Alerting rules**
- **Log retention policies**
- **Performance metrics**

## Monitoring Capabilities

- Application performance
- Error tracking
- User behavior
- System resources
- Business metrics
- Security monitoring
