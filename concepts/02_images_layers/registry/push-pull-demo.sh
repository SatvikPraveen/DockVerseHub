#!/bin/bash
# File Location: concepts/02_images_layers/registry/push-pull-demo.sh

set -e

REGISTRY_NAME="demo-registry"
REGISTRY_PORT="5000"
IMAGE_NAME="demo-app"

echo "======================================"
echo "    Docker Registry Push/Pull Demo"
echo "======================================"

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker is not running"
    exit 1
fi

echo "1. Starting local Docker registry..."
docker run -d -p ${REGISTRY_PORT}:5000 --name ${REGISTRY_NAME} registry:2 || {
    echo "Registry may already be running, continuing..."
    docker start ${REGISTRY_NAME} 2>/dev/null || true
}

# Wait for registry to be ready
sleep 3
echo "Registry running at localhost:${REGISTRY_PORT}"

echo -e "\n2. Building sample application image..."
mkdir -p /tmp/demo-app
cat > /tmp/demo-app/Dockerfile << 'EOF'
FROM alpine:latest
RUN echo '#!/bin/sh' > /hello.sh && \
    echo 'echo "Hello from registry demo!"' >> /hello.sh && \
    echo 'echo "Image: $IMAGE_NAME"' >> /hello.sh && \
    echo 'echo "Built: $(date)"' >> /hello.sh && \
    chmod +x /hello.sh
CMD ["/hello.sh"]
EOF

cd /tmp/demo-app
docker build -t ${IMAGE_NAME}:latest .

echo -e "\n3. Tagging image for local registry..."
docker tag ${IMAGE_NAME}:latest localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0
docker tag ${IMAGE_NAME}:latest localhost:${REGISTRY_PORT}/${IMAGE_NAME}:latest

echo -e "\n4. Pushing to local registry..."
docker push localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0
docker push localhost:${REGISTRY_PORT}/${IMAGE_NAME}:latest

echo -e "\n5. Listing registry contents..."
curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog | jq .

echo -e "\n6. Getting image tags..."
curl -s http://localhost:${REGISTRY_PORT}/v2/${IMAGE_NAME}/tags/list | jq .

echo -e "\n7. Removing local images..."
docker rmi ${IMAGE_NAME}:latest
docker rmi localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0
docker rmi localhost:${REGISTRY_PORT}/${IMAGE_NAME}:latest

echo -e "\n8. Pulling from registry..."
docker pull localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0

echo -e "\n9. Testing pulled image..."
docker run --rm localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0

echo -e "\n10. Registry API examples..."
echo "Available endpoints:"
echo "- Catalog: curl http://localhost:${REGISTRY_PORT}/v2/_catalog"
echo "- Tags: curl http://localhost:${REGISTRY_PORT}/v2/${IMAGE_NAME}/tags/list"
echo "- Manifest: curl http://localhost:${REGISTRY_PORT}/v2/${IMAGE_NAME}/manifests/v1.0"

echo -e "\nDemo completed! Clean up with:"
echo "docker stop ${REGISTRY_NAME} && docker rm ${REGISTRY_NAME}"
echo "docker rmi registry:2"
echo "rm -rf /tmp/demo-app"

# Cleanup function
cleanup() {
    echo -e "\nCleaning up..."
    docker stop ${REGISTRY_NAME} 2>/dev/null || true
    docker rm ${REGISTRY_NAME} 2>/dev/null || true
    docker rmi localhost:${REGISTRY_PORT}/${IMAGE_NAME}:v1.0 2>/dev/null || true
    rm -rf /tmp/demo-app
}

# Ask user if they want to clean up now
read -p "Clean up now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cleanup
fi