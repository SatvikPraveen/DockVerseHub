# 08_orchestration/cluster-management/upgrade-strategy.md

# Docker Swarm Upgrade Strategy

This document outlines comprehensive strategies for upgrading Docker Swarm clusters with minimal downtime and maximum safety.

## Upgrade Overview

### Supported Upgrade Paths

- **Patch Upgrades**: Same major.minor version (e.g., 24.0.1 → 24.0.2)
- **Minor Upgrades**: Same major version (e.g., 24.0 → 24.1)
- **Major Upgrades**: Different major versions (e.g., 23.x → 24.x)

### Upgrade Constraints

- Maximum 1 major version jump per upgrade cycle
- Manager nodes must be upgraded before worker nodes
- Minimum 3-node manager quorum maintained during upgrade

## Pre-Upgrade Preparation

### 1. Environment Assessment

**Current State Documentation:**

```bash
#!/bin/bash
# pre-upgrade-assessment.sh

echo "Docker Swarm Pre-Upgrade Assessment"
echo "==================================="

# Current Docker version
echo "Current Docker Version:"
docker version --format 'Server: {{.Server.Version}}, Client: {{.Client.Version}}'

# Cluster information
echo -e "\nCluster Status:"
docker info | grep -E "Swarm:|Nodes:|Managers:|EngineVersion:"

# Node information
echo -e "\nNode Status:"
docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.EngineVersion}}"

# Service status
echo -e "\nService Status:"
docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"

# Check for unhealthy services
UNHEALTHY=$(docker service ls --format "{{.Replicas}}" | grep -c "0/")
echo -e "\nUnhealthy Services: $UNHEALTHY"

# Resource usage
echo -e "\nResource Usage:"
docker system df

# Network status
echo -e "\nNetworks:"
docker network ls --filter driver=overlay --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
```

### 2. Backup Creation

**Pre-Upgrade Backup:**

```bash
#!/bin/bash
# pre-upgrade-backup.sh

BACKUP_DIR="/opt/upgrades/backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Creating pre-upgrade backup in $BACKUP_DIR"

# Full cluster backup
./backup-cluster.sh
cp -r /opt/docker-swarm-backups/swarm_backup_* "$BACKUP_DIR/"

# Service configurations
docker service ls -q | while read service_id; do
    docker service inspect "$service_id" > "$BACKUP_DIR/service_${service_id}.json"
done

# Compose files backup
find /opt/compose -name "*.yml" -exec cp {} "$BACKUP_DIR/" \;

echo "Pre-upgrade backup completed: $BACKUP_DIR"
```

### 3. Compatibility Verification

**Check Docker Engine Compatibility:**

```bash
#!/bin/bash
# check-compatibility.sh

TARGET_VERSION="24.0.7"
CURRENT_VERSION=$(docker version --format '{{.Server.Version}}')

echo "Current Version: $CURRENT_VERSION"
echo "Target Version: $TARGET_VERSION"

# Check API version compatibility
CURRENT_API=$(docker version --format '{{.Server.APIVersion}}')
echo "Current API Version: $CURRENT_API"

# Check for deprecated features
echo "Checking for deprecated features..."

# Legacy compose format
if docker service ls --format "{{.Name}}" | grep -q "_"; then
    echo "WARNING: Legacy compose stack detected"
fi

# Check for unsupported configurations
docker service ls -q | while read service_id; do
    docker service inspect "$service_id" --format '{{json .Spec}}' | \
    jq -r 'select(.TaskTemplate.RestartPolicy.Condition == "none") | "WARNING: Service with deprecated restart policy"'
done

echo "Compatibility check completed"
```

## Upgrade Strategies

### Strategy 1: Rolling Upgrade (Recommended)

**Advantages:**

- Zero downtime for applications
- Gradual risk exposure
- Easy rollback at each step

**Process:**

```bash
#!/bin/bash
# rolling-upgrade.sh

TARGET_VERSION="24.0.7"
UPGRADE_LOG="/var/log/docker-upgrade.log"

log() {
    echo "[$(date)] $1" | tee -a "$UPGRADE_LOG"
}

# Step 1: Upgrade manager nodes (one at a time)
upgrade_managers() {
    local managers=$(docker node ls --filter "role=manager" --format "{{.Hostname}}")

    for manager in $managers; do
        if [ "$manager" == "$(hostname)" ]; then
            continue  # Skip current node, do it last
        fi

        log "Upgrading manager node: $manager"

        # Demote to worker temporarily (if more than 3 managers)
        local manager_count=$(docker node ls --filter "role=manager" -q | wc -l)
        if [ "$manager_count" -gt 3 ]; then
            docker node demote "$manager"
        fi

        # Upgrade node (execute on remote node)
        ssh "$manager" "
            sudo systemctl stop docker
            sudo apt-get update
            sudo apt-get install -y docker-ce=$TARGET_VERSION
            sudo systemctl start docker
        "

        # Wait for node to rejoin
        sleep 30

        # Promote back to manager
        if [ "$manager_count" -gt 3 ]; then
            docker node promote "$manager"
        fi

        # Verify node health
        docker node inspect "$manager" --format "{{.Status.State}}"

        log "Manager $manager upgraded successfully"
    done

    # Upgrade current manager node last
    log "Upgrading current manager node: $(hostname)"
    # This requires coordination with other managers
}

# Step 2: Upgrade worker nodes
upgrade_workers() {
    local workers=$(docker node ls --filter "role=worker" --format "{{.Hostname}}")

    for worker in $workers; do
        log "Upgrading worker node: $worker"

        # Drain node
        docker node update --availability drain "$worker"

        # Wait for services to migrate
        sleep 60

        # Upgrade node
        ssh "$worker" "
            sudo systemctl stop docker
            sudo apt-get update
            sudo apt-get install -y docker-ce=$TARGET_VERSION
            sudo systemctl start docker
        "

        # Restore node availability
        docker node update --availability active "$worker"

        # Verify node health
        docker node inspect "$worker" --format "{{.Status.State}}"

        log "Worker $worker upgraded successfully"
    done
}

# Execute upgrade
log "Starting rolling upgrade to Docker $TARGET_VERSION"
upgrade_managers
upgrade_workers
log "Rolling upgrade completed"
```

### Strategy 2: Blue-Green Upgrade

**For Critical Production Systems:**

```bash
#!/bin/bash
# blue-green-upgrade.sh

# Create new cluster (green)
BLUE_CLUSTER="production"
GREEN_CLUSTER="production-new"

# Initialize green cluster with new Docker version
setup_green_cluster() {
    echo "Setting up green cluster with new Docker version"

    # Deploy to new cluster
    docker -H green-manager:2376 swarm init

    # Deploy services to green cluster
    docker -H green-manager:2376 stack deploy -c docker-compose.yml app

    # Wait for services to be healthy
    ./wait-for-health.sh green-manager:2376
}

# Switch traffic
switch_traffic() {
    echo "Switching traffic to green cluster"

    # Update load balancer configuration
    ./update-loadbalancer.sh --target green-cluster

    # Monitor for issues
    ./monitor-traffic.sh --duration 300
}

# Cleanup old cluster
cleanup_blue() {
    echo "Decommissioning blue cluster"
    docker -H blue-manager:2376 stack rm app
}

setup_green_cluster
switch_traffic
cleanup_blue
```

### Strategy 3: In-Place Upgrade

**For Development/Testing:**

```bash
#!/bin/bash
# in-place-upgrade.sh

TARGET_VERSION="24.0.7"

# Stop all services
docker service ls -q | xargs -I {} docker service scale {}=0

# Wait for services to stop
sleep 60

# Upgrade all nodes simultaneously
ansible-playbook -i inventory upgrade-docker.yml -e "target_version=$TARGET_VERSION"

# Restart services
docker service ls -q | xargs -I {} docker service scale {}=1

echo "In-place upgrade completed"
```

## Upgrade Execution

### Phase 1: Manager Node Upgrade

**Manager Upgrade Process:**

```bash
#!/bin/bash
# upgrade-manager.sh

NODE_NAME=$1
TARGET_VERSION=$2

if [ -z "$NODE_NAME" ] || [ -z "$TARGET_VERSION" ]; then
    echo "Usage: $0 <node_name> <target_version>"
    exit 1
fi

# Pre-upgrade checks
echo "Pre-upgrade checks for $NODE_NAME"
docker node inspect "$NODE_NAME" --format "{{.Status.State}}"

# Check manager count
MANAGER_COUNT=$(docker node ls --filter "role=manager" -q | wc -l)
if [ "$MANAGER_COUNT" -lt 3 ]; then
    echo "ERROR: Need at least 3 managers for safe upgrade"
    exit 1
fi

# Backup manager-specific data
docker swarm ca > "/tmp/ca-${NODE_NAME}.pem"

# Perform upgrade on remote node
ssh "$NODE_NAME" << EOF
    # Stop Docker daemon
    sudo systemctl stop docker

    # Update package repository
    sudo apt-get update

    # Install new Docker version
    sudo apt-get install -y docker-ce=${TARGET_VERSION}* docker-ce-cli=${TARGET_VERSION}*

    # Start Docker daemon
    sudo systemctl start docker

    # Verify installation
    docker version
EOF

# Verify node rejoined cluster
sleep 30
docker node ls | grep "$NODE_NAME"

# Verify cluster health
docker node ls --filter "role=manager" --filter "availability=active"

echo "Manager $NODE_NAME upgrade completed"
```

### Phase 2: Worker Node Upgrade

**Worker Upgrade Process:**

```bash
#!/bin/bash
# upgrade-worker.sh

NODE_NAME=$1
TARGET_VERSION=$2

# Drain node
echo "Draining node: $NODE_NAME"
docker node update --availability drain "$NODE_NAME"

# Wait for services to migrate
echo "Waiting for service migration..."
while [ "$(docker node ps "$NODE_NAME" --filter "desired-state=running" -q | wc -l)" -gt 0 ]; do
    sleep 10
    echo -n "."
done
echo "Service migration completed"

# Upgrade node
ssh "$NODE_NAME" << EOF
    sudo systemctl stop docker
    sudo apt-get update
    sudo apt-get install -y docker-ce=${TARGET_VERSION}*
    sudo systemctl start docker
EOF

# Reactivate node
docker node update --availability active "$NODE_NAME"

# Verify node health
docker node inspect "$NODE_NAME" --format "{{.Status.State}}: {{.Spec.Availability}}"

echo "Worker $NODE_NAME upgrade completed"
```

## Post-Upgrade Validation

### Comprehensive Health Check

```bash
#!/bin/bash
# post-upgrade-validation.sh

echo "Post-Upgrade Validation"
echo "======================="

# Check cluster status
echo "1. Cluster Status:"
docker info | grep -E "Swarm|Nodes|Managers"

# Check all nodes are healthy
echo -e "\n2. Node Health:"
docker node ls

UNHEALTHY_NODES=$(docker node ls --filter "status=down" -q | wc -l)
if [ "$UNHEALTHY_NODES" -gt 0 ]; then
    echo "ERROR: $UNHEALTHY_NODES unhealthy nodes detected"
    exit 1
fi

# Check service status
echo -e "\n3. Service Status:"
docker service ls

FAILED_SERVICES=$(docker service ls --format "{{.Replicas}}" | grep -c "0/")
if [ "$FAILED_SERVICES" -gt 0 ]; then
    echo "ERROR: $FAILED_SERVICES failed services detected"
    exit 1
fi

# Check network connectivity
echo -e "\n4. Network Connectivity:"
docker network ls --filter driver=overlay

# Test inter-service communication
echo -e "\n5. Service Communication Test:"
./test-service-connectivity.sh

# Performance baseline comparison
echo -e "\n6. Performance Check:"
./performance-benchmark.sh

echo -e "\nPost-upgrade validation completed successfully!"
```

### Service Connectivity Test

```bash
#!/bin/bash
# test-service-connectivity.sh

# Test HTTP endpoints
test_http_endpoint() {
    local service=$1
    local endpoint=$2

    echo "Testing $service at $endpoint"

    if curl -f -s "$endpoint" > /dev/null; then
        echo "✓ $service is responsive"
    else
        echo "✗ $service is not responding"
        return 1
    fi
}

# Test database connections
test_database_connection() {
    local service=$1
    local host=$2
    local port=$3

    echo "Testing database connection to $service"

    if timeout 5 bash -c "</dev/tcp/$host/$port"; then
        echo "✓ $service database is accessible"
    else
        echo "✗ $service database is not accessible"
        return 1
    fi
}

# Run connectivity tests
test_http_endpoint "web" "http://localhost/health"
test_http_endpoint "api" "http://localhost/api/health"
test_database_connection "postgres" "localhost" "5432"

echo "Service connectivity tests completed"
```

## Rollback Procedures

### Automatic Rollback Conditions

```bash
#!/bin/bash
# auto-rollback.sh

ROLLBACK_TRIGGERS=(
    "service_failure"
    "performance_degradation"
    "connectivity_issues"
)

check_rollback_conditions() {
    # Check service health
    local failed_services=$(docker service ls --format "{{.Replicas}}" | grep -c "0/")
    if [ "$failed_services" -gt 0 ]; then
        echo "ROLLBACK: Service failures detected"
        return 0
    fi

    # Check response times
    local avg_response=$(curl -w "%{time_total}" -s -o /dev/null http://localhost/health)
    if [ "$(echo "$avg_response > 2.0" | bc)" -eq 1 ]; then
        echo "ROLLBACK: Performance degradation detected"
        return 0
    fi

    return 1
}

# Execute rollback
execute_rollback() {
    echo "Executing automatic rollback..."

    # Restore from backup
    ./restore-cluster.sh /opt/upgrades/backup-$(date +%Y%m%d)*

    # Downgrade Docker version
    ./downgrade-docker.sh

    echo "Rollback completed"
}

if check_rollback_conditions; then
    execute_rollback
fi
```

### Manual Rollback Process

```bash
#!/bin/bash
# manual-rollback.sh

PREVIOUS_VERSION=$1
BACKUP_PATH=$2

if [ -z "$PREVIOUS_VERSION" ] || [ -z "$BACKUP_PATH" ]; then
    echo "Usage: $0 <previous_version> <backup_path>"
    exit 1
fi

echo "Rolling back to Docker version: $PREVIOUS_VERSION"
echo "Using backup from: $BACKUP_PATH"

# Step 1: Downgrade Docker on all nodes
downgrade_all_nodes() {
    docker node ls --format "{{.Hostname}}" | while read node; do
        echo "Downgrading $node to $PREVIOUS_VERSION"

        ssh "$node" << EOF
            sudo systemctl stop docker
            sudo apt-get install -y --allow-downgrades docker-ce=${PREVIOUS_VERSION}*
            sudo systemctl start docker
EOF
    done
}

# Step 2: Restore configurations
restore_configurations() {
    echo "Restoring service configurations..."

    # Remove current services
    docker service ls -q | xargs docker service rm

    # Restore from backup
    find "$BACKUP_PATH" -name "service_*.json" | while read service_file; do
        # Restore service configuration (manual process required)
        echo "Manual restoration required for: $service_file"
    done
}

# Execute rollback
downgrade_all_nodes
restore_configurations

echo "Manual rollback process initiated - requires manual intervention"
```

## Upgrade Best Practices

### 1. Timing Considerations

- **Maintenance Windows**: Schedule during low-traffic periods
- **Business Impact**: Coordinate with business stakeholders
- **Rollback Window**: Ensure sufficient time for rollback if needed

### 2. Communication Plan

- **Pre-upgrade**: Notify stakeholders 48 hours in advance
- **During upgrade**: Provide real-time status updates
- **Post-upgrade**: Confirm successful completion

### 3. Testing Protocol

- **Staging Environment**: Test upgrade process on staging first
- **Canary Deployment**: Upgrade subset of production first
- **Performance Testing**: Validate performance post-upgrade

### 4. Documentation Requirements

- **Upgrade Log**: Document all steps and issues
- **Configuration Changes**: Record any configuration modifications
- **Lessons Learned**: Document for future upgrades

## Monitoring During Upgrade

### Key Metrics to Monitor

```bash
#!/bin/bash
# upgrade-monitoring.sh

monitor_upgrade() {
    while true; do
        echo "=== Upgrade Monitoring $(date) ==="

        # Cluster health
        echo "Nodes: $(docker node ls --filter 'availability=active' -q | wc -l) active"

        # Service health
        echo "Services: $(docker service ls --format '{{.Replicas}}' | grep -v '0/' | wc -l) healthy"

        # Resource usage
        echo "Memory: $(docker system df --format '{{.Size}}' | head -1)"

        # Response times
        curl -w "Response time: %{time_total}s\n" -s -o /dev/null http://localhost/health

        sleep 30
    done
}

monitor_upgrade &
MONITOR_PID=$!

# Stop monitoring after upgrade
trap "kill $MONITOR_PID" EXIT
```

This comprehensive upgrade strategy ensures safe, reliable Docker Swarm upgrades with minimal downtime and maximum recoverability.
