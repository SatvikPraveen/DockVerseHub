# Getting Started with Docker

**File Location:** `concepts/01_getting_started/README.md`

Welcome to your Docker journey! This section covers the absolute basics to get you up and running with Docker containers.

## What is Docker?

Docker is a containerization platform that packages applications and their dependencies into lightweight, portable containers. Think of containers as standardized shipping boxes for your code - they run consistently across different environments.

## Key Concepts

### Container vs Image

- **Image**: A blueprint or template (like a class in programming)
- **Container**: A running instance of an image (like an object)

### Why Docker?

- **Consistency**: "It works on my machine" becomes "It works everywhere"
- **Isolation**: Applications run in separate environments
- **Efficiency**: Lightweight compared to virtual machines
- **Portability**: Run anywhere Docker is installed

## Quick Setup Verification

After installing Docker, verify your setup:

```bash
# Check Docker version
docker --version

# Test with hello world
docker run hello-world

# Check system info
docker system info
```

## Your First Container

Let's run a simple container:

```bash
# Pull and run Ubuntu container
docker run -it ubuntu:latest /bin/bash

# Inside the container, try:
ls
cat /etc/os-release
exit
```

## Essential Commands

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List images
docker images

# Remove a container
docker rm <container_id>

# Remove an image
docker rmi <image_name>
```

## Next Steps

1. Complete the exercises in the `exercises/` directory
2. Try building your own container with the provided Dockerfile
3. Run the interactive shell container demo

## Files in This Directory

- `Dockerfile` - Basic hello world container
- `Dockerfile.interactive` - Container with development tools
- `run_container.sh` - Demo script
- `installation/` - OS-specific installation guides
- `exercises/` - Hands-on practice

Ready to containerize your first application? Let's dive in!
