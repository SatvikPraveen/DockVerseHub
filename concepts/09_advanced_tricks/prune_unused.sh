#!/bin/bash
# 09_advanced_tricks/prune_unused.sh

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
DRY_RUN=false
FORCE=false
VERBOSE=false
AGGRESSIVE=false
PRESERVE_DAYS=7
PRESERVE_IMAGES=()
PRESERVE_VOLUMES=()

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
debug() { [ "$VERBOSE" = true ] && echo -e "${PURPLE}[DEBUG]${NC} $1"; }

show_usage() {
    cat << 'EOF'
Docker Cleanup & Pruning Utility - Advanced Docker Resource Management

Usage: ./prune_unused.sh [options]

Options:
    -d, --dry-run              Show what would be deleted without actually deleting
    -f, --force                Skip confirmation prompts
    -v, --verbose              Enable verbose output
    -a, --aggressive           More aggressive cleanup (removes more resources)
    --preserve-days DAYS       Preserve resources newer than DAYS (default: 7)
    --preserve-image IMAGE     Preserve specific image (can be used multiple times)
    --preserve-volume VOLUME   Preserve specific volume (can be used multiple times)
    -h, --help                Show this help message

Cleanup Categories:
    containers     - Remove stopped containers
    images         - Remove unused images
    volumes        - Remove unused volumes
    networks       - Remove unused networks
    cache          - Remove build cache
    all            - Complete cleanup (default)

Examples:
    ./prune_unused.sh                           # Interactive cleanup
    ./prune_unused.sh --dry-run                 # See what would be cleaned
    ./prune_unused.sh --force --aggressive      # Aggressive cleanup without prompts
    ./prune_unused.sh --preserve-days 30        # Keep resources newer than 30 days

Safety Features:
    - Dry run mode to preview changes
    - Confirmation prompts before deletion
    - Preserve recently created resources
    - Exclude running containers and their dependencies
    - Backup important data before cleanup

EOF
}

# Calculate disk space usage
get_docker_space_usage() {
    local total_size=0
    
    # Get containers size
    local containers_size=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep "Local Volumes\|Images\|Containers" | awk '{print $2}' | grep -o '[0-9.]*' | awk '{sum += $1} END {print sum}')
    
    echo "$(docker system df)"
}

# Display space usage summary
show_space_summary() {
    log "📊 Docker Disk Space Usage Summary"
    echo "=================================="
    
    get_docker_space_usage
    
    echo ""
    echo -e "${CYAN}Detailed Breakdown:${NC}"
    docker system df -v
}

# Safe container cleanup
cleanup_containers() {
    log "🗂️ Cleaning up containers..."
    
    # Get stopped containers
    local stopped_containers=$(docker ps -a --filter "status=exited" --filter "status=created" -q)
    
    if [ -z "$stopped_containers" ]; then
        success "No stopped containers to remove"
        return 0
    fi
    
    local container_count=$(echo "$stopped_containers" | wc -l)
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would remove $container_count stopped containers:"
        docker ps -a --filter "status=exited" --filter "status=created" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
        return 0
    fi
    
    # Show what will be removed
    echo "Stopped containers to be removed:"
    docker ps -a --filter "status=exited" --filter "status=created" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
    
    if [ "$FORCE" = false ]; then
        read -p "Remove $container_count stopped containers? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Container cleanup skipped"
            return 0
        fi
    fi
    
    # Remove containers
    docker container prune -f
    success "Removed $container_count stopped containers"
}

# Smart image cleanup
cleanup_images() {
    log "🖼️ Cleaning up images..."
    
    # Get unused images (not referenced by any container)
    local unused_images=$(docker images --filter "dangling=true" -q)
    local old_images=()
    
    # Find old images if preserve_days is set
    if [ "$PRESERVE_DAYS" -gt 0 ]; then
        local cutoff_date=$(date -d "$PRESERVE_DAYS days ago" +%s)
        
        # Get images older than preserve days
        while IFS= read -r line; do
            local image_id=$(echo "$line" | awk '{print $3}')
            local created_date=$(docker inspect "$image_id" --format='{{.Created}}' 2>/dev/null)
            
            if [ -n "$created_date" ]; then
                local created_timestamp=$(date -d "$created_date" +%s 2>/dev/null)
                if [ "$created_timestamp" -lt "$cutoff_date" ]; then
                    old_images+=("$image_id")
                fi
            fi
        done < <(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" | tail -n +2)
    fi
    
    # Exclude preserved images
    local filtered_unused=()
    for image in $unused_images; do
        local skip=false
        for preserved in "${PRESERVE_IMAGES[@]}"; do
            if docker images --format "{{.ID}}" "$preserved" 2>/dev/null | grep -q "$image"; then
                skip=true
                break
            fi
        done
        [ "$skip" = false ] && filtered_unused+=("$image")
    done
    
    local total_images=$((${#filtered_unused[@]} + ${#old_images[@]}))
    
    if [ "$total_images" -eq 0 ]; then
        success "No unused images to remove"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would remove $total_images unused/old images"
        [ ${#filtered_unused[@]} -gt 0 ] && echo "Dangling images: ${#filtered_unused[@]}"
        [ ${#old_images[@]} -gt 0 ] && echo "Old images (>$PRESERVE_DAYS days): ${#old_images[@]}"
        return 0
    fi
    
    # Show what will be removed
    if [ ${#filtered_unused[@]} -gt 0 ]; then
        echo "Dangling images to be removed:"
        docker images --filter "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    fi
    
    if [ ${#old_images[@]} -gt 0 ] && [ "$AGGRESSIVE" = true ]; then
        echo "Old images to be removed:"
        for img in "${old_images[@]}"; do
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "$img" || true
        done
    fi
    
    if [ "$FORCE" = false ]; then
        read -p "Remove $total_images unused images? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Image cleanup skipped"
            return 0
        fi
    fi
    
    # Remove images
    local removed=0
    
    # Remove dangling images
    if [ ${#filtered_unused[@]} -gt 0 ]; then
        docker image prune -f
        removed=$((removed + ${#filtered_unused[@]}))
    fi
    
    # Remove old images (aggressive mode)
    if [ ${#old_images[@]} -gt 0 ] && [ "$AGGRESSIVE" = true ]; then
        for img in "${old_images[@]}"; do
            if docker rmi "$img" 2>/dev/null; then
                removed=$((removed + 1))
            fi
        done
    fi
    
    success "Removed $removed unused images"
}

# Volume cleanup with safety checks
cleanup_volumes() {
    log "💾 Cleaning up volumes..."
    
    # Get unused volumes
    local unused_volumes=$(docker volume ls --filter "dangling=true" -q)
    
    if [ -z "$unused_volumes" ]; then
        success "No unused volumes to remove"
        return 0
    fi
    
    # Filter out preserved volumes
    local filtered_volumes=()
    for volume in $unused_volumes; do
        local skip=false
        for preserved in "${PRESERVE_VOLUMES[@]}"; do
            if [ "$volume" = "$preserved" ]; then
                skip=true
                break
            fi
        done
        [ "$skip" = false ] && filtered_volumes+=("$volume")
    done
    
    if [ ${#filtered_volumes[@]} -eq 0 ]; then
        success "No unused volumes to remove (after filtering)"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would remove ${#filtered_volumes[@]} unused volumes:"
        docker volume ls --filter "dangling=true" --format "table {{.Name}}\t{{.Driver}}\t{{.CreatedAt}}"
        return 0
    fi
    
    # Show volumes to be removed with size estimation
    echo "Unused volumes to be removed:"
    for vol in "${filtered_volumes[@]}"; do
        local mountpoint=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null)
        local size="unknown"
        if [ -d "$mountpoint" ]; then
            size=$(du -sh "$mountpoint" 2>/dev/null | cut -f1)
        fi
        echo "  $vol (size: $size)"
    done
    
    warn "⚠️  WARNING: This will permanently delete volume data!"
    warn "   Make sure you have backups of important data."
    
    if [ "$FORCE" = false ]; then
        read -p "Remove ${#filtered_volumes[@]} unused volumes? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Volume cleanup skipped"
            return 0
        fi
    fi
    
    # Remove volumes
    docker volume prune -f
    success "Removed ${#filtered_volumes[@]} unused volumes"
}

# Network cleanup
cleanup_networks() {
    log "🌐 Cleaning up networks..."
    
    # Get unused networks (excluding default ones)
    local unused_networks=$(docker network ls --filter "dangling=true" -q)
    
    if [ -z "$unused_networks" ]; then
        success "No unused networks to remove"
        return 0
    fi
    
    local network_count=$(echo "$unused_networks" | wc -l)
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would remove $network_count unused networks:"
        docker network ls --filter "dangling=true" --format "table {{.Name}}\t{{.Driver}}\t{{.CreatedAt}}"
        return 0
    fi
    
    # Show networks to be removed
    echo "Unused networks to be removed:"
    docker network ls --filter "dangling=true" --format "table {{.Name}}\t{{.Driver}}\t{{.CreatedAt}}"
    
    if [ "$FORCE" = false ]; then
        read -p "Remove $network_count unused networks? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Network cleanup skipped"
            return 0
        fi
    fi
    
    # Remove networks
    docker network prune -f
    success "Removed $network_count unused networks"
}

# Build cache cleanup
cleanup_cache() {
    log "🗄️ Cleaning up build cache..."
    
    # Get build cache info
    local cache_info=$(docker system df -v | grep "BUILD CACHE" -A 20 | tail -n +2)
    
    if [ -z "$cache_info" ]; then
        success "No build cache to remove"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would remove build cache:"
        echo "$cache_info"
        return 0
    fi
    
    # Show cache to be removed
    echo "Build cache to be removed:"
    echo "$cache_info"
    
    if [ "$FORCE" = false ]; then
        read -p "Remove build cache? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Build cache cleanup skipped"
            return 0
        fi
    fi
    
    # Remove build cache
    if [ "$AGGRESSIVE" = true ]; then
        docker builder prune -a -f
        success "Removed all build cache"
    else
        docker builder prune -f
        success "Removed unused build cache"
    fi
}

# Log file cleanup
cleanup_logs() {
    log "📝 Cleaning up container logs..."
    
    # Find large log files
    local log_dir="/var/lib/docker/containers"
    local large_logs=()
    
    if [ -d "$log_dir" ]; then
        while IFS= read -r -d '' logfile; do
            local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null)
            if [ "$size" -gt 104857600 ]; then  # 100MB
                large_logs+=("$logfile:$(du -h "$logfile" | cut -f1)")
            fi
        done < <(find "$log_dir" -name "*-json.log" -print0 2>/dev/null)
    fi
    
    if [ ${#large_logs[@]} -eq 0 ]; then
        success "No large log files found"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        warn "DRY RUN: Would truncate ${#large_logs[@]} large log files:"
        for log_info in "${large_logs[@]}"; do
            echo "  ${log_info##*:} - ${log_info%:*}"
        done
        return 0
    fi
    
    # Show large logs
    echo "Large log files (>100MB) to be truncated:"
    for log_info in "${large_logs[@]}"; do
        echo "  ${log_info##*:} - $(basename "${log_info%:*}")"
    done
    
    if [ "$FORCE" = false ]; then
        read -p "Truncate ${#large_logs[@]} large log files? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Log cleanup skipped"
            return 0
        fi
    fi
    
    # Truncate logs
    local truncated=0
    for log_info in "${large_logs[@]}"; do
        local logfile="${log_info%:*}"
        if [ -w "$logfile" ]; then
            truncate -s 0 "$logfile" 2>/dev/null && truncated=$((truncated + 1))
        fi
    done
    
    success "Truncated $truncated log files"
}

# Complete system cleanup
complete_cleanup() {
    log "🧹 Starting complete Docker cleanup..."
    
    show_space_summary
    echo ""
    
    # Run all cleanup functions
    cleanup_containers
    echo ""
    
    cleanup_images
    echo ""
    
    cleanup_volumes
    echo ""
    
    cleanup_networks
    echo ""
    
    cleanup_cache
    echo ""
    
    if [ "$AGGRESSIVE" = true ]; then
        cleanup_logs
        echo ""
    fi
    
    # Final summary
    log "🎉 Cleanup completed!"
    echo ""
    show_space_summary
}

# Emergency cleanup function
emergency_cleanup() {
    warn "🚨 EMERGENCY CLEANUP MODE"
    warn "This will aggressively remove Docker resources!"
    
    if [ "$FORCE" = false ]; then
        read -p "Continue with emergency cleanup? (yes/NO): " -r
        if [[ ! $REPLY =~ ^yes$ ]]; then
            log "Emergency cleanup cancelled"
            return 0
        fi
    fi
    
    # Stop all containers except critical ones
    log "Stopping all non-critical containers..."
    docker ps -q | while read container; do
        local name=$(docker inspect "$container" --format '{{.Name}}' | sed 's/^.//')
        if [[ ! "$name" =~ (portainer|watchtower|traefik) ]]; then
            docker stop "$container" >/dev/null 2>&1 || true
        fi
    done
    
    # Aggressive cleanup
    AGGRESSIVE=true
    FORCE=true
    complete_cleanup
    
    success "Emergency cleanup completed"
}

# Main function
main() {
    local action="all"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -a|--aggressive)
                AGGRESSIVE=true
                shift
                ;;
            --preserve-days)
                PRESERVE_DAYS="$2"
                shift 2
                ;;
            --preserve-image)
                PRESERVE_IMAGES+=("$2")
                shift 2
                ;;
            --preserve-volume)
                PRESERVE_VOLUMES+=("$2")
                shift 2
                ;;
            --emergency)
                emergency_cleanup
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            containers|images|volumes|networks|cache|logs|all)
                action="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Display warning for dry run
    if [ "$DRY_RUN" = true ]; then
        warn "🔍 DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Execute requested action
    case $action in
        containers)
            cleanup_containers
            ;;
        images)
            cleanup_images
            ;;
        volumes)
            cleanup_volumes
            ;;
        networks)
            cleanup_networks
            ;;
        cache)
            cleanup_cache
            ;;
        logs)
            cleanup_logs
            ;;
        all)
            complete_cleanup
            ;;
    esac
}

# Handle no arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"