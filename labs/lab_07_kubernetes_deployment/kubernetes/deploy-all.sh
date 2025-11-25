#!/bin/bash

# Lab 07 Deployment Script
# Deploys all Kubernetes resources for the multi-tier application

set -e

NAMESPACE="lab-07"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "======================================"
echo "Lab 07: Kubernetes Deployment Script"
echo "======================================"
echo ""

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

# Check if Minikube cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster not running."
    echo "   Run: minikube start --cpus=4 --memory=8192 --disk-size=20g"
    exit 1
fi

echo "✅ Kubernetes cluster is running"
echo ""

# Step 1: Create namespace
echo "Step 1: Creating namespace..."
if kubectl apply -f "$SCRIPT_DIR/namespace.yaml" > /dev/null; then
    echo "✅ Namespace created/verified"
else
    echo "❌ Failed to create namespace"
    exit 1
fi
echo ""

# Step 2: Create ConfigMap
echo "Step 2: Creating ConfigMap..."
if kubectl apply -f "$SCRIPT_DIR/configmap.yaml" > /dev/null; then
    echo "✅ ConfigMap created/verified"
else
    echo "❌ Failed to create ConfigMap"
    exit 1
fi
echo ""

# Step 3: Create Secret
echo "Step 3: Creating Secret..."
if kubectl apply -f "$SCRIPT_DIR/secret.yaml" > /dev/null; then
    echo "✅ Secret created/verified"
else
    echo "❌ Failed to create Secret"
    exit 1
fi
echo ""

# Step 4: Create PersistentVolumeClaim
echo "Step 4: Creating PersistentVolumeClaim..."
if kubectl apply -f "$SCRIPT_DIR/postgres-pvc.yaml" > /dev/null; then
    echo "✅ PersistentVolumeClaim created/verified"
else
    echo "❌ Failed to create PersistentVolumeClaim"
    exit 1
fi
echo ""

# Step 5: Deploy PostgreSQL
echo "Step 5: Deploying PostgreSQL..."
if kubectl apply -f "$SCRIPT_DIR/postgres-deployment.yaml" \
                 -f "$SCRIPT_DIR/postgres-service.yaml" > /dev/null; then
    echo "✅ PostgreSQL deployed"
    echo "   Waiting for PostgreSQL to be ready (this may take 30 seconds)..."
    kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=5m
    echo "✅ PostgreSQL is ready"
else
    echo "❌ Failed to deploy PostgreSQL"
    exit 1
fi
echo ""

# Step 6: Deploy API
echo "Step 6: Deploying API..."
if kubectl apply -f "$SCRIPT_DIR/api-deployment.yaml" \
                 -f "$SCRIPT_DIR/api-service.yaml" > /dev/null; then
    echo "✅ API deployed"
    echo "   Waiting for API to be ready (this may take 30 seconds)..."
    kubectl rollout status deployment/api -n "$NAMESPACE" --timeout=5m
    echo "✅ API is ready"
else
    echo "❌ Failed to deploy API"
    exit 1
fi
echo ""

# Step 7: Deploy Frontend
echo "Step 7: Deploying Frontend..."
if kubectl apply -f "$SCRIPT_DIR/frontend-deployment.yaml" \
                 -f "$SCRIPT_DIR/frontend-service.yaml" > /dev/null; then
    echo "✅ Frontend deployed"
    echo "   Waiting for Frontend to be ready (this may take 30 seconds)..."
    kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=5m
    echo "✅ Frontend is ready"
else
    echo "❌ Failed to deploy Frontend"
    exit 1
fi
echo ""

# Summary
echo "======================================"
echo "✅ Deployment Complete!"
echo "======================================"
echo ""
echo "Deployed Resources:"
kubectl get all -n "$NAMESPACE"
echo ""
echo "Services:"
echo ""
kubectl get services -n "$NAMESPACE"
echo ""
echo "Next steps:"
echo "1. Port-forward to the frontend:"
echo "   kubectl port-forward service/frontend 3000:80 -n $NAMESPACE"
echo ""
echo "2. Open your browser:"
echo "   http://localhost:3000"
echo ""
echo "3. To view logs:"
echo "   kubectl logs deployment/api -n $NAMESPACE"
echo "   kubectl logs deployment/frontend -n $NAMESPACE"
echo "   kubectl logs deployment/postgres -n $NAMESPACE"
echo ""
echo "4. To debug:"
echo "   kubectl describe pod <pod-name> -n $NAMESPACE"
echo "   kubectl exec -it pod/<pod-name> -n $NAMESPACE -- /bin/sh"
echo ""
