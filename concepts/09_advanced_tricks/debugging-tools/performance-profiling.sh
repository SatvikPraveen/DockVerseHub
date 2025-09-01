#!/bin/bash
# 09_advanced_tricks/debugging-tools/performance-profiling.sh

# Container Performance Profiling Tool
# Comprehensive performance analysis and bottleneck detection

set -euo pipefail

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Global configuration
CONTAINER_ID=""
DURATION=60
OUTPUT_DIR=""
PROFILE_CPU=false
PROFILE_MEMORY=false
PROFILE_IO=false
PROFILE_NETWORK=false
PROFILE_ALL=false
CONTINUOUS=false
INTERVAL=5
FLAME_GRAPH=false
VERBOSE=false

# Temporary files
TEMP_DIR=$(mktemp -d)
trap 'cleanup' EXIT

cleanup() {
    rm -rf "$TEMP_DIR"
}

# Logging functions
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

usage() {
    cat << EOF
Container Performance Profiling Tool

Usage: $0 [OPTIONS] <container_id_or_name>

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --duration SECONDS  Profiling duration (default: 60)
    -i, --interval SECONDS  Sampling interval (default: 5)
    -o, --output DIR        Save profiling results to directory
    -c, --continuous        Continuous profiling mode
    -f, --flame-graph       Generate flame graphs (requires perf)
    
    PROFILING MODES:
    -a, --all              Profile all aspects (CPU, Memory, I/O, Network)
    --cpu                  Profile CPU usage and performance
    --memory               Profile memory usage and allocation
    --io                   Profile disk I/O performance
    --network              Profile network performance
    
EXAMPLES:
    $0 my-container                        # Basic profiling
    $0 -a -d 120 my-container             # Complete 2-minute profile
    $0 --cpu --memory -o /tmp my-container # CPU and memory profiling
    $0 -c -i 10 my-container              # Continuous profiling every 10s
    $0 -f --cpu my-container              # CPU profiling with flame graphs

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    if [[ "$FLAME_GRAPH" == "true" ]] && ! command -v perf >/dev/null 2>&1; then
        log_warn "perf not found - flame graph generation will be disabled"
        FLAME_GRAPH=false
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Setup output directory
setup_output_dir() {
    if [[ -n "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "Output directory: $OUTPUT_DIR"
    fi
}

# Save output to file
save_output() {
    local filename="$1"
    local content="$2"
    
    if [[ -n "$OUTPUT_DIR" ]]; then
        echo "$content" > "$OUTPUT_DIR/$filename"
        log_debug "Saved to $OUTPUT_DIR/$filename"
    fi
}

# Get container PID
get_container_pid() {
    docker inspect "$CONTAINER_ID" --format '{{.State.Pid}}' 2>/dev/null
}

# Get container stats
get_container_stats() {
    docker stats "$CONTAINER_ID" --no-stream --format 'json' 2>/dev/null
}

# Profile CPU performance
profile_cpu() {
    print_header "CPU PERFORMANCE PROFILING"
    
    local container_pid
    container_pid=$(get_container_pid)
    
    if [[ -z "$container_pid" || "$container_pid" == "0" ]]; then
        log_error "Container is not running or PID not available"
        return 1
    fi
    
    log_info "Profiling CPU for $DURATION seconds..."
    
    # Get initial CPU information
    echo -e "${CYAN}Container CPU Information:${NC}"
    local cpu_info
    cpu_info=$(docker exec "$CONTAINER_ID" sh -c '
        echo "CPU Count: $(nproc)"
        echo "CPU Model: $(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2)"
        echo "CPU Frequency: $(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | cut -d: -f2)"
        echo "Load Average: $(uptime)"
    ' 2>/dev/null)
    echo "$cpu_info"
    save_output "cpu_info.txt" "$cpu_info"
    
    # Monitor CPU usage over time
    echo -e "\n${CYAN}CPU Usage Monitoring:${NC}"
    local cpu_samples=()
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    
    printf "%-20s %-10s %-10s %-10s %-15s\n" "Timestamp" "CPU%" "User%" "System%" "Load Avg"
    echo "----------------------------------------"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local timestamp=$(date '+%H:%M:%S')
        
        # Get Docker stats
        local stats
        stats=$(get_container_stats)
        local cpu_percent=$(echo "$stats" | jq -r '.CPUPerc // "0.00%"' | sed 's/%//')
        
        # Get detailed CPU stats from inside container
        local cpu_details
        cpu_details=$(docker exec "$CONTAINER_ID" sh -c '
            top -bn1 | grep "^%Cpu" | awk "{print \$2, \$4, \$6}"
        ' 2>/dev/null || echo "N/A N/A N/A")
        
        local user_cpu=$(echo "$cpu_details" | awk '{print $1}' | sed 's/%us,//')
        local sys_cpu=$(echo "$cpu_details" | awk '{print $2}' | sed 's/%sy,//')
        
        # Get load average
        local load_avg
        load_avg=$(docker exec "$CONTAINER_ID" uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        
        printf "%-20s %-10s %-10s %-10s %-15s\n" "$timestamp" "$cpu_percent%" "$user_cpu" "$sys_cpu" "$load_avg"
        
        cpu_samples+=("$cpu_percent")
        
        sleep "$INTERVAL"
    done
    
    # Calculate CPU statistics
    local cpu_avg cpu_max cpu_min
    cpu_avg=$(printf '%s\n' "${cpu_samples[@]}" | awk '{sum+=$1} END {print sum/NR}')
    cpu_max=$(printf '%s\n' "${cpu_samples[@]}" | sort -nr | head -1)
    cpu_min=$(printf '%s\n' "${cpu_samples[@]}" | sort -n | head -1)
    
    echo -e "\n${CYAN}CPU Statistics Summary:${NC}"
    local cpu_summary="
Average CPU Usage: ${cpu_avg}%
Maximum CPU Usage: ${cpu_max}%
Minimum CPU Usage: ${cpu_min}%
Sample Count: ${#cpu_samples[@]}
"
    echo "$cpu_summary"
    save_output "cpu_summary.txt" "$cpu_summary"
    
    # Get top CPU-consuming processes
    echo -e "\n${CYAN}Top CPU Consumers:${NC}"
    local top_cpu
    top_cpu=$(docker exec "$CONTAINER_ID" ps aux --sort=-%cpu | head -10 2>/dev/null)
    echo "$top_cpu"
    save_output "top_cpu_processes.txt" "$top_cpu"
    
    # CPU flame graph generation
    if [[ "$FLAME_GRAPH" == "true" ]] && command -v perf >/dev/null 2>&1; then
        echo -e "\n${CYAN}Generating CPU Flame Graph:${NC}"
        log_info "Recording CPU performance data for flame graph..."
        
        local flame_output="$TEMP_DIR/cpu_flame.perf"
        timeout "$DURATION" perf record -p "$container_pid" -g -o "$flame_output" 2>/dev/null || log_warn "Perf recording failed"
        
        if [[ -f "$flame_output" ]] && [[ -n "$OUTPUT_DIR" ]]; then
            perf script -i "$flame_output" > "$OUTPUT_DIR/cpu_flame.txt" 2>/dev/null || log_warn "Flame graph generation failed"
            log_info "CPU flame graph data saved to cpu_flame.txt"
        fi
    fi
}

# Profile memory usage
profile_memory() {
    print_header "MEMORY PERFORMANCE PROFILING"
    
    log_info "Profiling memory for $DURATION seconds..."
    
    # Get memory information
    echo -e "${CYAN}Container Memory Information:${NC}"
    local mem_info
    mem_info=$(docker exec "$CONTAINER_ID" sh -c '
        echo "Total Memory: $(free -h | grep ^Mem | awk "{print \$2}")"
        echo "Available Memory: $(free -h | grep ^Mem | awk "{print \$7}")"
        echo "Memory Limit: $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null | numfmt --to=iec || echo "unlimited")"
        echo "Memory Usage: $(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null | numfmt --to=iec || echo "unknown")"
    ' 2>/dev/null)
    echo "$mem_info"
    save_output "memory_info.txt" "$mem_info"
    
    # Monitor memory usage over time
    echo -e "\n${CYAN}Memory Usage Monitoring:${NC}"
    local mem_samples=()
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    
    printf "%-20s %-12s %-12s %-12s %-12s\n" "Timestamp" "Memory" "Memory%" "Cache" "Swap"
    echo "--------------------------------------------------------"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local timestamp=$(date '+%H:%M:%S')
        
        # Get Docker stats
        local stats
        stats=$(get_container_stats)
        local mem_usage=$(echo "$stats" | jq -r '.MemUsage // "0B"')
        local mem_percent=$(echo "$stats" | jq -r '.MemPerc // "0.00%"')
        
        # Get detailed memory stats
        local mem_details
        mem_details=$(docker exec "$CONTAINER_ID" sh -c '
            free -h | grep ^Mem | awk "{print \$3, \$6, \$7}"
        ' 2>/dev/null || echo "N/A N/A N/A")
        
        local cache=$(echo "$mem_details" | awk '{print $2}')
        local available=$(echo "$mem_details" | awk '{print $3}')
        
        printf "%-20s %-12s %-12s %-12s %-12s\n" "$timestamp" "$mem_usage" "$mem_percent" "$cache" "$available"
        
        # Store numeric value for statistics
        local mem_num=$(echo "$mem_percent" | sed 's/%//')
        mem_samples+=("$mem_num")
        
        sleep "$INTERVAL"
    done
    
    # Calculate memory statistics
    local mem_avg mem_max mem_min
    mem_avg=$(printf '%s\n' "${mem_samples[@]}" | awk '{sum+=$1} END {print sum/NR}')
    mem_max=$(printf '%s\n' "${mem_samples[@]}" | sort -nr | head -1)
    mem_min=$(printf '%s\n' "${mem_samples[@]}" | sort -n | head -1)
    
    echo -e "\n${CYAN}Memory Statistics Summary:${NC}"
    local mem_summary="
Average Memory Usage: ${mem_avg}%
Maximum Memory Usage: ${mem_max}%
Minimum Memory Usage: ${mem_min}%
Sample Count: ${#mem_samples[@]}
"
    echo "$mem_summary"
    save_output "memory_summary.txt" "$mem_summary"
    
    # Get top memory-consuming processes
    echo -e "\n${CYAN}Top Memory Consumers:${NC}"
    local top_mem
    top_mem=$(docker exec "$CONTAINER_ID" ps aux --sort=-%mem | head -10 2>/dev/null)
    echo "$top_mem"
    save_output "top_memory_processes.txt" "$top_mem"
    
    # Memory map analysis
    echo -e "\n${CYAN}Memory Map Analysis:${NC}"
    local mem_map
    mem_map=$(docker exec "$CONTAINER_ID" sh -c '
        echo "Memory Distribution:"
        cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree)"
    ' 2>/dev/null)
    echo "$mem_map"
    save_output "memory_map.txt" "$mem_map"
}

# Profile I/O performance
profile_io() {
    print_header "I/O PERFORMANCE PROFILING"
    
    log_info "Profiling I/O for $DURATION seconds..."
    
    # Get I/O information
    echo -e "${CYAN}Container I/O Information:${NC}"
    local io_info
    io_info=$(docker exec "$CONTAINER_ID" sh -c '
        echo "Disk Usage:"
        df -h
        echo ""
        echo "Mount Points:"
        mount | grep -v "proc\|sys\|dev"
    ' 2>/dev/null)
    echo "$io_info"
    save_output "io_info.txt" "$io_info"
    
    # Monitor I/O over time
    echo -e "\n${CYAN}I/O Usage Monitoring:${NC}"
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    
    printf "%-20s %-15s %-15s %-10s %-10s\n" "Timestamp" "Block I/O" "Read IOPS" "Write IOPS" "I/O Wait%"
    echo "---------------------------------------------------------------"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local timestamp=$(date '+%H:%M:%S')
        
        # Get Docker stats
        local stats
        stats=$(get_container_stats)
        local block_io=$(echo "$stats" | jq -r '.BlockIO // "0B / 0B"')
        
        # Get detailed I/O stats
        local io_stats
        io_stats=$(docker exec "$CONTAINER_ID" sh -c '
            iostat -x 1 1 2>/dev/null | tail -n +4 | head -1 | awk "{print \$4, \$5, \$10}" || echo "N/A N/A N/A"
        ' 2>/dev/null || echo "N/A N/A N/A")
        
        local read_iops=$(echo "$io_stats" | awk '{print $1}')
        local write_iops=$(echo "$io_stats" | awk '{print $2}')
        local io_wait=$(echo "$io_stats" | awk '{print $3}')
        
        printf "%-20s %-15s %-15s %-10s %-10s\n" "$timestamp" "$block_io" "$read_iops" "$write_iops" "$io_wait%"
        
        sleep "$INTERVAL"
    done
    
    # I/O-intensive processes
    echo -e "\n${CYAN}I/O Intensive Processes:${NC}"
    local io_procs
    io_procs=$(docker exec "$CONTAINER_ID" sh -c '
        if command -v iotop >/dev/null 2>&1; then
            iotop -b -n 1 -o | head -20
        else
            echo "iotop not available - using process list"
            ps aux | head -10
        fi
    ' 2>/dev/null)
    echo "$io_procs"
    save_output "io_processes.txt" "$io_procs"
}

# Profile network performance
profile_network() {
    print_header "NETWORK PERFORMANCE PROFILING"
    
    log_info "Profiling network for $DURATION seconds..."
    
    # Get network information
    echo -e "${CYAN}Container Network Information:${NC}"
    local net_info
    net_info=$(docker exec "$CONTAINER_ID" sh -c '
        echo "Network Interfaces:"
        ip addr show
        echo ""
        echo "Network Statistics:"
        cat /proc/net/dev | head -3
        cat /proc/net/dev | grep -v "lo:"
    ' 2>/dev/null)
    echo "$net_info"
    save_output "network_info.txt" "$net_info"
    
    # Monitor network over time
    echo -e "\n${CYAN}Network Usage Monitoring:${NC}"
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    
    printf "%-20s %-20s %-15s %-15s\n" "Timestamp" "Network I/O" "RX Packets/s" "TX Packets/s"
    echo "---------------------------------------------------------------"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local timestamp=$(date '+%H:%M:%S')
        
        # Get Docker stats
        local stats
        stats=$(get_container_stats)
        local net_io=$(echo "$stats" | jq -r '.NetIO // "0B / 0B"')
        
        # Get detailed network stats
        local net_stats
        net_stats=$(docker exec "$CONTAINER_ID" sh -c '
            cat /proc/net/dev | grep -v "lo:" | tail -1 | awk "{print \$3, \$11}" || echo "N/A N/A"
        ' 2>/dev/null || echo "N/A N/A")
        
        local rx_packets=$(echo "$net_stats" | awk '{print $1}')
        local tx_packets=$(echo "$net_stats" | awk '{print $2}')
        
        printf "%-20s %-20s %-15s %-15s\n" "$timestamp" "$net_io" "$rx_packets" "$tx_packets"
        
        sleep "$INTERVAL"
    done
    
    # Network connections
    echo -e "\n${CYAN}Active Network Connections:${NC}"
    local connections
    connections=$(docker exec "$CONTAINER_ID" netstat -tuln 2>/dev/null || echo "netstat not available")
    echo "$connections"
    save_output "network_connections.txt" "$connections"
}

# Generate comprehensive performance report
generate_report() {
    if [[ -n "$OUTPUT_DIR" ]]; then
        print_header "GENERATING PERFORMANCE REPORT"
        
        local report_file="$OUTPUT_DIR/performance_report.html"
        
        cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Container Performance Report - $CONTAINER_ID</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007cba; }
        .metrics { display: flex; justify-content: space-between; margin: 10px 0; }
        .metric { background-color: #f9f9f9; padding: 10px; border-radius: 3px; flex: 1; margin: 0 5px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #007cba; }
        .metric-label { font-size: 14px; color: #666; }
        pre { background-color: #f8f8f8; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Container Performance Report</h1>
        <p><strong>Container:</strong> $CONTAINER_ID</p>
        <p><strong>Report Date:</strong> $(date)</p>
        <p><strong>Profiling Duration:</strong> ${DURATION}s</p>
    </div>
    
    <div class="section">
        <h2>Executive Summary</h2>
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$(docker inspect "$CONTAINER_ID" --format '{{.State.Status}}')</div>
                <div class="metric-label">Container Status</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(docker stats "$CONTAINER_ID" --no-stream --format '{{.CPUPerc}}')</div>
                <div class="metric-label">Current CPU Usage</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(docker stats "$CONTAINER_ID" --no-stream --format '{{.MemPerc}}')</div>
                <div class="metric-label">Current Memory Usage</div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Files Generated</h2>
        <ul>
EOF
        
        # List generated files
        for file in "$OUTPUT_DIR"/*.txt; do
            if [[ -f "$file" ]]; then
                echo "            <li>$(basename "$file")</li>" >> "$report_file"
            fi
        done
        
        cat >> "$report_file" << EOF
        </ul>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
EOF
        
        # Add recommendations based on current metrics
        local cpu_usage=$(docker stats "$CONTAINER_ID" --no-stream --format '{{.CPUPerc}}' | sed 's/%//')
        local mem_usage=$(docker stats "$CONTAINER_ID" --no-stream --format '{{.MemPerc}}' | sed 's/%//')
        
        if (( $(echo "$cpu_usage > 80" | bc -l) 2>/dev/null )) || [[ "$cpu_usage" == "80" ]]; then
            echo "            <li>⚠️ High CPU usage detected - consider optimizing CPU-intensive operations</li>" >> "$report_file"
        fi
        
        if (( $(echo "$mem_usage > 85" | bc -l) 2>/dev/null )) || [[ "$mem_usage" == "85" ]]; then
            echo "            <li>⚠️ High memory usage detected - consider increasing memory limits or optimizing memory usage</li>" >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
            <li>✅ Regular performance monitoring recommended</li>
            <li>📊 Compare metrics with baseline performance</li>
        </ul>
    </div>
</body>
</html>
EOF
        
        log_info "Performance report generated: $report_file"
    fi
}

# Main profiling function
run_profiling() {
    local start_time=$(date)
    log_info "Starting performance profiling of container: $CONTAINER_ID"
    log_info "Duration: ${DURATION}s, Interval: ${INTERVAL}s"
    
    # Check if container is running
    if [[ "$(docker inspect "$CONTAINER_ID" --format '{{.State.Running}}')" != "true" ]]; then
        log_error "Container $CONTAINER_ID is not running"
        exit 1
    fi
    
    # Run selected profiling modes
    if [[ "$PROFILE_ALL" == "true" ]]; then
        profile_cpu &
        local cpu_pid=$!
        profile_memory &
        local mem_pid=$!
        profile_io &
        local io_pid=$!
        profile_network &
        local net_pid=$!
        
        wait $cpu_pid $mem_pid $io_pid $net_pid
    else
        [[ "$PROFILE_CPU" == "true" ]] && profile_cpu
        [[ "$PROFILE_MEMORY" == "true" ]] && profile_memory
        [[ "$PROFILE_IO" == "true" ]] && profile_io
        [[ "$PROFILE_NETWORK" == "true" ]] && profile_network
    fi
    
    generate_report
    
    local end_time=$(date)
    log_info "Profiling completed"
    log_info "Started: $start_time"
    log_info "Finished: $end_time"
}

# Continuous profiling mode
continuous_profiling() {
    log_info "Starting continuous profiling mode (Ctrl+C to stop)"
    
    while true; do
        print_separator
        echo "$(date): Running profiling cycle..."
        
        # Create timestamped output directory
        local timestamp_dir="$OUTPUT_DIR/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$timestamp_dir"
        local old_output_dir="$OUTPUT_DIR"
        OUTPUT_DIR="$timestamp_dir"
        
        run_profiling
        
        OUTPUT_DIR="$old_output_dir"
        
        log_info "Next cycle in ${INTERVAL}s..."
        sleep "$INTERVAL"
    done
}

# Parse command line arguments
main() {
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
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -f|--flame-graph)
                FLAME_GRAPH=true
                shift
                ;;
            -a|--all)
                PROFILE_ALL=true
                shift
                ;;
            --cpu)
                PROFILE_CPU=true
                shift
                ;;
            --memory)
                PROFILE_MEMORY=true
                shift
                ;;
            --io)
                PROFILE_IO=true
                shift
                ;;
            --network)
                PROFILE_NETWORK=true
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
    
    # Validate arguments
    if [[ -z "$CONTAINER_ID" ]]; then
        log_error "Container ID or name is required"
        usage
        exit 1
    fi
    
    # Set default profiling mode if none specified
    if [[ "$PROFILE_ALL" == "false" && "$PROFILE_CPU" == "false" && 
          "$PROFILE_MEMORY" == "false" && "$PROFILE_IO" == "false" && 
          "$PROFILE_NETWORK" == "false" ]]; then
        PROFILE_ALL=true
    fi
    
    check_dependencies
    setup_output_dir
    
    # Check if container exists
    if ! docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
        log_error "Container '$CONTAINER_ID' not found"
        exit 1
    fi
    
    # Run profiling
    if [[ "$CONTINUOUS" == "true" ]]; then
        continuous_profiling
    else
        run_profiling
    fi
}

# Run main function with all arguments
main "$@"