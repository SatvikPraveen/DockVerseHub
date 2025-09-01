#!/bin/bash
# Location: utilities/automation/deployment/rolling-update.sh
# Rolling update deployment automation script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DEFAULT_REPLICAS=3
DEFAULT_BATCH_SIZE=1
DEFAULT_HEALTH_TIMEOUT=60
DEFAULT_ENVIRONMENT="production"
COMPOSE_FILE="docker-compose.yml"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to health check service
health_check_service() {
    local service_name="$1"
    local timeout="$2"
    
    print_status "Health checking $service_name..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        local container_id=$(docker-compose ps -q "$service_name" | head -1)
        
        if [ -n "$container_id" ]; then
            local health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}healthy{{end}}' "$container_id")
            
            if [ "$health_status" = "healthy" ]; then
                print_success "$service_name is healthy"
                return 0
            elif [ "$health_status" = "unhealthy" ]; then
                print_error "$service_name is unhealthy"
                return 1
            fi
        fi
        
        sleep 5
    done
    
    print_error "Health check timeout for $service_name"
    return 1
}

# Function to get running replicas count
get_running_replicas() {
    local service_name="$1"
    docker-compose ps -q "$service_name" | wc -l
}

# Function to scale service
scale_service() {
    local service_name="$1"
    local replicas="$2"
    
    print_status "Scaling $service_name to $replicas replicas..."
    docker-compose up -d --scale "$service_name=$replicas"
}

# Function to update service image
update_service_image() {
    local service_name="$1"
    local new_image="$2"
    
    print_status "Updating $service_name to image $new_image..."
    
    # Create temporary compose file with new image
    local temp_compose=$(mktemp)
    sed "s|image:.*|image: $new_image|g" "$COMPOSE_FILE" > "$temp_compose"
    
    # Use temporary compose file
    COMPOSE_FILE="$temp_compose"
    export COMPOSE_FILE
    
    return 0
}

# Function to perform rolling update
rolling_update() {
    local service_name="$1"
    local new_image="$2"
    local target_replicas="$3"
    local batch_size="$4"
    local health_timeout="$5"
    
    print_status "Starting rolling update for $service_name"
    print_status "New image: $new_image"
    print_status "Target replicas: $target_replicas"
    print_status "Batch size: $batch_size"
    
    # Get current replica count
    local current_replicas=$(get_running_replicas "$service_name")
    print_status "Current replicas: $current_replicas"
    
    # Update service image configuration
    update_service_image "$service_name" "$new_image"
    
    # Rolling update strategy
    local updated_replicas=0
    local total_batches=$(((target_replicas + batch_size - 1) / batch_size))
    
    for ((batch=1; batch<=total_batches; batch++)); do
        local batch_replicas=$batch_size
        
        # Adjust batch size for last batch
        if [ $((updated_replicas + batch_size)) -gt $target_replicas ]; then
            batch_replicas=$((target_replicas - updated_replicas))
        fi
        
        print_status "Processing batch $batch/$total_batches ($batch_replicas replicas)..."
        
        # Scale up with new image
        local temp_replicas=$((current_replicas + batch_replicas))
        scale_service "$service_name" "$temp_replicas"
        
        # Wait for new containers to be healthy
        sleep 10
        
        local healthy_new=0
        local max_wait=5
        
        for ((i=1; i<=max_wait; i++)); do
            if health_check_service "$service_name" "$health_timeout"; then
                healthy_new=$((healthy_new + 1))
                if [ $healthy_new -eq $batch_replicas ]; then
                    break
                fi
            fi
            
            if [ $i -eq $max_wait ]; then
                print_error "New containers failed to become healthy"
                rollback_update "$service_name" "$current_replicas"
                return 1
            fi
            
            sleep 5
        done
        
        # Scale down old containers
        current_replicas=$temp_replicas
        updated_replicas=$((updated_replicas + batch_replicas))
        
        print_success "Batch $batch completed successfully"
        
        # Pause between batches (except for last batch)
        if [ $batch -lt $total_batches ]; then
            print_status "Pausing 10 seconds before next batch..."
            sleep 10
        fi
    done
    
    # Final scaling to target replicas
    if [ $current_replicas -ne $target_replicas ]; then
        scale_service "$service_name" "$target_replicas"
    fi
    
    # Final health check
    if health_check_service "$service_name" $((health_timeout * 2)); then
        print_success "Rolling update completed successfully!"
        return 0
    else
        print_error "Final health check failed"
        return 1
    fi
}

# Function to rollback update
rollback_update() {
    local service_name="$1"
    local original_replicas="$2"
    
    print_warning "Rolling back $service_name to $original_replicas replicas..."
    
    # Restore original compose file
    git checkout HEAD -- "$COMPOSE_FILE" 2>/dev/null || true
    
    # Scale back to original
    scale_service "$service_name" "$original_replicas"
    
    print_warning "Rollback completed"
}

# Function to pause deployment
pause_deployment() {
    print_warning "Deployment paused. Press Enter to continue or Ctrl+C to abort..."
    read -r
}

# Function to show deployment status
show_status() {
    local service_name="$1"
    
    print_status "Deployment Status for $service_name"
    echo "====================================="
    
    echo "Running containers:"
    docker-compose ps "$service_name"
    
    echo ""
    echo "Container health status:"
    docker-compose ps -q "$service_name" | while read -r container_id; do
        local name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container_id")
        local status=$(docker inspect --format='{{.State.Status}}' "$container_id")
        echo "  $name: $status ($health)"
    done
}

# Function to show help
show_help() {
    echo "Rolling Update Deployment Script"
    echo "Usage: $0 COMMAND SERVICE [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  update SERVICE IMAGE    Perform rolling update"
    echo "  status SERVICE          Show deployment status"
    echo "  rollback SERVICE        Rollback to previous version"
    echo "  pause SERVICE           Pause deployment (interactive)"
    echo ""
    echo "OPTIONS:"
    echo "  --replicas N           Target number of replicas (default: 3)"
    echo "  --batch-size N         Number of replicas to update per batch (default: 1)"
    echo "  --health-timeout N     Health check timeout in seconds (default: 60)"
    echo "  --environment ENV      Environment name (default: production)"
    echo "  --compose-file FILE    Docker compose file (default: docker-compose.yml)"
    echo "  --no-health-check      Skip health checks (not recommended)"
    echo ""
    echo "Examples:"
    echo "  $0 update web myapp:v2.0 --replicas 5 --batch-size 2"
    echo "  $0 status web"
    echo "  $0 rollback web"
}

# Parse command line arguments
COMMAND=""
SERVICE_NAME=""
NEW_IMAGE=""
REPLICAS=$DEFAULT_REPLICAS
BATCH_SIZE=$DEFAULT_BATCH_SIZE
HEALTH_TIMEOUT=$DEFAULT_HEALTH_TIMEOUT
ENVIRONMENT=$DEFAULT_ENVIRONMENT
SKIP_HEALTH_CHECK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --health-timeout)
            HEALTH_TIMEOUT="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --compose-file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --no-health-check)
            SKIP_HEALTH_CHECK=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        update)
            COMMAND="update"
            SERVICE_NAME="$2"
            NEW_IMAGE="$3"
            shift 3
            ;;
        status)
            COMMAND="status"
            SERVICE_NAME="$2"
            shift 2
            ;;
        rollback)
            COMMAND="rollback"
            SERVICE_NAME="$2"
            shift 2
            ;;
        pause)
            COMMAND="pause"
            SERVICE_NAME="$2"
            shift 2
            ;;
        *)
            print_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$COMMAND" ]; then
    print_error "Command is required"
    show_help
    exit 1
fi

if [ -z "$SERVICE_NAME" ]; then
    print_error "Service name is required"
    show_help
    exit 1
fi

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "Compose file $COMPOSE_FILE not found"
    exit 1
fi

# Execute command
case "$COMMAND" in
    update)
        if [ -z "$NEW_IMAGE" ]; then
            print_error "New image is required for update"
            exit 1
        fi
        
        # Validate numeric arguments
        if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]] || [ "$REPLICAS" -lt 1 ]; then
            print_error "Replicas must be a positive integer"
            exit 1
        fi
        
        if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [ "$BATCH_SIZE" -lt 1 ]; then
            print_error "Batch size must be a positive integer"
            exit 1
        fi
        
        if [ "$BATCH_SIZE" -gt "$REPLICAS" ]; then
            BATCH_SIZE=$REPLICAS
            print_warning "Batch size adjusted to match replica count: $BATCH_SIZE"
        fi
        
        rolling_update "$SERVICE_NAME" "$NEW_IMAGE" "$REPLICAS" "$BATCH_SIZE" "$HEALTH_TIMEOUT"
        ;;
    status)
        show_status "$SERVICE_NAME"
        ;;
    rollback)
        print_warning "Rolling back $SERVICE_NAME..."
        rollback_update "$SERVICE_NAME" "$REPLICAS"
        ;;
    pause)
        pause_deployment
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac