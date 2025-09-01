#!/bin/bash
# File Location: concepts/06_security/scan_image.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo "Usage: $0 [OPTIONS] IMAGE_NAME"
    echo ""
    echo "Security scanning tool for Docker images"
    echo ""
    echo "Options:"
    echo "  -t, --tool TOOL     Scanning tool (trivy, scout, grype)"
    echo "  -s, --severity LEVEL Minimum severity (LOW, MEDIUM, HIGH, CRITICAL)"
    echo "  -f, --format FORMAT  Output format (table, json, sarif)"
    echo "  -o, --output FILE    Save results to file"
    echo "  -q, --quiet          Minimal output"
    echo "  --skip-db-update     Skip vulnerability database update"
    echo "  -h, --help           Show this help"
}

check_tool_installed() {
    local tool=$1
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: $tool is not installed${NC}"
        echo "Install instructions:"
        case $tool in
            trivy)
                echo "https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
                ;;
            grype)
                echo "https://github.com/anchore/grype#installation"
                ;;
        esac
        return 1
    fi
}

scan_with_trivy() {
    local image=$1
    local severity=${2:-MEDIUM}
    local format=${3:-table}
    local output=$4
    local skip_update=$5
    
    echo -e "${BLUE}Scanning with Trivy...${NC}"
    
    local cmd="trivy image"
    
    if [ "$skip_update" = true ]; then
        cmd="$cmd --skip-db-update"
    fi
    
    cmd="$cmd --severity $severity --format $format"
    
    if [ -n "$output" ]; then
        cmd="$cmd --output $output"
    fi
    
    cmd="$cmd $image"
    
    eval $cmd
    
    # Additional Trivy scans
    echo -e "\n${YELLOW}Running additional Trivy scans...${NC}"
    
    # Scan for secrets
    echo "Scanning for secrets:"
    trivy fs --security-checks secret ./ 2>/dev/null || echo "No secrets scan available"
    
    # Scan for misconfigurations
    echo "Scanning for misconfigurations:"
    trivy config ./ 2>/dev/null || echo "No config scan available"
}

scan_with_scout() {
    local image=$1
    local format=${2:-text}
    local output=$3
    
    echo -e "${BLUE}Scanning with Docker Scout...${NC}"
    
    if ! docker scout version &> /dev/null; then
        echo -e "${RED}Docker Scout not available${NC}"
        return 1
    fi
    
    local cmd="docker scout cves $image"
    
    if [ "$format" = "json" ]; then
        cmd="$cmd --format json"
    fi
    
    if [ -n "$output" ]; then
        cmd="$cmd > $output"
    fi
    
    eval $cmd
    
    # Quick view
    echo -e "\n${YELLOW}Docker Scout quick view:${NC}"
    docker scout quickview $image
}

scan_with_grype() {
    local image=$1
    local severity=${2:-medium}
    local format=${3:-table}
    local output=$4
    
    echo -e "${BLUE}Scanning with Grype...${NC}"
    
    local cmd="grype $image"
    
    cmd="$cmd --fail-on $severity"
    cmd="$cmd --output $format"
    
    if [ -n "$output" ]; then
        cmd="$cmd --file $output"
    fi
    
    eval $cmd
}

analyze_results() {
    local image=$1
    local tool=$2
    
    echo -e "\n${YELLOW}Security Analysis Summary for: $image${NC}"
    echo "Scan tool: $tool"
    echo "Scan time: $(date)"
    
    # Basic image info
    echo -e "\n${BLUE}Image Information:${NC}"
    docker inspect $image --format='
Image ID: {{.Id}}
Created: {{.Created}}
Size: {{.Size}} bytes
Architecture: {{.Architecture}}
OS: {{.Os}}
' 2>/dev/null || echo "Could not retrieve image info"
    
    # Check for common security indicators
    echo -e "\n${BLUE}Security Indicators:${NC}"
    
    # Check if running as root
    local user=$(docker inspect $image --format='{{.Config.User}}' 2>/dev/null)
    if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
        echo -e "${RED}⚠ Container runs as root user${NC}"
    else
        echo -e "${GREEN}✓ Container runs as non-root user: $user${NC}"
    fi
    
    # Check exposed ports
    local ports=$(docker inspect $image --format='{{.Config.ExposedPorts}}' 2>/dev/null)
    if [ "$ports" != "map[]" ] && [ -n "$ports" ]; then
        echo -e "${YELLOW}ℹ Exposed ports: $ports${NC}"
    fi
    
    # Check for health check
    local healthcheck=$(docker inspect $image --format='{{.Config.Healthcheck}}' 2>/dev/null)
    if [ "$healthcheck" = "<nil>" ]; then
        echo -e "${YELLOW}⚠ No health check configured${NC}"
    else
        echo -e "${GREEN}✓ Health check configured${NC}"
    fi
}

main() {
    local image=""
    local tool="trivy"
    local severity="MEDIUM"
    local format="table"
    local output=""
    local quiet=false
    local skip_update=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tool)
                tool="$2"
                shift 2
                ;;
            -s|--severity)
                severity="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            --skip-db-update)
                skip_update=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$image" ]; then
                    image="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$image" ]; then
        echo -e "${RED}Error: No image specified${NC}"
        show_usage
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
    
    # Check if image exists
    if ! docker inspect "$image" &> /dev/null; then
        echo -e "${YELLOW}Image not found locally, attempting to pull...${NC}"
        docker pull "$image" || {
            echo -e "${RED}Error: Could not pull image $image${NC}"
            exit 1
        }
    fi
    
    echo -e "${GREEN}Starting security scan for: $image${NC}"
    
    # Run scan based on tool
    case $tool in
        trivy)
            check_tool_installed trivy && scan_with_trivy "$image" "$severity" "$format" "$output" "$skip_update"
            ;;
        scout)
            scan_with_scout "$image" "$format" "$output"
            ;;
        grype)
            check_tool_installed grype && scan_with_grype "$image" "$severity" "$format" "$output"
            ;;
        *)
            echo -e "${RED}Unknown scanning tool: $tool${NC}"
            echo "Supported tools: trivy, scout, grype"
            exit 1
            ;;
    esac
    
    # Analysis summary (unless quiet mode)
    if [ "$quiet" = false ]; then
        analyze_results "$image" "$tool"
    fi
    
    echo -e "\n${GREEN}Security scan completed!${NC}"
    
    if [ -n "$output" ]; then
        echo "Results saved to: $output"
    fi
}

main "$@"