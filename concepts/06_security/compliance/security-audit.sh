#!/bin/bash
# File Location: concepts/06_security/compliance/security-audit.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AUDIT_LOG="/tmp/docker-security-audit-$(date +%Y%m%d-%H%M%S).log"

log_message() {
    echo -e "$1" | tee -a "$AUDIT_LOG"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Docker Security Audit Tool"
    echo ""
    echo "Options:"
    echo "  -i, --images          Audit container images"
    echo "  -c, --containers      Audit running containers"
    echo "  -d, --daemon          Audit Docker daemon configuration"
    echo "  -h, --host            Audit host configuration"
    echo "  -n, --network         Audit network configuration"
    echo "  -a, --all             Run all audits"
    echo "  -o, --output FILE     Save detailed report to file"
    echo "  --help                Show this help"
}

audit_docker_daemon() {
    log_message "${BLUE}=== Docker Daemon Security Audit ===${NC}"
    
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    log_message "Docker Version: $docker_version"
    
    local docker_pid=$(pgrep dockerd)
    if [ -n "$docker_pid" ]; then
        local docker_user=$(ps -o user= -p $docker_pid)
        if [ "$docker_user" = "root" ]; then
            log_message "${YELLOW}⚠ Docker daemon running as root${NC}"
        else
            log_message "${GREEN}✓ Docker daemon not running as root${NC}"
        fi
    fi
    
    log_message "\nDocker daemon configuration:"
    docker info --format '{{json .}}' | jq -r '
        "Storage Driver: " + .Driver,
        "Logging Driver: " + .LoggingDriver,
        "Security Options: " + (.SecurityOptions | join(", ")),
        "Live Restore: " + (.LiveRestoreEnabled | tostring)
    ' 2>/dev/null || log_message "Could not retrieve daemon configuration"
    
    local insecure_registries=$(docker info --format '{{.RegistryConfig.InsecureRegistryCIDRs}}' 2>/dev/null)
    if [ "$insecure_registries" != "[]" ] && [ -n "$insecure_registries" ]; then
        log_message "${RED}✗ Insecure registries configured${NC}"
    else
        log_message "${GREEN}✓ No insecure registries configured${NC}"
    fi
}

audit_host_configuration() {
    log_message "\n${BLUE}=== Host Configuration Audit ===${NC}"
    
    local docker_group_members=$(getent group docker 2>/dev/null | cut -d: -f4)
    log_message "Docker group members: ${docker_group_members:-none}"
    
    log_message "\nFile permissions:"
    
    files_to_check=(
        "/var/run/docker.sock"
        "/etc/docker/daemon.json"
        "/lib/systemd/system/docker.service"
        "/usr/bin/docker"
        "/usr/bin/dockerd"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -e "$file" ]; then
            local perms=$(stat -c "%a %U:%G" "$file" 2>/dev/null)
            log_message "  $file: $perms"
        else
            log_message "  $file: Not found"
        fi
    done
    
    local docker_mount=$(df /var/lib/docker 2>/dev/null | tail -1 | awk '{print $1}')
    if [[ "$docker_mount" == *"docker"* ]]; then
        log_message "${GREEN}✓ Docker has separate partition${NC}"
    else
        log_message "${YELLOW}⚠ Docker shares root partition${NC}"
    fi
    
    if command -v auditctl &>/dev/null; then
        local docker_rules=$(auditctl -l 2>/dev/null | grep -c docker || echo 0)
        if [ "$docker_rules" -gt 0 ]; then
            log_message "${GREEN}✓ Docker audit rules configured${NC}"
        else
            log_message "${YELLOW}⚠ No Docker audit rules found${NC}"
        fi
    else
        log_message "${YELLOW}⚠ Audit system not available${NC}"
    fi
}

audit_images() {
    log_message "\n${BLUE}=== Container Images Security Audit ===${NC}"
    
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -10)
    
    if [ -z "$images" ]; then
        log_message "No images found"
        return
    fi
    
    while IFS= read -r image; do
        log_message "Analyzing image: $image"
        
        local user=$(docker inspect "$image" --format '{{.Config.User}}' 2>/dev/null || echo "")
        if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ]; then
            log_message "${RED}  ✗ Runs as root user${NC}"
        else
            log_message "${GREEN}  ✓ Runs as non-root user: $user${NC}"
        fi
        
        local healthcheck=$(docker inspect "$image" --format '{{.Config.Healthcheck}}' 2>/dev/null || echo "")
        if [ "$healthcheck" = "<nil>" ] || [ -z "$healthcheck" ]; then
            log_message "${YELLOW}  ⚠ No health check configured${NC}"
        else
            log_message "${GREEN}  ✓ Health check configured${NC}"
        fi
        
        local size=$(docker inspect "$image" --format '{{.Size}}' 2>/dev/null || echo 0)
        local size_mb=$((size / 1024 / 1024))
        if [ "$size_mb" -gt 1000 ]; then
            log_message "${YELLOW}  ⚠ Large image size: ${size_mb}MB${NC}"
        else
            log_message "${GREEN}  ✓ Reasonable image size: ${size_mb}MB${NC}"
        fi
        
        if command -v trivy &>/dev/null; then
            local critical_vulns=$(trivy image --severity CRITICAL --quiet --format json "$image" 2>/dev/null | jq '.Results[]?.Vulnerabilities | length' 2>/dev/null | awk '{sum += $1} END {print sum+0}')
            if [ "$critical_vulns" -gt 0 ]; then
                log_message "${RED}  ✗ Critical vulnerabilities: $critical_vulns${NC}"
            else
                log_message "${GREEN}  ✓ No critical vulnerabilities found${NC}"
            fi
        fi
        
    done <<< "$images"
}

audit_containers() {
    log_message "\n${BLUE}=== Running Containers Security Audit ===${NC}"
    
    local containers=$(docker ps --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        log_message "No running containers found"
        return
    fi
    
    while IFS= read -r container; do
        log_message "Analyzing container: $container"
        
        local privileged=$(docker inspect "$container" --format '{{.HostConfig.Privileged}}' 2>/dev/null)
        if [ "$privileged" = "true" ]; then
            log_message "${RED}  ✗ Running in privileged mode${NC}"
        else
            log_message "${GREEN}  ✓ Not running privileged${NC}"
        fi
        
        local cap_add=$(docker inspect "$container" --format '{{.HostConfig.CapAdd}}' 2>/dev/null)
        local cap_drop=$(docker inspect "$container" --format '{{.HostConfig.CapDrop}}' 2>/dev/null)
        
        if [ "$cap_add" != "[]" ] && [ "$cap_add" != "<nil>" ]; then
            log_message "${YELLOW}  ⚠ Added capabilities: $cap_add${NC}"
        fi
        if [ "$cap_drop" = "[]" ] || [ "$cap_drop" = "<nil>" ]; then
            log_message "${YELLOW}  ⚠ No capabilities dropped${NC}"
        else
            log_message "${GREEN}  ✓ Capabilities dropped${NC}"
        fi
        
        local memory=$(docker inspect "$container" --format '{{.HostConfig.Memory}}' 2>/dev/null)
        local cpus=$(docker inspect "$container" --format '{{.HostConfig.NanoCpus}}' 2>/dev/null)
        
        if [ "$memory" = "0" ]; then
            log_message "${YELLOW}  ⚠ No memory limit set${NC}"
        else
            local memory_mb=$((memory / 1024 / 1024))
            log_message "${GREEN}  ✓ Memory limit: ${memory_mb}MB${NC}"
        fi
        
        if [ "$cpus" = "0" ]; then
            log_message "${YELLOW}  ⚠ No CPU limit set${NC}"
        else
            log_message "${GREEN}  ✓ CPU limit configured${NC}"
        fi
        
        local read_only=$(docker inspect "$container" --format '{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null)
        if [ "$read_only" = "true" ]; then
            log_message "${GREEN}  ✓ Read-only root filesystem${NC}"
        else
            log_message "${YELLOW}  ⚠ Writable root filesystem${NC}"
        fi
        
    done <<< "$containers"
}

audit_network() {
    log_message "\n${BLUE}=== Network Security Audit ===${NC}"
    
    local networks=$(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none")
    
    log_message "Custom networks:"
    if [ -z "$networks" ]; then
        log_message "  No custom networks found"
    else
        while IFS= read -r network; do
            local driver=$(docker network inspect "$network" --format '{{.Driver}}' 2>/dev/null)
            local encrypted=$(docker network inspect "$network" --format '{{.Options.encrypted}}' 2>/dev/null)
            
            log_message "  Network: $network (Driver: $driver)"
            if [ "$encrypted" = "true" ]; then
                log_message "${GREEN}    ✓ Encryption enabled${NC}"
            else
                log_message "${YELLOW}    ⚠ Encryption not enabled${NC}"
            fi
        done <<< "$networks"
    fi
    
    log_message "\nPort exposures:"
    local exposed_ports=$(docker ps --format "{{.Names}} {{.Ports}}" | grep -v "^$")
    if [ -z "$exposed_ports" ]; then
        log_message "  No exposed ports found"
    else
        while IFS= read -r line; do
            if [[ "$line" == *"0.0.0.0:"* ]]; then
                log_message "${YELLOW}  ⚠ $line${NC}"
            else
                log_message "  $line"
            fi
        done <<< "$exposed_ports"
    fi
}

generate_report() {
    local output_file="$1"
    
    log_message "\n${BLUE}=== Security Audit Summary ===${NC}"
    log_message "Audit completed: $(date)"
    log_message "Audit log saved to: $AUDIT_LOG"
    
    if [ -n "$output_file" ]; then
        cp "$AUDIT_LOG" "$output_file"
        log_message "Detailed report saved to: $output_file"
    fi
    
    log_message "\n${YELLOW}Recommendations:${NC}"
    log_message "1. Run containers as non-root users"
    log_message "2. Set resource limits (memory/CPU)"
    log_message "3. Use read-only root filesystems where possible"
    log_message "4. Drop unnecessary capabilities"
    log_message "5. Avoid privileged mode"
    log_message "6. Scan images for vulnerabilities regularly"
    log_message "7. Use encrypted overlay networks"
    log_message "8. Limit exposed ports to specific interfaces"
}

main() {
    local run_images=false
    local run_containers=false
    local run_daemon=false
    local run_host=false
    local run_network=false
    local output_file=""
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--images)
                run_images=true
                shift
                ;;
            -c|--containers)
                run_containers=true
                shift
                ;;
            -d|--daemon)
                run_daemon=true
                shift
                ;;
            -h|--host)
                run_host=true
                shift
                ;;
            -n|--network)
                run_network=true
                shift
                ;;
            -a|--all)
                run_images=true
                run_containers=true
                run_daemon=true
                run_host=true
                run_network=true
                shift
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if ! docker info &>/dev/null; then
        log_message "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
    
    log_message "${GREEN}Starting Docker Security Audit...${NC}"
    
    [ "$run_daemon" = true ] && audit_docker_daemon
    [ "$run_host" = true ] && audit_host_configuration
    [ "$run_images" = true ] && audit_images
    [ "$run_containers" = true ] && audit_containers
    [ "$run_network" = true ] && audit_network
    
    generate_report "$output_file"
}

main "$@"