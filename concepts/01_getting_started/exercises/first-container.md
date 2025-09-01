# Exercise: Your First Container

**File Location:** `concepts/01_getting_started/exercises/first-container.md`

## Objective

Learn basic container operations by running, managing, and interacting with your first Docker containers.

## Prerequisites

- Docker installed and running
- Completed verification script successfully

## Exercise 1: Hello World

Run your first container:

```bash
# Pull and run hello-world image
docker run hello-world
```

**Questions:**

1. What happened when you ran this command?
2. Is the container still running? How do you check?

## Exercise 2: Interactive Containers

### 2a: Ubuntu Container

```bash
# Run Ubuntu interactively
docker run -it ubuntu:latest /bin/bash

# Inside the container, try these commands:
whoami
hostname
ls /
cat /etc/os-release
apt-get update && apt-get install -y curl
curl -s https://httpbin.org/ip
exit
```

### 2b: Alpine Container

```bash
# Try a smaller Linux distribution
docker run -it alpine:latest /bin/sh

# Inside the container:
whoami
cat /etc/os-release
apk update && apk add curl
curl -s https://httpbin.org/ip
exit
```

**Questions:**

1. What's the difference between Ubuntu and Alpine containers?
2. Which one started faster? Why might that be?

## Exercise 3: Background Containers

```bash
# Run nginx web server in background
docker run -d -p 8080:80 --name my-nginx nginx:latest

# Check if it's running
docker ps

# Test the web server
curl http://localhost:8080
# Or open http://localhost:8080 in browser

# View container logs
docker logs my-nginx

# Stop the container
docker stop my-nginx

# Remove the container
docker rm my-nginx
```

## Exercise 4: Container Management

```bash
# Run multiple containers
docker run -d --name web1 nginx:latest
docker run -d --name web2 httpd:latest
docker run -it --name interactive ubuntu:latest /bin/bash
# (exit the interactive container)

# List all containers (running and stopped)
docker ps -a

# Start a stopped container
docker start web1

# Execute command in running container
docker exec -it web1 /bin/bash
# Inside container: ls /usr/share/nginx/html
# Exit

# View resource usage
docker stats --no-stream

# Clean up
docker stop web1 web2
docker rm web1 web2 interactive
```

## Exercise 5: Working with Images

```bash
# List current images
docker images

# Pull specific image versions
docker pull python:3.9
docker pull python:3.11

# Compare image sizes
docker images python

# Run Python container
docker run -it python:3.9 python
# In Python: print("Hello from Docker!")
# Exit with: exit()

# Remove unused images
docker image prune
```

## Exercise 6: Data and Volumes

```bash
# Create a container that writes data
docker run --rm -v /tmp/docker-exercise:/data alpine:latest sh -c "echo 'Hello from container' > /data/message.txt"

# Check if file was created on host
cat /tmp/docker-exercise/message.txt

# Create a named volume
docker volume create my-data

# Use the volume
docker run --rm -v my-data:/app alpine:latest sh -c "echo 'Persistent data' > /app/important.txt"

# Access the same volume from another container
docker run --rm -v my-data:/app alpine:latest cat /app/important.txt

# List volumes
docker volume ls

# Clean up
docker volume rm my-data
rm -rf /tmp/docker-exercise
```

## Challenge Exercise: Build a Simple App Container

Create a simple web application:

```bash
# Create a directory
mkdir my-first-app
cd my-first-app

# Create a simple HTML file
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>My First Docker App</title>
</head>
<body>
    <h1>Hello from Docker!</h1>
    <p>This page is served from a container.</p>
    <p>Container ID: <span id="hostname"></span></p>
    <script>
        fetch('/hostname')
            .then(r => r.text())
            .then(hostname => {
                document.getElementById('hostname').textContent = hostname;
            });
    </script>
</body>
</html>
EOF

# Create a simple Python web server
cat > app.py << 'EOF'
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket
import os

class MyHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/hostname':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(socket.gethostname().encode())
        else:
            super().do_GET()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), MyHandler)
    print('Server running on port 8000')
    server.serve_forever()
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
EOF

# Build and run
docker build -t my-first-app .
docker run -d -p 8000:8000 --name my-app my-first-app

# Test it
curl http://localhost:8000
# Open http://localhost:8000 in browser

# Clean up
docker stop my-app
docker rm my-app
docker rmi my-first-app
cd ..
rm -rf my-first-app
```

## Troubleshooting Tips

### Container Won't Start

```bash
# Check container logs
docker logs <container_name>

# Run with different command to debug
docker run -it <image> /bin/sh
```

### Port Already in Use

```bash
# Find what's using the port
netstat -tulpn | grep :8080
# Or use different port: -p 8081:80
```

### Permission Denied

```bash
# Check if user is in docker group (Linux)
groups $USER

# If not, add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Questions for Review

1. What's the difference between `docker run` and `docker exec`?
2. When should you use `-d` flag vs `-it` flags?
3. What happens to data in a container when it's removed?
4. How do you expose a port from a container?
5. What's the difference between stopping and removing a container?

## Next Steps

After completing these exercises:

1. Move to `02_images_layers` to learn about Docker images
2. Practice the `basic-commands.md` exercise
3. Try building more complex applications

## Summary

You've learned:

- Running containers interactively and in background
- Managing container lifecycle (start, stop, remove)
- Working with ports and volumes
- Basic troubleshooting techniques
- Building your first containerized application
