# Complete Observability Stack - Docker Compose Example

This directory contains a complete, production-like observability setup with Prometheus, Grafana, Jaeger, and an instrumented application.

## Quick Start

```bash
docker-compose up -d
```

Access:
- **Application**: http://localhost:5000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Jaeger**: http://localhost:16686

## Files Included

- `docker-compose.yml`: Complete stack definition
- `prometheus.yml`: Prometheus configuration
- `grafana-dashboard.json`: Pre-built dashboard
- `app/`: Instrumented Python application
- `scripts/`: Helper scripts for demos

## Architecture

```
Application (Flask + OpenTelemetry)
├─ Metrics → Prometheus (9090)
├─ Traces → Jaeger (6831)
└─ Logs → stdout

Visualization
├─ Prometheus → Query metrics
├─ Grafana → Dashboards
└─ Jaeger → Trace visualization
```

