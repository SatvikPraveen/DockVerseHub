#!/bin/bash
# minikube-setup.sh - Setup Minikube for local Kubernetes development

set -e

echo "=========================================="
echo "Minikube Setup Script"
echo "=========================================="

# Detect OS
OS="$(uname)"

if [ "$OS" = "Darwin" ]; then
    echo "macOS detected"
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    echo "Installing Minikube via Homebrew..."
    brew install minikube
    
elif [ "$OS" = "Linux" ]; then
    echo "Linux detected"
    if ! command -v apt-get &> /dev/null; then
        echo "Error: apt-get not found. Manual installation required."
        echo "Visit: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    echo "Installing Minikube..."
    curl -LO https://github.com/kubernetes/minikube/releases/download/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Installing..."
    if [ "$OS" = "Darwin" ]; then
        brew install kubectl
    else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
fi

echo ""
echo "Verifying installation..."
minikube version
kubectl version --client

echo ""
echo "=========================================="
echo "Starting Minikube cluster..."
echo "=========================================="

minikube start --cpus=4 --memory=8192 --disk-size=20g

echo ""
echo "=========================================="
echo "Minikube Status"
echo "=========================================="
minikube status

echo ""
echo "=========================================="
echo "Testing kubectl"
echo "=========================================="
kubectl cluster-info
kubectl get nodes

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Access dashboard: minikube dashboard"
echo "2. Deploy app: kubectl apply -f deployment.yaml"
echo "3. Check services: kubectl get services"
echo "4. Port-forward: kubectl port-forward service/app 8080:80"
echo ""
echo "Useful commands:"
echo "  minikube stop      - Stop the cluster"
echo "  minikube delete    - Delete the cluster"
echo "  minikube logs      - View cluster logs"
echo "  minikube ssh       - SSH into cluster"
echo "  kubectl logs pod   - View pod logs"
echo ""
