#!/bin/bash
# File Location: concepts/04_networking/troubleshooting/connectivity-test.sh

set -e

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Test Docker container network connectivity"
    echo ""
    echo "Options:"
    echo "  -c, --container NAME    Test from specific container"
    echo "  -t, --target TARGET     Test connection to target"
    echo "  -p, --port PORT         Test specific port"
    echo "  -n, --network NETWORK   Test within specific network"
    echo "  -a, --all               Test all running containers"
    echo "  -h, --help              Show this help"
}

test_container_connectivity() {
    local container="$1"
    local target="$2"
    local port="$3"
    
    echo "Testing connectivity from $container to $target${port:+:$port}"
    
    if ! docker exec "$container" which ping &>/dev/null; then
        echo "Installing network tools in $container..."
        docker exec "$container" sh -c "
            if which apk &>/dev/null; then
                apk add --no-cache iputils curl bind-tools netcat-openbsd
            elif which apt-get &>/dev/null; then
                apt-get update && apt-get install -y iputils-ping curl dnsutils netcat
            elif which yum &>/dev/null; then
                yum install -y iputils curl bind-utils nc
            fi
        " 2>/dev/null || echo "Could not install network tools"
    fi
    
    # Test ping
    echo "Ping test:"
    if docker exec "$container" ping -c 3 "$target" 2>/dev/null; then
        echo "✓ Ping successful"
    else
        echo "✗ Ping failed"
    fi
    
    # Test DNS resolution
    echo "DNS resolution test:"
    if docker exec "$container" nslookup "$target" 2>/dev/null; then
        echo "✓ DNS resolution successful"
    else
        echo "✗ DNS resolution failed"
    fi
    
    # Test port connectivity if specified
    if [ -n "$port" ]; then
        echo "Port connectivity test ($port):"
        if docker exec "$container" nc -z "$target" "$port" 2>/dev/null; then
            echo "✓ Port $port is open"
        else
            echo "✗ Port $port is closed or unreachable"
        fi
        
        # Test HTTP if port 80 or 443
        if [ "$port" = "80" ] || [ "$port" = "443" ]; then
            protocol="http"
            [ "$port" = "443" ] && protocol="https"
            
            echo "HTTP test:"
            if docker exec "$container" curl -f -s "${protocol}://${target}:${port}/" >/dev/null 2>&1; then
                echo "✓ HTTP request successful"
            else
                echo "✗ HTTP request failed"
            fi
        fi
    fi
    
    echo ""
}

test_network_isolation() {
    local network="$1"
    
    echo "Testing network isolation for: $network"
    echo "Containers in network:"
    docker network inspect "$network" --format '{{range $k,$v := .Containers}}{{$v.Name}} ({{$v.IPv4Address}}){{"\n"}}{{end}}'
    
    # Get containers in network
    local containers=($(docker network inspect "$network" --format '{{range $k,$v := .Containers}}{{$v.Name}} {{end}}'))
    
    if [ ${#containers[@]} -lt 2 ]; then
        echo "Not enough containers in network for connectivity test"
        return
    fi
    
    # Test connectivity between containers
    for i in "${!containers[@]}"; do
        for j in "${!containers[@]}"; do
            if [ $i -ne $j ]; then
                echo "Testing ${containers[$i]} → ${containers[$j]}"
                test_container_connectivity "${containers[$i]}" "${containers[$j]}"
            fi
        done
    done
}

main() {
    local container=""
    local target=""
    local port=""
    local network=""
    local test_all=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--container)
                container="$2"
                shift 2
                ;;
            -t|--target)
                target="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -n|--network)
                network="$2"
                shift 2
                ;;
            -a|--all)
                test_all=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check Docker is running
    if ! docker info &>/dev/null; then
        echo "Error: Docker is not running"
        exit 1
    fi
    
    echo "=== Docker Network Connectivity Test ==="
    echo "Time: $(date)"
    echo ""
    
    if [ "$test_all" = true ]; then
        echo "Testing all running containers..."
        local running_containers=($(docker ps --format "{{.Names}}"))
        
        for container in "${running_containers[@]}"; do
            echo "--- Testing container: $container ---"
            
            # Test external connectivity
            test_container_connectivity "$container" "google.com" "80"
            
            # Test internal connectivity to other containers
            for other in "${running_containers[@]}"; do
                if [ "$container" != "$other" ]; then
                    test_container_connectivity "$container" "$other"
                fi
            done
        done
        
    elif [ -n "$network" ]; then
        test_network_isolation "$network"
        
    elif [ -n "$container" ] && [ -n "$target" ]; then
        test_container_connectivity "$container" "$target" "$port"
        
    else
        echo "No specific test parameters provided. Running basic network diagnostics..."
        
        echo "Docker networks:"
        docker network ls
        
        echo ""
        echo "Running containers and their networks:"
        docker ps --format "table {{.Names}}\t{{.Networks}}\t{{.Ports}}"
        
        echo ""
        echo "Network gateway information:"
        docker network inspect bridge --format '{{.IPAM.Config}}'
    fi
    
    echo ""
    echo "Test completed at $(date)"
}

main "$@"