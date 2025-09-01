# Migration Strategies: VM to Container & Platform Transitions

**Location: `docs/migration-strategies.md`**

## Migration Overview

Container migration involves transitioning from traditional infrastructure (VMs, bare metal) to containerized environments, or moving between different container platforms. This requires careful planning, gradual implementation, and risk mitigation strategies.

## VM to Container Migration

### Assessment Phase

```bash
#!/bin/bash
# vm-assessment.sh - Analyze VMs for containerization readiness

VM_LIST="vm1.example.com vm2.example.com vm3.example.com"

for VM in $VM_LIST; do
    echo "=== Assessing $VM ==="

    # System info
    ssh $VM "uname -a; cat /etc/os-release"

    # Resource usage
    ssh $VM "free -h; df -h; lscpu | grep 'CPU(s)'"

    # Running services
    ssh $VM "systemctl --type=service --state=running"

    # Network connections
    ssh $VM "netstat -tulpn | grep LISTEN"

    # Installed packages
    ssh $VM "dpkg -l | wc -l" 2>/dev/null || ssh $VM "rpm -qa | wc -l"

    # Process analysis
    ssh $VM "ps aux --sort=-%cpu | head -10"

    echo "==============================="
done
```

### Migration Decision Matrix

| Application Type       | Containerization Difficulty | Strategy                          |
| ---------------------- | --------------------------- | --------------------------------- |
| **Stateless Web Apps** | Easy                        | Direct migration                  |
| **Microservices**      | Easy                        | Direct migration                  |
| **Databases**          | Medium                      | Use managed services or operators |
| **Monoliths**          | Hard                        | Gradual decomposition             |
| **Legacy Systems**     | Hard                        | Keep on VMs initially             |
| **File Servers**       | Medium                      | Use persistent volumes            |

### Containerization Patterns

#### Lift and Shift

```dockerfile
# Simple lift and shift approach
FROM ubuntu:20.04

# Install all VM packages
RUN apt-get update && apt-get install -y \
    apache2 \
    mysql-server \
    php7.4 \
    php7.4-mysql \
    && rm -rf /var/lib/apt/lists/*

# Copy entire application
COPY /var/www/html /var/www/html
COPY /etc/apache2/sites-available /etc/apache2/sites-available

# Start all services (not recommended)
CMD service mysql start && apache2ctl -D FOREGROUND
```

#### Decomposition Approach

```yaml
# docker-compose.yml - Decomposed application
version: "3.8"
services:
  web:
    build: ./web
    ports:
      - "80:80"
    depends_on:
      - api
      - database
    environment:
      - API_URL=http://api:3000

  api:
    build: ./api
    ports:
      - "3000:3000"
    depends_on:
      - database
    environment:
      - DB_HOST=database
      - DB_PORT=3306

  database:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=rootpass
      - MYSQL_DATABASE=myapp
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
```

### Migration Tools

#### VM to Container Tools

```bash
# P2C (Physical to Container) using img2docker
pip install img2docker
img2docker vm-backup.tar myapp:migrated

# Using Kubernetes migration tools
# Crane (VMware)
crane export vm://vcenter.example.com/vm/myvm myvm.ova
crane import myvm.ova docker://myapp:migrated

# Velero for Kubernetes migrations
velero backup create vm-migration --include-resources=*
```

#### Database Migration

```bash
#!/bin/bash
# database-migration.sh

# Export from VM
ssh vm.example.com "mysqldump -u root -p myapp > /tmp/myapp.sql"
scp vm.example.com:/tmp/myapp.sql ./

# Import to container
docker exec -i mysql-container mysql -u root -p myapp < myapp.sql

# Verify migration
docker exec mysql-container mysql -u root -p -e "SHOW TABLES;" myapp
```

## Platform Migration Strategies

### Docker Swarm to Kubernetes

#### Configuration Conversion

```bash
# Install kompose
curl -L https://github.com/kubernetes/kompose/releases/download/v1.26.1/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv ./kompose /usr/local/bin/kompose

# Convert docker-compose to Kubernetes
kompose convert -f docker-compose.yml
```

```yaml
# Original docker-compose.yml
version: "3.8"
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s

# Generated Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      io.kompose.service: web
  template:
    metadata:
      labels:
        io.kompose.service: web
    spec:
      containers:
        - image: nginx:alpine
          name: web
          ports:
            - containerPort: 80
```

#### Migration Script

```bash
#!/bin/bash
# swarm-to-k8s-migration.sh

NAMESPACE="migrated-app"
COMPOSE_FILE="docker-compose.yml"

echo "=== Swarm to Kubernetes Migration ==="

# Create namespace
kubectl create namespace $NAMESPACE

# Convert compose file
kompose convert -f $COMPOSE_FILE -o k8s/

# Apply Kubernetes manifests
kubectl apply -f k8s/ -n $NAMESPACE

# Migrate secrets
docker secret ls --format "{{.Name}}" | while read secret; do
    docker secret inspect $secret --format '{{.Spec.Data}}' | base64 -d | \
    kubectl create secret generic $secret --from-file=- -n $NAMESPACE
done

# Migrate configs
docker config ls --format "{{.Name}}" | while read config; do
    docker config inspect $config --format '{{.Spec.Data}}' | base64 -d | \
    kubectl create configmap $config --from-file=- -n $NAMESPACE
done

echo "Migration completed. Verify with: kubectl get all -n $NAMESPACE"
```

### Kubernetes to Docker Swarm

#### Reverse Migration

```python
#!/usr/bin/env python3
# k8s-to-swarm.py - Convert Kubernetes to Docker Compose

import yaml
import sys

def convert_deployment_to_service(deployment):
    """Convert Kubernetes Deployment to Docker Compose service"""
    service = {}

    # Basic service configuration
    container = deployment['spec']['template']['spec']['containers'][0]
    service['image'] = container['image']

    # Replicas
    if 'replicas' in deployment['spec']:
        service['deploy'] = {
            'replicas': deployment['spec']['replicas']
        }

    # Ports
    if 'ports' in container:
        service['ports'] = []
        for port in container['ports']:
            service['ports'].append(f"{port['containerPort']}:{port['containerPort']}")

    # Environment variables
    if 'env' in container:
        service['environment'] = {}
        for env in container['env']:
            service['environment'][env['name']] = env['value']

    return service

def main():
    if len(sys.argv) != 2:
        print("Usage: python k8s-to-swarm.py deployment.yaml")
        sys.exit(1)

    with open(sys.argv[1], 'r') as file:
        k8s_manifest = yaml.safe_load(file)

    compose = {
        'version': '3.8',
        'services': {}
    }

    if k8s_manifest['kind'] == 'Deployment':
        service_name = k8s_manifest['metadata']['name']
        compose['services'][service_name] = convert_deployment_to_service(k8s_manifest)

    print(yaml.dump(compose, default_flow_style=False))

if __name__ == "__main__":
    main()
```

## Cloud Migration

### On-Premises to Cloud

#### AWS Migration

```yaml
# aws-migration.yml
version: "3.8"
services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.labels.region == us-west-2a

  database:
    image: postgres:13
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - type: volume
        source: db_data
        target: /var/lib/postgresql/data
        volume:
          driver: rexray/ebs
          driver_opts:
            size: 100
            volumetype: gp2

secrets:
  db_password:
    external: true

volumes:
  db_data:
    driver: rexray/ebs
```

#### Azure Migration

```bash
# azure-migration.sh
#!/bin/bash

RESOURCE_GROUP="myapp-rg"
ACR_NAME="myappregistry"
AKS_CLUSTER="myapp-cluster"

# Create Azure resources
az group create --name $RESOURCE_GROUP --location eastus
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
az aks create --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --node-count 3

# Push images to ACR
az acr login --name $ACR_NAME
docker tag myapp:latest $ACR_NAME.azurecr.io/myapp:latest
docker push $ACR_NAME.azurecr.io/myapp:latest

# Deploy to AKS
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER
kubectl apply -f k8s-manifests/
```

### Multi-Cloud Strategy

```yaml
# multi-cloud-compose.yml
version: "3.8"
services:
  app-aws:
    image: myapp:latest
    deploy:
      placement:
        constraints:
          - node.labels.cloud == aws
      replicas: 2

  app-azure:
    image: myapp:latest
    deploy:
      placement:
        constraints:
          - node.labels.cloud == azure
      replicas: 2

  load-balancer:
    image: haproxy:alpine
    configs:
      - source: haproxy_config
        target: /usr/local/etc/haproxy/haproxy.cfg
    ports:
      - "80:80"

configs:
  haproxy_config:
    external: true
```

## Database Migration Strategies

### Relational Database Migration

#### PostgreSQL Migration

```bash
#!/bin/bash
# postgres-migration.sh

OLD_HOST="vm.example.com"
NEW_HOST="postgres-container"
DATABASE="myapp"

echo "=== PostgreSQL Migration ==="

# 1. Create dump from old server
pg_dump -h $OLD_HOST -U postgres $DATABASE > backup.sql

# 2. Start new PostgreSQL container
docker run -d \
  --name postgres-new \
  -e POSTGRES_DB=$DATABASE \
  -e POSTGRES_PASSWORD=newpassword \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:13

# 3. Wait for container to be ready
while ! docker exec postgres-new pg_isready; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done

# 4. Import data
cat backup.sql | docker exec -i postgres-new psql -U postgres $DATABASE

# 5. Verify migration
docker exec postgres-new psql -U postgres -d $DATABASE -c "\dt"

echo "Migration completed"
```

#### MySQL Migration

```python
#!/usr/bin/env python3
# mysql-migration.py

import subprocess
import time
import os

def run_command(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.returncode == 0, result.stdout, result.stderr

def migrate_mysql():
    old_host = "vm.example.com"
    database = "myapp"

    print("=== MySQL Migration ===")

    # Export data
    print("Exporting data...")
    success, out, err = run_command(f"mysqldump -h {old_host} -u root -p {database} > backup.sql")
    if not success:
        print(f"Export failed: {err}")
        return False

    # Start new MySQL container
    print("Starting new MySQL container...")
    success, _, _ = run_command("""
        docker run -d \
          --name mysql-new \
          -e MYSQL_ROOT_PASSWORD=newpassword \
          -e MYSQL_DATABASE=myapp \
          -v mysql_data:/var/lib/mysql \
          mysql:8.0
    """)

    # Wait for MySQL to be ready
    print("Waiting for MySQL to be ready...")
    for _ in range(30):
        success, _, _ = run_command("docker exec mysql-new mysqladmin ping -u root -pnewpassword")
        if success:
            break
        time.sleep(2)
    else:
        print("MySQL failed to start")
        return False

    # Import data
    print("Importing data...")
    success, _, err = run_command("cat backup.sql | docker exec -i mysql-new mysql -u root -pnewpassword myapp")
    if not success:
        print(f"Import failed: {err}")
        return False

    print("Migration completed successfully")
    return True

if __name__ == "__main__":
    migrate_mysql()
```

### NoSQL Database Migration

#### MongoDB Migration

```javascript
// mongodb-migration.js
const { MongoClient } = require("mongodb");

async function migrateMongoData() {
  // Source connection
  const sourceClient = new MongoClient("mongodb://old-server:27017", {
    useUnifiedTopology: true,
  });

  // Target connection
  const targetClient = new MongoClient("mongodb://mongodb-container:27017", {
    useUnifiedTopology: true,
  });

  try {
    await sourceClient.connect();
    await targetClient.connect();

    const sourceDb = sourceClient.db("myapp");
    const targetDb = targetClient.db("myapp");

    // Get collections
    const collections = await sourceDb.listCollections().toArray();

    for (const collection of collections) {
      const collectionName = collection.name;
      console.log(`Migrating collection: ${collectionName}`);

      // Export data
      const documents = await sourceDb
        .collection(collectionName)
        .find()
        .toArray();

      // Import data
      if (documents.length > 0) {
        await targetDb.collection(collectionName).insertMany(documents);
      }

      console.log(`Migrated ${documents.length} documents`);
    }

    console.log("Migration completed successfully");
  } catch (error) {
    console.error("Migration failed:", error);
  } finally {
    await sourceClient.close();
    await targetClient.close();
  }
}

migrateMongoData();
```

## Application Refactoring

### Monolith to Microservices

#### Service Extraction

```python
# Original monolith structure
# monolith/
# ├── app.py (all functionality)
# ├── models.py
# └── requirements.txt

# Extracted microservices
# user-service/
# ├── app.py
# ├── models/user.py
# └── requirements.txt
#
# order-service/
# ├── app.py
# ├── models/order.py
# └── requirements.txt
#
# notification-service/
# ├── app.py
# ├── models/notification.py
# └── requirements.txt
```

```yaml
# microservices-compose.yml
version: "3.8"
services:
  user-service:
    build: ./user-service
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/users
    networks:
      - backend

  order-service:
    build: ./order-service
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/orders
      - USER_SERVICE_URL=http://user-service:5000
    networks:
      - backend

  notification-service:
    build: ./notification-service
    environment:
      - RABBITMQ_URL=amqp://rabbitmq:5672
    networks:
      - backend

  api-gateway:
    build: ./api-gateway
    ports:
      - "80:80"
    environment:
      - USER_SERVICE=user-service:5000
      - ORDER_SERVICE=order-service:5000
    networks:
      - frontend
      - backend

networks:
  frontend:
  backend:
```

### Strangler Fig Pattern

```yaml
# strangler-fig-compose.yml
version: "3.8"
services:
  # Legacy monolith
  legacy-app:
    image: legacy-monolith:latest
    networks:
      - backend

  # New microservices
  user-service:
    image: user-service:latest
    networks:
      - backend

  order-service:
    image: order-service:latest
    networks:
      - backend

  # Proxy to route traffic
  nginx-proxy:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-strangler.conf:/etc/nginx/nginx.conf
    networks:
      - frontend
      - backend

networks:
  frontend:
  backend:
```

```nginx
# nginx-strangler.conf
upstream legacy {
    server legacy-app:8080;
}

upstream user_service {
    server user-service:5000;
}

upstream order_service {
    server order-service:5000;
}

server {
    listen 80;

    # Route new endpoints to microservices
    location /api/users/ {
        proxy_pass http://user_service;
    }

    location /api/orders/ {
        proxy_pass http://order_service;
    }

    # Everything else to legacy
    location / {
        proxy_pass http://legacy;
    }
}
```

## Migration Best Practices

### Pre-Migration Checklist

```bash
#!/bin/bash
# pre-migration-checklist.sh

echo "=== Pre-Migration Checklist ==="

# 1. Application assessment
echo "□ Application dependencies mapped"
echo "□ Database schema documented"
echo "□ Configuration externalized"
echo "□ Secrets identified and secured"
echo "□ Network dependencies mapped"
echo "□ Storage requirements analyzed"
echo "□ Performance baselines established"
echo "□ Rollback plan prepared"

# 2. Infrastructure readiness
echo "□ Container registry available"
echo "□ Orchestration platform ready"
echo "□ Monitoring tools configured"
echo "□ Backup systems in place"
echo "□ Network policies defined"
echo "□ Security scanning enabled"

# 3. Team preparation
echo "□ Team trained on containers"
echo "□ Runbooks updated"
echo "□ Emergency procedures defined"
echo "□ Communication plan ready"
```

### Migration Phases

#### Phase 1: Lift and Shift

```yaml
# phase1-lift-shift.yml
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.liftshift
    ports:
      - "80:80"
    volumes:
      - app_data:/var/lib/app
    environment:
      - LEGACY_MODE=true

volumes:
  app_data:
```

#### Phase 2: Optimize and Decompose

```yaml
# phase2-optimize.yml
version: "3.8"
services:
  frontend:
    build: ./frontend
    ports:
      - "80:80"

  api:
    build: ./api
    environment:
      - DATABASE_URL=postgresql://db:5432/myapp

  database:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

#### Phase 3: Cloud Native

```yaml
# phase3-cloud-native.yml
version: "3.8"
services:
  frontend:
    image: myregistry/frontend:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s

  api:
    image: myregistry/api:latest
    deploy:
      replicas: 5
    secrets:
      - db_password

  cache:
    image: redis:alpine
    deploy:
      replicas: 1

secrets:
  db_password:
    external: true
```

### Migration Validation

```bash
#!/bin/bash
# migration-validation.sh

SERVICE_NAME=$1
LEGACY_URL=$2
NEW_URL=$3

echo "=== Migration Validation ==="
echo "Service: $SERVICE_NAME"

# Performance comparison
echo "Running performance tests..."
ab -n 1000 -c 10 $LEGACY_URL/api/health > legacy_perf.txt
ab -n 1000 -c 10 $NEW_URL/api/health > new_perf.txt

# Functional tests
echo "Running functional tests..."
curl -f $NEW_URL/api/health || echo "Health check failed"
curl -f $NEW_URL/api/users || echo "Users API failed"

# Data validation
echo "Validating data consistency..."
LEGACY_COUNT=$(curl -s $LEGACY_URL/api/users/count)
NEW_COUNT=$(curl -s $NEW_URL/api/users/count)

if [ "$LEGACY_COUNT" = "$NEW_COUNT" ]; then
    echo "✓ Data counts match: $LEGACY_COUNT"
else
    echo "✗ Data counts differ: Legacy=$LEGACY_COUNT, New=$NEW_COUNT"
fi

echo "Validation completed"
```

## Rollback Strategies

### Automated Rollback

```bash
#!/bin/bash
# automated-rollback.sh

SERVICE_NAME=$1
HEALTH_ENDPOINT=$2
MAX_FAILURES=5
FAILURE_COUNT=0

echo "Monitoring service health: $SERVICE_NAME"

while true; do
    if curl -f $HEALTH_ENDPOINT >/dev/null 2>&1; then
        echo "$(date): Health check passed"
        FAILURE_COUNT=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo "$(date): Health check failed ($FAILURE_COUNT/$MAX_FAILURES)"

        if [ $FAILURE_COUNT -ge $MAX_FAILURES ]; then
            echo "Initiating rollback..."
            docker service rollback $SERVICE_NAME
            break
        fi
    fi

    sleep 30
done
```

### Blue-Green Rollback

```bash
#!/bin/bash
# blue-green-rollback.sh

CURRENT_ENV=$(docker-compose -f docker-compose.nginx.yml exec nginx cat /etc/nginx/conf.d/upstream.conf | grep -o 'blue\|green')
ROLLBACK_ENV=$([ "$CURRENT_ENV" = "blue" ] && echo "green" || echo "blue")

echo "Current: $CURRENT_ENV, Rolling back to: $ROLLBACK_ENV"

# Switch traffic back
cat > nginx/upstream.conf << EOF
upstream app_backend {
    server ${ROLLBACK_ENV}-app:3000;
}
EOF

docker-compose -f docker-compose.nginx.yml exec nginx nginx -s reload
echo "Rollback completed"
```

## Next Steps

- Learn [Cost Optimization](./cost-optimization.md) post-migration
- Check [Performance Optimization](./performance-optimization.md) for migrated workloads
- Explore [Troubleshooting](./troubleshooting.md) migration issues
- Understand [Production Deployment](./production-deployment.md) best practices
