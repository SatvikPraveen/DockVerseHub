# 08_orchestration/cluster-management/disaster-recovery.md

# Docker Swarm Disaster Recovery Plan

This document outlines comprehensive disaster recovery procedures for Docker Swarm clusters, covering various failure scenarios and recovery strategies.

## Disaster Recovery Overview

### Recovery Time Objectives (RTO)

- **Critical Services**: 15 minutes
- **Non-Critical Services**: 1 hour
- **Full Cluster Recovery**: 4 hours
- **Data Recovery**: 2 hours

### Recovery Point Objectives (RPO)

- **Database Services**: 5 minutes (continuous replication)
- **Application State**: 1 hour (regular backups)
- **Configuration**: Real-time (version controlled)

## Failure Scenarios

### 1. Single Node Failure

**Detection:**

```bash
# Check node status
docker node ls

# Look for down/unreachable nodes
docker node ls --filter "status=down"
```

**Recovery Steps:**

```bash
# Remove failed node from cluster
docker node rm <node-id> --force

# Add replacement node
# On new node:
docker swarm join --token <worker-token> <manager-ip>:2377

# Verify services redistributed
docker service ps <service-name>
```

### 2. Manager Node Failure

**Single Manager Loss:**

```bash
# Promote worker to manager
docker node promote <worker-node-id>

# Verify cluster health
docker node ls
docker service ls
```

**Quorum Loss (Multiple Manager Failure):**

```bash
# Force new cluster from surviving manager
docker swarm init --force-new-cluster --advertise-addr <manager-ip>

# Re-add other managers
# On each manager node:
docker swarm join --token <manager-token> <leader-ip>:2377
```

### 3. Complete Cluster Failure

**Recovery Process:**

1. **Initialize New Cluster**

```bash
# Start fresh cluster
docker swarm init --advertise-addr <new-manager-ip>

# Create networks
docker network create --driver overlay frontend
docker network create --driver overlay backend
```

2. **Restore Secrets and Configs**

```bash
# Recreate secrets from backup
echo "password123" | docker secret create db_password -

# Restore configs
docker config create nginx_config nginx.conf
```

3. **Restore Services**

```bash
# Deploy from backup configurations
docker stack deploy -c docker-compose.yml app-stack
```

## Backup Strategy

### Automated Backup Schedule

**Daily Backups:**

```bash
# Cron job for daily backups
0 2 * * * /opt/scripts/backup-cluster.sh >> /var/log/swarm-backup.log 2>&1
```

**Backup Components:**

- Cluster metadata and node information
- Service configurations and secrets metadata
- Network configurations
- Volume data
- Application configurations

### Backup Verification

**Automated Verification Script:**

```bash
#!/bin/bash
# verify-backup.sh

BACKUP_FILE=$1

# Extract and verify backup
TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Check essential components
BACKUP_PATH="$TEMP_DIR/swarm_backup_*"

if [ -f "$BACKUP_PATH/cluster/swarm_info.json" ]; then
    echo "✓ Cluster info present"
else
    echo "✗ Cluster info missing"
    exit 1
fi

if [ -f "$BACKUP_PATH/services/services_list.json" ]; then
    echo "✓ Services backup present"
else
    echo "✗ Services backup missing"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"
echo "Backup verification completed successfully"
```

## Data Recovery Procedures

### Database Recovery

**PostgreSQL Recovery:**

```bash
# Stop affected service
docker service scale app_database=0

# Create recovery container
docker run -it --rm \
  -v database_data:/var/lib/postgresql/data \
  -v /backup:/backup \
  postgres:15 bash

# Inside container:
# Restore from backup
psql -U postgres -d appdb < /backup/database_dump.sql
```

**MongoDB Recovery:**

```bash
# Restore MongoDB
docker exec -it mongodb_container mongorestore \
  --host mongodb:27017 \
  --db appdb \
  /backup/mongodb_dump
```

### Volume Data Recovery

**Restore Volume from Backup:**

```bash
# Create new volume
docker volume create restored_data

# Restore data from backup
docker run --rm \
  -v restored_data:/data \
  -v /backup:/backup \
  alpine tar -xzf /backup/volume_data.tar.gz -C /data
```

## Network Recovery

### Recreate Overlay Networks

```bash
# Recreate application networks
docker network create \
  --driver overlay \
  --subnet 10.0.1.0/24 \
  --gateway 10.0.1.1 \
  frontend

docker network create \
  --driver overlay \
  --subnet 10.0.2.0/24 \
  --gateway 10.0.2.1 \
  backend
```

### Network Troubleshooting

**Common Network Issues:**

```bash
# Check network connectivity
docker exec -it <container> ping <service-name>

# Inspect network configuration
docker network inspect <network-name>

# Check DNS resolution
docker exec -it <container> nslookup <service-name>
```

## Service Recovery

### Service Restoration Priority

1. **Critical Infrastructure Services**

   - Load balancers
   - DNS services
   - Monitoring systems

2. **Data Services**

   - Databases
   - Message queues
   - Cache layers

3. **Application Services**

   - API services
   - Web applications
   - Background workers

4. **Support Services**
   - Logging
   - Metrics collection
   - Backup services

### Service Recovery Script

```bash
#!/bin/bash
# restore-services.sh

BACKUP_DIR="/restore/swarm_backup_*"
COMPOSE_FILE="docker-compose.yml"

log() {
    echo "[$(date)] $1"
}

# Restore secrets first
log "Restoring secrets..."
while IFS= read -r secret_file; do
    secret_name=$(basename "$secret_file" .json)
    # Note: Secret data cannot be restored, must be recreated
    log "Secret $secret_name needs manual recreation"
done < <(find "$BACKUP_DIR/secrets" -name "*.json")

# Restore configs
log "Restoring configs..."
while IFS= read -r config_file; do
    config_name=$(basename "$config_file" .json)
    config_data_file="${config_file%.*}_data.txt"

    if [ -f "$config_data_file" ]; then
        docker config create "$config_name" "$config_data_file" 2>/dev/null || true
        log "Restored config: $config_name"
    fi
done < <(find "$BACKUP_DIR/configs" -name "*.json")

# Deploy services
log "Deploying services from compose file..."
if [ -f "$COMPOSE_FILE" ]; then
    docker stack deploy -c "$COMPOSE_FILE" restored-app
    log "Services deployment initiated"
else
    log "Compose file not found, manual service recreation required"
fi

# Verify deployment
sleep 30
docker service ls
log "Service restoration completed"
```

## Monitoring and Alerting

### Health Check Script

```bash
#!/bin/bash
# cluster-health-check.sh

# Check cluster status
MANAGER_COUNT=$(docker node ls --filter "role=manager" --filter "availability=active" -q | wc -l)
WORKER_COUNT=$(docker node ls --filter "role=worker" --filter "availability=active" -q | wc -l)
FAILED_SERVICES=$(docker service ls --filter "desired-state=running" --format "{{.Replicas}}" | grep "0/" | wc -l)

echo "Cluster Health Report"
echo "===================="
echo "Active Managers: $MANAGER_COUNT"
echo "Active Workers: $WORKER_COUNT"
echo "Failed Services: $FAILED_SERVICES"

# Alert conditions
if [ "$MANAGER_COUNT" -lt 3 ]; then
    echo "WARNING: Less than 3 managers available"
fi

if [ "$FAILED_SERVICES" -gt 0 ]; then
    echo "CRITICAL: $FAILED_SERVICES services not running"
fi
```

### Prometheus Alerting Rules

```yaml
# swarm-alerts.yml
groups:
  - name: swarm.rules
    rules:
      - alert: SwarmNodeDown
        expr: up{job="docker"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Swarm node {{ $labels.instance }} is down"

      - alert: SwarmManagerQuorumLoss
        expr: count(up{job="docker-manager"} == 1) < 2
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Swarm manager quorum lost"

      - alert: ServiceReplicaDown
        expr: (docker_service_replicas_desired - docker_service_replicas_running) > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Service {{ $labels.service_name }} has missing replicas"
```

## Communication Plan

### Incident Response Team

**Primary Contacts:**

- **Incident Commander**: ops-lead@company.com
- **Technical Lead**: tech-lead@company.com
- **Database Admin**: dba@company.com
- **Network Admin**: netadmin@company.com

### Communication Channels

1. **Emergency Channel**: #incident-response (Slack)
2. **Status Page**: status.company.com
3. **Customer Communication**: support@company.com
4. **Management Updates**: executives@company.com

### Status Update Template

```
INCIDENT UPDATE #{{number}}
Time: {{timestamp}}
Status: {{status}}
Impact: {{impact_description}}
Actions Taken:
- {{action_1}}
- {{action_2}}
Next Update: {{next_update_time}}
```

## Testing and Validation

### Disaster Recovery Testing Schedule

**Monthly Tests:**

- Single node failure simulation
- Service failover testing
- Backup verification

**Quarterly Tests:**

- Manager node failure
- Network partition testing
- Complete service restoration

**Annual Tests:**

- Full cluster disaster recovery
- Multi-site failover
- Data center loss simulation

### Testing Checklist

```bash
#!/bin/bash
# dr-test-checklist.sh

echo "Disaster Recovery Test Checklist"
echo "================================"

# Test 1: Backup Verification
echo "□ Verify latest backup integrity"
echo "□ Test backup extraction"
echo "□ Validate backup completeness"

# Test 2: Node Failure Simulation
echo "□ Stop worker node"
echo "□ Verify service redistribution"
echo "□ Test node replacement"

# Test 3: Service Recovery
echo "□ Stop critical service"
echo "□ Verify automated recovery"
echo "□ Test manual intervention"

# Test 4: Data Recovery
echo "□ Simulate data corruption"
echo "□ Restore from backup"
echo "□ Verify data integrity"

# Test 5: Communication
echo "□ Test alert notifications"
echo "□ Verify escalation procedures"
echo "□ Update status page"

echo ""
echo "Test completion requires sign-off from:"
echo "- Technical Lead: ________________"
echo "- Operations Manager: ________________"
echo "- Date: ________________"
```

## Recovery Time Optimization

### Fast Recovery Strategies

**Pre-positioned Resources:**

- Warm standby nodes ready to join
- Pre-built container images in local registry
- Configuration templates stored in version control
- Automated deployment scripts tested and ready

**Quick Start Scripts:**

```bash
#!/bin/bash
# quick-recovery.sh

# Rapid cluster initialization
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Deploy critical services first
docker stack deploy -c critical-services.yml critical

# Wait for critical services to be healthy
./wait-for-services.sh critical

# Deploy remaining services
docker stack deploy -c application.yml app

echo "Quick recovery completed in $(date)"
```

## Documentation Maintenance

### Runbook Updates

- Monthly review of procedures
- Post-incident procedure updates
- Team training on new procedures
- Regular testing of documented steps

### Version Control

All disaster recovery documentation and scripts must be:

- Stored in version control (Git)
- Reviewed through pull requests
- Tagged with versions for releases
- Backed up to multiple locations

## Post-Recovery Actions

### System Verification

1. **Health Checks**: Verify all services are running
2. **Performance Testing**: Confirm system performance
3. **Data Integrity**: Validate data consistency
4. **User Access**: Test application functionality

### Post-Incident Review

1. **Timeline Documentation**: Record incident timeline
2. **Root Cause Analysis**: Identify failure causes
3. **Improvement Actions**: Plan preventive measures
4. **Procedure Updates**: Revise recovery procedures

This disaster recovery plan ensures comprehensive coverage of failure scenarios with tested procedures for rapid recovery and minimal downtime.
