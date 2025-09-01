#!/bin/bash
# Location: labs/lab_06_production_deployment/security/firewall-rules.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SSH_PORT="${SSH_PORT:-22}"
HTTP_PORT="80"
HTTPS_PORT="443"
DOCKER_SUBNET="172.16.0.0/12"
MONITORING_PORTS="3000,9090,9091,9092,9093"
ADMIN_IPS="${ADMIN_IPS:-}"
FAIL2BAN_CHAIN="fail2ban"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

backup_rules() {
    log "Backing up current iptables rules"
    iptables-save > "/root/iptables-backup-$(date +%Y%m%d_%H%M%S).rules"
    success "Rules backed up"
}

setup_basic_chains() {
    log "Setting up basic firewall chains"
    
    # Create custom chains
    iptables -N LOGGING 2>/dev/null || true
    iptables -N RATE_LIMIT 2>/dev/null || true
    iptables -N DOCKER_FILTER 2>/dev/null || true
    
    success "Basic chains created"
}

set_default_policies() {
    log "Setting default policies"
    
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    success "Default policies set (DROP INPUT/FORWARD, ACCEPT OUTPUT)"
}

allow_loopback() {
    log "Allowing loopback traffic"
    
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    success "Loopback traffic allowed"
}

allow_established() {
    log "Allowing established and related connections"
    
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    success "Established connections allowed"
}

setup_rate_limiting() {
    log "Setting up rate limiting"
    
    # HTTP/HTTPS rate limiting
    iptables -A RATE_LIMIT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
    iptables -A RATE_LIMIT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
    
    # SSH rate limiting
    iptables -A RATE_LIMIT -p tcp --dport ${SSH_PORT} -m limit --limit 5/minute --limit-burst 10 -j ACCEPT
    
    # Default drop for rate limited traffic
    iptables -A RATE_LIMIT -j LOG --log-prefix "RATE_LIMITED: " --log-level 4
    iptables -A RATE_LIMIT -j DROP
    
    success "Rate limiting configured"
}

allow_ssh() {
    log "Configuring SSH access on port ${SSH_PORT}"
    
    if [[ -n "${ADMIN_IPS}" ]]; then
        # Allow SSH only from admin IPs
        for ip in $(echo ${ADMIN_IPS} | tr ',' ' '); do
            iptables -A INPUT -p tcp -s ${ip} --dport ${SSH_PORT} -j RATE_LIMIT
            log "SSH allowed from ${ip}"
        done
    else
        # Allow SSH from anywhere (with rate limiting)
        iptables -A INPUT -p tcp --dport ${SSH_PORT} -j RATE_LIMIT
        warn "SSH allowed from anywhere - consider restricting to specific IPs"
    fi
    
    success "SSH access configured"
}

allow_web_traffic() {
    log "Allowing web traffic (HTTP/HTTPS)"
    
    iptables -A INPUT -p tcp --dport ${HTTP_PORT} -j RATE_LIMIT
    iptables -A INPUT -p tcp --dport ${HTTPS_PORT} -j RATE_LIMIT
    
    success "Web traffic allowed"
}

setup_docker_rules() {
    log "Setting up Docker networking rules"
    
    # Allow Docker container communication
    iptables -A DOCKER_FILTER -s ${DOCKER_SUBNET} -j ACCEPT
    iptables -A DOCKER_FILTER -d ${DOCKER_SUBNET} -j ACCEPT
    
    # Allow Docker bridge traffic
    iptables -A INPUT -i docker0 -j ACCEPT
    iptables -A FORWARD -i docker0 -j ACCEPT
    iptables -A FORWARD -o docker0 -j ACCEPT
    
    # Allow Docker custom networks
    for network in $(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none"); do
        NETWORK_INTERFACE=$(docker network inspect ${network} --format "{{range .Options}}{{.}}{{end}}" | grep -oP 'com.docker.network.bridge.name=\K\w+' || echo "")
        if [[ -n "${NETWORK_INTERFACE}" ]]; then
            iptables -A INPUT -i ${NETWORK_INTERFACE} -j ACCEPT
            iptables -A FORWARD -i ${NETWORK_INTERFACE} -j ACCEPT
            iptables -A FORWARD -o ${NETWORK_INTERFACE} -j ACCEPT
            log "Docker network ${network} (${NETWORK_INTERFACE}) allowed"
        fi
    done
    
    success "Docker rules configured"
}

setup_monitoring_access() {
    log "Setting up monitoring access"
    
    if [[ -n "${ADMIN_IPS}" ]]; then
        for ip in $(echo ${ADMIN_IPS} | tr ',' ' '); do
            for port in $(echo ${MONITORING_PORTS} | tr ',' ' '); do
                iptables -A INPUT -p tcp -s ${ip} --dport ${port} -j ACCEPT
            done
        done
        success "Monitoring access restricted to admin IPs"
    else
        warn "No admin IPs specified - monitoring ports will be blocked"
    fi
}

setup_icmp() {
    log "Configuring ICMP rules"
    
    # Allow ping with rate limiting
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 5/minute --limit-burst 10 -j ACCEPT
    
    # Allow necessary ICMP types
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
    
    success "ICMP rules configured"
}

setup_logging() {
    log "Setting up logging rules"
    
    # Log dropped packets (rate limited)
    iptables -A INPUT -m limit --limit 5/minute --limit-burst 10 -j LOG --log-prefix "DROPPED: " --log-level 4
    
    # Add final DROP rule
    iptables -A INPUT -j DROP
    
    success "Logging configured"
}

setup_fail2ban_integration() {
    log "Setting up Fail2Ban integration"
    
    # Create Fail2Ban chain if it doesn't exist
    iptables -N ${FAIL2BAN_CHAIN} 2>/dev/null || true
    
    # Insert Fail2Ban chain at the beginning of INPUT
    iptables -I INPUT 1 -j ${FAIL2BAN_CHAIN}
    
    success "Fail2Ban integration ready"
}

setup_ddos_protection() {
    log "Setting up DDoS protection"
    
    # Limit new connections
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
    
    # SYN flood protection
    iptables -A INPUT -p tcp --syn -m limit --limit 1/second --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    
    # Port scanning protection
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    
    success "DDoS protection configured"
}

save_rules() {
    log "Saving iptables rules"
    
    # Save rules for different distros
    if command -v iptables-save >/dev/null && command -v netfilter-persistent >/dev/null; then
        iptables-save > /etc/iptables/rules.v4
        netfilter-persistent save
    elif command -v service >/dev/null; then
        service iptables save 2>/dev/null || true
    else
        # Create startup script
        cat > /etc/init.d/firewall << 'EOF'
#!/bin/bash
case "$1" in
    start)
        /root/firewall-rules.sh --apply
        ;;
    stop)
        iptables -F
        iptables -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
EOF
        chmod +x /etc/init.d/firewall
        warn "Created startup script at /etc/init.d/firewall"
    fi
    
    success "Rules saved"
}

show_status() {
    log "Current firewall status:"
    echo
    
    echo "=== INPUT Chain ==="
    iptables -L INPUT -n --line-numbers
    echo
    
    echo "=== RATE_LIMIT Chain ==="
    iptables -L RATE_LIMIT -n --line-numbers 2>/dev/null || echo "Not created"
    echo
    
    echo "=== Active Connections ==="
    ss -tuln | head -10
    echo
    
    echo "=== Recent Dropped Packets ==="
    dmesg | grep "DROPPED:" | tail -5 || echo "No dropped packets logged"
}

test_rules() {
    log "Testing firewall rules"
    
    # Test SSH connectivity (if admin IPs are set)
    if [[ -n "${ADMIN_IPS}" ]]; then
        for ip in $(echo ${ADMIN_IPS} | tr ',' ' '); do
            if timeout 5 telnet ${ip} ${SSH_PORT} 2>/dev/null | grep -q "Connected"; then
                success "SSH accessible from ${ip}"
            else
                warn "SSH may not be accessible from ${ip}"
            fi
        done
    fi
    
    # Test web ports
    if timeout 5 curl -s http://localhost:${HTTP_PORT}/health >/dev/null 2>&1; then
        success "HTTP port ${HTTP_PORT} accessible"
    else
        warn "HTTP port ${HTTP_PORT} may not be accessible"
    fi
    
    if timeout 5 curl -s -k https://localhost:${HTTPS_PORT}/health >/dev/null 2>&1; then
        success "HTTPS port ${HTTPS_PORT} accessible"
    else
        warn "HTTPS port ${HTTPS_PORT} may not be accessible"
    fi
}

main() {
    log "Starting firewall configuration"
    
    check_root
    backup_rules
    
    # Clear existing rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    setup_basic_chains
    set_default_policies
    allow_loopback
    allow_established
    setup_rate_limiting
    setup_fail2ban_integration
    allow_ssh
    allow_web_traffic
    setup_docker_rules
    setup_monitoring_access
    setup_icmp
    setup_ddos_protection
    setup_logging
    
    save_rules
    
    success "Firewall configuration completed"
    
    show_status
}

case "${1:-}" in
    --apply)
        main
        ;;
    --status)
        show_status
        ;;
    --test)
        test_rules
        ;;
    --backup)
        check_root
        backup_rules
        ;;
    --restore)
        check_root
        if [[ -n "${2:-}" ]] && [[ -f "$2" ]]; then
            iptables-restore < "$2"
            success "Rules restored from $2"
        else
            error "Backup file not specified or not found"
            exit 1
        fi
        ;;
    --reset)
        check_root
        log "Resetting firewall rules"
        iptables -F
        iptables -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        success "Firewall reset to default (ACCEPT ALL)"
        ;;
    --help|-h)
        echo "Firewall Rules Script"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --apply     Apply firewall rules"
        echo "  --status    Show current status"
        echo "  --test      Test connectivity"
        echo "  --backup    Backup current rules"
        echo "  --restore FILE  Restore from backup"
        echo "  --reset     Reset to default (allow all)"
        echo "  --help      Show this help"
        echo ""
        echo "Environment Variables:"
        echo "  SSH_PORT     SSH port (default: 22)"
        echo "  ADMIN_IPS    Comma-separated admin IPs"
        echo "  BLOCKED_COUNTRIES  Countries to block"
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1. Use --help for usage."
        exit 1
        ;;
esac