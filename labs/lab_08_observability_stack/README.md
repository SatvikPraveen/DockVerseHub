# Lab 08: Complete Observability Stack

**Duration:** 4-5 hours | **Level:** Advanced

## 📚 Overview

In this lab, you'll build a complete observability solution for a microservices application. You'll deploy Prometheus, Grafana, Jaeger, and an instrumented multi-service application, then practice monitoring, tracing, and alerting.

## 🎯 Learning Objectives

After completing this lab, you'll be able to:
1. Deploy a complete observability stack with Prometheus, Grafana, Jaeger, and OpenTelemetry
2. Instrument microservices with OpenTelemetry
3. Create Prometheus metrics and recording rules
4. Build Grafana dashboards and alerts
5. Debug applications using distributed traces
6. Implement SLO/SLI monitoring
7. Respond to alerts and incidents

## 📋 Prerequisites

- Docker and Docker Compose
- Basic understanding of microservices
- Knowledge of Module 13 concepts (or review first)
- Terminal/CLI experience

## ⏱️ Estimated Time Breakdown

- Part 1: Setup (15 min)
- Part 2: Explore Prometheus (30 min)
- Part 3: Create Dashboards (45 min)
- Part 4: Debug with Traces (30 min)
- Part 5: Incident Response (45 min)
- Exercises (60 min)

**Total: 4-5 hours**

## 📁 Lab Structure

```
lab_08_observability_stack/
├── README.md (this file)
├── Part1_Setup.md
├── Part2_Prometheus.md
├── Part3_Dashboards.md
├── Part4_Tracing.md
├── Part5_Incidents.md
├── Exercises.md
├── Solutions/
│   ├── dashboard-template.json
│   └── alert-rules.yml
└── docker-compose.yml
```

## 🚀 Quick Start

```bash
# Clone lab
cd labs/lab_08_observability_stack

# Deploy stack
docker-compose up -d

# Wait for services
sleep 30

# Run exercise 1
bash exercises/exercise1.sh
```

## 📊 Services Running

| Service | Port | Purpose |
|---------|------|---------|
| Application API | 5000 | Sample microservice |
| Prometheus | 9090 | Metrics collection |
| Grafana | 3000 | Dashboarding |
| Jaeger | 16686 | Trace visualization |
| Redis | 6379 | Caching (internal) |

## 🎓 What You'll Build

By the end of this lab, you'll have:

1. **Working observability stack** - All 4 tools integrated
2. **Custom dashboards** - Real-time application metrics
3. **Alert rules** - Automated incident detection
4. **Instrumented app** - Sending metrics and traces
5. **Incident response** - Handle real (simulated) failures

## 📖 Lab Sections

1. **Part 1: Setup** - Deploy services
2. **Part 2: Prometheus** - Collect and query metrics
3. **Part 3: Dashboards** - Visualize data in Grafana
4. **Part 4: Tracing** - Debug with Jaeger
5. **Part 5: Incidents** - Respond to failures

---

## Next Steps

Start with **Part 1: Setup**

