#!/bin/bash
# File Location: concepts/04_networking/inspect_network.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}    Docker Network Inspection Tool${NC}"
echo -e "${BLUE}======================================${NC}"

# Check Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# List all networks
echo -e "\n${YELLOW}Docker Networks:${NC}"
docker network ls

# Inspect each network
echo -e "\n${YELLOW}Network Details:${NC}"
for network in $(docker network ls --format "{{.Name}}" | grep -v NETWORK); do
    if [ "$network" != "none" ]; then
        echo -e "\n${GREEN}Network: $network${NC}"
        echo "----------------------------------------"
        
        # Get network info
        driver=$(docker network inspect $network --format '{{.Driver}}')
        subnet=$(docker network inspect $network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        gateway=$(docker network inspect $network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
        
        echo "Driver: $driver"
        echo "Subnet: $subnet"
        echo "Gateway: $gateway"
        
        # List containers on this network
        containers=$(docker network inspect $network --format '{{range $k,$v := .Containers}}{{$v.Name}} {{end}}')
        if [ ! -z "$containers" ]; then
            echo "Containers: $containers"
        else
            echo "Containers: none"
        fi
    fi
done

# Show running containers and their networks
echo -e "\n${YELLOW}Container Network Assignments:${NC}"
docker ps --format "table {{.Names}}\t{{.Networks}}\t{{.Ports}}"

# Test connectivity if containers exist
if docker ps -q | grep -q .; then
    echo -e "\n${YELLOW}Testing Container Connectivity:${NC}"
    
    # Get first running container
    first_container=$(docker ps --format "{{.Names}}" | head -1)
    
    if [ ! -z "$first_container" ]; then
        echo -e "\nTesting from container: $first_container"
        
        # Test network commands in container
        if docker exec $first_container which ping &> /dev/null; then
            echo "Ping capability: Available"
        else
            echo "Ping capability: Not available"
        fi
        
        if docker exec $first_container which nslookup &> /dev/null; then
            echo "DNS tools: Available"
        else
            echo "DNS tools: Not available"
        fi
        
        # Show network interfaces in container
        echo -e "\nNetwork interfaces in $first_container:"
        docker exec $first_container ip addr 2>/dev/null || \
        docker exec $first_container ifconfig 2>/dev/null || \
        echo "Network interface commands not available"
        
        # Test DNS resolution
        echo -e "\nTesting DNS resolution:"
        docker exec $first_container nslookup google.com 2>/dev/null || \
        echo "DNS resolution test failed or nslookup not available"
    fi
fi

echo -e "\n${GREEN}Network inspection completed!${NC}"