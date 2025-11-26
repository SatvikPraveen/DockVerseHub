# Lab 07 Exercises

## Exercise Set: Hands-On Kubernetes

These exercises build on the concepts from Module 11 and the deployed Lab 07 application. Complete these practical scenarios to master Kubernetes deployment and operations.

---

## ✅ Exercise 1: Deployment Status and Viewing

**Objective:** Understand how to monitor deployment status

### Tasks:

1. View all deployments in the lab namespace:
```bash
kubectl get deployments -n lab-07
```

2. Get detailed information about the API deployment:
```bash
kubectl describe deployment api -n lab-07
```

3. View the deployment YAML:
```bash
kubectl get deployment api -o yaml -n lab-07
```

4. Check rollout status:
```bash
kubectl rollout status deployment/api -n lab-07
```

### Questions:
- How many replicas are configured?
- What image is being used?
- What probes are configured?

---

## ✅ Exercise 2: Pod Inspection and Logs

**Objective:** Debug application issues using logs

### Tasks:

1. List all pods:
```bash
kubectl get pods -n lab-07
```

2. View API pod logs:
```bash
kubectl logs deployment/api -n lab-07
```

3. Follow logs in real-time:
```bash
kubectl logs -f deployment/api -n lab-07
```

4. View logs from a specific pod:
```bash
POD_NAME=$(kubectl get pods -n lab-07 -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n lab-07
```

5. View previous pod logs (if a pod restarted):
```bash
kubectl logs deployment/api -n lab-07 --previous
```

### Questions:
- What initialization messages do you see?
- What is the API listening on?

---

## ✅ Exercise 3: Port-Forwarding and Testing

**Objective:** Access services from your local machine

### Tasks:

1. Port-forward to the frontend:
```bash
kubectl port-forward service/frontend 3000:80 -n lab-07
```
Then visit http://localhost:3000 in your browser

2. In another terminal, port-forward to the API:
```bash
kubectl port-forward service/api-service 5000:5000 -n lab-07
```

3. Test the API health endpoint:
```bash
curl http://localhost:5000/health
```

4. Get all users:
```bash
curl http://localhost:5000/api/users | json_pp
```

5. Create a new user:
```bash
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com"}' | json_pp
```

### Questions:
- Can you create a new user via the API?
- Does it appear in the frontend interface?

---

## ✅ Exercise 4: Scaling Deployments

**Objective:** Understand horizontal pod autoscaling

### Tasks:

1. View current replicas:
```bash
kubectl get deployment api -n lab-07
```

2. Scale to 3 replicas:
```bash
kubectl scale deployment api --replicas=3 -n lab-07
```

3. Watch scaling in real-time:
```bash
kubectl get pods -n lab-07 -l app=api --watch
```

4. Verify all 3 are running:
```bash
kubectl get pods -n lab-07 -l app=api
```

5. Scale back down:
```bash
kubectl scale deployment api --replicas=2 -n lab-07
```

### Questions:
- How long does it take for new pods to become ready?
- What happens to the old pods when scaling down?

---

## ✅ Exercise 5: Rolling Updates

**Objective:** Understand how Kubernetes handles deployment updates

### Tasks:

1. Check current image:
```bash
kubectl get deployment api -o jsonpath='{.spec.template.spec.containers[0].image}' -n lab-07
```

2. Simulate an update (change image tag):
```bash
kubectl set image deployment/api api=lab-07-api:v2.0 -n lab-07
```

3. Monitor the rollout:
```bash
kubectl rollout status deployment/api -n lab-07
```

4. Watch pods during update:
```bash
kubectl get pods -n lab-07 -l app=api --watch
```

5. Check rollout history:
```bash
kubectl rollout history deployment/api -n lab-07
```

6. Rollback to previous version:
```bash
kubectl rollout undo deployment/api -n lab-07
```

7. Verify rollback:
```bash
kubectl rollout status deployment/api -n lab-07
```

### Questions:
- How many pods are running during a rolling update?
- What's the maxSurge and maxUnavailable configuration?

---

## ✅ Exercise 6: ConfigMap and Secret Management

**Objective:** Manage application configuration

### Tasks:

1. View ConfigMap:
```bash
kubectl get configmap app-config -n lab-07 -o yaml
```

2. Edit ConfigMap:
```bash
kubectl edit configmap app-config -n lab-07
```

3. Verify changes:
```bash
kubectl get configmap app-config -n lab-07 -o yaml
```

4. Restart deployments to pick up changes:
```bash
kubectl rollout restart deployment/api -n lab-07
kubectl rollout restart deployment/frontend -n lab-07
```

5. View Secret (encrypted):
```bash
kubectl get secret app-secret -n lab-07 -o yaml
```

6. Decode a secret:
```bash
kubectl get secret app-secret -n lab-07 -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d
```

### Questions:
- What happens when you edit a ConfigMap?
- Do pods automatically reload the new config?
- Why are Secrets base64-encoded?

---

## ✅ Exercise 7: Connecting to Database

**Objective:** Debug database connectivity

### Tasks:

1. Get PostgreSQL pod name:
```bash
POD=$(kubectl get pods -n lab-07 -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo $POD
```

2. Execute psql inside the pod:
```bash
kubectl exec -it $POD -n lab-07 -- psql -U postgres
```

3. Inside psql:
```sql
\l                          -- List databases
\c lab07                    -- Connect to lab database
\dt                         -- List tables
SELECT * FROM users;       -- View users
\q                          -- Exit
```

4. Port-forward to database:
```bash
kubectl port-forward service/postgres-service 5432:5432 -n lab-07
```

5. Connect from local machine (in another terminal):
```bash
psql -h localhost -U postgres -d lab07
```

### Questions:
- What tables exist in the database?
- How many users are in the database?
- Can you insert a row?

---

## ✅ Exercise 8: Troubleshooting Common Issues

**Objective:** Develop debugging skills

### Scenarios:

**Scenario A: Pod in CrashLoopBackOff**
```bash
# View pod events
kubectl describe pod <pod-name> -n lab-07

# View logs
kubectl logs <pod-name> -n lab-07

# Try previous logs
kubectl logs <pod-name> -n lab-07 --previous
```

**Scenario B: Service not accessible**
```bash
# Check endpoints
kubectl get endpoints api-service -n lab-07

# Check service definition
kubectl get service api-service -n lab-07 -o yaml

# Check selector matches pods
kubectl get pods -n lab-07 -L app
```

**Scenario C: Pod pending**
```bash
# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl describe pod <pod-name> -n lab-07

# Check events
kubectl get events -n lab-07
```

### Tasks:

1. Delete a pod and watch it auto-restart:
```bash
POD=$(kubectl get pods -n lab-07 -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD -n lab-07
kubectl get pods -n lab-07 -l app=api --watch
```

2. Scale to 0 and back:
```bash
kubectl scale deployment api --replicas=0 -n lab-07
kubectl get pods -n lab-07
kubectl scale deployment api --replicas=2 -n lab-07
```

3. Check resource limits:
```bash
kubectl describe pod <pod-name> -n lab-07 | grep -A 5 "Limits\|Requests"
```

### Questions:
- What happens when a pod is deleted?
- How does Kubernetes ensure the desired replica count?

---

## ✅ Exercise 9: Advanced - Deploy with Minikube Ingress

**Objective:** Use Ingress for HTTP routing (Optional, requires advanced setup)

### Tasks:

1. Enable Ingress addon:
```bash
minikube addons enable ingress
```

2. Create an Ingress resource (advanced):
```bash
cat > ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: lab-07
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 5000
EOF
kubectl apply -f ingress.yaml
```

3. Get Ingress details:
```bash
kubectl get ingress -n lab-07
kubectl describe ingress app-ingress -n lab-07
```

---

## ✅ Exercise 10: Cleanup

**Objective:** Learn to clean up resources

### Tasks:

1. Delete a single resource:
```bash
kubectl delete deployment api -n lab-07
```

2. Delete all resources in namespace:
```bash
kubectl delete all -n lab-07
```

3. Delete the namespace:
```bash
kubectl delete namespace lab-07
```

4. Verify deletion:
```bash
kubectl get namespaces
kubectl get all -n lab-07  # Should error
```

### Questions:
- What gets deleted with `delete all`?
- What about PersistentVolumeClaims?
- How do you re-deploy?

---

## 🎯 Challenge Exercises

### Challenge 1: Canary Deployment
- Deploy a new version of the API to a single pod
- Gradually increase traffic to the new version
- Rollback if issues occur

### Challenge 2: Multi-Tier Scaling
- Scale different tiers independently
- Observe how services maintain communication
- Monitor impact on database

### Challenge 3: Failure Scenario
- Kill the PostgreSQL pod
- Watch application behavior
- Verify automatic recovery

### Challenge 4: Configuration Rotation
- Update database password in Secret
- Restart deployments to pick up changes
- Test connectivity

---

## 📋 Exercise Completion Checklist

- [ ] Can view deployment status and details
- [ ] Can read and follow logs
- [ ] Can port-forward and access services
- [ ] Can scale deployments
- [ ] Can perform rolling updates
- [ ] Can rollback deployments
- [ ] Can manage ConfigMaps and Secrets
- [ ] Can connect to PostgreSQL
- [ ] Can troubleshoot common issues
- [ ] Can cleanup resources
- [ ] Understand auto-healing (pod restart)
- [ ] Understand rolling update strategy

---

## 🔗 Resources

- [kubectl Cheatsheet](../../../docs/docker-cheatsheet.md)
- [Kubernetes Module 11 - Concepts](../../../concepts/11_kubernetes/)
- [Lab 06 - Docker Compose](../lab_06_production_deployment/)

