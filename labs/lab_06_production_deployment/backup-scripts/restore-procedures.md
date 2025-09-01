# Restore Procedures

**Location**: `labs/lab_06_production_deployment/backup-scripts/restore-procedures.md`

## 🎯 Overview

This document provides comprehensive procedures for restoring databases, volumes, and configurations from backups in case of system failure or data corruption.

## 📋 Pre-Restoration Checklist

### Before Starting Any Restore Operation:

- [ ] **Stop all services** that write to the target systems
- [ ] **Verify backup integrity** before restoration
- [ ] **Document current system state** for potential rollback
- [ ] **Notify stakeholders** of maintenance window
- [ ] **Ensure sufficient disk space** for restoration
- [ ] **Have rollback plan ready** in case restore fails

## 🗄️ Database Restoration

### PostgreSQL Restoration

#### 1. Stop Applications

```bash
# Stop services that connect to PostgreSQL
docker-compose -f docker-compose.prod.yml stop user-service order-service
```

#### 2. Restore User Database

```bash
# Find latest backup
LATEST_BACKUP=$(ls -t backups/postgres/userdb_*.sql.gz | head -1)

# Restore database
docker-compose -f docker-compose.prod.yml exec postgres-user dropdb -U userdb_user userdb --if-exists
docker-compose -f docker-compose.prod.yml exec postgres-user createdb -U userdb_user userdb
gunzip -c "$LATEST_BACKUP" | docker-compose -f docker-compose.prod.yml exec -T postgres-user psql -U userdb_user -d userdb

# Verify restoration
docker-compose -f docker-compose.prod.yml exec postgres-user psql -U userdb_user -d userdb -c "SELECT COUNT(*) FROM users;"
```

#### 3. Restore Order Database

```bash
# Find latest backup
LATEST_BACKUP=$(ls -t backups/postgres/orderdb_*.sql.gz | head -1)

# Restore database
docker-compose -f docker-compose.prod.yml exec postgres-order dropdb -U orderdb_user orderdb --if-exists
docker-compose -f docker-compose.prod.yml exec postgres-order createdb -U orderdb_user orderdb
gunzip -c "$LATEST_BACKUP" | docker-compose -f docker-compose.prod.yml exec -T postgres-order psql -U orderdb_user -d orderdb

# Verify restoration
docker-compose -f docker-compose.prod.yml exec postgres-order psql -U orderdb_user -d orderdb -c "SELECT COUNT(*) FROM orders;"
```

#### 4. Point-in-Time Recovery (PITR)

```bash
# For PostgreSQL PITR (requires WAL archiving)
RECOVERY_TARGET="2024-01-15 14:30:00"

# Stop PostgreSQL
docker-compose -f docker-compose.prod.yml stop postgres-user

# Restore base backup
tar -xzf /backups/postgres/base_backup_20240115.tar.gz -C /var/lib/postgresql/data

# Create recovery.conf
echo "restore_command = 'cp /backups/postgres/wal/%f %p'" > recovery.conf
echo "recovery_target_time = '$RECOVERY_TARGET'" >> recovery.conf
echo "recovery_target_action = 'promote'" >> recovery.conf

# Start PostgreSQL
docker-compose -f docker-compose.prod.yml start postgres-user
```

### MongoDB Restoration

#### 1. Stop Notification Service

```bash
docker-compose -f docker-compose.prod.yml stop notification-service
```

#### 2. Restore MongoDB Database

```bash
# Find latest backup
LATEST_BACKUP=$(ls -t backups/mongodb/notifydb_*.tar.gz | head -1)

# Extract backup
mkdir -p /tmp/mongodb-restore
tar -xzf "$LATEST_BACKUP" -C /tmp/mongodb-restore

# Drop existing database
docker-compose -f docker-compose.prod.yml exec mongodb mongosh --eval "db.getSiblingDB('notifydb').dropDatabase()"

# Restore database
docker-compose -f docker-compose.prod.yml exec -T mongodb mongorestore --db notifydb /tmp/mongodb-restore/notifydb

# Verify restoration
docker-compose -f docker-compose.prod.yml exec mongodb mongosh notifydb --eval "db.notifications.countDocuments()"

# Cleanup
rm -rf /tmp/mongodb-restore
```

### Redis Restoration

#### 1. Stop Services Using Redis

```bash
docker-compose -f docker-compose.prod.yml stop user-service order-service notification-service
```

#### 2. Restore Redis Data

```bash
# Stop Redis
docker-compose -f docker-compose.prod.yml stop redis

# Find latest Redis backup (RDB file)
LATEST_BACKUP=$(ls -t backups/redis/dump_*.rdb | head -1)

# Copy backup to Redis data directory
docker cp "$LATEST_BACKUP" $(docker-compose -f docker-compose.prod.yml ps -q redis):/data/dump.rdb

# Start Redis
docker-compose -f docker-compose.prod.yml start redis

# Verify data
docker-compose -f docker-compose.prod.yml exec redis redis-cli INFO keyspace
```

## 💾 Volume Restoration

### General Volume Restore Process

#### 1. Stop All Services

```bash
docker-compose -f docker-compose.prod.yml down
```

#### 2. Restore Specific Volume

```bash
# Function to restore volume
restore_volume() {
    local volume_name="$1"
    local backup_file="$2"

    echo "Restoring volume: $volume_name from $backup_file"

    # Remove existing volume
    docker volume rm "lab06_${volume_name}" 2>/dev/null || true

    # Create new volume
    docker volume create "lab06_${volume_name}"

    # Restore data
    docker run --rm \
        -v "lab06_${volume_name}:/volume" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine:latest \
        tar -xzf "/backup/$(basename "$backup_file")" -C /volume

    echo "Volume $volume_name restored successfully"
}

# Example: Restore prometheus data
BACKUP_FILE=$(ls -t volume-backups/prometheus-data_*.tar.gz | head -1)
restore_volume "prometheus-data" "$BACKUP_FILE"
```

#### 3. Restore All Volumes from Backup Set

```bash
#!/bin/bash
# restore-all-volumes.sh

BACKUP_DATE="20240115_143000"  # Specify backup date/time

volumes=(
    "postgres-user-data"
    "postgres-order-data"
    "mongodb-data"
    "redis-data"
    "prometheus-data"
    "grafana-data"
    "nginx-logs"
    "elasticsearch-data"
)

for volume in "${volumes[@]}"; do
    backup_file="volume-backups/${volume}_${BACKUP_DATE}.tar.gz"
    if [[ -f "$backup_file" ]]; then
        restore_volume "$volume" "$backup_file"
    else
        echo "Warning: Backup file not found: $backup_file"
    fi
done

echo "All volumes restored. Starting services..."
docker-compose -f docker-compose.prod.yml up -d
```

## 🔄 Full System Restoration

### Complete Disaster Recovery

#### 1. Infrastructure Setup

```bash
# Ensure Docker and Docker Compose are installed
# Ensure all necessary directories exist
mkdir -p {backups,ssl/certificates,nginx/static}

# Restore configuration files
tar -xzf backups/config_latest.tar.gz
```

#### 2. Restore SSL Certificates

```bash
# Restore certificates from backup
tar -xzf backups/ssl-certificates_latest.tar.gz -C ssl/certificates/

# Verify certificate validity
openssl x509 -in ssl/certificates/cert.pem -text -noout | grep "Not After"
```

#### 3. Restore Secrets and Configuration

```bash
# Restore environment variables
cp backups/.env.backup .env

# Restore Docker Compose overrides
cp backups/docker-compose.override.yml.backup docker-compose.override.yml

# Restore nginx configuration
cp backups/nginx.conf.backup nginx/nginx.conf
```

#### 4. Sequential Service Restoration

```bash
#!/bin/bash
# full-restore.sh

echo "Starting full system restoration..."

# 1. Start infrastructure services
docker-compose -f docker-compose.prod.yml up -d postgres-user postgres-order mongodb redis elasticsearch

# Wait for databases to be ready
sleep 30

# 2. Restore databases
echo "Restoring databases..."
./restore-databases.sh

# 3. Start application services
docker-compose -f docker-compose.prod.yml up -d user-service order-service notification-service

# Wait for services to be ready
sleep 20

# 4. Start frontend and monitoring
docker-compose -f docker-compose.prod.yml up -d nginx prometheus grafana jaeger

# 5. Verify all services are healthy
./health-checks.py

echo "Full system restoration completed"
```

## 📊 Monitoring and Logging Restoration

### Restore Prometheus Data

```bash
# Stop Prometheus
docker-compose -f docker-compose.prod.yml stop prometheus

# Restore Prometheus data
BACKUP_FILE=$(ls -t volume-backups/prometheus-data_*.tar.gz | head -1)
restore_volume "prometheus-data" "$BACKUP_FILE"

# Start Prometheus
docker-compose -f docker-compose.prod.yml start prometheus

# Verify metrics are available
curl http://localhost:9090/api/v1/query?query=up
```

### Restore Grafana Dashboards and Data

```bash
# Stop Grafana
docker-compose -f docker-compose.prod.yml stop grafana

# Restore Grafana data
BACKUP_FILE=$(ls -t volume-backups/grafana-data_*.tar.gz | head -1)
restore_volume "grafana-data" "$BACKUP_FILE"

# Start Grafana
docker-compose -f docker-compose.prod.yml start grafana

# Verify dashboards are available
curl -u admin:password http://localhost:3000/api/search
```

## 🧪 Testing Restored System

### Database Integrity Checks

```bash
# PostgreSQL integrity checks
docker-compose -f docker-compose.prod.yml exec postgres-user psql -U userdb_user -d userdb -c "
    SELECT schemaname, tablename,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables WHERE schemaname = 'public';
"

# MongoDB integrity checks
docker-compose -f docker-compose.prod.yml exec mongodb mongosh notifydb --eval "
    db.runCommand({dbStats: 1});
    db.notifications.find().limit(5);
"
```

### Application Health Verification

```bash
# Run comprehensive health checks
python3 monitoring/health-checks.py

# Test API endpoints
curl -f https://your-domain.com/api/v1/users/health
curl -f https://your-domain.com/api/v1/orders/health
curl -f https://your-domain.com/api/v1/notifications/health

# Test user registration flow
curl -X POST https://your-domain.com/api/v1/users/register \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test123"}'
```

### Performance Validation

```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com/

# Monitor resource usage
docker stats --no-stream

# Check database performance
docker-compose -f docker-compose.prod.yml exec postgres-user psql -U userdb_user -d userdb -c "
    SELECT query, mean_exec_time, calls
    FROM pg_stat_statements
    ORDER BY mean_exec_time DESC LIMIT 10;
"
```

## 🚨 Rollback Procedures

### If Restoration Fails

#### 1. Stop All Services

```bash
docker-compose -f docker-compose.prod.yml down
```

#### 2. Restore from Previous Known Good State

```bash
# Restore previous volume snapshots
./restore-volumes.sh --date=20240114_120000

# Restore previous database backups
./restore-databases.sh --date=20240114_120000
```

#### 3. Activate Backup Site (if available)

```bash
# Switch DNS to backup site
# Update load balancer configuration
# Notify users of temporary service location
```

## 📚 Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

### Target Metrics

- **RTO (Recovery Time Objective)**: 4 hours maximum downtime
- **RPO (Recovery Point Objective)**: Maximum 1 hour data loss

### Service Priority Levels

#### Critical (RTO: 30 minutes)

- User authentication service
- Payment processing
- Core API endpoints

#### Important (RTO: 2 hours)

- Order processing
- Notification service
- Monitoring systems

#### Standard (RTO: 4 hours)

- Reporting systems
- Analytics dashboards
- Log aggregation

## 📞 Emergency Contacts

### Restoration Team

- **Database Administrator**: +1-555-0101
- **Infrastructure Lead**: +1-555-0102
- **Security Officer**: +1-555-0103
- **Business Continuity Manager**: +1-555-0104

### Escalation Path

1. **Level 1**: On-call engineer attempts restoration
2. **Level 2**: Database administrator joins (if > 1 hour)
3. **Level 3**: Infrastructure lead joins (if > 2 hours)
4. **Level 4**: Management notification (if > 4 hours)

## 📝 Post-Restoration Tasks

### Immediate (0-2 hours)

- [ ] Verify all services are healthy
- [ ] Run smoke tests on critical functions
- [ ] Monitor error rates and performance
- [ ] Update incident tracking system

### Short-term (2-24 hours)

- [ ] Perform comprehensive testing
- [ ] Review and analyze root cause
- [ ] Update documentation based on lessons learned
- [ ] Schedule post-incident review meeting

### Long-term (1-7 days)

- [ ] Conduct full security audit
- [ ] Review and update backup procedures
- [ ] Implement additional monitoring if needed
- [ ] Update disaster recovery procedures

## 🔍 Troubleshooting Common Issues

### Database Connection Errors After Restore

```bash
# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres-user

# Verify user permissions
docker-compose -f docker-compose.prod.yml exec postgres-user psql -U postgres -c "\du"

# Reset connection pools
docker-compose -f docker-compose.prod.yml restart user-service order-service
```

### Volume Mount Issues

```bash
# Check volume exists
docker volume ls | grep lab06

# Inspect volume details
docker volume inspect lab06_postgres-user-data

# Fix permissions
docker run --rm -v lab06_postgres-user-data:/data alpine:latest chmod -R 700 /data
```

### SSL Certificate Problems

```bash
# Verify certificate files
ls -la ssl/certificates/

# Test certificate validity
openssl x509 -in ssl/certificates/cert.pem -text -noout

# Regenerate if necessary
./ssl/generate-certs.sh your-domain.com
```

Remember: **Always test restore procedures regularly** and keep this documentation updated with any changes to the system architecture or backup strategies.
