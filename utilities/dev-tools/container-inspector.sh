#!/bin/bash
# Location: utilities/dev-tools/container-inspector.sh
# Advanced container inspection and debugging tool

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to inspect container basic info
inspect_basic_info() {
    local container="$1"
    
    print_header "Basic Container Information"
    
    echo "Container Name: $(docker inspect --format='{{.Name}}' "$container" | sed 's|^/||')"
    echo "Container ID: $(docker inspect --format='{{.Id}}' "$container" | cut -c1-12)"
    echo "Image: $(docker inspect --format='{{.Config.Image}}' "$container")"
    echo "Status: $(docker inspect --format='{{.State.Status}}' "$container")"
    echo "Created: $(docker inspect --format='{{.Created}}' "$container")"
    echo "Started: $(docker inspect --format='{{.State.StartedAt}}' "$container")"
    
    local restart_count=$(docker inspect --format='{{.RestartCount}}' "$container")
    echo "Restart Count: $restart_count"
    
    if [ "$restart_count" -gt 0 ]; then
        print_warning "Container has restarted $restart_count times"
    fi
    
    local health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container")
    echo "Health Status: $health_status"
    
    echo ""
}

# Function to inspect container configuration
inspect_configuration() {
    local container="$1"
    
    print_header "Container Configuration"
    
    echo "Working Directory: $(docker inspect --format='{{.Config.WorkingDir}}' "$container")"
    echo "User: $(docker inspect --format='{{.Config.User}}' "$container")"
    echo "Shell: $(docker inspect --format='{{.Config.Shell}}' "$container")"
    
    echo ""
    echo "Environment Variables:"
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$container" | while read -r env; do
        if [[ "$env" =~ ^(PASSWORD|SECRET|KEY|TOKEN) ]]; then
            echo "  $env [REDACTED]"
        else
            echo "  $env"
        fi
    done
    
    echo ""
    echo "Command: $(docker inspect --format='{{.Config.Cmd}}' "$container")"
    echo "Entrypoint: $(docker inspect --format='{{.Config.Entrypoint}}' "$container")"
    
    echo ""
}

# Function to inspect networking
inspect_networking() {
    local container="$1"
    
    print_header "Network Configuration"
    
    echo "Network Mode: $(docker inspect --format='{{.HostConfig.NetworkMode}}' "$container")"
    
    echo ""
    echo "Networks:"
    docker inspect --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}: {{$conf.IPAddress}}{{"\n"}}{{end}}' "$container"
    
    echo ""
    echo "Port Bindings:"
    docker inspect --format='{{range $port, $bindings := .NetworkSettings.Ports}}{{$port}}: {{range $bindings}}{{.HostIP}}:{{.HostPort}} {{end}}{{"\n"}}{{end}}' "$container"
    
    echo ""
    echo "DNS Servers:"
    docker inspect --format='{{range .HostConfig.Dns}}{{.}}{{"\n"}}{{end}}' "$container"
    
    echo ""
}

# Function to inspect storage
inspect_storage() {
    local container="$1"
    
    print_header "Storage Configuration"
    
    echo "Mounts:"
    docker inspect --format='{{range .Mounts}}Type: {{.Type}}, Source: {{.Source}}, Destination: {{.Destination}}, Mode: {{.Mode}}{{"\n"}}{{end}}' "$container"
    
    echo ""
    echo "Volumes:"
    docker inspect --format='{{range $vol, $path := .Config.Volumes}}{{$vol}} -> {{$path}}{{"\n"}}{{end}}' "$container"
    
    echo ""
}

# Function to inspect resource limits
inspect_resources() {
    local container="$1"
    
    print_header "Resource Limits"
    
    local memory_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$container")
    local cpu_quota=$(docker inspect --format='{{.HostConfig.CpuQuota}}' "$container")
    local cpu_period=$(docker inspect --format='{{.HostConfig.CpuPeriod}}' "$container")
    local cpu_shares=$(docker inspect --format='{{.HostConfig.CpuShares}}' "$container")
    
    if [ "$memory_limit" -gt 0 ]; then
        echo "Memory Limit: $((memory_limit / 1024 / 1024)) MB"
    else
        echo "Memory Limit: unlimited"
    fi
    
    if [ "$cpu_quota" -gt 0 ] && [ "$cpu_period" -gt 0 ]; then
        local cpu_limit=$(echo "scale=2; $cpu_quota / $cpu_period" | bc)
        echo "CPU Limit: ${cpu_limit} cores"
    else
        echo "CPU Limit: unlimited"
    fi
    
    echo "CPU Shares: $cpu_shares"
    
    echo ""
    echo "Current Resource Usage:"
    docker stats --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemUsage}} ({{.MemPerc}})" "$container"
    
    echo ""
}

# Function to inspect security settings
inspect_security() {
    local container="$1"
    
    print_header "Security Configuration"
    
    local privileged=$(docker inspect --format='{{.HostConfig.Privileged}}' "$container")
    echo "Privileged: $privileged"
    
    if [ "$privileged" = "true" ]; then
        print_warning "Container is running in privileged mode!"
    fi
    
    echo "Capabilities Added: $(docker inspect --format='{{.HostConfig.CapAdd}}' "$container")"
    echo "Capabilities Dropped: $(docker inspect --format='{{.HostConfig.CapDrop}}' "$container")"
    
    local user=$(docker inspect --format='{{.Config.User}}' "$container")
    if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
        print_warning "Container is running as root!"
    else
        print_success "Container running as non-root user: $user"
    fi
    
    echo "Security Options: $(docker inspect --format='{{.HostConfig.SecurityOpt}}' "$container")"
    
    echo ""
}

# Function to analyze logs
analyze_logs() {
    local container="$1"
    local lines="${2:-50}"
    
    print_header "Recent Logs Analysis (last $lines lines)"
    
    local log_driver=$(docker inspect --format='{{.HostConfig.LogConfig.Type}}' "$container")
    echo "Log Driver: $log_driver"
    echo ""
    
    # Get recent logs
    docker logs --tail "$lines" --timestamps "$container" 2>&1 | while IFS= read -r line; do
        if echo "$line" | grep -qi "error\|exception\|failed\|fatal"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -qi "warning\|warn"; then
            echo -e "${YELLOW}$line${NC}"
        elif echo "$line" | grep -qi "info\|success"; then
            echo -e "${GREEN}$line${NC}"
        else
            echo "$line"
        fi
    done
    
    echo ""
    
    # Log statistics
    local error_count=$(docker logs --tail 1000 "$container" 2>&1 | grep -ci "error\|exception\|failed\|fatal" || echo "0")
    local warning_count=$(docker logs --tail 1000 "$container" 2>&1 | grep -ci "warning\|warn" || echo "0")
    
    echo "Log Statistics (last 1000 lines):"
    echo "  Errors: $error_count"
    echo "  Warnings: $warning_count"
    
    echo ""
}

# Function to inspect processes
inspect_processes() {
    local container="$1"
    
    print_header "Running Processes"
    
    if docker exec "$container" ps aux &>/dev/null; then
        docker exec "$container" ps aux
    elif docker exec "$container" ps &>/dev/null; then
        docker exec "$container" ps
    else
        print_warning "Cannot inspect processes - ps command not available in container"
    fi
    
    echo ""
}

# Function to test connectivity
test_connectivity() {
    local container="$1"
    
    print_header "Network Connectivity Tests"
    
    # Test DNS resolution
    if docker exec "$container" nslookup google.com &>/dev/null; then
        print_success "DNS resolution: OK"
    else
        print_error "DNS resolution: FAILED"
    fi
    
    # Test internet connectivity
    if docker exec "$container" ping -c 1 8.8.8.8 &>/dev/null; then
        print_success "Internet connectivity: OK"
    else
        print_error "Internet connectivity: FAILED"
    fi
    
    # Test HTTP connectivity
    if docker exec "$container" curl -s --connect-timeout 5 http://httpbin.org/status/200 &>/dev/null; then
        print_success "HTTP connectivity: OK"
    elif docker exec "$container" wget -q --spider --timeout=5 http://httpbin.org/status/200 &>/dev/null; then
        print_success "HTTP connectivity: OK (via wget)"
    else
        print_warning "HTTP connectivity: Cannot test (curl/wget not available)"
    fi
    
    echo ""
}

# Function to generate comprehensive report
generate_report() {
    local container="$1"
    local report_file="container_inspection_$(date +%Y%m%d_%H%M%S).txt"
    
    print_status "Generating comprehensive report: $report_file"
    
    {
        echo "Docker Container Inspection Report"
        echo "Generated: $(date)"
        echo "Container: $container"
        echo "========================================"
        echo ""
        
        inspect_basic_info "$container"
        inspect_configuration "$container"
        inspect_networking "$container"
        inspect_storage "$container"
        inspect_resources "$container"
        inspect_security "$container"
        analyze_logs "$container" 100
        
        echo "========================================"
        echo "Raw Docker Inspect Output:"
        echo "========================================"
        docker inspect "$container"
        
    } > "$report_file" 2>&1
    
    print_success "Report saved to: $report_file"
}

# Function to show help
show_help() {
    echo "Docker Container Inspector"
    echo "Usage: $0 [OPTIONS] CONTAINER"
    echo ""
    echo "OPTIONS:"
    echo "  -a, --all              Show all inspection details"
    echo "  -b, --basic            Show basic information only"
    echo "  -n, --network          Show network configuration"
    echo "  -s, --storage          Show storage configuration"
    echo "  -r, --resources        Show resource limits and usage"
    echo "  --security             Show security configuration"
    echo "  --logs [LINES]         Analyze logs (default: 50 lines)"
    echo "  --processes            Show running processes"
    echo "  --connectivity         Test network connectivity"
    echo "  --report               Generate comprehensive report"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 nginx                      # Basic inspection"
    echo "  $0 -a nginx                   # Full inspection"
    echo "  $0 --logs 100 nginx           # Analyze 100 log lines"
    echo "  $0 --report webapp            # Generate full report"
}

# Parse arguments
SHOW_ALL=false
SHOW_BASIC=false
SHOW_NETWORK=false
SHOW_STORAGE=false
SHOW_RESOURCES=false
SHOW_SECURITY=false
SHOW_LOGS=false
SHOW_PROCESSES=false
TEST_CONNECTIVITY=false
GENERATE_REPORT=false
LOG_LINES=50
CONTAINER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -b|--basic)
            SHOW_BASIC=true
            shift
            ;;
        -n|--network)
            SHOW_NETWORK=true
            shift
            ;;
        -s|--storage)
            SHOW_STORAGE=true
            shift
            ;;
        -r|--resources)
            SHOW_RESOURCES=true
            shift
            ;;
        --security)
            SHOW_SECURITY=true
            shift
            ;;
        --logs)
            SHOW_LOGS=true
            if [[ $2 =~ ^[0-9]+$ ]]; then
                LOG_LINES="$2"
                shift
            fi
            shift
            ;;
        --processes)
            SHOW_PROCESSES=true
            shift
            ;;
        --connectivity)
            TEST_CONNECTIVITY=true
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            CONTAINER="$1"
            shift
            ;;
    esac
done

# Validate container argument
if [ -z "$CONTAINER" ]; then
    print_error "Container name or ID is required"
    show_help
    exit 1
fi

# Check if container exists
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    if ! docker ps -a --format "{{.ID}}" | grep -q "^${CONTAINER}"; then
        print_error "Container '$CONTAINER' not found"
        exit 1
    fi
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    exit 1
fi

print_status "Inspecting container: $CONTAINER"
echo ""

# Generate report if requested
if [ "$GENERATE_REPORT" = true ]; then
    generate_report "$CONTAINER"
    exit 0
fi

# Show all sections if --all is specified or no specific section requested
if [ "$SHOW_ALL" = true ] || ([ "$SHOW_BASIC" = false ] && [ "$SHOW_NETWORK" = false ] && [ "$SHOW_STORAGE" = false ] && [ "$SHOW_RESOURCES" = false ] && [ "$SHOW_SECURITY" = false ] && [ "$SHOW_LOGS" = false ] && [ "$SHOW_PROCESSES" = false ] && [ "$TEST_CONNECTIVITY" = false ]); then
    inspect_basic_info "$CONTAINER"
    inspect_configuration "$CONTAINER"
    inspect_networking "$CONTAINER"
    inspect_storage "$CONTAINER"
    inspect_resources "$CONTAINER"
    inspect_security "$CONTAINER"
    analyze_logs "$CONTAINER" "$LOG_LINES"
    inspect_processes "$CONTAINER"
    test_connectivity "$CONTAINER"
else
    # Show specific sections
    [ "$SHOW_BASIC" = true ] && inspect_basic_info "$CONTAINER"
    [ "$SHOW_NETWORK" = true ] && inspect_networking "$CONTAINER"
    [ "$SHOW_STORAGE" = true ] && inspect_storage "$CONTAINER"
    [ "$SHOW_RESOURCES" = true ] && inspect_resources "$CONTAINER"
    [ "$SHOW_SECURITY" = true ] && inspect_security "$CONTAINER"
    [ "$SHOW_LOGS" = true ] && analyze_logs "$CONTAINER" "$LOG_LINES"
    [ "$SHOW_PROCESSES" = true ] && inspect_processes "$CONTAINER"
    [ "$TEST_CONNECTIVITY" = true ] && test_connectivity "$CONTAINER"
fi

print_success "Container inspection completed!"
echo ""
echo "Tips:"
echo "- Use --report to generate a comprehensive text report"
echo "- Use --logs [number] to analyze more log entries"
echo "- Use docker exec -it $CONTAINER /bin/sh to enter the container"