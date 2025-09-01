#!/bin/bash
# 09_advanced_tricks/debugging-tools/container-inspection.sh

# Container Inspection and Debugging Tool
# Comprehensive container analysis and troubleshooting utilities

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
CONTAINER_ID=""
OUTPUT_DIR=""
VERBOSE=false
SAVE_LOGS=false

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

print_header() {
    echo -e "\n${BLUE}==================== $1 ====================${NC}"
}

print_separator() {
    echo -e "${PURPLE}${'='*60}${NC}"
}

# Function to display usage
usage() {
    cat << EOF
Container Inspection and Debugging Tool

Usage: $0 [OPTIONS] <container_id_or_name>

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -o, --output DIR        Save inspection results to directory
    -l, --save-logs         Save container logs to files
    -a, --all               Run all inspection checks
    -p, --processes         Inspect running processes
    -n, --network           Inspect network configuration
    -f, --filesystem        Inspect filesystem and mounts
    -r, --resources         Inspect resource usage
    -e, --environment       Inspect environment variables
    -c, --config            Inspect container configuration
    -s, --stats             Show real-time container statistics
    -d, --dependencies      Check container dependencies
    -t, --troubleshoot      Run troubleshooting diagnostics

EXAMPLES:
    $0 my-container                     # Basic inspection
    $0 -a my-container                  # Complete inspection
    $0 -v -o /tmp/debug my-container    # Verbose with output save
    $0 -s my-container                  # Real-time statistics
    $0 -t my-container                  # Troubleshooting mode

EOF
}

# Function to check if container exists
check_container_exists() {
    if ! docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
        log_error "Container '$CONTAINER_ID' not found"
        exit 1
    fi
}

# Function to setup output directory
setup_output_dir() {
    if [[ -n "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "Output directory: $OUTPUT_DIR"
    fi
}

# Function to save output to file
save_output() {
    local filename="$1"
    local content="$2"
    
    if [[ -n "$OUTPUT_DIR" ]]; then
        echo "$content" > "$OUTPUT_DIR/$filename"
        log_debug "Saved to $OUTPUT_DIR/$filename"
    fi
}

# Basic container information
inspect_basic_info() {
    print_header "BASIC CONTAINER INFORMATION"
    
    local info
    info=$(docker inspect "$CONTAINER_ID" --format '
Container ID: {{.Id}}
Name: {{.Name}}
Image: {{.Config.Image}}
Status: {{.State.Status}}
Running: {{.State.Running}}
Started At: {{.State.StartedAt}}
Finished At: {{.State.FinishedAt}}
Restart Count: {{.RestartCount}}
Platform: {{.Platform}}
Driver: {{.Driver}}
')
    
    echo "$info"
    save_output "basic_info.txt" "$info"
    
    # Container state details
    local state
    state=$(docker inspect "$CONTAINER_ID" --format '
State Details:
  PID: {{.State.Pid}}
  Exit Code: {{.State.ExitCode}}
  Error: {{.State.Error}}
  OOMKilled: {{.State.OOMKilled}}
  Dead: {{.State.Dead}}
  Paused: {{.State.Paused}}
  Restarting: {{.State.Restarting}}
')
    
    echo "$state"
    save_output "state_details.txt" "$state"
}

# Inspect running processes
inspect_processes() {
    print_header "RUNNING PROCESSES"
    
    local processes
    if docker exec "$CONTAINER_ID" ps aux 2>/dev/null; then
        processes=$(docker exec "$CONTAINER_ID" ps aux 2>/dev/null)
        save_output "processes.txt" "$processes"
    else
        log_warn "Could not inspect processes (container may be stopped)"
    fi
    
    # Process tree
    echo -e "\n${CYAN}Process Tree:${NC}"
    if docker exec "$CONTAINER_ID" pstree -p 2>/dev/null; then
        local process_tree
        process_tree=$(docker exec "$CONTAINER_ID" pstree -p 2>/dev/null)
        save_output "process_tree.txt" "$process_tree"
    else
        log_warn "pstree not available in container"
    fi
    
    # Top processes by CPU and memory
    echo -e "\n${CYAN}Top Processes by CPU:${NC}"
    docker exec "$CONTAINER_ID" sh -c 'ps aux --sort=-%cpu | head -10' 2>/dev/null || log_warn "Could not get CPU usage"
    
    echo -e "\n${CYAN}Top Processes by Memory:${NC}"
    docker exec "$CONTAINER_ID" sh -c 'ps aux --sort=-%mem | head -10' 2>/dev/null || log_warn "Could not get memory usage"
}

# Inspect network configuration
inspect_network() {
    print_header "NETWORK CONFIGURATION"
    
    # Container network settings
    local network_info
    network_info=$(docker inspect "$CONTAINER_ID" --format '
Network Mode: {{.HostConfig.NetworkMode}}
IP Address: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
Gateway: {{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}
MAC Address: {{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}
Ports: {{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}
')
    
    echo "$network_info"
    save_output "network_info.txt" "$network_info"
    
    # Network interfaces inside container
    echo -e "\n${CYAN}Network Interfaces:${NC}"
    if docker exec "$CONTAINER_ID" ip addr 2>/dev/null; then
        local interfaces
        interfaces=$(docker exec "$CONTAINER_ID" ip addr 2>/dev/null)
        save_output "interfaces.txt" "$interfaces"
    else
        log_warn "Could not inspect network interfaces"
    fi
    
    # Routing table
    echo -e "\n${CYAN}Routing Table:${NC}"
    docker exec "$CONTAINER_ID" ip route 2>/dev/null || log_warn "Could not get routing table"
    
    # DNS configuration
    echo -e "\n${CYAN}DNS Configuration:${NC}"
    docker exec "$CONTAINER_ID" cat /etc/resolv.conf 2>/dev/null || log_warn "Could not read DNS config"
    
    # Network connectivity tests
    echo -e "\n${CYAN}Network Connectivity Tests:${NC}"
    docker exec "$CONTAINER_ID" ping -c 3 8.8.8.8 2>/dev/null || log_warn "External connectivity test failed"
    docker exec "$CONTAINER_ID" nslookup google.com 2>/dev/null || log_warn "DNS resolution test failed"
}

# Inspect filesystem and mounts
inspect_filesystem() {
    print_header "FILESYSTEM AND MOUNTS"
    
    # Mount information
    local mounts
    mounts=$(docker inspect "$CONTAINER_ID" --format '{{range .Mounts}}
Type: {{.Type}}
Source: {{.Source}}
Destination: {{.Destination}}
Mode: {{.Mode}}
RW: {{.RW}}
Propagation: {{.Propagation}}
{{end}}')
    
    echo "Mount Points:"
    echo "$mounts"
    save_output "mounts.txt" "$mounts"
    
    # Disk usage
    echo -e "\n${CYAN}Disk Usage:${NC}"
    if docker exec "$CONTAINER_ID" df -h 2>/dev/null; then
        local disk_usage
        disk_usage=$(docker exec "$CONTAINER_ID" df -h 2>/dev/null)
        save_output "disk_usage.txt" "$disk_usage"
    fi
    
    # Inode usage
    echo -e "\n${CYAN}Inode Usage:${NC}"
    docker exec "$CONTAINER_ID" df -i 2>/dev/null || log_warn "Could not get inode usage"
    
    # Large files
    echo -e "\n${CYAN}Largest Files (>10MB):${NC}"
    docker exec "$CONTAINER_ID" find / -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -20 || log_warn "Could not find large files"
    
    # File system type
    echo -e "\n${CYAN}Filesystem Information:${NC}"
    docker exec "$CONTAINER_ID" mount | column -t 2>/dev/null || log_warn "Could not get filesystem info"
}

# Inspect resource usage
inspect_resources() {
    print_header "RESOURCE USAGE"
    
    # Docker stats
    echo -e "${CYAN}Current Resource Usage:${NC}"
    docker stats "$CONTAINER_ID" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    # Memory details
    echo -e "\n${CYAN}Memory Details:${NC}"
    if docker exec "$CONTAINER_ID" free -h 2>/dev/null; then
        local memory_info
        memory_info=$(docker exec "$CONTAINER_ID" free -h 2>/dev/null)
        save_output "memory_info.txt" "$memory_info"
    fi
    
    # CPU information
    echo -e "\n${CYAN}CPU Information:${NC}"
    docker exec "$CONTAINER_ID" nproc 2>/dev/null || log_warn "Could not get CPU count"
    docker exec "$CONTAINER_ID" cat /proc/cpuinfo | grep "model name" | head -1 2>/dev/null || log_warn "Could not get CPU model"
    
    # Load average
    echo -e "\n${CYAN}Load Average:${NC}"
    docker exec "$CONTAINER_ID" uptime 2>/dev/null || log_warn "Could not get load average"
    
    # Resource limits from Docker
    echo -e "\n${CYAN}Docker Resource Limits:${NC}"
    docker inspect "$CONTAINER_ID" --format '
Memory Limit: {{.HostConfig.Memory}}
Memory Swap: {{.HostConfig.MemorySwap}}
CPU Shares: {{.HostConfig.CpuShares}}
CPU Quota: {{.HostConfig.CpuQuota}}
CPU Period: {{.HostConfig.CpuPeriod}}
CPU Count: {{.HostConfig.NanoCpus}}
'
}

# Inspect environment variables
inspect_environment() {
    print_header "ENVIRONMENT VARIABLES"
    
    local env_vars
    env_vars=$(docker inspect "$CONTAINER_ID" --format '{{range .Config.Env}}{{println .}}{{end}}' | sort)
    
    echo "$env_vars"
    save_output "environment.txt" "$env_vars"
    
    # Environment inside container (may differ from config)
    echo -e "\n${CYAN}Runtime Environment:${NC}"
    if docker exec "$CONTAINER_ID" env 2>/dev/null | sort; then
        local runtime_env
        runtime_env=$(docker exec "$CONTAINER_ID" env 2>/dev/null | sort)
        save_output "runtime_environment.txt" "$runtime_env"
    fi
}

# Inspect container configuration
inspect_config() {
    print_header "CONTAINER CONFIGURATION"
    
    local full_config
    full_config=$(docker inspect "$CONTAINER_ID")
    
    echo "Full container configuration saved to file"
    save_output "full_config.json" "$full_config"
    
    # Key configuration elements
    echo -e "${CYAN}Key Configuration:${NC}"
    docker inspect "$CONTAINER_ID" --format '
Image: {{.Config.Image}}
Hostname: {{.Config.Hostname}}
User: {{.Config.User}}
WorkingDir: {{.Config.WorkingDir}}
Entrypoint: {{.Config.Entrypoint}}
Cmd: {{.Config.Cmd}}
Labels: {{range $key, $value := .Config.Labels}}
  {{$key}}: {{$value}}{{end}}
'
    
    # Security configuration
    echo -e "\n${CYAN}Security Configuration:${NC}"
    docker inspect "$CONTAINER_ID" --format '
Privileged: {{.HostConfig.Privileged}}
ReadonlyRootfs: {{.HostConfig.ReadonlyRootfs}}
SecurityOpt: {{range .HostConfig.SecurityOpt}}{{.}} {{end}}
CapAdd: {{range .HostConfig.CapAdd}}{{.}} {{end}}
CapDrop: {{range .HostConfig.CapDrop}}{{.}} {{end}}
'
}

# Show real-time statistics
show_stats() {
    print_header "REAL-TIME CONTAINER STATISTICS"
    log_info "Press Ctrl+C to stop"
    
    docker stats "$CONTAINER_ID"
}

# Check container dependencies
check_dependencies() {
    print_header "CONTAINER DEPENDENCIES"
    
    # Linked containers
    echo -e "${CYAN}Container Links:${NC}"
    docker inspect "$CONTAINER_ID" --format '{{range $key, $value := .HostConfig.Links}}{{$key}} -> {{$value}}{{end}}'
    
    # Network dependencies
    echo -e "\n${CYAN}Network Connections:${NC}"
    docker inspect "$CONTAINER_ID" --format '{{range $key, $value := .NetworkSettings.Networks}}Network: {{$key}}{{end}}'
    
    # Volume dependencies
    echo -e "\n${CYAN}Volume Dependencies:${NC}"
    docker inspect "$CONTAINER_ID" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{end}}'
    
    # Check if container depends on other containers
    echo -e "\n${CYAN}Service Dependencies:${NC}"
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_file
        compose_file=$(find . -name "docker-compose*.yml" | head -1)
        if [[ -n "$compose_file" ]]; then
            log_info "Found compose file: $compose_file"
            grep -A 10 -B 2 "$CONTAINER_ID" "$compose_file" 2>/dev/null || log_warn "Container not found in compose file"
        fi
    fi
}

# Run troubleshooting diagnostics
troubleshoot() {
    print_header "TROUBLESHOOTING DIAGNOSTICS"
    
    # Check if container is running
    local status
    status=$(docker inspect "$CONTAINER_ID" --format '{{.State.Status}}')
    
    if [[ "$status" != "running" ]]; then
        log_error "Container is not running (Status: $status)"
        
        # Get exit code and error
        local exit_code error
        exit_code=$(docker inspect "$CONTAINER_ID" --format '{{.State.ExitCode}}')
        error=$(docker inspect "$CONTAINER_ID" --format '{{.State.Error}}')
        
        echo "Exit Code: $exit_code"
        echo "Error: $error"
        
        # Show recent logs
        echo -e "\n${CYAN}Recent Logs:${NC}"
        docker logs --tail 50 "$CONTAINER_ID"
        
        return
    fi
    
    # Health check status
    echo -e "${CYAN}Health Check Status:${NC}"
    local health
    health=$(docker inspect "$CONTAINER_ID" --format '{{.State.Health.Status}}' 2>/dev/null || echo "No health check configured")
    echo "Status: $health"
    
    # Check resource constraints
    echo -e "\n${CYAN}Resource Constraint Analysis:${NC}"
    local mem_limit cpu_limit
    mem_limit=$(docker inspect "$CONTAINER_ID" --format '{{.HostConfig.Memory}}')
    cpu_limit=$(docker inspect "$CONTAINER_ID" --format '{{.HostConfig.CpuQuota}}')
    
    if [[ "$mem_limit" != "0" ]]; then
        echo "Memory limit: $((mem_limit / 1024 / 1024))MB"
    else
        echo "No memory limit set"
    fi
    
    if [[ "$cpu_limit" != "0" ]]; then
        echo "CPU limit: $cpu_limit microseconds per period"
    else
        echo "No CPU limit set"
    fi
    
    # Check for common issues
    echo -e "\n${CYAN}Common Issue Checks:${NC}"
    
    # Disk space
    if docker exec "$CONTAINER_ID" df -h / 2>/dev/null | grep -E '9[0-9]%|100%'; then
        log_warn "Disk space may be running low"
    fi
    
    # Memory usage
    if docker stats "$CONTAINER_ID" --no-stream --format '{{.MemPerc}}' | grep -E '9[0-9]\.|100\.'; then
        log_warn "Memory usage is very high"
    fi
    
    # Check for zombie processes
    local zombies
    zombies=$(docker exec "$CONTAINER_ID" ps aux 2>/dev/null | grep -c '<defunct>' || echo "0")
    if [[ "$zombies" -gt "0" ]]; then
        log_warn "Found $zombies zombie processes"
    fi
    
    # Network connectivity
    echo -e "\n${CYAN}Network Connectivity Test:${NC}"
    if ! docker exec "$CONTAINER_ID" ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_warn "External network connectivity issue detected"
    else
        log_info "External network connectivity OK"
    fi
}

# Save container logs
save_logs() {
    if [[ "$SAVE_LOGS" == "true" && -n "$OUTPUT_DIR" ]]; then
        print_header "SAVING CONTAINER LOGS"
        
        log_info "Saving container logs..."
        docker logs "$CONTAINER_ID" > "$OUTPUT_DIR/container_logs.txt" 2>&1
        
        log_info "Saving recent logs with timestamps..."
        docker logs -t --since="24h" "$CONTAINER_ID" > "$OUTPUT_DIR/recent_logs.txt" 2>&1
        
        log_info "Logs saved to $OUTPUT_DIR/"
    fi
}

# Generate summary report
generate_summary() {
    if [[ -n "$OUTPUT_DIR" ]]; then
        print_header "GENERATING SUMMARY REPORT"
        
        local summary_file="$OUTPUT_DIR/inspection_summary.md"
        
        cat > "$summary_file" << EOF
# Container Inspection Summary

**Container:** $CONTAINER_ID
**Date:** $(date)
**Inspector:** $(whoami)@$(hostname)

## Status
- **State:** $(docker inspect "$CONTAINER_ID" --format '{{.State.Status}}')
- **Running:** $(docker inspect "$CONTAINER_ID" --format '{{.State.Running}}')
- **Health:** $(docker inspect "$CONTAINER_ID" --format '{{.State.Health.Status}}' 2>/dev/null || echo "No health check")

## Resource Usage
$(docker stats "$CONTAINER_ID" --no-stream --format "- **CPU:** {{.CPUPerc}}\n- **Memory:** {{.MemUsage}} ({{.MemPerc}})\n- **Network I/O:** {{.NetIO}}\n- **Block I/O:** {{.BlockIO}}")

## Files Generated
$(ls -la "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json 2>/dev/null | awk '{print "- " $9 " (" $5 " bytes)"}')

## Recommendations
EOF
        
        # Add recommendations based on findings
        if docker stats "$CONTAINER_ID" --no-stream --format '{{.MemPerc}}' | grep -qE '9[0-9]\.|100\.'; then
            echo "- ⚠️  Consider increasing memory limits or optimizing memory usage" >> "$summary_file"
        fi
        
        if docker exec "$CONTAINER_ID" df -h / 2>/dev/null | grep -qE '9[0-9]%|100%'; then
            echo "- ⚠️  Disk space is running low - consider cleanup or volume expansion" >> "$summary_file"
        fi
        
        log_info "Summary report generated: $summary_file"
    fi
}

# Main function
main() {
    local run_all=false
    local check_processes=false
    local check_network=false
    local check_filesystem=false
    local check_resources=false
    local check_environment=false
    local check_config=false
    local show_statistics=false
    local check_deps=false
    local run_troubleshoot=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -l|--save-logs)
                SAVE_LOGS=true
                shift
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            -p|--processes)
                check_processes=true
                shift
                ;;
            -n|--network)
                check_network=true
                shift
                ;;
            -f|--filesystem)
                check_filesystem=true
                shift
                ;;
            -r|--resources)
                check_resources=true
                shift
                ;;
            -e|--environment)
                check_environment=true
                shift
                ;;
            -c|--config)
                check_config=true
                shift
                ;;
            -s|--stats)
                show_statistics=true
                shift
                ;;
            -d|--dependencies)
                check_deps=true
                shift
                ;;
            -t|--troubleshoot)
                run_troubleshoot=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$CONTAINER_ID" ]]; then
                    CONTAINER_ID="$1"
                else
                    log_error "Multiple container IDs specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if container ID is provided
    if [[ -z "$CONTAINER_ID" ]]; then
        log_error "Container ID or name is required"
        usage
        exit 1
    fi
    
    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if container exists
    check_container_exists
    
    # Setup output directory
    setup_output_dir
    
    log_info "Inspecting container: $CONTAINER_ID"
    
    # Always show basic info
    inspect_basic_info
    
    # Run specific checks or all checks
    if [[ "$run_all" == "true" ]]; then
        inspect_processes
        inspect_network
        inspect_filesystem
        inspect_resources
        inspect_environment
        inspect_config
        check_dependencies
        troubleshoot
    else
        [[ "$check_processes" == "true" ]] && inspect_processes
        [[ "$check_network" == "true" ]] && inspect_network
        [[ "$check_filesystem" == "true" ]] && inspect_filesystem
        [[ "$check_resources" == "true" ]] && inspect_resources
        [[ "$check_environment" == "true" ]] && inspect_environment
        [[ "$check_config" == "true" ]] && inspect_config
        [[ "$check_deps" == "true" ]] && check_dependencies
        [[ "$run_troubleshoot" == "true" ]] && troubleshoot
    fi
    
    # Show real-time stats (this will block)
    [[ "$show_statistics" == "true" ]] && show_stats
    
    # Save logs if requested
    save_logs
    
    # Generate summary report
    generate_summary
    
    print_separator
    log_info "Container inspection completed"
    [[ -n "$OUTPUT_DIR" ]] && log_info "Results saved to: $OUTPUT_DIR"
}

# Run main function with all arguments
main "$@"