#!/bin/bash
# File Location: concepts/06_security/image-signing/notary-demo.sh

set -e

echo "Docker Content Trust (Notary) Demo"
echo "=================================="

# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.docker.io

echo "1. Docker Content Trust enabled"
echo "DOCKER_CONTENT_TRUST: $DOCKER_CONTENT_TRUST"

# Build and sign an image
echo -e "\n2. Building and signing image..."
docker build -t myrepo/signed-app:v1.0 .

echo -e "\n3. Pushing signed image..."
docker push myrepo/signed-app:v1.0

echo -e "\n4. Pulling signed image..."
docker pull myrepo/signed-app:v1.0

echo -e "\n5. Listing trust data..."
docker trust inspect myrepo/signed-app:v1.0

# Disable DCT and try to pull unsigned image
echo -e "\n6. Testing unsigned image pull..."
export DOCKER_CONTENT_TRUST=0
docker pull alpine:unsigned || echo "Failed to pull unsigned image (good)"

echo -e "\nNotary demo completed!"