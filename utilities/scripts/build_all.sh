#!/bin/bash
# Location: utilities/scripts/build_all.sh
# Build all Dockerfiles in the repository with parallel processing and optimization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MAX_PARALLEL_BUILDS=4
BUILD_LOG_DIR="build_logs"
FAILED_BUILDS=()
SUCCESSFUL_BUILDS=()

# Create log directory
mkdir -p "$BUILD_LOG_DIR"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to find all Dockerfiles
find_dockerfiles() {
    find . -name "Dockerfile*" -type f | grep -v "/.git/" | sort
}

# Function to generate image tag from dockerfile path
generate_tag() {
    local dockerfile_path="$1"
    local dir_name=$(dirname "$dockerfile_path" | sed 's|^\./||')
    local file_name=$(basename "$dockerfile_path")
    
    # Create a meaningful tag
    local tag="dockversehub"
    
    if [ "$dir_name" != "." ]; then
        tag="${tag}-${dir_name//\//-}"
    fi
    
    if [ "$file_name" != "Dockerfile" ]; then
        local suffix=$(echo "$file_name" | sed 's/Dockerfile\.//' | sed 's/Dockerfile//')
        if [ -n "$suffix" ]; then
            tag="${tag}-${suffix}"
        fi
    fi
    
    # Clean up the tag (lowercase, replace special chars)
    echo "$tag" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/-$//'
}

# Function to build a single Dockerfile
build_dockerfile() {
    local dockerfile="$1"
    local tag="$2"
    local log_file="$BUILD_LOG_DIR/${tag}.log"
    
    print_status "Building $dockerfile as $tag..."
    
    # Get directory of Dockerfile for build context
    local build_context=$(dirname "$dockerfile")
    
    # Build with progress and capture logs
    if docker build \
        --progress=plain \
        --file "$dockerfile" \
        --tag "$tag" \
        --label "built-by=build_all_script" \
        --label "build-date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --label "dockerfile-path=$dockerfile" \
        "$build_context" > "$log_file" 2>&1; then
        
        SUCCESSFUL_BUILDS+=("$tag")
        print_success "Built $tag successfully"
        return 0
    else
        FAILED_BUILDS+=("$tag")
        print_error "Failed to build $tag (check $log_file)"
        return 1
    fi
}

# Function to build all Dockerfiles in parallel
build_all_parallel() {
    local dockerfiles=("$@")
    local pids=()
    local active_builds=0
    
    for dockerfile in "${dockerfiles[@]}"; do
        # Wait if we've reached max parallel builds
        while [ $active_builds -ge $MAX_PARALLEL_BUILDS ]; do
            wait -n  # Wait for any background job to finish
            active_builds=$((active_builds - 1))
        done
        
        local tag=$(generate_tag "$dockerfile")
        
        # Start build in background
        (build_dockerfile "$dockerfile" "$tag") &
        pids+=($!)
        active_builds=$((active_builds + 1))
        
        # Small delay to prevent overwhelming the system
        sleep 0.1
    done
    
    # Wait for all remaining builds to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
}

# Function to analyze build results
analyze_results() {
    echo ""
    print_status "Build Analysis"
    print_status "=============="
    
    echo "Successful builds: ${#SUCCESSFUL_BUILDS[@]}"
    echo "Failed builds: ${#FAILED_BUILDS[@]}"
    echo ""
    
    if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
        print_success "Successfully built images:"
        for tag in "${SUCCESSFUL_BUILDS[@]}"; do
            echo "  ✓ $tag"
        done
        echo ""
    fi
    
    if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
        print_error "Failed builds:"
        for tag in "${FAILED_BUILDS[@]}"; do
            echo "  ✗ $tag"
        done
        echo ""
        print_warning "Check individual log files in $BUILD_LOG_DIR/ for details"
    fi
    
    # Show disk usage
    print_status "Docker images disk usage:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep dockversehub || true
}

# Function to clean up old build logs
cleanup_logs() {
    if [ -d "$BUILD_LOG_DIR" ]; then
        find "$BUILD_LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    fi
}

# Function to show help
show_help() {
    echo "Docker Build All Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -j, --parallel N    Set maximum parallel builds (default: 4)"
    echo "  -f, --filter PATH   Build only Dockerfiles matching path pattern"
    echo "  -c, --clean         Clean up old build logs before starting"
    echo "  --no-cache          Build without using cache"
    echo "  --dry-run           Show what would be built without building"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Build all Dockerfiles"
    echo "  $0 -j 8                     # Use 8 parallel builds"
    echo "  $0 -f 'labs/'              # Build only lab Dockerfiles"
    echo "  $0 --clean --no-cache       # Clean logs and build without cache"
}

# Parse command line arguments
FILTER=""
CLEAN_LOGS=false
NO_CACHE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--parallel)
            MAX_PARALLEL_BUILDS="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_LOGS=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
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

# Validate parallel builds number
if ! [[ "$MAX_PARALLEL_BUILDS" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLEL_BUILDS" -lt 1 ]; then
    print_error "Invalid number of parallel builds: $MAX_PARALLEL_BUILDS"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Clean up old logs if requested
if [ "$CLEAN_LOGS" = true ]; then
    print_status "Cleaning up old build logs..."
    rm -rf "$BUILD_LOG_DIR"/*.log 2>/dev/null || true
fi

# Find all Dockerfiles
print_status "Scanning for Dockerfiles..."
dockerfiles=($(find_dockerfiles))

# Apply filter if specified
if [ -n "$FILTER" ]; then
    filtered_dockerfiles=()
    for dockerfile in "${dockerfiles[@]}"; do
        if echo "$dockerfile" | grep -q "$FILTER"; then
            filtered_dockerfiles+=("$dockerfile")
        fi
    done
    dockerfiles=("${filtered_dockerfiles[@]}")
fi

if [ ${#dockerfiles[@]} -eq 0 ]; then
    print_warning "No Dockerfiles found"
    if [ -n "$FILTER" ]; then
        print_warning "Filter: $FILTER"
    fi
    exit 0
fi

print_status "Found ${#dockerfiles[@]} Dockerfiles to build"
print_status "Using $MAX_PARALLEL_BUILDS parallel builds"

# Show what would be built in dry-run mode
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No actual builds will be performed"
    echo ""
    print_status "Would build the following:"
    
    for dockerfile in "${dockerfiles[@]}"; do
        local tag=$(generate_tag "$dockerfile")
        echo "  $dockerfile -> $tag"
    done
    exit 0
fi

# Add no-cache flag if specified
if [ "$NO_CACHE" = true ]; then
    export DOCKER_BUILDKIT=1
    print_status "Building without cache"
fi

# Start the build process
print_status "Starting parallel builds..."
echo "Build logs will be saved to: $BUILD_LOG_DIR/"
echo ""

start_time=$(date +%s)

# Build all Dockerfiles
build_all_parallel "${dockerfiles[@]}"

end_time=$(date +%s)
duration=$((end_time - start_time))

# Analyze and show results
analyze_results

print_status "Total build time: ${duration}s"

# Exit with error code if any builds failed
if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    exit 1
else
    print_success "All builds completed successfully!"
    exit 0
fi