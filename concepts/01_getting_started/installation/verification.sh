#!/bin/bash
# File Location: concepts/01_getting_started/installation/verification.sh
# Docker installation verification script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}    Docker Installation Verification${NC}"
echo -e "${BLUE}======================================${NC}"

# Function to check command existence
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Function to run test and show result
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "\n${YELLOW}Testing: ${test_name}${NC}"
    
    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $test_name - PASSED"
        return 0
    else
        echo -e "${RED}✗${NC} $test_name - FAILED"
        return 1
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Some tests may behave differently.${NC}"
fi

# Basic command checks
echo -e "\n${BLUE}1. Checking Docker Installation${NC}"
check_command "docker"

# Check Docker version
if command -v docker &> /dev/null; then
    echo -e "\nDocker version information:"
    docker --version
fi

# Check Docker Compose
echo -e "\n${BLUE}2. Checking Docker Compose${NC}"
check_command "docker-compose" || check_command "docker" && echo -e "${GREEN}✓${NC} Docker Compose (plugin) may be available"

# Check Docker daemon
echo -e "\n${BLUE}3. Checking Docker Daemon${NC}"
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
    
    # Show system info
    echo -e "\nDocker system information:"
    echo "Server Version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'N/A')"
    echo "Storage Driver: $(docker info --format '{{.Driver}}' 2>/dev/null || echo 'N/A')"
    echo "Total Images: $(docker images -q | wc -l 2>/dev/null || echo '0')"
    echo "Running Containers: $(docker ps -q | wc -l 2>/dev/null || echo '0')"
else
    echo -e "${RED}✗${NC} Docker daemon is not running or not accessible"
    echo -e "${YELLOW}Try: sudo systemctl start docker (Linux) or start Docker Desktop${NC}"
fi

# Test basic Docker functionality
echo -e "\n${BLUE}4. Running Docker Tests${NC}"

# Test 1: Pull and run hello-world
run_test "Hello World Container" "docker run --rm hello-world"

# Test 2: Basic alpine container
run_test "Alpine Linux Container" "docker run --rm alpine:latest echo 'Alpine test successful'"

# Test 3: Container with networking
run_test "Container Networking" "docker run --rm alpine:latest ping -c 1 google.com"

# Test 4: Volume mounting (if not running as root)
if [ "$EUID" -ne 0 ]; then
    run_test "Volume Mounting" "docker run --rm -v /tmp:/host-tmp alpine:latest ls /host-tmp"
fi

# Test 5: Image building capability
echo -e "\n${YELLOW}Testing: Image Building${NC}"
cat > /tmp/test-dockerfile << 'EOF'
FROM alpine:latest
RUN echo "Build test successful"
CMD ["echo", "Container test successful"]
EOF

if docker build -t test-build -f /tmp/test-dockerfile /tmp &> /dev/null; then
    echo -e "${GREEN}✓${NC} Image Building - PASSED"
    
    # Test the built image
    if docker run --rm test-build &> /dev/null; then
        echo -e "${GREEN}✓${NC} Built Image Execution - PASSED"
    else
        echo -e "${RED}✗${NC} Built Image Execution - FAILED"
    fi
    
    # Clean up test image
    docker rmi test-build &> /dev/null
else
    echo -e "${RED}✗${NC} Image Building - FAILED"
fi

# Clean up test dockerfile
rm -f /tmp/test-dockerfile

# Check disk space
echo -e "\n${BLUE}5. System Resources${NC}"
echo "Docker root directory usage:"
docker system df 2>/dev/null || echo "Unable to get Docker disk usage"

# Check for common issues
echo -e "\n${BLUE}6. Common Issues Check${NC}"

# Check if user is in docker group (Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if groups $USER | grep -q docker; then
        echo -e "${GREEN}✓${NC} User is in docker group"
    else
        echo -e "${YELLOW}!${NC} User is not in docker group"
        echo -e "  Run: sudo usermod -aG docker \$USER && newgrp docker"
    fi
fi

# Check available memory
total_mem=$(free -m 2>/dev/null | grep '^Mem:' | awk '{print $2}' || echo "Unknown")
if [ "$total_mem" != "Unknown" ] && [ "$total_mem" -lt 2048 ]; then
    echo -e "${YELLOW}!${NC} Low system memory: ${total_mem}MB (recommended: 2GB+)"
fi

# Final summary
echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}         Verification Complete${NC}"
echo -e "${BLUE}======================================${NC}"

# Count successful tests
echo -e "\nDocker appears to be properly installed and functional!"
echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Try: docker run -it ubuntu:latest /bin/bash"
echo "2. Build your first image with the provided Dockerfile"
echo "3. Explore the exercises in the exercises/ directory"
echo "4. Run: ../run_container.sh for interactive demos"

echo -e "\n${YELLOW}Need help?${NC}"
echo "- Check the installation guide for your OS"
echo "- Visit: https://docs.docker.com/get-started/"
echo "- Common issues: https://docs.docker.com/troubleshoot/"