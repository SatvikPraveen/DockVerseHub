#!/bin/bash
# Location: utilities/automation/deployment/blue-green.sh
# Blue-green deployment automation script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DEPLOYMENT_DIR="/opt/deployments"
NGINX_CONFIG_DIR="/etc/nginx/conf.d"
HEALTH_CHECK_ENDPOINT="/health"
HEALTH_CHECK_TIMEOUT=300
ROLLBACK_TIMEOUT=60

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to get current active environment
get_active_environment() {
    if [ -f "$DEPLOYMENT_DIR/active_env" ]; then
        cat "$DEPLOYMENT_DIR/active_env"
    else
        echo "blue"
    fi
}

# Function to get inactive environment
get_inactive_environment() {
    local active=$(get_active_environment)
    if [ "$active" = "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Function to health check
health_check() {
    local environment="$1"
    local url="$2"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"
    
    print_status "Performing health check for $environment environment..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        if curl -sf --connect-timeout 5 "$url$HEALTH_CHECK_ENDPOINT" > /dev/null 2>&1; then
            print_success "Health check passed for $environment"
            return 0
        fi
        sleep 5
    done
    
    print_error "Health check failed for $environment after ${timeout}s"
    return 1
}

# Function to switch load balancer traffic
switch_traffic() {
    local target_env="$1"
    
    print_status "Switching traffic to $target_env environment..."
    
    # Update nginx upstream configuration
    cat > "$NGINX_CONFIG_DIR/upstream.conf" << EOF
upstream app {
    server ${target_env}_web_1:8080 max_fails=3 fail_timeout=30s;
    server ${target_env}_web_2:8080 max_fails=3 fail_timeout=30s backup;
}
EOF
    
    # Reload nginx configuration
    if docker exec nginx nginx -s reload; then
        print_success "Load balancer updated to route to $target_env"
        echo "$target_env" > "$DEPLOYMENT_DIR/active_env"
    else
        print_error "Failed to update load balancer"
        return 1
    fi
}

# Function to deploy new version
deploy_new_version() {
    local image="$1"
    local target_env=$(get_inactive_environment)
    local compose_file="$DEPLOYMENT_DIR/docker-compose.$target_env.yml"
    
    print_status "Deploying $image to $target_env environment..."
    
    # Create compose file for target environment
    cat > "$compose_file" << EOF
version: '3.8'
services:
  web:
    image: $image
    deploy:
      replicas: 2
    networks:
      - app-network
    environment:
      - NODE_ENV=production
      - PORT=8080
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  app-network:
    external: true
EOF
    
    # Deploy to target environment
    docker-compose -f "$compose_file" -p "$target_env" up -d
    
    # Wait for containers to be ready
    sleep 30
    
    # Health check
    if health_check "$target_env" "http://${target_env}_web_1:8080"; then
        print_success "Deployment to $target_env completed successfully"
        return 0
    else
        print_error "Deployment to $target_env failed health check"
        docker-compose -f "$compose_file" -p "$target_env" down
        return 1
    fi
}

# Function to perform blue-green deployment
deploy() {
    local image="$1"
    local active_env=$(get_active_environment)
    local target_env=$(get_inactive_environment)
    
    print_status "Starting blue-green deployment..."
    print_status "Current active: $active_env, Target: $target_env"
    
    # Deploy new version
    if ! deploy_new_version "$image"; then
        print_error "Deployment failed"
        exit 1
    fi
    
    # Switch traffic
    if switch_traffic "$target_env"; then
        print_success "Blue-green deployment completed successfully!"
        print_status "New active environment: $target_env"
        
        # Clean up old environment after successful switch
        sleep 30
        cleanup_old_environment "$active_env"
    else
        print_error "Traffic switch failed, rolling back..."
        rollback
        exit 1
    fi
}

# Function to rollback deployment
rollback() {
    local current_active=$(get_active_environment)
    local rollback_target=$(get_inactive_environment)
    
    print_warning "Starting rollback process..."
    
    # Check if rollback target environment exists
    if docker-compose -f "$DEPLOYMENT_DIR/docker-compose.$rollback_target.yml" -p "$rollback_target" ps | grep -q "Up"; then
        print_status "Rolling back to $rollback_target environment"
        switch_traffic "$rollback_target"
        print_success "Rollback completed to $rollback_target"
    else
        print_error "Cannot rollback: $rollback_target environment not available"
        exit 1
    fi
}

# Function to cleanup old environment
cleanup_old_environment() {
    local env="$1"
    local compose_file="$DEPLOYMENT_DIR/docker-compose.$env.yml"
    
    print_status "Cleaning up old $env environment..."
    
    if [ -f "$compose_file" ]; then
        docker-compose -f "$compose_file" -p "$env" down --volumes
        print_success "Cleaned up $env environment"
    fi
}

# Function to show current status
status() {
    local active_env=$(get_active_environment)
    
    print_status "Blue-Green Deployment Status"
    echo "=============================="
    echo "Active Environment: $active_env"
    echo ""
    
    # Show running services
    for env in blue green; do
        echo "[$env Environment]"
        if docker-compose -f "$DEPLOYMENT_DIR/docker-compose.$env.yml" -p "$env" ps 2>/dev/null | grep -q "Up"; then
            docker-compose -f "$DEPLOYMENT_DIR/docker-compose.$env.yml" -p "$env" ps
        else
            echo "  No services running"
        fi
        echo ""
    done
}

# Function to show help
show_help() {
    echo "Blue-Green Deployment Script"
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "  deploy IMAGE        Deploy new image using blue-green strategy"
    echo "  rollback           Rollback to previous environment"
    echo "  status             Show current deployment status"
    echo "  cleanup ENV        Cleanup specific environment (blue/green)"
    echo "  switch ENV         Manually switch traffic to environment"
    echo ""
    echo "OPTIONS:"
    echo "  --health-timeout N Set health check timeout (default: 300s)"
    echo "  --health-endpoint  Set health check endpoint (default: /health)"
    echo "  --deployment-dir   Set deployment directory"
    echo ""
    echo "Examples:"
    echo "  $0 deploy myapp:v2.0"
    echo "  $0 rollback"
    echo "  $0 status"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --health-timeout)
            HEALTH_CHECK_TIMEOUT="$2"
            shift 2
            ;;
        --health-endpoint)
            HEALTH_CHECK_ENDPOINT="$2"
            shift 2
            ;;
        --deployment-dir)
            DEPLOYMENT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy)
            COMMAND="deploy"
            IMAGE="$2"
            shift 2
            ;;
        rollback)
            COMMAND="rollback"
            shift
            ;;
        status)
            COMMAND="status"
            shift
            ;;
        cleanup)
            COMMAND="cleanup"
            CLEANUP_ENV="$2"
            shift 2
            ;;
        switch)
            COMMAND="switch"
            SWITCH_ENV="$2"
            shift 2
            ;;
        *)
            print_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Create deployment directory if it doesn't exist
mkdir -p "$DEPLOYMENT_DIR"

# Execute command
case "${COMMAND:-}" in
    deploy)
        if [ -z "$IMAGE" ]; then
            print_error "Image name is required for deployment"
            show_help
            exit 1
        fi
        deploy "$IMAGE"
        ;;
    rollback)
        rollback
        ;;
    status)
        status
        ;;
    cleanup)
        if [ -z "$CLEANUP_ENV" ]; then
            print_error "Environment name is required for cleanup"
            exit 1
        fi
        cleanup_old_environment "$CLEANUP_ENV"
        ;;
    switch)
        if [ -z "$SWITCH_ENV" ]; then
            print_error "Environment name is required for switch"
            exit 1
        fi
        switch_traffic "$SWITCH_ENV"
        ;;
    *)
        print_error "No command specified"
        show_help
        exit 1
        ;;
esac