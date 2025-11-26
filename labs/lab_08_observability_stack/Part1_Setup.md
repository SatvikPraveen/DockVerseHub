# Part 1: Setup Complete Observability Stack

## 🎯 Objective

Deploy and verify all observability components are running correctly.

## 📦 Prerequisites Check

```bash
# Verify Docker
docker --version
# Expected: Docker version 20.10+

# Verify Docker Compose
docker-compose --version
# Expected: Docker Compose version 2.0+
```

## 🚀 Deployment

### Step 1: Review Configuration

```bash
cat docker-compose.yml
```

Key services:
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Dashboarding (port 3000)
- **Jaeger**: Tracing (port 16686)
- **API**: Sample application (port 5000)
- **Redis**: Caching backend

### Step 2: Start Services

```bash
# Start all services in background
docker-compose up -d

# Check logs
docker-compose logs -f

# Wait for services (they may take 10-15 seconds)
sleep 15
```

### Step 3: Verify Services Are Running

```bash
# List running containers
docker-compose ps

# Expected output:
# NAME              STATUS
# prometheus        Up X seconds
# grafana           Up X seconds
# jaeger            Up X seconds
# api               Up X seconds
# redis             Up X seconds
```

### Step 4: Test Endpoints

```bash
# Test API health
curl http://localhost:5000/health
# Expected: {"status":"healthy"}

# Test Prometheus
curl http://localhost:9090/-/healthy
# Expected: HTTP 200

# Test Grafana
curl http://localhost:3000/api/health
# Expected: {"commit":"XXX","database":"ok",...}

# Test Jaeger
curl http://localhost:16686/api/services
# Expected: {"data":[],...}
```

## 🌐 Access Services

Open in browser:

1. **Application**: http://localhost:5000
2. **Prometheus**: http://localhost:9090
   - Check targets: Status → Targets
3. **Grafana**: http://localhost:3000
   - Username: admin
   - Password: admin
4. **Jaeger**: http://localhost:16686
   - Service: Select "observability-demo"

## 📊 Generate Initial Data

```bash
# Make some requests to generate metrics
for i in {1..10}; do
  curl http://localhost:5000/api/data
  sleep 1
done

# Check Prometheus has data
curl 'http://localhost:9090/api/v1/query?query=rate(app_requests_total[5m])'
```

## 🧪 Exercise 1: Verify Stack Health

### Task

Create a simple health check script that:
1. Verifies all services are running
2. Checks each endpoint responds
3. Confirms Prometheus is collecting metrics
4. Validates Grafana can reach data sources

### Solution Steps

```bash
#!/bin/bash
# save as: verify-stack.sh

echo "🔍 Verifying observability stack..."

# Check containers
echo "1. Checking containers..."
RUNNING=$(docker-compose ps | grep -c "Up")
echo "   Running: $RUNNING/5"

# Check endpoints
echo "2. Checking endpoints..."
echo -n "   API: "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5000/health

echo -n "   Prometheus: "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9090/-/healthy

echo -n "   Grafana: "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health

# Check metrics exist
echo "3. Checking metrics..."
METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=app_requests_total' | jq '.data.result | length')
echo "   Metrics found: $METRICS"

echo "✅ Stack verification complete"
```

Run it:
```bash
bash verify-stack.sh
```

## 📝 Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :9090

# Kill process or change docker-compose port mapping
```

### Services Not Starting
```bash
# Check logs
docker-compose logs prometheus
docker-compose logs grafana
docker-compose logs jaeger

# Restart service
docker-compose restart prometheus
```

### Memory Issues
```bash
# Reduce docker resource limits in docker-compose.yml
# Or increase Docker desktop memory allocation
```

## ✅ Completion Criteria

- [ ] All 5 services running
- [ ] All endpoints respond with HTTP 200
- [ ] Can access Prometheus targets page
- [ ] Can access Grafana (login admin/admin)
- [ ] Can access Jaeger
- [ ] At least 1 metric visible in Prometheus

---

## Next Steps

Proceed to **Part 2: Prometheus Metrics Collection**

