# Docker Installation - Ubuntu

**File Location:** `concepts/01_getting_started/installation/ubuntu.md`

## Prerequisites

- Ubuntu 18.04 LTS or newer
- 64-bit architecture
- Sudo privileges

## Installation Methods

### Method 1: Using Docker's Official Repository (Recommended)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
sudo apt-get update

# Install Docker Engine
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Method 2: Convenience Script

```bash
# Download and run installation script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## Post-Installation Setup

### Add User to Docker Group (Optional)

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker
```

### Enable Docker Service

```bash
# Enable Docker to start on boot
sudo systemctl enable docker

# Start Docker service
sudo systemctl start docker
```

## Verification

```bash
# Check Docker version
docker --version

# Run test container
docker run hello-world

# Check Docker info
docker system info
```

## Troubleshooting

### Permission Denied Error

If you get permission denied errors:

```bash
# Check if user is in docker group
groups $USER

# If not in docker group:
sudo usermod -aG docker $USER
newgrp docker
```

### Service Not Running

```bash
# Check Docker service status
sudo systemctl status docker

# Start if stopped
sudo systemctl start docker

# Restart if needed
sudo systemctl restart docker
```

### Storage Issues

```bash
# Check disk space
df -h

# Clean up unused Docker resources
docker system prune -a
```

## Uninstallation

```bash
# Remove Docker packages
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Remove Docker repository
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.gpg

# Remove Docker data (optional)
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

## Next Steps

- Run the verification script: `./verification.sh`
- Try the getting started exercises
- Build your first container
