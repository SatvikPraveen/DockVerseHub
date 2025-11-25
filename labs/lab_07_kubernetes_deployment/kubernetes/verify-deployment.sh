#!/bin/bash

# Lab 07 Verification Script
# Checks the health and status of deployed resources

NAMESPACE="lab-07"

echo "======================================"
echo "Lab 07: Deployment Verification"
echo "======================================"
echo ""

# Check cluster
echo "1. Cluster Status:"
if kubectl cluster-info &> /dev/null; then
    echo "   ✅ Kubernetes cluster is running"
else
    echo "   ❌ Kubernetes cluster is not accessible"
    exit 1
fi
echo ""

# Check namespace
echo "2. Namespace Status:"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "   ✅ Namespace '$NAMESPACE' exists"
else
    echo "   ❌ Namespace '$NAMESPACE' not found"
    exit 1
fi
echo ""

# Check deployments
echo "3. Deployment Status:"
kubectl get deployments -n "$NAMESPACE" -o wide
echo ""

# Check pods
echo "4. Pod Status:"
PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers -q)
if [ -z "$PODS" ]; then
    echo "   ⚠️  No pods found"
else
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    
    # Check pod readiness
    READY=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
    TOTAL=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$READY" -eq "$TOTAL" ]; then
        echo "   ✅ All pods are ready ($READY/$TOTAL)"
    else
        echo "   ⚠️  Not all pods are ready ($READY/$TOTAL)"
    fi
fi
echo ""

# Check services
echo "5. Service Status:"
kubectl get services -n "$NAMESPACE" -o wide
echo ""

# Check ingress
echo "6. Persistent Volumes:"
kubectl get pvc -n "$NAMESPACE"
echo ""

# Check ConfigMap and Secret
echo "7. Configuration:"
echo "   ConfigMaps:"
kubectl get configmap -n "$NAMESPACE" --no-headers
echo "   Secrets:"
kubectl get secret -n "$NAMESPACE" --no-headers | grep -v default-token
echo ""

# Health checks
echo "8. Application Health Checks:"

# API health
API_POD=$(kubectl get pods -n "$NAMESPACE" -l app=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$API_POD" ]; then
    echo "   Checking API pod: $API_POD"
    if kubectl exec -n "$NAMESPACE" "$API_POD" -- curl -f http://localhost:5000/health &> /dev/null; then
        echo "   ✅ API is healthy"
    else
        echo "   ⚠️  API health check failed"
    fi
else
    echo "   ⚠️  No API pods found"
fi

# Database connectivity
DB_POD=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$DB_POD" ]; then
    echo "   Checking Database pod: $DB_POD"
    if kubectl exec -n "$NAMESPACE" "$DB_POD" -- pg_isready -U postgres &> /dev/null; then
        echo "   ✅ PostgreSQL is healthy"
    else
        echo "   ⚠️  PostgreSQL health check failed"
    fi
else
    echo "   ⚠️  No PostgreSQL pods found"
fi
echo ""

# Resource usage
echo "9. Resource Usage:"
if kubectl top nodes &> /dev/null 2>&1; then
    echo "   Nodes:"
    kubectl top nodes
    echo ""
    echo "   Pods:"
    kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "   ⚠️  Metrics not available yet (pod restart may be needed)"
else
    echo "   ⚠️  Metrics server not installed"
fi
echo ""

# Next steps
echo "======================================"
echo "Verification Summary:"
echo "======================================"
echo ""
echo "Port-forward to access the application:"
echo "  kubectl port-forward service/frontend 3000:80 -n $NAMESPACE"
echo ""
echo "View logs:"
echo "  kubectl logs deployment/api -n $NAMESPACE"
echo "  kubectl logs deployment/frontend -n $NAMESPACE"
echo "  kubectl logs deployment/postgres -n $NAMESPACE"
echo ""
