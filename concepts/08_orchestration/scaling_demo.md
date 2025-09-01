# 08_orchestration/scaling_demo.md

# Scaling Services Demo

This guide demonstrates how to scale services up and down in a Docker Swarm cluster, including monitoring the effects and understanding load distribution.

## Prerequisites

- Docker Swarm cluster initialized
- Demo stack deployed (`docker stack deploy -c docker-compose.yml demo-app`)

## Basic Scaling Operations

### 1. Check Current Service Status

```bash
# View all services
docker service ls

# View specific service details
docker service ps demo-app_web

# View service configuration
docker service inspect demo-app_web --pretty
```

### 2. Scale Web Service

```bash
# Scale web service to 5 replicas
docker service scale demo-app_web=5

# Alternative syntax
docker service update --replicas 5 demo-app_web

# Scale multiple services at once
docker service scale demo-app_web=5 demo-app_api=3
```

### 3. Monitor Scaling Progress

```bash
# Watch service scaling in real-time
watch docker service ps demo-app_web

# View service logs during scaling
docker service logs -f demo-app_web

# Check resource usage
docker stats $(docker ps -q --filter "name=demo-app_web")
```

## Advanced Scaling Scenarios

### Horizontal Scaling with Load Testing

```bash
# Generate load to demonstrate auto-scaling needs
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Generate concurrent requests
hey -n 10000 -c 100 http://localhost/

# Monitor service performance during load
docker service ps demo-app_web
docker service logs demo-app_web --tail 50
```

### Rolling Updates During Scaling

```bash
# Update service with rolling deployment
docker service update \
  --image nginx:1.21-alpine \
  --update-parallelism 2 \
  --update-delay 10s \
  demo-app_web

# Monitor rolling update progress
docker service ps demo-app_web
```

### Resource-Constrained Scaling

```bash
# Scale with resource limits
docker service update \
  --replicas 8 \
  --limit-cpu 0.5 \
  --limit-memory 128M \
  --reserve-cpu 0.25 \
  --reserve-memory 64M \
  demo-app_web
```

## Placement Strategies

### 1. Spread Across Availability Zones

```bash
# Add zone labels to nodes
docker node update --label-add zone=zone1 node1
docker node update --label-add zone=zone2 node2
docker node update --label-add zone=zone3 node3

# Update service with zone spreading
docker service update \
  --placement-pref 'spread=node.labels.zone' \
  demo-app_web
```

### 2. Node Constraints

```bash
# Scale only on worker nodes
docker service update \
  --constraint-add 'node.role==worker' \
  --replicas 6 \
  demo-app_web

# Scale on nodes with SSD storage
docker service update \
  --constraint-add 'node.labels.storage==ssd' \
  --replicas 4 \
  demo-app_api
```

## Monitoring and Observability

### Service Health Monitoring

```bash
# Check service health status
docker service ps demo-app_web --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}"

# View detailed service events
docker service ps demo-app_web --no-trunc

# Monitor cluster-wide resource usage
docker node ls
docker system df
```

### Load Balancing Verification

```bash
# Test load distribution across replicas
for i in {1..20}; do
  curl -s http://localhost/api/info | jq '.hostname'
  sleep 0.5
done

# Check connection distribution
docker service logs demo-app_web | grep -E "GET|POST" | tail -20
```

## Scaling Patterns

### 1. Scheduled Scaling

Create a cron job for predictable load patterns:

```bash
# Scale up during business hours (8 AM)
0 8 * * 1-5 docker service scale demo-app_web=10

# Scale down after hours (6 PM)
0 18 * * 1-5 docker service scale demo-app_web=3
```

### 2. Event-Driven Scaling

```bash
# Scale based on queue length (example script)
#!/bin/bash
QUEUE_LENGTH=$(redis-cli -h redis-host LLEN work_queue)

if [ $QUEUE_LENGTH -gt 100 ]; then
    docker service scale demo-app_worker=10
elif [ $QUEUE_LENGTH -lt 10 ]; then
    docker service scale demo-app_worker=2
fi
```

### 3. Metric-Based Scaling

```bash
# Scale based on CPU usage (requires monitoring stack)
#!/bin/bash
AVG_CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" | sed 's/%//' | awk '{sum+=$1} END {print sum/NR}')

if (( $(echo "$AVG_CPU > 80" | bc -l) )); then
    CURRENT_REPLICAS=$(docker service inspect demo-app_web --format='{{.Spec.Mode.Replicated.Replicas}}')
    NEW_REPLICAS=$((CURRENT_REPLICAS + 2))
    docker service scale demo-app_web=$NEW_REPLICAS
fi
```

## Scaling Best Practices

### 1. Gradual Scaling

```bash
# Scale gradually to avoid overwhelming the system
scale_gradually() {
    local service=$1
    local target=$2
    local current=$(docker service inspect $service --format='{{.Spec.Mode.Replicated.Replicas}}')

    while [ $current -lt $target ]; do
        current=$((current + 1))
        docker service scale $service=$current
        echo "Scaled to $current replicas, waiting..."
        sleep 10
    done
}

scale_gradually demo-app_web 10
```

### 2. Health Check Validation

```bash
# Verify all replicas are healthy before considering scaling complete
check_service_health() {
    local service=$1
    local expected_replicas=$2

    while true; do
        running=$(docker service ps $service --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running")
        if [ $running -eq $expected_replicas ]; then
            echo "All $expected_replicas replicas are healthy"
            break
        fi
        echo "Waiting for replicas to become healthy ($running/$expected_replicas)"
        sleep 5
    done
}

docker service scale demo-app_web=5
check_service_health demo-app_web 5
```

### 3. Rollback on Failure

```bash
# Scale with automatic rollback on failure
safe_scale() {
    local service=$1
    local new_replicas=$2
    local old_replicas=$(docker service inspect $service --format='{{.Spec.Mode.Replicated.Replicas}}')

    docker service scale $service=$new_replicas

    # Wait and check if scaling was successful
    sleep 30

    healthy=$(docker service ps $service --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running")

    if [ $healthy -lt $new_replicas ]; then
        echo "Scaling failed, rolling back to $old_replicas replicas"
        docker service scale $service=$old_replicas
        return 1
    fi

    echo "Scaling successful: $new_replicas healthy replicas"
    return 0
}

safe_scale demo-app_web 8
```

## Troubleshooting Scaling Issues

### Common Problems and Solutions

1. **Insufficient Resources**

   ```bash
   # Check node resources
   docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}"

   # Check resource constraints
   docker service inspect demo-app_web --format='{{json .Spec.TaskTemplate.Resources}}'
   ```

2. **Placement Constraints**

   ```bash
   # Check placement constraints
   docker service inspect demo-app_web --format='{{json .Spec.TaskTemplate.Placement}}'

   # Remove constraints if needed
   docker service update --constraint-rm 'node.labels.storage==ssd' demo-app_web
   ```

3. **Network Issues**

   ```bash
   # Check network connectivity
   docker network ls
   docker service inspect demo-app_web --format='{{json .Spec.TaskTemplate.Networks}}'

   # Test service discovery
   docker exec -it $(docker ps -q --filter "name=demo-app_web" | head -1) nslookup demo-app_api
   ```

## Performance Metrics

Monitor these key metrics during scaling:

- **Response Time**: Track latency changes as replicas scale
- **Throughput**: Measure requests per second capacity
- **Resource Utilization**: Monitor CPU, memory, and network usage
- **Error Rate**: Watch for increases in 5xx errors during scaling
- **Load Distribution**: Ensure even traffic distribution across replicas

## Cleanup

```bash
# Scale down services
docker service scale demo-app_web=1 demo-app_api=1

# Remove the entire stack
docker stack rm demo-app

# Verify cleanup
docker service ls
docker container ls
```
