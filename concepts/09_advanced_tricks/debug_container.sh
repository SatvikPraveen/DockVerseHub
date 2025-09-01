#!/bin/bash
# 09_advanced_tricks/debug_container.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEBUG_IMAGE="nicolaka/netshoot"
TIMEOUT=30
VERBOSE=false

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
debug() { [ "$VERBOSE" = true ] && echo -e "${PURPLE}[DEBUG]${NC} $1"; }

show_usage() {
    cat << EOF
Container Debug Toolkit - Advanced Docker Container Debugging

Usage: $0 [command] [options] [container_name_or_id]

Commands:
    inspect     - Comprehensive container inspection
    network     - Network diagnostics and troubleshooting  
    process     - Process and performance analysis
    filesystem  - Filesystem and storage debugging
    logs        - Advanced log analysis
    attach      - Attach debugging tools to container
    health      - Health check analysis
    resources   - Resource usage analysis
    security    - Security analysis
    build       - Build debugging and optimization

Options:
    -v, --verbose           Enable verbose output
    -t, --timeout SECONDS   Set timeout for operations (default: 30)
    -i, --image IMAGE       Debug image to use (default: nicolaka/netshoot)
    -h, --help             Show this help message

Examples:
    $0 inspect webapp                    # Full container inspection
    $0 network webapp                    # Network debugging
    $0 process webapp                    # Process analysis  
    $0 attach webapp                     # Attach debug container
    $0 logs webapp --tail 100           # Advanced log analysis
    $0 build --stuck Dockerfile         # Debug stuck builds

EOF
}

# Check if container exists and is accessible
validate_container() {
    local container=$1
    
    if [ -z "$container" ]; then
        error "Container name or ID required"
        return 1
    fi
    
    if ! docker inspect "$container" >/dev/null 2>&1; then
        error "Container '$container' not found"
        return 1
    fi
    
    debug "Container '$container' validated"
}

# Comprehensive container inspection
inspect_container() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🔍 Comprehensive Container Inspection: $container"
    echo "========================================================"
    
    # Basic container info
    echo -e "${CYAN}📊 Basic Information:${NC}"
    docker inspect "$container" --format '
Container ID: {{.Id}}
Image: {{.Config.Image}}
State: {{.State.Status}}
Running: {{.State.Running}}
Started: {{.State.StartedAt}}
Restart Count: {{.RestartCount}}
Platform: {{.Platform}}
'
    
    # Process information
    echo -e "${CYAN}🔄 Process Information:${NC}"
    if docker exec "$container" ps aux 2>/dev/null; then
        success "Process list retrieved"
    else
        warn "Could not retrieve process list (container may not have ps command)"
        # Alternative process check
        docker top "$container" 2>/dev/null || warn "Process information unavailable"
    fi
    
    # Resource usage
    echo -e "${CYAN}📈 Resource Usage:${NC}"
    docker stats "$container" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"
    
    # Port mappings
    echo -e "${CYAN}🌐 Port Mappings:${NC}"
    docker port "$container" 2>/dev/null || echo "No port mappings"
    
    # Volume mounts
    echo -e "${CYAN}💾 Volume Mounts:${NC}"
    docker inspect "$container" --format '{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}} ({{.Mode}}){{"\n"}}{{end}}'
    
    # Environment variables
    echo -e "${CYAN}🌍 Environment Variables:${NC}"
    docker exec "$container" env 2>/dev/null | sort || warn "Could not retrieve environment variables"
    
    # Network settings
    echo -e "${CYAN}🔗 Network Settings:${NC}"
    docker inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}: {{$value.IPAddress}}{{"\n"}}{{end}}'
    
    # Recent log entries
    echo -e "${CYAN}📝 Recent Log Entries (last 10):${NC}"
    docker logs --tail 10 "$container" 2>&1 | head -20
    
    success "Container inspection completed"
}

# Advanced network debugging
debug_network() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🌐 Network Debugging: $container"
    echo "================================"
    
    # Get container IP
    local container_ip=$(docker inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}{{$value.IPAddress}}{{end}}' | head -1)
    
    echo -e "${CYAN}📍 Container Network Info:${NC}"
    echo "Container IP: $container_ip"
    
    # Network interfaces
    echo -e "${CYAN}🔌 Network Interfaces:${NC}"
    docker exec "$container" ip addr show 2>/dev/null || docker exec "$container" ifconfig 2>/dev/null || warn "Network interface info unavailable"
    
    # Routing table
    echo -e "${CYAN}🛣️ Routing Table:${NC}"
    docker exec "$container" ip route show 2>/dev/null || docker exec "$container" route -n 2>/dev/null || warn "Routing info unavailable"
    
    # DNS configuration
    echo -e "${CYAN}🔍 DNS Configuration:${NC}"
    docker exec "$container" cat /etc/resolv.conf 2>/dev/null || warn "DNS config unavailable"
    
    # Test connectivity to common endpoints
    echo -e "${CYAN}🔗 Connectivity Tests:${NC}"
    test_endpoints=("8.8.8.8" "google.com" "docker.com")
    
    for endpoint in "${test_endpoints[@]}"; do
        if docker exec "$container" ping -c 2 "$endpoint" >/dev/null 2>&1; then
            success "✓ Can reach $endpoint"
        else
            error "✗ Cannot reach $endpoint"
        fi
    done
    
    # Port scans
    echo -e "${CYAN}📡 Open Ports:${NC}"
    docker exec "$container" netstat -tulpn 2>/dev/null | grep LISTEN || \
    docker exec "$container" ss -tulpn 2>/dev/null | grep LISTEN || \
    warn "Port information unavailable"
    
    # Network namespace debugging with netshoot
    if docker images "$DEBUG_IMAGE" >/dev/null 2>&1 || docker pull "$DEBUG_IMAGE" >/dev/null 2>&1; then
        echo -e "${CYAN}🛠️ Advanced Network Debugging (using netshoot):${NC}"
        
        log "Starting netshoot container for network debugging..."
        docker run --rm -it --network container:"$container" "$DEBUG_IMAGE" bash -c "
        echo '=== Network Namespace Analysis ==='
        ip addr show
        echo
        echo '=== Routing Table ==='  
        ip route show
        echo
        echo '=== DNS Resolution Test ==='
        nslookup google.com || true
        echo
        echo '=== Port Connectivity ==='
        nc -zv google.com 80 || true
        echo
        echo '=== Network Traffic Analysis (5 seconds) ==='
        timeout 5 tcpdump -i any -c 10 2>/dev/null || echo 'No traffic captured'
        "
    else
        warn "Debug image $DEBUG_IMAGE not available for advanced network debugging"
    fi
    
    success "Network debugging completed"
}

# Process and performance analysis
debug_processes() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🔄 Process Analysis: $container"
    echo "============================="
    
    # Process tree
    echo -e "${CYAN}🌳 Process Tree:${NC}"
    docker exec "$container" pstree -p 2>/dev/null || docker exec "$container" ps auxf 2>/dev/null || warn "Process tree unavailable"
    
    # Top processes by CPU/Memory
    echo -e "${CYAN}📊 Resource Usage by Process:${NC}"
    docker exec "$container" top -b -n 1 2>/dev/null | head -20 || docker exec "$container" ps aux --sort=-%cpu,-%mem 2>/dev/null | head -10
    
    # System load
    echo -e "${CYAN}⚡ System Load:${NC}"
    docker exec "$container" uptime 2>/dev/null || warn "Uptime info unavailable"
    
    # Memory analysis
    echo -e "${CYAN}🧠 Memory Analysis:${NC}"
    docker exec "$container" free -h 2>/dev/null || warn "Memory info unavailable"
    
    # Disk I/O
    echo -e "${CYAN}💿 Disk I/O:${NC}"
    docker exec "$container" iostat -x 1 1 2>/dev/null || docker exec "$container" vmstat 1 1 2>/dev/null || warn "I/O stats unavailable"
    
    # Open files
    echo -e "${CYAN}📁 Open Files:${NC}"
    docker exec "$container" lsof 2>/dev/null | head -20 || docker exec "$container" ls -la /proc/*/fd/ 2>/dev/null | wc -l && echo "file descriptors" || warn "Open files info unavailable"
    
    # Performance profiling with perf (if available)
    echo -e "${CYAN}🎯 Performance Profiling:${NC}"
    if docker exec "$container" which perf >/dev/null 2>&1; then
        log "Running performance profile (5 seconds)..."
        docker exec "$container" perf top -n -d 5 2>/dev/null || warn "Performance profiling failed"
    else
        warn "perf command not available in container"
    fi
    
    success "Process analysis completed"
}

# Filesystem debugging
debug_filesystem() {
    local container=$1
    validate_container "$container" || return 1
    
    log "💾 Filesystem Debugging: $container"
    echo "================================="
    
    # Disk usage
    echo -e "${CYAN}📊 Disk Usage:${NC}"
    docker exec "$container" df -h 2>/dev/null || warn "Disk usage unavailable"
    
    # Inode usage
    echo -e "${CYAN}🔢 Inode Usage:${NC}"
    docker exec "$container" df -i 2>/dev/null || warn "Inode usage unavailable"
    
    # Mount points
    echo -e "${CYAN}🗂️ Mount Points:${NC}"
    docker exec "$container" mount 2>/dev/null || docker exec "$container" cat /proc/mounts 2>/dev/null || warn "Mount info unavailable"
    
    # Large files
    echo -e "${CYAN}📦 Large Files (>10MB):${NC}"
    docker exec "$container" find / -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -10 || warn "Large file search failed"
    
    # Filesystem errors
    echo -e "${CYAN}⚠️ Filesystem Errors:${NC}"
    docker exec "$container" dmesg 2>/dev/null | grep -i "error\|fail\|corrupt" | tail -5 || warn "Kernel messages unavailable"
    
    # Directory sizes
    echo -e "${CYAN}📁 Directory Sizes:${NC}"
    docker exec "$container" du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10 || warn "Directory size analysis failed"
    
    # Recent file changes
    echo -e "${CYAN}🕐 Recent File Changes (last hour):${NC}"
    docker exec "$container" find /var/log -type f -mmin -60 2>/dev/null || warn "Recent changes search failed"
    
    success "Filesystem debugging completed"
}

# Advanced log analysis
debug_logs() {
    local container=$1
    local tail_lines=${2:-50}
    validate_container "$container" || return 1
    
    log "📝 Advanced Log Analysis: $container"
    echo "===================================="
    
    # Basic log info
    echo -e "${CYAN}ℹ️ Log Information:${NC}"
    local log_driver=$(docker inspect "$container" --format '{{.HostConfig.LogConfig.Type}}')
    echo "Log Driver: $log_driver"
    
    # Recent logs with timestamps
    echo -e "${CYAN}🕐 Recent Logs (last $tail_lines lines):${NC}"
    docker logs --timestamps --tail "$tail_lines" "$container" 2>&1
    
    # Error analysis
    echo -e "${CYAN}❌ Error Analysis:${NC}"
    local error_count=$(docker logs "$container" 2>&1 | grep -i "error\|exception\|fail\|fatal" | wc -l)
    echo "Error/Exception count: $error_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo "Recent errors:"
        docker logs "$container" 2>&1 | grep -i "error\|exception\|fail\|fatal" | tail -5
    fi
    
    # Log patterns analysis
    echo -e "${CYAN}📊 Log Patterns:${NC}"
    echo "Most frequent log entries:"
    docker logs "$container" 2>&1 | head -1000 | sort | uniq -c | sort -nr | head -5
    
    # Log size analysis
    echo -e "${CYAN}📏 Log Size Analysis:${NC}"
    if [ "$log_driver" = "json-file" ]; then
        local log_path="/var/lib/docker/containers/$(docker inspect "$container" --format '{{.Id}}')/$(docker inspect "$container" --format '{{.Id}}')-json.log"
        if [ -f "$log_path" ]; then
            echo "Log file size: $(du -h "$log_path" | cut -f1)"
        fi
    fi
    
    # Real-time log monitoring option
    echo -e "${CYAN}👁️ Real-time Monitoring:${NC}"
    read -p "Start real-time log monitoring? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Starting real-time log monitoring (Ctrl+C to stop)..."
        docker logs -f "$container"
    fi
    
    success "Log analysis completed"
}

# Attach debugging container
attach_debug_container() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🛠️ Attaching Debug Container: $container"
    echo "======================================="
    
    # Pull debug image if not available
    if ! docker images "$DEBUG_IMAGE" >/dev/null 2>&1; then
        log "Pulling debug image: $DEBUG_IMAGE"
        docker pull "$DEBUG_IMAGE" || {
            error "Failed to pull debug image"
            return 1
        }
    fi
    
    # Get container details
    local container_pid=$(docker inspect "$container" --format '{{.State.Pid}}')
    local container_network=$(docker inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' | head -1)
    
    echo "Container PID: $container_pid"
    echo "Container Network: $container_network"
    
    # Attach debug container with various debugging tools
    log "Starting interactive debugging session..."
    echo "Available tools: tcpdump, netstat, ss, nmap, dig, curl, wget, strace, htop"
    echo "Type 'exit' to end debugging session"
    
    docker run -it --rm \
        --name "${container}_debug_$(date +%s)" \
        --network container:"$container" \
        --pid container:"$container" \
        --cap-add SYS_PTRACE \
        --cap-add SYS_ADMIN \
        "$DEBUG_IMAGE"
    
    success "Debug session ended"
}

# Health check analysis
debug_health() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🏥 Health Check Analysis: $container"
    echo "=================================="
    
    # Health status
    local health_status=$(docker inspect "$container" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
    echo "Health Status: $health_status"
    
    if [ "$health_status" != "no healthcheck" ]; then
        # Health check configuration
        echo -e "${CYAN}⚕️ Health Check Configuration:${NC}"
        docker inspect "$container" --format '{{.Config.Healthcheck}}'
        
        # Health check history
        echo -e "${CYAN}📜 Health Check History:${NC}"
        docker inspect "$container" --format '{{range .State.Health.Log}}{{.Start}}: {{.Output}}{{end}}'
        
        # Manual health check execution
        echo -e "${CYAN}🔬 Manual Health Check Test:${NC}"
        local healthcheck_cmd=$(docker inspect "$container" --format '{{join .Config.Healthcheck.Test " "}}')
        if [ "$healthcheck_cmd" != "" ]; then
            echo "Executing: $healthcheck_cmd"
            docker exec "$container" $healthcheck_cmd || warn "Health check command failed"
        fi
    else
        warn "No health check configured for this container"
        echo "Consider adding a health check to your Dockerfile:"
        echo "HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost/ || exit 1"
    fi
    
    success "Health check analysis completed"
}

# Resource usage analysis
debug_resources() {
    local container=$1
    validate_container "$container" || return 1
    
    log "📊 Resource Usage Analysis: $container"
    echo "====================================="
    
    # Current resource usage
    echo -e "${CYAN}📈 Current Usage:${NC}"
    docker stats "$container" --no-stream
    
    # Resource limits
    echo -e "${CYAN}🚧 Resource Limits:${NC}"
    docker inspect "$container" --format '
Memory Limit: {{.HostConfig.Memory}}
CPU Limit: {{.HostConfig.CpuQuota}}
CPU Period: {{.HostConfig.CpuPeriod}}
CPU Shares: {{.HostConfig.CpuShares}}
Swap Limit: {{.HostConfig.MemorySwap}}
OOM Kill Disable: {{.HostConfig.OomKillDisable}}
'
    
    # Detailed memory usage
    echo -e "${CYAN}🧠 Detailed Memory Usage:${NC}"
    local container_id=$(docker inspect "$container" --format '{{.Id}}')
    if [ -f "/sys/fs/cgroup/memory/docker/$container_id/memory.usage_in_bytes" ]; then
        echo "Memory Usage: $(cat /sys/fs/cgroup/memory/docker/$container_id/memory.usage_in_bytes 2>/dev/null) bytes"
        echo "Memory Limit: $(cat /sys/fs/cgroup/memory/docker/$container_id/memory.limit_in_bytes 2>/dev/null) bytes"
    fi
    
    # Process memory breakdown
    echo -e "${CYAN}🔍 Process Memory Breakdown:${NC}"
    docker exec "$container" ps aux --sort=-%mem | head -10 2>/dev/null || warn "Process memory info unavailable"
    
    # Historical resource usage (if available)
    echo -e "${CYAN}📊 Resource Usage Trend (last 30 seconds):${NC}"
    log "Monitoring resource usage..."
    for i in {1..6}; do
        docker stats "$container" --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" | awk '{print "CPU: " $1 " Memory: " $2}'
        sleep 5
    done
    
    success "Resource analysis completed"
}

# Security analysis
debug_security() {
    local container=$1
    validate_container "$container" || return 1
    
    log "🔒 Security Analysis: $container"
    echo "============================="
    
    # Security options
    echo -e "${CYAN}🛡️ Security Configuration:${NC}"
    docker inspect "$container" --format '
Privileged: {{.HostConfig.Privileged}}
User: {{.Config.User}}
Security Options: {{join .HostConfig.SecurityOpt " "}}
Capabilities: {{join .HostConfig.CapAdd " "}} (added), {{join .HostConfig.CapDrop " "}} (dropped)
Read-only Root: {{.HostConfig.ReadonlyRootfs}}
No New Privileges: {{.HostConfig.SecurityOpt}}
'
    
    # Running processes and users
    echo -e "${CYAN}👤 Process Users:${NC}"
    docker exec "$container" ps aux 2>/dev/null | awk '{print $1}' | sort | uniq -c || warn "Process user info unavailable"
    
    # File permissions analysis
    echo -e "${CYAN}📁 Critical File Permissions:${NC}"
    docker exec "$container" ls -la / 2>/dev/null | grep -E "(bin|etc|usr)" || warn "File permission check failed"
    
    # Network security
    echo -e "${CYAN}🌐 Network Security:${NC}"
    docker exec "$container" netstat -tulpn 2>/dev/null | grep "0.0.0.0" && warn "Services listening on all interfaces" || success "No services listening on all interfaces"
    
    # SUID/SGID files
    echo -e "${CYAN}🔑 SUID/SGID Files:${NC}"
    docker exec "$container" find / -type f \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \; 2>/dev/null | head -10 || warn "SUID/SGID file search failed"
    
    success "Security analysis completed"
}

# Build debugging
debug_build() {
    local dockerfile=${1:-Dockerfile}
    
    log "🔨 Build Debugging: $dockerfile"
    echo "==============================="
    
    if [ ! -f "$dockerfile" ]; then
        error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    # Analyze Dockerfile
    echo -e "${CYAN}📋 Dockerfile Analysis:${NC}"
    echo "Total lines: $(wc -l < "$dockerfile")"
    echo "FROM statements: $(grep -c "^FROM" "$dockerfile")"
    echo "RUN statements: $(grep -c "^RUN" "$dockerfile")"
    echo "COPY/ADD statements: $(grep -c -E "^(COPY|ADD)" "$dockerfile")"
    
    # Check for common issues
    echo -e "${CYAN}⚠️ Potential Issues:${NC}"
    
    # Large context warning
    local context_size=$(du -sh . 2>/dev/null | cut -f1)
    echo "Build context size: $context_size"
    
    # Missing .dockerignore
    [ ! -f ".dockerignore" ] && warn "No .dockerignore file found"
    
    # Cache busting layers
    if grep -q "RUN.*update\|RUN.*upgrade" "$dockerfile"; then
        warn "Package updates in RUN commands may bust cache"
    fi
    
    # Build with verbose output
    echo -e "${CYAN}🔍 Verbose Build Analysis:${NC}"
    read -p "Run verbose build analysis? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DOCKER_BUILDKIT=1 docker build --progress=plain --no-cache -f "$dockerfile" .
    fi
    
    success "Build debugging completed"
}

# Main function
main() {
    local command=""
    local container=""
    local extra_args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--image)
                DEBUG_IMAGE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            inspect|network|process|filesystem|logs|attach|health|resources|security|build)
                command="$1"
                shift
                ;;
            --*)
                extra_args+=("$1")
                shift
                ;;
            *)
                if [ -z "$container" ]; then
                    container="$1"
                else
                    extra_args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Default command if none specified
    if [ -z "$command" ]; then
        command="inspect"
    fi
    
    # Execute command
    case $command in
        inspect)
            inspect_container "$container"
            ;;
        network)
            debug_network "$container"
            ;;
        process)
            debug_processes "$container"
            ;;
        filesystem)
            debug_filesystem "$container"
            ;;
        logs)
            debug_logs "$container" "${extra_args[0]:-50}"
            ;;
        attach)
            attach_debug_container "$container"
            ;;
        health)
            debug_health "$container"
            ;;
        resources)
            debug_resources "$container"
            ;;
        security)
            debug_security "$container"
            ;;
        build)
            debug_build "$container"
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing+=("docker")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# Initialize
check_dependencies

# Handle no arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"