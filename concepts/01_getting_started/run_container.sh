#!/bin/bash
# File Location: concepts/01_getting_started/run_container.sh
# Script to spin up the demo containers

set -e

echo "======================================="
echo "    Docker Getting Started Demo"
echo "======================================="

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

echo "Building hello world container..."
docker build -t dockversehub/hello-world .

echo "Building interactive container..."
docker build -f Dockerfile.interactive -t dockversehub/interactive .

echo ""
echo "Demo 1: Hello World Container"
echo "Running: docker run --rm dockversehub/hello-world"
echo "-------------------------------------"
docker run --rm dockversehub/hello-world

echo ""
echo "Demo 2: Interactive Container"
echo "Running: docker run -it --rm dockversehub/interactive"
echo "-------------------------------------"
echo "Starting interactive shell... (type 'exit' to return)"
sleep 2
docker run -it --rm dockversehub/interactive

echo ""
echo "Demo completed! Images created:"
docker images | grep dockversehub

echo ""
echo "To clean up, run:"
echo "docker rmi dockversehub/hello-world dockversehub/interactive"