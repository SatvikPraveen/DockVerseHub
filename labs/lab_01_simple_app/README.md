# Lab 01: Simple Containerized Application

**File Location:** `labs/lab_01_simple_app/README.md`

## Overview

This lab introduces the basics of containerizing a simple Python web application using Docker. You'll learn how to create a Dockerfile, build an image, and run a container.

## What You'll Learn

- Writing a basic Dockerfile
- Building and running Docker containers
- Port mapping and basic container networking
- Using docker-compose for simplified container management

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of Python and web applications

## Application Structure

```
lab_01_simple_app/
├── README.md           # This file
├── Dockerfile          # Container definition
├── app.py             # Simple Flask web application
├── requirements.txt    # Python dependencies
└── docker-compose.yml  # Container orchestration
```

## Quick Start

### Method 1: Using Docker Commands

```bash
# Build the Docker image
docker build -t simple-app .

# Run the container
docker run -p 8080:5000 simple-app

# Access the application
curl http://localhost:8080
```

### Method 2: Using Docker Compose

```bash
# Start the application
docker-compose up

# Access the application
curl http://localhost:8080

# Stop the application
docker-compose down
```

## Key Concepts Demonstrated

### 1. Dockerfile Best Practices

- Using official Python base image
- Setting working directory
- Copying requirements first (layer caching)
- Installing dependencies
- Copying application code
- Exposing the correct port
- Using non-root user for security

### 2. Container Networking

- Port mapping from host to container
- Understanding container internal ports vs host ports

### 3. Docker Compose Benefits

- Simplified container management
- Environment variable configuration
- Easy service orchestration

## Exercises

### Exercise 1: Modify the Application

1. Change the welcome message in `app.py`
2. Rebuild the Docker image
3. Run the new container and verify changes

### Exercise 2: Environment Variables

1. Modify `app.py` to read a custom message from an environment variable
2. Update `docker-compose.yml` to set this environment variable
3. Test the application with different messages

### Exercise 3: Volume Mounting

1. Add volume mounting to persist application logs
2. Modify the app to write logs to a file
3. Verify logs persist after container restart

## Common Commands

```bash
# Build image with tag
docker build -t simple-app:v1.0 .

# Run container with custom name
docker run --name my-simple-app -p 8080:5000 -d simple-app

# View running containers
docker ps

# View container logs
docker logs my-simple-app

# Stop and remove container
docker stop my-simple-app
docker rm my-simple-app

# Remove image
docker rmi simple-app
```

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080
# Or use different port
docker run -p 8081:5000 simple-app
```

### Container Won't Start

```bash
# Check container logs
docker logs <container_name>

# Run container interactively for debugging
docker run -it simple-app /bin/bash
```

### Image Build Fails

```bash
# Build with verbose output
docker build --no-cache -t simple-app .

# Check Dockerfile syntax
docker build --dry-run .
```

## Next Steps

- Proceed to Lab 02 for multi-container applications
- Experiment with different base images (alpine, slim)
- Add health checks to your container
- Implement proper logging and monitoring

## Additional Resources

- [Docker Official Documentation](https://docs.docker.com/)
- [Python Docker Best Practices](https://docs.docker.com/language/python/)
- [Flask Documentation](https://flask.palletsprojects.com/)
