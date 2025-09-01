# Docker Installation - macOS

**File Location:** `concepts/01_getting_started/installation/macos.md`

## Prerequisites

- macOS 10.15 or newer
- Apple chip (M1/M2) or Intel processor
- 4GB RAM minimum
- Administrator access

## Installation Methods

### Method 1: Docker Desktop (Recommended)

#### For Apple Silicon (M1/M2)

```bash
# Download Docker Desktop for Apple Silicon
curl -o Docker.dmg https://desktop.docker.com/mac/main/arm64/Docker.dmg

# Or download from website
# https://www.docker.com/products/docker-desktop
```

#### For Intel Macs

```bash
# Download Docker Desktop for Intel
curl -o Docker.dmg https://desktop.docker.com/mac/main/amd64/Docker.dmg
```

#### Installation Steps

1. Open the downloaded DMG file
2. Drag Docker.app to Applications folder
3. Launch Docker from Applications
4. Grant necessary permissions when prompted

### Method 2: Homebrew

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop via Homebrew Cask
brew install --cask docker

# Or install Docker CLI tools only
brew install docker docker-compose
```

### Method 3: MacPorts

```bash
# Install Docker via MacPorts
sudo port install docker

# Install Docker Compose
sudo port install docker-compose
```

## Post-Installation Setup

### Start Docker Desktop

1. Open Docker Desktop from Applications
2. Accept license agreement
3. Complete onboarding tutorial
4. Docker icon appears in menu bar when ready

### Command Line Access

```bash
# Verify Docker installation
docker --version
docker-compose --version

# Test Docker
docker run hello-world
```

### Configure Resources

1. Click Docker icon in menu bar
2. Select Preferences
3. Adjust resources under Resources tab:
   - CPU: 2-4 cores recommended
   - Memory: 2-8 GB depending on usage
   - Disk: Adjust disk image size

## Configuration Options

### Enable Experimental Features

```bash
# Edit Docker daemon configuration
vim ~/.docker/config.json
```

```json
{
  "experimental": "enabled",
  "debug": true
}
```

### Configure File Sharing

1. Docker → Preferences → Resources → File Sharing
2. Add directories that need to be accessible to containers
3. Common directories:
   - `/Users` (usually pre-configured)
   - `/tmp`
   - `/private`

### Proxy Configuration

If behind corporate firewall:

```bash
# Docker → Preferences → Resources → Proxies
# Configure HTTP/HTTPS proxy settings
```

## Troubleshooting

### Docker Desktop Won't Start

```bash
# Check system requirements
system_profiler SPHardwareDataType

# Reset Docker Desktop
rm -rf ~/Library/Group\ Containers/group.com.docker
rm -rf ~/Library/Containers/com.docker.docker

# Restart Docker Desktop
```

### Permission Issues

```bash
# Fix Docker socket permissions
sudo chown $(whoami):staff /var/run/docker.sock

# Or restart Docker Desktop
```

### Performance Issues

```bash
# Check resource usage
docker system df
docker system prune

# Increase allocated resources in Docker Desktop preferences
```

### Homebrew Installation Issues

```bash
# Update Homebrew
brew update
brew upgrade

# Reinstall Docker
brew uninstall --cask docker
brew install --cask docker
```

## Apple Silicon Specific

### Running x86 Images

```bash
# Use --platform flag for Intel images
docker run --platform linux/amd64 ubuntu:latest

# Build multi-architecture images
docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
```

### Performance Optimization

- Use ARM-based images when available
- Enable VirtioFS for better file system performance
- Use Docker volumes for better I/O performance

## Alternative Installation: Lima + nerdctl

For command-line only setup:

```bash
# Install Lima
brew install lima

# Start Lima VM with Docker
limactl start template://docker

# Use nerdctl instead of docker
lima nerdctl run hello-world
```

## Uninstallation

### Docker Desktop

```bash
# Remove application
rm -rf /Applications/Docker.app

# Clean up user data
rm -rf ~/Library/Group\ Containers/group.com.docker
rm -rf ~/Library/Containers/com.docker.docker
rm -rf ~/.docker
```

### Homebrew

```bash
# Uninstall via Homebrew
brew uninstall --cask docker
brew cleanup
```

## Common Commands Verification

```bash
# Version information
docker version
docker info

# Container operations
docker pull alpine
docker images
docker ps
docker ps -a

# Clean up
docker container prune
docker image prune
docker system prune -a
```

## Next Steps

- Run the verification script
- Configure your development environment
- Try building your first container
- Explore Docker Desktop dashboard
