#!/bin/bash
# Location: utilities/scripts/security_scan.sh
# Comprehensive Docker security scanning script using multiple tools

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCAN_REPORT_DIR="security_reports"
TRIVY_DB_CACHE="${HOME}/.trivy"
SEVERITY_THRESHOLD="HIGH"
REPORT_FORMAT="table"
FAIL_ON_HIGH=true

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Create reports directory
mkdir -p "$SCAN_REPORT_DIR"

# Function to check if tool is installed
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed"
        return 1
    fi
    return 0
}

# Function to install Trivy if not present
install_trivy() {
    if ! check_tool trivy; then
        print_status "Installing Trivy..."
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        print_success "Trivy installed successfully"
    fi
}

# Function to scan image with Trivy
scan_with_trivy() {
    local image="$1"
    local report_file="$SCAN_REPORT_DIR/trivy_${image//[\/:]/_}.txt"
    
    print_status "Scanning $image with Trivy..."
    
    trivy image \
        --format "$REPORT_FORMAT" \
        --severity "$SEVERITY_THRESHOLD,CRITICAL" \
        --output "$report_file" \
        "$image"
    
    local vuln_count=$(grep -c "Total:" "$report_file" 2>/dev/null || echo "0")
    if [ "$vuln_count" -gt 0 ]; then
        print_warning "Found vulnerabilities in $image (see $report_file)"
        return 1
    else
        print_success "$image passed Trivy scan"
        return 0
    fi
}

# Function to scan Dockerfile with hadolint
scan_dockerfile() {
    local dockerfile="$1"
    local report_file="$SCAN_REPORT_DIR/hadolint_$(basename "$dockerfile").txt"
    
    if ! check_tool hadolint; then
        print_warning "Hadolint not installed, skipping Dockerfile scan"
        return 2
    fi
    
    print_status "Scanning $dockerfile with hadolint..."
    
    if hadolint "$dockerfile" > "$report_file" 2>&1; then
        print_success "$dockerfile passed hadolint scan"
        return 0
    else
        print_warning "Dockerfile issues found in $dockerfile (see $report_file)"
        return 1
    fi
}

# Function to check container runtime security
check_runtime_security() {
    local container="$1"
    local report_file="$SCAN_REPORT_DIR/runtime_${container}.txt"
    
    print_status "Checking runtime security for $container..."
    
    {
        echo "=== Container Runtime Security Check ==="
        echo "Container: $container"
        echo "Timestamp: $(date)"
        echo ""
        
        # Check if running as root
        echo "--- User Check ---"
        local user=$(docker inspect --format '{{.Config.User}}' "$container")
        if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
            echo "WARNING: Container running as root"
        else
            echo "OK: Container running as user: $user"
        fi
        
        # Check capabilities
        echo ""
        echo "--- Capabilities Check ---"
        docker inspect --format '{{.HostConfig.CapAdd}}' "$container" | grep -q "null" || echo "WARNING: Additional capabilities added"
        docker inspect --format '{{.HostConfig.CapDrop}}' "$container" | grep -q "null" || echo "OK: Capabilities dropped"
        
        # Check privileged mode
        echo ""
        echo "--- Privilege Check ---"
        local privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$container")
        if [ "$privileged" = "true" ]; then
            echo "CRITICAL: Container running in privileged mode"
        else
            echo "OK: Container not privileged"
        fi
        
        # Check network mode
        echo ""
        echo "--- Network Check ---"
        local network_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$container")
        if [ "$network_mode" = "host" ]; then
            echo "WARNING: Container using host network"
        else
            echo "OK: Container network mode: $network_mode"
        fi
        
        # Check mounted volumes
        echo ""
        echo "--- Volume Mounts Check ---"
        docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} ({{.Mode}}){{"\n"}}{{end}}' "$container" | while read -r mount; do
            if echo "$mount" | grep -q "/var/run/docker.sock"; then
                echo "CRITICAL: Docker socket mounted"
            elif echo "$mount" | grep -q ":/.*:.*rw"; then
                echo "WARNING: Read-write mount: $mount"
            else
                echo "INFO: Mount: $mount"
            fi
        done
        
    } > "$report_file"
    
    if grep -q "CRITICAL\|WARNING" "$report_file"; then
        print_warning "Security issues found in $container (see $report_file)"
        return 1
    else
        print_success "$container passed runtime security check"
        return 0
    fi
}

# Function to generate comprehensive report
generate_report() {
    local summary_file="$SCAN_REPORT_DIR/security_summary.html"
    
    print_status "Generating comprehensive security report..."
    
    cat > "$summary_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Docker Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .critical { color: #d32f2f; font-weight: bold; }
        .warning { color: #f57c00; font-weight: bold; }
        .success { color: #388e3c; font-weight: bold; }
        .report-section { margin: 20px 0; padding: 15px; border-left: 4px solid #2196f3; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Docker Security Scan Report</h1>
        <p>Generated on: $(date)</p>
        <p>Scan Directory: $SCAN_REPORT_DIR</p>
    </div>
    
    <div class="report-section">
        <h2>Scan Summary</h2>
        <table>
            <tr><th>Scan Type</th><th>Files Scanned</th><th>Issues Found</th></tr>
            <tr><td>Trivy (Vulnerabilities)</td><td>$(ls "$SCAN_REPORT_DIR"/trivy_* 2>/dev/null | wc -l)</td><td>$(grep -l "Total:" "$SCAN_REPORT_DIR"/trivy_* 2>/dev/null | wc -l)</td></tr>
            <tr><td>Hadolint (Dockerfile)</td><td>$(ls "$SCAN_REPORT_DIR"/hadolint_* 2>/dev/null | wc -l)</td><td>$(find "$SCAN_REPORT_DIR" -name "hadolint_*" -size +0 2>/dev/null | wc -l)</td></tr>
            <tr><td>Runtime Security</td><td>$(ls "$SCAN_REPORT_DIR"/runtime_* 2>/dev/null | wc -l)</td><td>$(grep -l "WARNING\|CRITICAL" "$SCAN_REPORT_DIR"/runtime_* 2>/dev/null | wc -l)</td></tr>
        </table>
    </div>
    
    <div class="report-section">
        <h2>Detailed Reports</h2>
        <p>Individual scan reports are available in the following files:</p>
        <ul>
EOF

    # Add links to individual reports
    for report in "$SCAN_REPORT_DIR"/*.txt; do
        if [ -f "$report" ]; then
            echo "            <li><a href=\"$(basename "$report")\">$(basename "$report")</a></li>" >> "$summary_file"
        fi
    done

    cat >> "$summary_file" << EOF
        </ul>
    </div>
    
    <div class="report-section">
        <h2>Recommendations</h2>
        <ul>
            <li>Address all CRITICAL vulnerabilities immediately</li>
            <li>Plan remediation for HIGH severity issues</li>
            <li>Review and fix Dockerfile best practices violations</li>
            <li>Ensure containers run with least privileges</li>
            <li>Regularly update base images and dependencies</li>
            <li>Implement runtime security monitoring</li>
        </ul>
    </div>
</body>
</html>
EOF

    print_success "Comprehensive report generated: $summary_file"
}

# Function to show help
show_help() {
    echo "Docker Security Scanning Script"
    echo "Usage: $0 [OPTIONS] [IMAGES...]"
    echo ""
    echo "OPTIONS:"
    echo "  -i, --image IMAGE       Scan specific image"
    echo "  -f, --dockerfile FILE   Scan Dockerfile"
    echo "  -c, --container NAME    Check running container security"
    echo "  -a, --all              Scan all local images"
    echo "  -s, --severity LEVEL   Set severity threshold (LOW,MEDIUM,HIGH,CRITICAL)"
    echo "  --format FORMAT        Set report format (table,json,sarif)"
    echo "  --no-fail             Don't fail on vulnerabilities"
    echo "  --install-tools       Install required security tools"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -i nginx:latest                    # Scan specific image"
    echo "  $0 -f Dockerfile                     # Scan Dockerfile"
    echo "  $0 -a                                # Scan all local images"
    echo "  $0 -c webapp-container               # Check container security"
}

# Parse arguments
SCAN_ALL=false
INSTALL_TOOLS=false
TARGET_IMAGES=()
TARGET_DOCKERFILES=()
TARGET_CONTAINERS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            TARGET_IMAGES+=("$2")
            shift 2
            ;;
        -f|--dockerfile)
            TARGET_DOCKERFILES+=("$2")
            shift 2
            ;;
        -c|--container)
            TARGET_CONTAINERS+=("$2")
            shift 2
            ;;
        -a|--all)
            SCAN_ALL=true
            shift
            ;;
        -s|--severity)
            SEVERITY_THRESHOLD="$2"
            shift 2
            ;;
        --format)
            REPORT_FORMAT="$2"
            shift 2
            ;;
        --no-fail)
            FAIL_ON_HIGH=false
            shift
            ;;
        --install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            TARGET_IMAGES+=("$1")
            shift
            ;;
    esac
done

# Install tools if requested
if [ "$INSTALL_TOOLS" = true ]; then
    install_trivy
    
    # Install hadolint
    if ! check_tool hadolint; then
        print_status "Installing hadolint..."
        wget -qO- "https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64" > /usr/local/bin/hadolint
        chmod +x /usr/local/bin/hadolint
        print_success "Hadolint installed"
    fi
fi

# Check Docker availability
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    exit 1
fi

print_status "Starting Docker security scan..."

# Variables to track results
TOTAL_SCANS=0
FAILED_SCANS=0

# Scan all local images if requested
if [ "$SCAN_ALL" = true ]; then
    print_status "Scanning all local images..."
    while IFS= read -r image; do
        TARGET_IMAGES+=("$image")
    done < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")
fi

# Scan specified images
for image in "${TARGET_IMAGES[@]}"; do
    ((TOTAL_SCANS++))
    if ! scan_with_trivy "$image"; then
        ((FAILED_SCANS++))
    fi
done

# Scan Dockerfiles
for dockerfile in "${TARGET_DOCKERFILES[@]}"; do
    if [ -f "$dockerfile" ]; then
        ((TOTAL_SCANS++))
        if ! scan_dockerfile "$dockerfile"; then
            ((FAILED_SCANS++))
        fi
    else
        print_error "Dockerfile not found: $dockerfile"
    fi
done

# Check container runtime security
for container in "${TARGET_CONTAINERS[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        ((TOTAL_SCANS++))
        if ! check_runtime_security "$container"; then
            ((FAILED_SCANS++))
        fi
    else
        print_error "Container not found or not running: $container"
    fi
done

# Generate comprehensive report
generate_report

# Summary
echo ""
print_status "Security Scan Summary"
print_status "===================="
echo "Total scans performed: $TOTAL_SCANS"
echo "Scans with issues: $FAILED_SCANS"
echo "Clean scans: $((TOTAL_SCANS - FAILED_SCANS))"
echo ""
print_status "Reports saved to: $SCAN_REPORT_DIR/"

# Exit based on results
if [ "$FAILED_SCANS" -gt 0 ] && [ "$FAIL_ON_HIGH" = true ]; then
    print_error "Security issues found! Check reports for details."
    exit 1
else
    print_success "Security scan completed!"
    exit 0
fi