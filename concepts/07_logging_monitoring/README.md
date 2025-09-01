# 07_logging_monitoring/README.md

# Centralized Logging & Monitoring with Docker

This lab demonstrates comprehensive logging and monitoring solutions for containerized applications using industry-standard tools like ELK Stack, Prometheus, and Grafana.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │───▶│    Logstash     │───▶│  Elasticsearch  │
│   Containers    │    │   (Processor)   │    │   (Storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                              │
         ▼                                              ▼
┌─────────────────┐                          ┌─────────────────┐
│   Prometheus    │                          │     Kibana      │
│   (Metrics)     │                          │ (Visualization) │
└─────────────────┘                          └─────────────────┘
         │
         ▼
┌─────────────────┐
│     Grafana     │
│  (Dashboards)   │
└─────────────────┘
```

## Quick Start

1. **Start the complete stack:**

   ```bash
   docker-compose up -d
   ```

2. **Access services:**

   - Kibana: http://localhost:5601
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - Sample App: http://localhost:8080

3. **Generate logs:**
   ```bash
   # The sample app will automatically generate logs
   curl http://localhost:8080/api/logs
   ```

## Components

### ELK Stack (Elasticsearch, Logstash, Kibana)

- **Elasticsearch**: Stores and indexes logs
- **Logstash**: Processes and transforms logs
- **Kibana**: Visualizes logs and creates dashboards

### Monitoring Stack

- **Prometheus**: Collects metrics from containers
- **Grafana**: Creates monitoring dashboards
- **AlertManager**: Handles alerting rules
- **Node Exporter**: System metrics collection

### Log Drivers

Examples of different Docker logging drivers:

- `json-file`: Default JSON logging
- `syslog`: System log integration
- `fluentd`: Fluentd log forwarding
- `gelf`: Graylog Extended Log Format

## Key Features

1. **Centralized Log Collection**: All container logs in one place
2. **Real-time Monitoring**: Live metrics and dashboards
3. **Alerting**: Automated alerts for anomalies
4. **Log Processing**: Transform and enrich log data
5. **Visualization**: Rich dashboards and charts

## Learning Objectives

- Implement centralized logging for microservices
- Set up monitoring and alerting
- Configure different logging drivers
- Create custom dashboards
- Process and analyze log data
- Implement log retention policies

## Best Practices Demonstrated

- Structured logging with JSON format
- Log rotation and retention
- Resource-efficient log processing
- Security considerations for log data
- Performance optimization for high-volume logs
