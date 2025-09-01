#!/bin/bash
# Location: utilities/scripts/health_check.sh
# Container health monitoring script with alerting capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HEALTH_LOG="/var/log/docker-health.log"
ALERT_THRESHOLD=3
WEBHOOK_URL=""
EMAIL=""
CHECK_INTERVAL=30

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[HEALTHY]${NC} $1"
}

print_error() {
    echo -e "${RED}[UNHEALTHY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to log with timestamp
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTH_LOG"
}

# Function to check individual container health
check_container_health() {
    local container_id="$1"
    local container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
    
    # Get container status
    local status=$(docker inspect --format='{{.State.Status}}' "$container_id")
    local health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container_id")
    
    # Container state check
    if [ "$status" != "running" ]; then
        print_error "Container $container_name is not running (Status: $status)"
        log_message "UNHEALTHY: $container_name - Status: $status"
        return 1
    fi
    
    # Health check status
    case "$health_status" in
        "healthy")
            print_success "Container $container_name is healthy"
            log_message "HEALTHY: $container_name - Health: $health_status"
            return 0
            ;;
        "unhealthy")
            print_error "Container $container_name failed health check"
            log_message "UNHEALTHY: $container_name - Health: $health_status"
            
            # Show health check logs
            local health_logs=$(docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$container_id" | tail -3)
            if [ -n "$health_logs" ]; then
                print_warning "Recent health check logs:"
                echo "$health_logs"
            fi
            return 1
            ;;
        "starting")
            print_warning "Container $container_name health check is starting"
            log_message "STARTING: $container_name - Health: $health_status"
            return 2
            ;;
        "no-healthcheck")
            print_warning "Container $container_name has no health check defined"
            log_message "NO-HEALTHCHECK: $container_name"
            return 2
            ;;
        *)
            print_warning "Container $container_name has unknown health status: $health_status"
            log_message "UNKNOWN: $container_name - Health: $health_status"
            return 2
            ;;
    esac
}

# Function to check container resource usage
check_container_resources() {
    local container_id="$1"
    local container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
    
    # Get resource stats
    local stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}" "$container_id")
    IFS=',' read -r cpu_percent mem_usage mem_percent <<< "$stats"
    
    # Remove % sign for numeric comparison
    cpu_num=$(echo "$cpu_percent" | sed 's/%//')
    mem_num=$(echo "$mem_percent" | sed 's/%//')
    
    # Check CPU usage (warning if > 80%, critical if > 95%)
    if (( $(echo "$cpu_num > 95" | bc -l) )); then
        print_error "Container $container_name has critical CPU usage: $cpu_percent"
        log_message "CRITICAL: $container_name - CPU: $cpu_percent"
    elif (( $(echo "$cpu_num > 80" | bc -l) )); then
        print_warning "Container $container_name has high CPU usage: $cpu_percent"
        log_message "WARNING: $container_name - CPU: $cpu_percent"
    fi
    
    # Check memory usage (warning if > 80%, critical if > 95%)
    if (( $(echo "$mem_num > 95" | bc -l) )); then
        print_error "Container $container_name has critical memory usage: $mem_percent ($mem_usage)"
        log_message "CRITICAL: $container_name - Memory: $mem_percent ($mem_usage)"
    elif (( $(echo "$mem_num > 80" | bc -l) )); then
        print_warning "Container $container_name has high memory usage: $mem_percent ($mem_usage)"
        log_message "WARNING: $container_name - Memory: $mem_percent ($mem_usage)"
    fi
}

# Function to check container restart count
check_container_restarts() {
    local container_id="$1"
    local container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
    local restart_count=$(docker inspect --format='{{.RestartCount}}' "$container_id")
    
    if [ "$restart_count" -gt "$ALERT_THRESHOLD" ]; then
        print_warning "Container $container_name has restarted $restart_count times"
        log_message "WARNING: $container_name - Restart count: $restart_count"
    fi
}

# Function to send webhook alert
send_webhook_alert() {
    local message="$1"
    
    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"Docker Health Alert: $message\"}" \
            "$WEBHOOK_URL" || true
    fi
}

# Function to send email alert
send_email_alert() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$EMAIL" || true
    fi
}

# Function to perform comprehensive health check
comprehensive_health_check() {
    local containers=()
    local unhealthy_containers=()
    local starting_containers=()
    
    print_status "Starting comprehensive health check..."
    echo ""
    
    # Get all running containers
    while IFS= read -r container_id; do
        containers+=("$container_id")
    done < <(docker ps -q)
    
    if [ ${#containers[@]} -eq 0 ]; then
        print_warning "No running containers found"
        return 0
    fi
    
    print_status "Checking ${#containers[@]} running containers..."
    echo ""
    
    # Check each container
    for container_id in "${containers[@]}"; do
        local container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
        
        echo "Checking container: $container_name"
        echo "=================="
        
        # Health check
        if ! check_container_health "$container_id"; then
            case $? in
                1) unhealthy_containers+=("$container_name") ;;
                2) starting_containers+=("$container_name") ;;
            esac
        fi
        
        # Resource check
        check_container_resources "$container_id"
        
        # Restart count check
        check_container_restarts "$container_id"
        
        echo ""
    done
    
    # Summary
    print_status "Health Check Summary"
    print_status "==================="
    echo "Total containers checked: ${#containers[@]}"
    echo "Healthy containers: $((${#containers[@]} - ${#unhealthy_containers[@]} - ${#starting_containers[@]}))"
    echo "Unhealthy containers: ${#unhealthy_containers[@]}"
    echo "Starting containers: ${#starting_containers[@]}"
    
    # Alert on unhealthy containers
    if [ ${#unhealthy_containers[@]} -gt 0 ]; then
        local alert_message="Unhealthy containers detected: ${unhealthy_containers[*]}"
        print_error "$alert_message"
        send_webhook_alert "$alert_message"
        send_email_alert "Docker Health Alert" "$alert_message"
    fi
    
    return ${#unhealthy_containers[@]}
}

# Function to monitor continuously
continuous_monitoring() {
    print_status "Starting continuous health monitoring (interval: ${CHECK_INTERVAL}s)"
    print_status "Press Ctrl+C to stop monitoring"
    
    while true; do
        echo ""
        echo "========================================"
        echo "Health Check at $(date)"
        echo "========================================"
        
        comprehensive_health_check
        
        sleep "$CHECK_INTERVAL"
    done
}

# Function to show help
show_help() {
    echo "Docker Container Health Check Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -c, --container NAME    Check specific container only"
    echo "  -m, --monitor           Start continuous monitoring"
    echo "  -i, --interval N        Set monitoring interval in seconds (default: 30)"
    echo "  -t, --threshold N       Set restart count alert threshold (default: 3)"
    echo "  -w, --webhook URL       Set webhook URL for alerts"
    echo "  -e, --email ADDRESS     Set email address for alerts"
    echo "  -l, --log-file FILE     Set log file path (default: /var/log/docker-health.log)"
    echo "  --json                  Output results in JSON format"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # One-time health check"
    echo "  $0 -c nginx                          # Check specific container"
    echo "  $0 -m -i 60                         # Monitor every 60 seconds"
    echo "  $0 -w http://hooks.slack.com/...     # Send alerts to Slack"
}

# Parse command line arguments
SPECIFIC_CONTAINER=""
MONITOR_MODE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            SPECIFIC_CONTAINER="$2"
            shift 2
            ;;
        -m|--monitor)
            MONITOR_MODE=true
            shift
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -t|--threshold)
            ALERT_THRESHOLD="$2"
            shift 2
            ;;
        -w|--webhook)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -l|--log-file)
            HEALTH_LOG="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create log file directory if it doesn't exist
mkdir -p "$(dirname "$HEALTH_LOG")"

# Check specific container if requested
if [ -n "$SPECIFIC_CONTAINER" ]; then
    container_id=$(docker ps -q --filter "name=$SPECIFIC_CONTAINER")
    
    if [ -z "$container_id" ]; then
        print_error "Container '$SPECIFIC_CONTAINER' not found or not running"
        exit 1
    fi
    
    print_status "Checking container: $SPECIFIC_CONTAINER"
    echo ""
    
    check_container_health "$container_id"
    check_container_resources "$container_id"
    check_container_restarts "$container_id"
    
    exit $?
fi

# Start monitoring mode or one-time check
if [ "$MONITOR_MODE" = true ]; then
    # Set up trap for graceful shutdown
    trap 'print_status "Monitoring stopped"; exit 0' INT TERM
    continuous_monitoring
else
    comprehensive_health_check
    exit $?
fi