#!/bin/bash
# File Location: concepts/02_images_layers/inspect_image.sh
# Inspect layers & sizes analysis script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

show_usage() {
    echo "Usage: $0 [IMAGE_NAME] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -d, --detailed    Show detailed layer information"
    echo "  -s, --size        Focus on size analysis"
    echo "  -c, --compare     Compare multiple images"
    echo ""
    echo "Examples:"
    echo "  $0 ubuntu:latest"
    echo "  $0 nginx:alpine -d"
    echo "  $0 python:3.9 --size"
}

# Check if Docker is running
check_docker() {
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

# Format size in human readable format
format_size() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Analyze image layers
analyze_layers() {
    local image=$1
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Layer Analysis for $image${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo -e "\n${YELLOW}Image History:${NC}"
    docker history "$image" --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" --no-trunc
    
    echo -e "\n${YELLOW}Layer Details:${NC}"
    docker inspect "$image" --format='{{range .RootFS.Layers}}{{printf "%.12s\n" .}}{{end}}' | while read layer; do
        echo "Layer: $layer"
    done
}

# Size analysis
size_analysis() {
    local image=$1
    echo -e "${PURPLE}Size Breakdown for $image:${NC}"
    
    # Get image info
    local size=$(docker inspect "$image" --format='{{.Size}}' 2>/dev/null)
    local virtual_size=$(docker inspect "$image" --format='{{.VirtualSize}}' 2>/dev/null)
    
    echo "Total Size: $(format_size $size)"
    echo "Virtual Size: $(format_size $virtual_size)"
    
    # Show layer sizes
    echo -e "\n${CYAN}Layer Sizes:${NC}"
    docker history "$image" --format "table {{.Size}}\t{{.CreatedBy}}" | head -20
}

# Compare images
compare_images() {
    echo -e "${GREEN}Image Comparison:${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | head -10
}

# Main execution
main() {
    check_docker
    
    local image=""
    local detailed=false
    local size_focus=false
    local compare=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--detailed)
                detailed=true
                shift
                ;;
            -s|--size)
                size_focus=true
                shift
                ;;
            -c|--compare)
                compare=true
                shift
                ;;
            *)
                if [ -z "$image" ]; then
                    image="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ "$compare" = true ]; then
        compare_images
        exit 0
    fi
    
    if [ -z "$image" ]; then
        echo -e "${RED}Error: Please provide an image name${NC}"
        show_usage
        exit 1
    fi
    
    # Check if image exists
    if ! docker inspect "$image" &> /dev/null; then
        echo -e "${YELLOW}Image $image not found locally. Pulling...${NC}"
        docker pull "$image"
    fi
    
    echo -e "${GREEN}Analyzing image: $image${NC}\n"
    
    if [ "$size_focus" = true ]; then
        size_analysis "$image"
    elif [ "$detailed" = true ]; then
        analyze_layers "$image"
        echo ""
        size_analysis "$image"
    else
        # Basic analysis
        echo -e "${YELLOW}Basic Image Information:${NC}"
        docker inspect "$image" --format='Repository: {{.RepoTags}}
Created: {{.Created}}
Size: {{.Size}} bytes
Architecture: {{.Architecture}}
OS: {{.Os}}'
        
        echo -e "\n${YELLOW}Layer Count:${NC}"
        docker inspect "$image" --format='{{len .RootFS.Layers}} layers'
        
        echo -e "\n${YELLOW}Recent History (top 5):${NC}"
        docker history "$image" --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" | head -6
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi