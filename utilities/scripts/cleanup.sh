#!/bin/bash
# Location: utilities/scripts/cleanup.sh
# Docker cleanup script - Remove unused containers, images, volumes, and networks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show Docker disk usage
show_docker_usage() {
    print_status "Current Docker disk usage:"
    docker system df
    echo ""
}

# Function to clean stopped containers
clean_containers() {
    print_status "Removing stopped containers..."
    
    STOPPED_CONTAINERS=$(docker ps -aq --filter "status=exited")
    if [ -n "$STOPPED_CONTAINERS" ]; then
        docker rm $STOPPED_CONTAINERS
        print_success "Removed stopped containers"
    else
        print_status "No stopped containers to remove"
    fi
}

# Function to clean dangling images
clean_dangling_images() {
    print_status "Removing dangling images..."
    
    DANGLING_IMAGES=$(docker images -qf "dangling=true")
    if [ -n "$DANGLING_IMAGES" ]; then
        docker rmi $DANGLING_IMAGES
        print_success "Removed dangling images"
    else
        print_status "No dangling images to remove"
    fi
}

# Function to clean unused images (more aggressive)
clean_unused_images() {
    if [ "$AGGRESSIVE" = true ]; then
        print_status "Removing all unused images..."
        docker image prune -af
        print_success "Removed unused images"
    fi
}

# Function to clean unused volumes
clean_volumes() {
    print_status "Removing unused volumes..."
    
    UNUSED_VOLUMES=$(docker volume ls -qf dangling=true)
    if [ -n "$UNUSED_VOLUMES" ]; then
        docker volume rm $UNUSED_VOLUMES
        print_success "Removed unused volumes"
    else
        print_status "No unused volumes to remove"
    fi
}

# Function to clean unused networks
clean_networks() {
    print_status "Removing unused networks..."
    docker network prune -f
    print_success "Network cleanup completed"
}

# Function to clean build cache
clean_build_cache() {
    print_status "Cleaning Docker build cache..."
    docker builder prune -af
    print_success "Build cache cleaned"
}

# Function to perform system-wide cleanup
system_cleanup() {
    print_status "Performing system-wide cleanup..."
    if [ "$AGGRESSIVE" = true ]; then
        docker system prune -af --volumes
    else
        docker system prune -f
    fi
    print_success "System cleanup completed"
}

# Function to show cleanup summary
show_summary() {
    echo ""
    print_status "Cleanup Summary:"
    print_status "=================="
    show_docker_usage
    
    # Show reclaimed space
    print_success "Cleanup completed successfully!"
    print_status "Run 'docker system df' to see current usage"
}

# Function to show help
show_help() {
    echo "Docker Cleanup Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -a, --aggressive    Perform aggressive cleanup (removes unused images)"
    echo "  -c, --containers    Clean only containers"
    echo "  -i, --images        Clean only images"
    echo "  -v, --volumes       Clean only volumes"
    echo "  -n, --networks      Clean only networks"
    echo "  -b, --build-cache   Clean only build cache"
    echo "  -s, --system        Perform system-wide cleanup"
    echo "  --dry-run           Show what would be cleaned without actually doing it"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Basic cleanup"
    echo "  $0 -a               # Aggressive cleanup"
    echo "  $0 -c -v            # Clean containers and volumes only"
    echo "  $0 --dry-run        # See what would be cleaned"
}

# Parse command line arguments
AGGRESSIVE=false
CONTAINERS_ONLY=false
IMAGES_ONLY=false
VOLUMES_ONLY=false
NETWORKS_ONLY=false
BUILD_CACHE_ONLY=false
SYSTEM_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--aggressive)
            AGGRESSIVE=true
            shift
            ;;
        -c|--containers)
            CONTAINERS_ONLY=true
            shift
            ;;
        -i|--images)
            IMAGES_ONLY=true
            shift
            ;;
        -v|--volumes)
            VOLUMES_ONLY=true
            shift
            ;;
        -n|--networks)
            NETWORKS_ONLY=true
            shift
            ;;
        -b|--build-cache)
            BUILD_CACHE_ONLY=true
            shift
            ;;
        -s|--system)
            SYSTEM_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Show current usage before cleanup
echo "Docker Cleanup Script Starting..."
echo "=================================="
show_docker_usage

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No actual cleanup will be performed"
    echo ""
    
    print_status "Would remove:"
    echo "- Stopped containers: $(docker ps -aq --filter 'status=exited' | wc -l)"
    echo "- Dangling images: $(docker images -qf 'dangling=true' | wc -l)"
    echo "- Unused volumes: $(docker volume ls -qf dangling=true | wc -l)"
    echo "- Unused networks: $(docker network ls --filter type=custom -q | wc -l)"
    
    if [ "$AGGRESSIVE" = true ]; then
        echo "- All unused images (aggressive mode)"
    fi
    
    exit 0
fi

# Perform cleanup based on options
if [ "$SYSTEM_ONLY" = true ]; then
    system_cleanup
elif [ "$CONTAINERS_ONLY" = true ]; then
    clean_containers
elif [ "$IMAGES_ONLY" = true ]; then
    clean_dangling_images
    clean_unused_images
elif [ "$VOLUMES_ONLY" = true ]; then
    clean_volumes
elif [ "$NETWORKS_ONLY" = true ]; then
    clean_networks
elif [ "$BUILD_CACHE_ONLY" = true ]; then
    clean_build_cache
else
    # Default: clean everything step by step
    clean_containers
    clean_dangling_images
    clean_unused_images
    clean_volumes
    clean_networks
    clean_build_cache
fi

# Show summary
show_summary

print_success "Docker cleanup completed!"
echo "Tips:"
echo "- Run with -a flag for more aggressive cleanup"
echo "- Use --dry-run to preview cleanup actions"
echo "- Schedule this script with cron for regular maintenance"