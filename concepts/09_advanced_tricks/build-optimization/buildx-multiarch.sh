#!/bin/bash
# 09_advanced_tricks/build-optimization/buildx-multiarch.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
BUILDER_NAME="multiarch-builder"
REGISTRY=""
IMAGE_NAME=""
DOCKERFILE="Dockerfile"
PUSH=false
VERBOSE=false

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

show_usage() {
    cat << 'EOF'
Multi-Architecture Docker Build Script

Usage: ./buildx-multiarch.sh [options]

Options:
    -i, --image IMAGE          Image name (required)
    -r, --registry REGISTRY    Registry URL
    -p, --platforms PLATFORMS  Target platforms (default: linux/amd64,linux/arm64,linux/arm/v7)
    -f, --file DOCKERFILE      Dockerfile path (default: Dockerfile)
    -b, --builder BUILDER      Builder name (default: multiarch-builder)
    --push                     Push to registry
    -v, --verbose              Verbose output
    -h, --help                 Show help

Examples:
    ./buildx-multiarch.sh -i myapp:latest --push
    ./buildx-multiarch.sh -i myapp:v1.0 -r docker.io/username --push
    ./buildx-multiarch.sh -i myapp -p "linux/amd64,linux/arm64" --push

EOF
}

setup_buildx() {
    log "Setting up Docker Buildx..."
    
    if ! docker buildx version >/dev/null 2>&1; then
        error "Docker Buildx not available"
        exit 1
    fi
    
    if docker buildx ls | grep -q "$BUILDER_NAME"; then
        log "Using existing builder: $BUILDER_NAME"
    else
        log "Creating new builder: $BUILDER_NAME"
        docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
    fi
    
    docker buildx use "$BUILDER_NAME"
    success "Buildx setup complete"
}

build_multiarch() {
    local build_args=""
    local full_image="${REGISTRY:+$REGISTRY/}$IMAGE_NAME"
    
    log "Building multi-architecture image: $full_image"
    log "Platforms: $PLATFORMS"
    
    if [ "$PUSH" = true ]; then
        build_args="--push"
    else
        build_args="--load"
        warn "Not pushing to registry (use --push to push)"
    fi
    
    if [ "$VERBOSE" = true ]; then
        build_args="$build_args --progress=plain"
    fi
    
    docker buildx build \
        --platform "$PLATFORMS" \
        --file "$DOCKERFILE" \
        --tag "$full_image" \
        $build_args \
        .
    
    success "Multi-architecture build completed"
}

inspect_manifest() {
    local full_image="${REGISTRY:+$REGISTRY/}$IMAGE_NAME"
    
    if [ "$PUSH" = true ]; then
        log "Inspecting manifest..."
        docker buildx imagetools inspect "$full_image"
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--image)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -p|--platforms)
                PLATFORMS="$2"
                shift 2
                ;;
            -f|--file)
                DOCKERFILE="$2"
                shift 2
                ;;
            -b|--builder)
                BUILDER_NAME="$2"
                shift 2
                ;;
            --push)
                PUSH=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$IMAGE_NAME" ]; then
        error "Image name is required"
        show_usage
        exit 1
    fi
    
    if [ ! -f "$DOCKERFILE" ]; then
        error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi
    
    setup_buildx
    build_multiarch
    inspect_manifest
}

main "$@"