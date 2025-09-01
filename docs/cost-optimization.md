# Cost Optimization: Resource Efficiency & Management

**Location: `docs/cost-optimization.md`**

## Cost Optimization Overview

Docker cost optimization focuses on efficient resource utilization, smart infrastructure choices, and automated management to reduce operational expenses while maintaining performance and reliability.

## Resource Optimization

### Right-Sizing Containers

```yaml
# Before: Over-provisioned
version: '3.8'
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          memory: 2G      # Too much
          cpus: '2.0'     # Too much
        reservations:
          memory: 1G
          cpus: '1.0'

# After: Right-sized
version: '3.8'
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          memory: 512M    # Appropriate
          cpus: '0.5'     # Appropriate
        reservations:
          memory: 256M
          cpus: '0.25'
```

### Resource Monitoring Script

```bash
#!/bin/bash
# resource-analysis.sh - Analyze container resource usage

echo "=== Container Resource Analysis ==="
echo "Date: $(date)"
echo

# Get resource usage stats
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" > /tmp/resource_stats.txt

# Analyze over-provisioned containers
echo "=== Over-Provisioned Analysis ==="
while IFS=$'\t' read -r name cpu mem_usage mem_perc net_io block_io; do
    if [[ "$cpu" =~ ^[0-9]+\.[0-9]+% ]]; then
        cpu_num=$(echo $cpu | sed 's/%//')
        mem_perc_num=$(echo $mem_perc | sed 's/%//')

        # Check if resources are under-utilized
        if (( $(echo "$cpu_num < 20" | bc -l) )) && (( $(echo "$mem_perc_num < 40" | bc -l) )); then
            echo "🔍 $name: CPU: $cpu, Memory: $mem_perc (Consider downsizing)"
        fi
    fi
done < <(tail -n +2 /tmp/resource_stats.txt)

# Generate sizing recommendations
echo
echo "=== Sizing Recommendations ==="
docker stats --no-stream --format "{{.Name}}\t{{.MemUsage}}" | while IFS=$'\t' read -r name usage; do
    if [[ "$usage" =~ ([0-9.]+)([MG])iB ]]; then
        value=${BASH_REMATCH[1]}
        unit=${BASH_REMATCH[2]}

        if [ "$unit" = "M" ]; then
            recommended=$((${value%.*} + 100))
            echo "$name: Current ~${value}MiB, Recommend limit: ${recommended}M"
        elif [ "$unit" = "G" ]; then
            recommended=$(echo "$value + 0.2" | bc)
            echo "$name: Current ~${value}GiB, Recommend limit: ${recommended}G"
        fi
    fi
done
```

### Vertical Pod Autoscaling (VPA) for Kubernetes

```yaml
# vpa-recommendation.yml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Off" # Recommendation only
  resourcePolicy:
    containerPolicies:
      - containerName: app
        maxAllowed:
          cpu: 1
          memory: 1Gi
        minAllowed:
          cpu: 100m
          memory: 128Mi
```

## Image Optimization

### Multi-Stage Build Optimization

```dockerfile
# Cost-optimized Dockerfile
FROM node:16-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --production

FROM node:16-alpine AS runtime
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

# Copy only necessary files
COPY --from=dependencies --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --chown=nextjs:nodejs package.json ./

USER nextjs
EXPOSE 3000
CMD ["node", "dist/server.js"]

# Final image: ~80MB vs 300MB+ without optimization
```

### Image Size Analysis

```bash
#!/bin/bash
# image-cost-analysis.sh

echo "=== Docker Image Cost Analysis ==="

# Analyze image sizes
echo "Image Size Analysis:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
    sort -k3 -hr | head -20

echo
echo "=== Cost Optimization Opportunities ==="

# Find large images
docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | \
    grep -E '[0-9]+\.?[0-9]*GB|[5-9][0-9][0-9]MB|[0-9]{4,}MB' | \
    while IFS=$'\t' read -r image size; do
        echo "🔍 Large image: $image ($size) - Consider optimization"
    done

# Analyze layer efficiency
echo
echo "=== Layer Analysis ==="
for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | head -5); do
    echo "Analyzing $image:"
    docker history $image --format "table {{.Size}}\t{{.CreatedBy}}" | head -10
    echo
done
```

### Image Registry Costs

```python
#!/usr/bin/env python3
# registry-cost-calculator.py

import requests
import json
from datetime import datetime, timedelta

def calculate_registry_costs():
    """Calculate Docker registry storage costs"""

    # Docker Hub pricing (example)
    docker_hub_pricing = {
        'free_tier_gb': 0.5,
        'team_cost_per_gb': 0.50,  # USD per GB per month
        'pro_cost_per_gb': 0.50
    }

    # AWS ECR pricing
    ecr_pricing = {
        'storage_per_gb': 0.10,  # USD per GB per month
        'data_transfer_out': 0.09  # USD per GB
    }

    # Example usage calculation
    total_image_size_gb = 25.6
    monthly_pulls_gb = 100.5

    print("=== Registry Cost Analysis ===")
    print(f"Total stored images: {total_image_size_gb:.1f} GB")
    print(f"Monthly data transfer: {monthly_pulls_gb:.1f} GB")
    print()

    # Docker Hub costs
    if total_image_size_gb > docker_hub_pricing['free_tier_gb']:
        excess_gb = total_image_size_gb - docker_hub_pricing['free_tier_gb']
        docker_hub_cost = excess_gb * docker_hub_pricing['team_cost_per_gb']
        print(f"Docker Hub (Team): ${docker_hub_cost:.2f}/month")
    else:
        print("Docker Hub (Free): $0.00/month")

    # AWS ECR costs
    ecr_storage_cost = total_image_size_gb * ecr_pricing['storage_per_gb']
    ecr_transfer_cost = monthly_pulls_gb * ecr_pricing['data_transfer_out']
    ecr_total = ecr_storage_cost + ecr_transfer_cost

    print(f"AWS ECR Storage: ${ecr_storage_cost:.2f}/month")
    print(f"AWS ECR Transfer: ${ecr_transfer_cost:.2f}/month")
    print(f"AWS ECR Total: ${ecr_total:.2f}/month")

    # Recommendations
    print("\n=== Cost Optimization Recommendations ===")
    if total_image_size_gb > 10:
        print("• Consider image cleanup policies")
        print("• Implement multi-stage builds")
        print("• Use minimal base images (alpine, distroless)")

    if monthly_pulls_gb > 50:
        print("• Implement image caching strategies")
        print("• Consider regional registries")
        print("• Use image pull policies effectively")

if __name__ == "__main__":
    calculate_registry_costs()
```

## Infrastructure Optimization

### Spot Instances and Preemptible VMs

```yaml
# spot-instance-compose.yml
version: "3.8"
services:
  # Critical services on regular instances
  database:
    image: postgres:13
    deploy:
      placement:
        constraints:
          - node.labels.instance-type == regular
      restart_policy:
        condition: on-failure

  # Batch processing on spot instances
  worker:
    image: myapp-worker:latest
    deploy:
      replicas: 5
      placement:
        constraints:
          - node.labels.instance-type == spot
      restart_policy:
        condition: any
        max_attempts: 10
```

### Resource Scheduling

```python
#!/usr/bin/env python3
# cost-aware-scheduler.py

import docker
import time
from datetime import datetime

class CostAwareScheduler:
    def __init__(self):
        self.client = docker.from_env()

        # Define cost tiers (example rates)
        self.node_costs = {
            'premium': 0.10,    # $/hour
            'standard': 0.05,   # $/hour
            'spot': 0.02,       # $/hour
        }

    def get_cheapest_nodes(self, required_resources):
        """Find cheapest nodes that meet requirements"""
        nodes = self.client.api.nodes()
        suitable_nodes = []

        for node in nodes:
            node_type = node['Spec']['Labels'].get('cost-tier', 'standard')
            node_resources = node['Status']['Resources']

            # Check if node can handle requirements
            if (node_resources['MemoryBytes'] >= required_resources.get('memory', 0) and
                node_resources['NanoCPUs'] >= required_resources.get('cpu', 0)):

                suitable_nodes.append({
                    'id': node['ID'],
                    'type': node_type,
                    'cost_per_hour': self.node_costs.get(node_type, 0.05)
                })

        # Sort by cost
        return sorted(suitable_nodes, key=lambda x: x['cost_per_hour'])

    def schedule_container(self, image, requirements, max_cost_per_hour=0.08):
        """Schedule container on cost-appropriate node"""
        suitable_nodes = self.get_cheapest_nodes(requirements)

        for node in suitable_nodes:
            if node['cost_per_hour'] <= max_cost_per_hour:
                print(f"Scheduling on {node['type']} node (${node['cost_per_hour']}/hour)")

                # Create service with placement constraint
                self.client.services.create(
                    image=image,
                    constraints=[f"node.id == {node['id']}"],
                    resources=docker.types.Resources(
                        mem_limit=requirements.get('memory'),
                        cpu_limit=requirements.get('cpu')
                    )
                )
                return node

        print("No suitable cost-effective nodes found")
        return None

# Usage example
scheduler = CostAwareScheduler()
requirements = {'memory': 512 * 1024 * 1024, 'cpu': 500000000}  # 512MB, 0.5 CPU
scheduler.schedule_container('myapp:latest', requirements)
```

### Auto-Scaling Based on Cost

```yaml
# cost-aware-scaling.yml
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 2
      placement:
        preferences:
          - spread: node.labels.cost-tier
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
    environment:
      - SCALE_DOWN_THRESHOLD=70 # Scale down at 70% resource usage
      - SCALE_UP_THRESHOLD=80 # Scale up at 80% resource usage
      - MAX_COST_PER_HOUR=0.50 # Don't exceed $0.50/hour total
```

## Storage Optimization

### Volume Cost Management

```bash
#!/bin/bash
# volume-cost-optimizer.sh

echo "=== Volume Cost Optimization ==="

# Analyze volume usage
echo "Volume Usage Analysis:"
docker system df -v | grep -A 20 "Local Volumes:" | \
    awk '/^[a-f0-9]/ {print $1, $2}' | \
    sort -k2 -hr | \
    while read volume size; do
        if [[ "$size" =~ ([0-9.]+)([MG])B ]]; then
            value=${BASH_REMATCH[1]}
            unit=${BASH_REMATCH[2]}

            if [ "$unit" = "G" ] && (( $(echo "$value > 5" | bc -l) )); then
                echo "🔍 Large volume: $volume ($size)"

                # Check if volume is in use
                containers=$(docker ps -a --filter volume=$volume --format "{{.Names}}")
                if [ -z "$containers" ]; then
                    echo "  ❌ Unused - Consider removal"
                else
                    echo "  ✅ In use by: $containers"
                fi
            fi
        fi
    done

# Find duplicate data
echo
echo "=== Duplicate Volume Detection ==="
# This would require more sophisticated analysis
# but the concept is to identify similar data patterns
```

### Storage Tiering Strategy

```yaml
# storage-tiers.yml
version: "3.8"
services:
  database:
    image: postgres:13
    volumes:
      # Hot data - SSD storage
      - type: volume
        source: db_hot
        target: /var/lib/postgresql/data
        volume:
          driver: local
          driver_opts:
            type: none
            o: bind
            device: /mnt/ssd/postgres

  analytics:
    image: analytics-app:latest
    volumes:
      # Cold data - cheaper HDD storage
      - type: volume
        source: analytics_data
        target: /data
        volume:
          driver: local
          driver_opts:
            type: none
            o: bind
            device: /mnt/hdd/analytics

volumes:
  db_hot:
    external: true
  analytics_data:
    external: true
```

## Network Cost Optimization

### Bandwidth Optimization

```yaml
# bandwidth-optimized-compose.yml
version: "3.8"
services:
  app:
    image: myapp:latest
    networks:
      - app-network
    deploy:
      placement:
        constraints:
          - node.labels.region == primary # Keep traffic local

  cache:
    image: redis:alpine
    networks:
      - app-network
    deploy:
      placement:
        constraints:
          - node.labels.region == primary # Co-locate with app

  cdn:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - static_assets:/usr/share/nginx/html
    deploy:
      placement:
        preferences:
          - spread: node.labels.region # Distribute CDN

networks:
  app-network:
    driver: overlay
    driver_opts:
      encrypted: "false" # Reduce CPU overhead for internal traffic

volumes:
  static_assets:
```

### Data Transfer Cost Calculator

```python
#!/usr/bin/env python3
# network-cost-calculator.py

def calculate_data_transfer_costs():
    """Calculate network data transfer costs"""

    # Cloud provider pricing (example)
    aws_pricing = {
        'outbound_first_gb': 0,        # Free tier
        'outbound_next_9999_gb': 0.09,  # Per GB
        'outbound_next_40000_gb': 0.085, # Per GB
        'inbound': 0,                   # Usually free
    }

    azure_pricing = {
        'outbound_first_5gb': 0,        # Free tier
        'outbound_next_10000gb': 0.087,  # Per GB
        'inbound': 0,
    }

    # Example usage
    monthly_outbound_gb = 2500
    monthly_inbound_gb = 1000

    print("=== Network Cost Analysis ===")
    print(f"Monthly outbound: {monthly_outbound_gb} GB")
    print(f"Monthly inbound: {monthly_inbound_gb} GB")
    print()

    # AWS calculation
    aws_cost = 0
    if monthly_outbound_gb > 1:
        billable_gb = monthly_outbound_gb - 1  # First GB free
        aws_cost = min(billable_gb, 9999) * aws_pricing['outbound_next_9999_gb']
        if billable_gb > 9999:
            aws_cost += (billable_gb - 9999) * aws_pricing['outbound_next_40000_gb']

    # Azure calculation
    azure_cost = 0
    if monthly_outbound_gb > 5:
        billable_gb = monthly_outbound_gb - 5  # First 5GB free
        azure_cost = billable_gb * azure_pricing['outbound_next_10000gb']

    print(f"Azure data transfer cost: ${azure_cost:.2f}/month")

    # Optimization recommendations
    print("\n=== Network Cost Optimization ===")
    if monthly_outbound_gb > 1000:
        print("• Consider CDN for static assets")
        print("• Implement data compression")
        print("• Use regional data centers")

    if monthly_inbound_gb > 500:
        print("• Optimize API payload sizes")
        print("• Implement request caching")

if __name__ == "__main__":
    calculate_data_transfer_costs()
```

## Container Orchestration Cost Management

### Cost-Aware Scheduling

```python
#!/usr/bin/env python3
# cost-scheduler.py

import json
import subprocess
from datetime import datetime

class CostOptimizedScheduler:
    def __init__(self):
        self.node_costs = self._load_node_costs()

    def _load_node_costs(self):
        """Load current node costs from cloud provider APIs"""
        return {
            'c5.large': {'cost_per_hour': 0.096, 'cpu': 2, 'memory': 4096},
            't3.medium': {'cost_per_hour': 0.0416, 'cpu': 2, 'memory': 4096},
            't3.micro': {'cost_per_hour': 0.0104, 'cpu': 2, 'memory': 1024},
        }

    def find_cheapest_suitable_node(self, requirements):
        """Find cheapest node that meets requirements"""
        suitable_nodes = []

        for node_type, specs in self.node_costs.items():
            if (specs['cpu'] >= requirements['cpu'] and
                specs['memory'] >= requirements['memory']):

                cost_efficiency = specs['cost_per_hour'] / (specs['cpu'] + specs['memory']/1024)
                suitable_nodes.append({
                    'type': node_type,
                    'cost_per_hour': specs['cost_per_hour'],
                    'efficiency': cost_efficiency
                })

        return sorted(suitable_nodes, key=lambda x: x['efficiency'])

    def estimate_monthly_cost(self, containers):
        """Estimate monthly costs for container workloads"""
        total_cost = 0

        for container in containers:
            best_nodes = self.find_cheapest_suitable_node(container['requirements'])
            if best_nodes:
                hourly_cost = best_nodes[0]['cost_per_hour']
                monthly_cost = hourly_cost * 24 * 30 * container.get('replicas', 1)
                total_cost += monthly_cost

                print(f"Container: {container['name']}")
                print(f"  Best node: {best_nodes[0]['type']}")
                print(f"  Monthly cost: ${monthly_cost:.2f}")

        print(f"\nTotal estimated monthly cost: ${total_cost:.2f}")
        return total_cost

# Usage example
scheduler = CostOptimizedScheduler()
containers = [
    {
        'name': 'web-app',
        'requirements': {'cpu': 1, 'memory': 2048},
        'replicas': 3
    },
    {
        'name': 'worker',
        'requirements': {'cpu': 2, 'memory': 4096},
        'replicas': 2
    }
]

scheduler.estimate_monthly_cost(containers)
```

### Resource Pool Management

```yaml
# resource-pools.yml
version: "3.8"
services:
  # Production pool - guaranteed resources
  web-prod:
    image: myapp:latest
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.labels.pool == production
          - node.labels.instance-type == on-demand
      resources:
        limits:
          memory: 512M
          cpus: "0.5"
        reservations:
          memory: 256M
          cpus: "0.25"

  # Development pool - burstable/spot instances
  web-dev:
    image: myapp:dev
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.pool == development
          - node.labels.instance-type == spot
      resources:
        limits:
          memory: 256M
          cpus: "0.25"

  # Batch pool - preemptible instances
  batch-jobs:
    image: batch-processor:latest
    deploy:
      replicas: 5
      placement:
        constraints:
          - node.labels.pool == batch
          - node.labels.instance-type == preemptible
      restart_policy:
        condition: any
        max_attempts: 10
```

## Monitoring and Cost Tracking

### Cost Monitoring Dashboard

```python
#!/usr/bin/env python3
# cost-monitor.py

import docker
import psutil
import json
from datetime import datetime, timedelta

class CostMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.cost_rates = {
            'cpu_hour': 0.02,      # $0.02 per CPU hour
            'memory_gb_hour': 0.01, # $0.01 per GB hour
            'storage_gb_month': 0.05, # $0.05 per GB month
        }

    def calculate_container_costs(self, hours=24):
        """Calculate costs for all running containers"""
        containers = self.client.containers.list()
        total_cost = 0
        cost_breakdown = []

        for container in containers:
            stats = container.stats(stream=False)

            # Extract resource usage
            cpu_usage = self._calculate_cpu_usage(stats)
            memory_usage_gb = stats['memory_stats']['usage'] / (1024**3)

            # Calculate costs
            cpu_cost = cpu_usage * self.cost_rates['cpu_hour'] * hours
            memory_cost = memory_usage_gb * self.cost_rates['memory_gb_hour'] * hours
            container_cost = cpu_cost + memory_cost

            cost_breakdown.append({
                'name': container.name,
                'cpu_cost': cpu_cost,
                'memory_cost': memory_cost,
                'total_cost': container_cost
            })

            total_cost += container_cost

        return {
            'total_cost': total_cost,
            'breakdown': cost_breakdown,
            'period_hours': hours
        }

    def _calculate_cpu_usage(self, stats):
        """Calculate CPU usage from stats"""
        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                   stats['precpu_stats']['cpu_usage']['total_usage']
        system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                      stats['precpu_stats']['system_cpu_usage']

        if system_delta > 0:
            return (cpu_delta / system_delta) * len(stats['cpu_stats']['cpu_usage']['percpu_usage'])
        return 0

    def generate_cost_report(self):
        """Generate comprehensive cost report"""
        daily_costs = self.calculate_container_costs(24)
        monthly_projection = daily_costs['total_cost'] * 30

        print("=== Docker Cost Report ===")
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Daily cost: ${daily_costs['total_cost']:.2f}")
        print(f"Monthly projection: ${monthly_projection:.2f}")
        print()

        print("=== Cost Breakdown by Container ===")
        for container in daily_costs['breakdown']:
            print(f"Container: {container['name']}")
            print(f"  CPU cost: ${container['cpu_cost']:.3f}")
            print(f"  Memory cost: ${container['memory_cost']:.3f}")
            print(f"  Total: ${container['total_cost']:.3f}")
            print()

        # Find most expensive containers
        sorted_containers = sorted(daily_costs['breakdown'],
                                 key=lambda x: x['total_cost'], reverse=True)

        print("=== Top 3 Most Expensive Containers ===")
        for container in sorted_containers[:3]:
            print(f"1. {container['name']}: ${container['total_cost']:.3f}/day")

if __name__ == "__main__":
    monitor = CostMonitor()
    monitor.generate_cost_report()
```

### Automated Cost Alerts

```bash
#!/bin/bash
# cost-alerts.sh

COST_THRESHOLD=50.00  # Daily cost threshold in USD
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Calculate current costs
DAILY_COST=$(python3 cost-monitor.py | grep "Daily cost" | grep -o '\$[0-9.]*' | sed 's/\$//')

# Check if cost exceeds threshold
if (( $(echo "$DAILY_COST > $COST_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 Daily Docker costs exceeded threshold: \${DAILY_COST} > \${COST_THRESHOLD}"

    # Send Slack alert
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$MESSAGE\"}" \
        $WEBHOOK_URL

    # Log alert
    echo "$(date): COST ALERT - $MESSAGE" >> /var/log/docker-costs.log

    # Optional: Scale down non-critical services
    echo "Scaling down non-critical services..."
    docker service scale dev-env_worker=1
    docker service scale test-runner=0
fi
```

## Automated Optimization

### Cost-Based Auto-Scaling

```python
#!/usr/bin/env python3
# cost-aware-autoscaler.py

import docker
import time
import json

class CostAwareAutoScaler:
    def __init__(self):
        self.client = docker.from_env()
        self.max_hourly_cost = 10.00  # Maximum $10/hour
        self.cost_per_replica = 0.50   # Cost per replica per hour

    def get_current_cost(self):
        """Calculate current hourly cost"""
        services = self.client.services.list()
        total_cost = 0

        for service in services:
            replicas = service.attrs['Spec']['Mode']['Replicated']['Replicas']
            total_cost += replicas * self.cost_per_replica

        return total_cost

    def scale_based_on_cost_and_load(self):
        """Scale services based on cost constraints and load"""
        current_cost = self.get_current_cost()

        print(f"Current hourly cost: ${current_cost:.2f}")
        print(f"Maximum allowed: ${self.max_hourly_cost:.2f}")

        if current_cost > self.max_hourly_cost:
            print("Cost threshold exceeded, scaling down...")
            self._scale_down_services()
        elif current_cost < self.max_hourly_cost * 0.7:
            print("Cost utilization low, checking if scaling up is beneficial...")
            self._conditional_scale_up()

    def _scale_down_services(self):
        """Scale down non-critical services"""
        services = self.client.services.list()

        for service in services:
            service_name = service.name
            current_replicas = service.attrs['Spec']['Mode']['Replicated']['Replicas']

            # Scale down non-production services first
            if 'dev' in service_name or 'test' in service_name:
                if current_replicas > 1:
                    new_replicas = max(1, current_replicas - 1)
                    service.update(mode={'Replicated': {'Replicas': new_replicas}})
                    print(f"Scaled down {service_name}: {current_replicas} -> {new_replicas}")

    def _conditional_scale_up(self):
        """Scale up if load warrants it and cost allows"""
        # This would integrate with monitoring to check CPU/memory usage
        # and scale up only if needed
        pass

    def run_continuous_optimization(self):
        """Run continuous cost optimization"""
        while True:
            try:
                self.scale_based_on_cost_and_load()
                time.sleep(300)  # Check every 5 minutes
            except Exception as e:
                print(f"Error in cost optimization: {e}")
                time.sleep(60)

if __name__ == "__main__":
    scaler = CostAwareAutoScaler()
    scaler.run_continuous_optimization()
```

### Scheduled Resource Management

```yaml
# scheduled-scaling.yml
version: "3.8"
services:
  scheduler:
    image: cost-scheduler:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - BUSINESS_HOURS=09:00-17:00
      - TIMEZONE=America/New_York
      - WEEKEND_SCALE_DOWN=true
    deploy:
      placement:
        constraints:
          - node.role == manager
    command: |
      sh -c '
        while true; do
          HOUR=$(date +%H)
          DAY=$(date +%u)  # 1=Monday, 7=Sunday
          
          # Business hours scaling
          if [ $HOUR -ge 9 ] && [ $HOUR -lt 17 ] && [ $DAY -le 5 ]; then
            echo "Business hours - scaling up"
            docker service scale web-app=5
            docker service scale api=3
          else
            echo "Off hours - scaling down"
            docker service scale web-app=2
            docker service scale api=1
          fi
          
          # Weekend scaling
          if [ $DAY -gt 5 ]; then
            echo "Weekend - minimal scaling"
            docker service scale web-app=1
            docker service scale api=1
            docker service scale worker=0
          fi
          
          sleep 3600  # Check every hour
        done
      '
```

## Cost Optimization Best Practices

### Development Environment Optimization

```yaml
# dev-cost-optimized.yml
version: "3.8"
services:
  # Shared development database
  shared-db:
    image: postgres:13-alpine
    environment:
      - POSTGRES_DB=shared_dev
    volumes:
      - shared_db_data:/var/lib/postgresql/data
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.environment == development

  # Individual developer containers (lightweight)
  dev-app:
    image: myapp:dev
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 256M
          cpus: "0.25"
    environment:
      - NODE_ENV=development
      - DB_HOST=shared-db

volumes:
  shared_db_data:
```

### Resource Cleanup Automation

```bash
#!/bin/bash
# automated-cleanup.sh

echo "=== Automated Resource Cleanup ==="

# Remove unused images older than 7 days
echo "Cleaning up old images..."
docker image prune -a --filter "until=168h" -f

# Remove unused volumes
echo "Cleaning up unused volumes..."
docker volume prune -f

# Remove unused networks
echo "Cleaning up unused networks..."
docker network prune -f

# Remove stopped containers older than 24 hours
echo "Cleaning up old containers..."
docker container prune --filter "until=24h" -f

# Stop development services during off-hours
HOUR=$(date +%H)
if [ $HOUR -lt 8 ] || [ $HOUR -gt 18 ]; then
    echo "Off-hours: stopping development services..."
    docker-compose -f docker-compose.dev.yml stop
fi

# Calculate saved space
echo "=== Cleanup Summary ==="
docker system df
```

### Cost Monitoring Integration

```python
#!/usr/bin/env python3
# cost-integration.py

import requests
import json
from datetime import datetime

def send_cost_metrics_to_monitoring():
    """Send cost metrics to monitoring system"""

    # Calculate current costs (simplified)
    cost_data = {
        'timestamp': datetime.now().isoformat(),
        'daily_cost': 25.50,
        'monthly_projection': 765.00,
        'containers': [
            {'name': 'web-app', 'cost': 15.30},
            {'name': 'database', 'cost': 8.20},
            {'name': 'worker', 'cost': 2.00}
        ]
    }

    # Send to Prometheus (example)
    prometheus_metrics = f"""
# HELP docker_daily_cost Daily Docker infrastructure cost in USD
# TYPE docker_daily_cost gauge
docker_daily_cost {cost_data['daily_cost']}

# HELP docker_monthly_projection Monthly cost projection in USD
# TYPE docker_monthly_projection gauge
docker_monthly_projection {cost_data['monthly_projection']}
"""

    # Write to file for Prometheus to scrape
    with open('/tmp/docker_cost_metrics.prom', 'w') as f:
        f.write(prometheus_metrics)

    # Send to time series database
    try:
        requests.post('http://influxdb:8086/write',
                     params={'db': 'docker_costs'},
                     data=f"daily_cost value={cost_data['daily_cost']}")
    except Exception as e:
        print(f"Failed to send metrics: {e}")

if __name__ == "__main__":
    send_cost_metrics_to_monitoring()
```

## Cost Optimization Checklist

### Infrastructure Level

```
□ Use appropriate instance types (CPU vs memory optimized)
□ Implement spot/preemptible instances for non-critical workloads
□ Set up auto-scaling based on demand and cost
□ Use reserved instances for predictable workloads
□ Implement resource quotas and limits
□ Regular cost monitoring and alerting
□ Clean up unused resources automatically
```

### Application Level

```
□ Optimize Docker images (multi-stage builds, minimal bases)
□ Right-size container resources
□ Implement efficient caching strategies
□ Use CDN for static assets
□ Optimize database queries and connections
□ Implement graceful degradation
□ Use health checks to prevent resource waste
```

### Operational Level

```
□ Schedule non-critical workloads during off-peak hours
□ Implement cost-aware scheduling policies
□ Regular cost review meetings
□ Train team on cost optimization practices
□ Use infrastructure as code for consistency
□ Monitor and optimize data transfer costs
□ Implement proper logging levels to reduce costs
```

## Cost Optimization Tools

### Open Source Tools

- **Kubecost**: Kubernetes cost monitoring
- **OpenCost**: CNCF cost monitoring standard
- **Prometheus**: Metrics collection
- **Grafana**: Cost visualization dashboards

### Cloud Provider Tools

- **AWS Cost Explorer**: AWS cost analysis
- **Azure Cost Management**: Azure cost tracking
- **GCP Cost Tools**: Google Cloud cost optimization

### Commercial Solutions

- **Spot.io**: Multi-cloud cost optimization
- **CloudHealth**: Cloud cost management
- **Cloudability**: Cost analytics platform

## Next Steps

- Implement [Performance Optimization](./performance-optimization.md) to reduce resource usage
- Check [Monitoring and Logging](./monitoring-logging.md) for cost-effective observability
- Learn [Production Deployment](./production-deployment.md) cost optimization strategies
- Explore [Glossary](./glossary.md) for cost-related Docker terminology
