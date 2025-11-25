# From Docker Compose to Kubernetes

**Time:** 2 hours | **Prerequisites:** Module 1 fundamentals | **Level:** Advanced

Learn to translate Docker Compose configurations to Kubernetes manifests.

---

## Comparison: Compose vs Kubernetes

### Docker Compose File Structure

```yaml
version: '3.8'

services:
  web:
    image: nginx:1.14
    ports:
      - "80:80"
    depends_on:
      - api
    environment:
      API_URL: http://api:8080
    restart: always

  api:
    build: ./api
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://db:5432/myapp
    depends_on:
      - db
    restart: always

  db:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data
    restart: always

volumes:
  db_data:
```

### Equivalent Kubernetes Manifests

```yaml
# Kubernetes uses separate manifests for each resource

# 1. Database Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: secret
        volumeMounts:
        - name: db-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: db-storage
        persistentVolumeClaim:
          claimName: db-pvc

---

# 2. Database Service
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432

---

# 3. ConfigMap for shared config
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_URL: "postgres://db:5432/myapp"
  API_URL: "http://api:8080"

---

# 4. API Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 3  # K8s can scale this
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: myapp/api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL

---

# 5. API Service
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080

---

# 6. Web (Frontend) Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.14
        ports:
        - containerPort: 80
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: API_URL

---

# 7. Web Service (LoadBalancer for external access)
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80

---

# 8. PersistentVolumeClaim for database
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

---

## Translation Patterns

### Pattern 1: Simple Service

**Compose:**
```yaml
services:
  web:
    image: nginx:1.14
    ports:
      - "80:80"
```

**Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1  # Docker Compose runs 1 by default
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.14
        ports:
        - containerPort: 80

---

apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

### Pattern 2: Environment Variables

**Compose:**
```yaml
services:
  app:
    image: myapp:1.0
    environment:
      DATABASE_URL: postgres://db:5432/mydb
      API_KEY: my-secret-key
      DEBUG: "false"
```

**Kubernetes:**
```yaml
# Option 1: Direct environment variables
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myapp:1.0
        env:
        - name: DATABASE_URL
          value: "postgres://db:5432/mydb"
        - name: DEBUG
          value: "false"
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: api-key

---

# Option 2: Using ConfigMap (non-secret)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_URL: "postgres://db:5432/mydb"
  DEBUG: "false"

---

# Option 3: Using Secret (sensitive)
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  api-key: "my-secret-key"
```

### Pattern 3: Volumes

**Compose:**
```yaml
services:
  db:
    image: postgres:13
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
spec:
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:13
        volumeMounts:
        - name: db-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: db-storage
        persistentVolumeClaim:
          claimName: db-pvc
```

### Pattern 4: Build (Custom Images)

**Compose:**
```yaml
services:
  app:
    build: ./app    # Build from Dockerfile
    ports:
      - "8080:8080"
```

**Kubernetes:**
```yaml
# Note: K8s doesn't build images; they must be pushed to registry

# Step 1: Build and push image
# docker build -t myregistry/myapp:1.0 ./app
# docker push myregistry/myapp:1.0

# Step 2: Reference in K8s
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: app
        image: myregistry/myapp:1.0
        ports:
        - containerPort: 8080
      # For private registries:
      imagePullSecrets:
      - name: registry-secret
```

---

## Translating Depends_on

**Compose:**
```yaml
services:
  web:
    depends_on:
      - api
      - db
  api:
    depends_on:
      - db
  db:
    ...
```

**Kubernetes:**
Kubernetes doesn't have direct `depends_on`. Instead:

```yaml
# Use init containers to wait for dependencies
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      # Init containers run before main containers
      initContainers:
      - name: wait-for-api
        image: busybox
        command: ['sh', '-c', 'until wget -q http://api:8080/health; do echo waiting for api; sleep 1; done']
      - name: wait-for-db
        image: busybox
        command: ['sh', '-c', 'until wget -q http://db:5432; do echo waiting for db; sleep 1; done']
      
      containers:
      - name: web
        image: nginx:1.14
        ports:
        - containerPort: 80
```

---

## Migration Strategy

### Step 1: Analyze Compose File

```bash
# Identify:
- Services
- Networks
- Volumes
- Environment variables
- Port mappings
- Dependencies
```

### Step 2: Create Kubernetes Resources

For each service in Compose, create:
- Deployment or StatefulSet (if stateful)
- Service for network access
- ConfigMaps for configuration
- Secrets for sensitive data
- PersistentVolumeClaims if needed

### Step 3: Organize Manifests

```
kubernetes/
├── namespace.yaml           # Create namespace
├── config/
│   ├── configmap.yaml       # ConfigMaps
│   └── secret.yaml          # Secrets
├── data/
│   ├── pvc.yaml            # Persistent volumes
│   └── statefulset.yaml    # Stateful services
└── apps/
    ├── api-deployment.yaml
    ├── api-service.yaml
    ├── web-deployment.yaml
    └── web-service.yaml
```

### Step 4: Deploy

```bash
# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Create configuration
kubectl apply -f kubernetes/config/

# Create storage
kubectl apply -f kubernetes/data/

# Deploy applications
kubectl apply -f kubernetes/apps/

# Verify
kubectl get all -n your-namespace
```

---

## Full Migration Example

### Before: Docker Compose

```bash
docker-compose up -d
# Services available:
# - Frontend: http://localhost:3000
# - API: http://localhost:8000
# - Database: postgres on port 5432
```

### After: Kubernetes

```bash
# 1. Create all resources
kubectl apply -f kubernetes/

# 2. Expose frontend (get LoadBalancer IP)
kubectl get service frontend

# 3. Access
# - Frontend: http://<EXTERNAL-IP>:3000
# - API: http://<EXTERNAL-IP>:8000
# - Database: Internal only (service name: postgres)
```

---

## Key Differences to Remember

| Aspect | Docker Compose | Kubernetes |
|--------|---|---|
| **Networking** | Automatic (service name = DNS) | Same (service name = DNS) |
| **Restart** | `restart: always` | Automatic (liveness probes) |
| **Scaling** | Manual (compose scale) | Automatic (replicas, HPA) |
| **Storage** | Volumes | Persistent Volumes |
| **Secrets** | Environment files | Secrets resource |
| **Configuration** | .env files | ConfigMaps |
| **Deployment** | Single file | Multiple files |
| **Updates** | `docker-compose up` | Rolling updates (automatic) |

---

## Practice: Convert Your Compose File

1. Write down all services from your Compose file
2. For each service:
   - Create a Deployment
   - Create a Service
   - Add ConfigMaps for config
   - Add Secrets for passwords
3. Order resources logically
4. Test on Minikube
5. Refine based on testing

---

**Outcome:** Ability to convert Docker Compose to Kubernetes  
**Time:** 2 hours  
**Next:** Read deployment-patterns.md for production deployments

