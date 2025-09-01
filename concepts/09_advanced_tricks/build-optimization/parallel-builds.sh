#!/bin/bash
# 09_advanced_tricks/build-optimization/parallel-builds.sh

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
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}
BUILD_TIMEOUT=${BUILD_TIMEOUT:-1800}  # 30 minutes
REGISTRY=${REGISTRY:-"localhost:5000"}
CACHE_REGISTRY=${CACHE_REGISTRY:-"$REGISTRY/cache"}
VERBOSE=false
DRY_RUN=false
PUSH_IMAGES=false

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"; }
debug() { [ "$VERBOSE" = true ] && echo -e "${PURPLE}[DEBUG]${NC} $(date '+%H:%M:%S') $1"; }

show_usage() {
    cat << 'EOF'
Parallel Docker Build System - Advanced Build Optimization

Usage: ./parallel-builds.sh [options] [build_config_file]

Options:
    -j, --jobs N               Maximum parallel jobs (default: 4)
    -t, --timeout SECONDS      Build timeout per job (default: 1800)
    -r, --registry REGISTRY    Docker registry for images (default: localhost:5000)
    -c, --cache-registry REG   Cache registry (default: same as registry)
    -p, --push                 Push images after successful builds
    -v, --verbose              Enable verbose output
    -d, --dry-run             Show what would be built without building
    -h, --help                Show this help message

Build Configuration:
    The script can read build configurations from a YAML file or auto-discover
    Dockerfiles in the current directory structure.

Examples:
    ./parallel-builds.sh                           # Auto-discover and build
    ./parallel-builds.sh -j 8 -p builds.yaml      # Use 8 jobs and push images
    ./parallel-builds.sh --dry-run                 # Show build plan

Auto-discovery:
    Automatically finds Dockerfiles and creates build jobs based on:
    - Directory structure
    - Dependency analysis  
    - Build context optimization

EOF
}

# Build job structure
declare -A BUILD_JOBS=()
declare -A JOB_STATUS=()
declare -A JOB_PIDS=()
declare -A JOB_START_TIME=()
declare -A JOB_DEPENDENCIES=()

# Auto-discover Dockerfiles and create build jobs
auto_discover_builds() {
    log "🔍 Auto-discovering build jobs..."
    
    local job_id=1
    
    # Find all Dockerfiles
    while IFS= read -r -d '' dockerfile; do
        local dir=$(dirname "$dockerfile")
        local name=$(basename "$dir")
        local context_dir="$dir"
        
        # Skip if Dockerfile is in root and there are other Dockerfiles
        if [ "$dir" = "." ] && [ "$(find . -name "Dockerfile*" | wc -l)" -gt 1 ]; then
            continue
        fi
        
        # Determine image name
        local image_name
        if [ -f "$dir/package.json" ]; then
            image_name=$(jq -r '.name // "unknown"' "$dir/package.json" 2>/dev/null || echo "$name")
        else
            image_name="$name"
        fi
        
        # Clean image name
        image_name=$(echo "$image_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
        
        # Create job
        local job_key="job$job_id"
        BUILD_JOBS["$job_key"]="$dockerfile|$context_dir|$image_name"
        JOB_STATUS["$job_key"]="pending"
        
        debug "Discovered: $dockerfile -> $image_name"
        job_id=$((job_id + 1))
        
    done < <(find . -name "Dockerfile*" -type f -print0 | head -20)  # Limit to 20 jobs
    
    success "Discovered ${#BUILD_JOBS[@]} build jobs"
}

# Analyze dependencies between builds
analyze_dependencies() {
    log "🔗 Analyzing build dependencies..."
    
    for job_key in "${!BUILD_JOBS[@]}"; do
        IFS='|' read -r dockerfile context_dir image_name <<< "${BUILD_JOBS[$job_key]}"
        
        # Look for FROM statements that reference other local builds
        local dependencies=()
        while IFS= read -r from_line; do
            local from_image=$(echo "$from_line" | awk '{print $2}' | cut -d':' -f1)
            
            # Check if this references another local build
            for other_job in "${!BUILD_JOBS[@]}"; do
                if [ "$other_job" != "$job_key" ]; then
                    IFS='|' read -r _ _ other_image <<< "${BUILD_JOBS[$other_job]}"
                    if [ "$from_image" = "$other_image" ]; then
                        dependencies+=("$other_job")
                    fi
                fi
            done
        done < <(grep "^FROM " "$dockerfile" 2>/dev/null || true)
        
        if [ ${#dependencies[@]} -gt 0 ]; then
            JOB_DEPENDENCIES["$job_key"]=$(IFS=','; echo "${dependencies[*]}")
            debug "Job $job_key depends on: ${JOB_DEPENDENCIES[$job_key]}"
        fi
    done
}

# Check if job dependencies are satisfied
dependencies_satisfied() {
    local job_key=$1
    local deps=${JOB_DEPENDENCIES[$job_key]:-""}
    
    if [ -z "$deps" ]; then
        return 0
    fi
    
    IFS=',' read -ra dep_array <<< "$deps"
    for dep in "${dep_array[@]}"; do
        if [ "${JOB_STATUS[$dep]}" != "completed" ]; then
            return 1
        fi
    done
    
    return 0
}

# Build a single Docker image
build_image() {
    local job_key=$1
    IFS='|' read -r dockerfile context_dir image_name <<< "${BUILD_JOBS[$job_key]}"
    
    local build_log="/tmp/build_${job_key}.log"
    local full_image_name="$REGISTRY/$image_name:latest"
    local cache_from="$CACHE_REGISTRY/$image_name:cache"
    local cache_to="type=registry,ref=$cache_from,mode=max"
    
    debug "Starting build for $job_key: $image_name"
    
    {
        echo "=== Build started at $(date) ==="
        echo "Dockerfile: $dockerfile"
        echo "Context: $context_dir"
        echo "Image: $full_image_name"
        echo "Cache: $cache_from"
        echo ""
        
        # Check if buildx is available
        if docker buildx version >/dev/null 2>&1; then
            # Use buildx for advanced features
            docker buildx build \
                --file "$dockerfile" \
                --tag "$full_image_name" \
                --cache-from "type=registry,ref=$cache_from" \
                --cache-to "$cache_to" \
                --metadata-file "/tmp/build_${job_key}_metadata.json" \
                --progress plain \
                ${PUSH_IMAGES:+--push} \
                "$context_dir"
        else
            # Fallback to regular build
            docker build \
                --file "$dockerfile" \
                --tag "$full_image_name" \
                --cache-from "$cache_from" \
                "$context_dir"
            
            # Push if requested
            if [ "$PUSH_IMAGES" = true ]; then
                docker push "$full_image_name"
            fi
        fi
        
        echo ""
        echo "=== Build completed at $(date) ==="
        
    } > "$build_log" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        JOB_STATUS["$job_key"]="completed"
        success "✅ $image_name build completed"
        
        # Show build metadata if available
        if [ -f "/tmp/build_${job_key}_metadata.json" ]; then
            local image_id=$(jq -r '.["containerimage.digest"] // "unknown"' "/tmp/build_${job_key}_metadata.json" 2>/dev/null)
            debug "Image digest: $image_id"
        fi
    else
        JOB_STATUS["$job_key"]="failed"
        error "❌ $image_name build failed"
        
        # Show last few lines of build log
        echo "Last 10 lines of build log:"
        tail -10 "$build_log" | sed 's/^/  /'
    fi
    
    return $exit_code
}

# Monitor build progress
monitor_builds() {
    log "📊 Monitoring build progress..."
    
    while true; do
        local running=0
        local completed=0
        local failed=0
        local pending=0
        
        for job_key in "${!JOB_STATUS[@]}"; do
            case "${JOB_STATUS[$job_key]}" in
                running) running=$((running + 1)) ;;
                completed) completed=$((completed + 1)) ;;
                failed) failed=$((failed + 1)) ;;
                pending) pending=$((pending + 1)) ;;
            esac
        done
        
        local total=${#BUILD_JOBS[@]}
        local progress=$((completed * 100 / total))
        
        printf "\r${CYAN}Progress: ${NC}%d%% ${BLUE}(${NC}%d${BLUE}/${NC}%d${BLUE}) ${NC}" "$progress" "$completed" "$total"
        printf "${GREEN}✅%d ${RED}❌%d ${YELLOW}⏳%d ${BLUE}🔄%d${NC}" "$completed" "$failed" "$pending" "$running"
        
        # Check if all jobs are done
        if [ $((completed + failed)) -eq "$total" ]; then
            echo ""
            break
        fi
        
        sleep 2
    done
}

# Execute parallel builds
execute_builds() {
    log "🚀 Starting parallel builds (max $MAX_PARALLEL_JOBS jobs)..."
    
    # Start monitoring in background
    monitor_builds &
    local monitor_pid=$!
    
    # Track active jobs
    local active_jobs=0
    local job_queue=("${!BUILD_JOBS[@]}")
    local queue_index=0
    
    # Build loop
    while [ ${#job_queue[@]} -gt 0 ] || [ $active_jobs -gt 0 ]; do
        
        # Start new jobs if under limit
        while [ $active_jobs -lt $MAX_PARALLEL_JOBS ] && [ $queue_index -lt ${#job_queue[@]} ]; do
            local job_key="${job_queue[$queue_index]}"
            
            # Check if dependencies are satisfied
            if dependencies_satisfied "$job_key"; then
                # Start the build
                JOB_STATUS["$job_key"]="running"
                JOB_START_TIME["$job_key"]=$(date +%s)
                
                build_image "$job_key" &
                JOB_PIDS["$job_key"]=$!
                
                active_jobs=$((active_jobs + 1))
                debug "Started job $job_key (PID: ${JOB_PIDS[$job_key]})"
                
                # Remove from queue
                unset job_queue[$queue_index]
                job_queue=("${job_queue[@]}")  # Reindex array
            else
                queue_index=$((queue_index + 1))
            fi
        done
        
        # Check for completed jobs
        for job_key in "${!JOB_PIDS[@]}"; do
            local pid=${JOB_PIDS[$job_key]}
            
            if ! kill -0 "$pid" 2>/dev/null; then
                # Job finished
                wait "$pid"
                local exit_code=$?
                
                local duration=$(($(date +%s) - ${JOB_START_TIME[$job_key]}))
                
                if [ $exit_code -eq 0 ]; then
                    JOB_STATUS["$job_key"]="completed"
                else
                    JOB_STATUS["$job_key"]="failed"
                fi
                
                debug "Job $job_key finished in ${duration}s with exit code $exit_code"
                
                unset JOB_PIDS["$job_key"]
                active_jobs=$((active_jobs - 1))
                
                # Reset queue index for dependency check
                queue_index=0
            fi
        done
        
        # Check for timeouts
        for job_key in "${!JOB_PIDS[@]}"; do
            local pid=${JOB_PIDS[$job_key]}
            local start_time=${JOB_START_TIME[$job_key]}
            local current_time=$(date +%s)
            local duration=$((current_time - start_time))
            
            if [ $duration -gt $BUILD_TIMEOUT ]; then
                warn "Job $job_key timed out after ${duration}s, killing..."
                kill -TERM "$pid" 2>/dev/null || true
                sleep 5
                kill -KILL "$pid" 2>/dev/null || true
                
                JOB_STATUS["$job_key"]="failed"
                unset JOB_PIDS["$job_key"]
                active_jobs=$((active_jobs - 1))
            fi
        done
        
        sleep 1
    done
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
}

# Generate build report
generate_report() {
    log "📋 Generating build report..."
    
    local total=${#BUILD_JOBS[@]}
    local completed=0
    local failed=0
    
    echo ""
    echo "=================================="
    echo "     PARALLEL BUILD REPORT"
    echo "=================================="
    echo ""
    
    for job_key in "${!BUILD_JOBS[@]}"; do
        IFS='|' read -r dockerfile context_dir image_name <<< "${BUILD_JOBS[$job_key]}"
        local status=${JOB_STATUS[$job_key]}
        
        case $status in
            completed)
                echo -e "✅ ${GREEN}$image_name${NC} - $dockerfile"
                completed=$((completed + 1))
                ;;
            failed)
                echo -e "❌ ${RED}$image_name${NC} - $dockerfile"
                failed=$((failed + 1))
                ;;
            *)
                echo -e "⏸️  ${YELLOW}$image_name${NC} - $dockerfile ($status)"
                ;;
        esac
    done
    
    echo ""
    echo "Summary:"
    echo "  Total jobs: $total"
    echo "  Completed: $completed"
    echo "  Failed: $failed"
    echo "  Success rate: $((completed * 100 / total))%"
    echo ""
    
    if [ $failed -gt 0 ]; then
        echo "Failed builds:"
        for job_key in "${!BUILD_JOBS[@]}"; do
            if [ "${JOB_STATUS[$job_key]}" = "failed" ]; then
                IFS='|' read -r dockerfile context_dir image_name <<< "${BUILD_JOBS[$job_key]}"
                echo "  - $image_name (log: /tmp/build_${job_key}.log)"
            fi
        done
        echo ""
    fi
}

# Cleanup function
cleanup() {
    log "🧹 Cleaning up..."
    
    # Kill any remaining background jobs
    for pid in "${JOB_PIDS[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    
    # Clean up temporary files older than 1 hour
    find /tmp -name "build_job*.log" -mmin +60 -delete 2>/dev/null || true
    find /tmp -name "build_job*_metadata.json" -mmin +60 -delete 2>/dev/null || true
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Main function
main() {
    local build_config=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--jobs)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -t|--timeout)
                BUILD_TIMEOUT="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -c|--cache-registry)
                CACHE_REGISTRY="$2"
                shift 2
                ;;
            -p|--push)
                PUSH_IMAGES=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                build_config="$1"
                shift
                ;;
        esac
    done
    
    # Validate Docker daemon
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Validate buildx if needed
    if ! docker buildx version >/dev/null 2>&1; then
        warn "Docker buildx not available, using regular build"
    fi
    
    log "🐳 Starting parallel Docker builds"
    debug "Configuration: jobs=$MAX_PARALLEL_JOBS, timeout=$BUILD_TIMEOUT, registry=$REGISTRY"
    
    # Load build configuration or auto-discover
    if [ -n "$build_config" ] && [ -f "$build_config" ]; then
        log "📋 Loading build configuration from $build_config"
        # TODO: Implement YAML config parsing
        error "YAML configuration not yet implemented, using auto-discovery"
    fi
    
    # Auto-discover builds
    auto_discover_builds
    
    if [ ${#BUILD_JOBS[@]} -eq 0 ]; then
        warn "No build jobs discovered"
        exit 0
    fi
    
    # Analyze dependencies
    analyze_dependencies
    
    # Show dry run information
    if [ "$DRY_RUN" = true ]; then
        warn "🔍 DRY RUN MODE - No builds will be executed"
        echo ""
        echo "Build jobs that would be executed:"
        for job_key in "${!BUILD_JOBS[@]}"; do
            IFS='|' read -r dockerfile context_dir image_name <<< "${BUILD_JOBS[$job_key]}"
            echo "  - $image_name ($dockerfile)"
            if [ -n "${JOB_DEPENDENCIES[$job_key]:-}" ]; then
                echo "    Dependencies: ${JOB_DEPENDENCIES[$job_key]}"
            fi
        done
        exit 0
    fi
    
    # Execute builds
    local start_time=$(date +%s)
    execute_builds
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Generate report
    generate_report
    
    success "🎉 Parallel builds completed in ${total_duration}s"
    
    # Exit with error if any builds failed
    for status in "${JOB_STATUS[@]}"; do
        if [ "$status" = "failed" ]; then
            exit 1
        fi
    done
}

# Run main function
main "$@"