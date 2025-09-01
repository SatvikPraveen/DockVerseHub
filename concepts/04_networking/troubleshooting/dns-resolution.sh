#!/bin/bash
# File Location: concepts/04_networking/troubleshooting/dns-resolution.sh

set -e

check_dns_resolution() {
    local container="$1"
    local target="$2"
    
    echo "Testing DNS resolution from $container for $target"
    
    # Install DNS tools if needed
    docker exec "$container" sh -c "
        if which nslookup &>/dev/null || which dig &>/dev/null; then
            exit 0
        fi
        
        if which apk &>/dev/null; then
            apk add --no-cache bind-tools
        elif which apt-get &>/dev/null; then
            apt-get update && apt-get install -y dnsutils
        elif which yum &>/dev/null; then
            yum install -y bind-utils
        fi
    " 2>/dev/null || echo "Could not install DNS tools"
    
    # Test with nslookup
    echo "nslookup test:"
    if docker exec "$container" nslookup "$target" 2>/dev/null; then
        echo "✓ nslookup successful"
    else
        echo "✗ nslookup failed"
    fi
    
    # Test with dig if available
    if docker exec "$container" which dig &>/dev/null; then
        echo "dig test:"
        docker exec "$container" dig "$target" +short 2>/dev/null || echo "dig failed"
    fi
    
    # Show DNS configuration
    echo "DNS configuration in $container:"
    docker exec "$container" cat /etc/resolv.conf 2>/dev/null || echo "Cannot read resolv.conf"
    
    echo ""
}

test_container_dns() {
    local container="$1"
    
    echo "=== DNS Resolution Test for $container ==="
    
    # Test external DNS
    check_dns_resolution "$container" "google.com"
    check_dns_resolution "$container" "docker.com"
    
    # Test internal container DNS
    local containers=($(docker ps --format "{{.Names}}" | grep -v "^$container$"))
    
    if [ ${#containers[@]} -gt 0 ]; then
        echo "Testing internal container DNS resolution:"
        for other in "${containers[@]}"; do
            check_dns_resolution "$container" "$other"
        done
    fi
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <container_name> [target]"
        echo "Test DNS resolution from container"
        exit 1
    fi
    
    local container="$1"
    local target="$2"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
        echo "Container $container is not running"
        exit 1
    fi
    
    if [ -n "$target" ]; then
        check_dns_resolution "$container" "$target"
    else
        test_container_dns "$container"
    fi
}

main "$@"