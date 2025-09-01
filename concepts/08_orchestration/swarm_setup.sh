#!/bin/bash
# 08_orchestration/swarm_setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MANAGER_NODES=${MANAGER_NODES:-1}
WORKER_NODES=${WORKER_NODES:-2}
NETWORK_NAME=${NETWORK_NAME:-traefik-public}

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    success "Docker is installed and running"
}

init_swarm() {
    log "Initializing Docker Swarm..."
    
    # Check if already in swarm mode
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        warn "Node is already part of a swarm cluster"
        return 0
    fi
    
    # Initialize swarm
    MANAGER_IP=$(docker info 2>/dev/null | grep "Node Address" | cut -d' ' -f3 || echo "127.0.0.1")
    
    if [ -z "$MANAGER_IP" ] || [ "$MANAGER_IP" = "" ]; then
        # Get the first non-loopback IP
        MANAGER_IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $7}' 2>/dev/null || echo "127.0.0.1")
    fi
    
    log "Initializing swarm with manager IP: $MANAGER_IP"
    
    # Initialize the swarm
    SWARM_OUTPUT=$(docker swarm init --advertise-addr "$MANAGER_IP" 2>&1)
    
    if [ $? -eq 0 ]; then
        success "Swarm initialized successfully"
        echo "$SWARM_OUTPUT"
    else
        if echo "$SWARM_OUTPUT" | grep -q "already part of a swarm"; then
            warn "Node is already part of a swarm"
        else
            error "Failed to initialize swarm: $SWARM_OUTPUT"
            exit 1
        fi
    fi
}

get_join_tokens() {
    log "Getting join tokens..."
    
    echo -e "\n${BLUE}=== Manager Join Token ===${NC}"
    MANAGER_TOKEN=$(docker swarm join-token manager -q 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "docker swarm join --token $MANAGER_TOKEN $(docker info --format '{{.Swarm.NodeAddr}}'):2377"
    else
        error "Failed to get manager join token"
    fi
    
    echo -e "\n${BLUE}=== Worker Join Token ===${NC}"
    WORKER_TOKEN=$(docker swarm join-token worker -q 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "docker swarm join --token $WORKER_TOKEN $(docker info --format '{{.Swarm.NodeAddr}}'):2377"
    else
        error "Failed to get worker join token"
    fi
}

create_networks() {
    log "Creating overlay networks..."
    
    # Create external network for Traefik
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        docker network create \
            --driver overlay \
            --attachable \
            "$NETWORK_NAME"
        success "Created network: $NETWORK_NAME"
    else
        warn "Network $NETWORK_NAME already exists"
    fi
    
    # Create other application networks
    local networks=("frontend" "backend" "database" "monitoring" "logging")
    
    for net in "${networks[@]}"; do
        if ! docker network ls | grep -q "$net"; then
            docker network create \
                --driver overlay \
                --attachable \
                "$net"
            success "Created network: $net"
        else
            warn "Network $net already exists"
        fi
    done
}

create_secrets() {
    log "Creating secrets..."
    
    # Database password
    if ! docker secret ls | grep -q "db_password"; then
        echo "$(openssl rand -base64 32)" | docker secret create db_password -
        success "Created secret: db_password"
    else
        warn "Secret db_password already exists"
    fi
    
    # API key
    if ! docker secret ls | grep -q "api_key"; then
        echo "$(uuidgen)" | docker secret create api_key -
        success "Created secret: api_key"
    else
        warn "Secret api_key already exists"
    fi
}

create_configs() {
    log "Creating configs..."
    
    # Nginx config
    if ! docker config ls | grep -q "nginx_config"; then
        cat << 'EOF' | docker config create nginx_config -
events {
    worker_connections 1024;
}

http {
    upstream api {
        server api:8080;
    }
    
    server {
        listen 80;
        
        location /health {
            return 200 'healthy\n';
            add_header Content-Type text/plain;
        }
        
        location /api/ {
            proxy_pass http://api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ =404;
        }
    }
}
EOF
        success "Created config: nginx_config"
    else
        warn "Config nginx_config already exists"
    fi
    
    # App config
    if ! docker config ls | grep -q "app_config"; then
        cat << 'EOF' | docker config create app_config -
{
    "version": "1.0.0",
    "environment": "production",
    "features": {
        "caching": true,
        "logging": true,
        "metrics": true
    },
    "database": {
        "pool_size": 10,
        "timeout": 30
    }
}
EOF
        success "Created config: app_config"
    else
        warn "Config app_config already exists"
    fi
    
    # Prometheus config
    if ! docker config ls | grep -q "prometheus_config"; then
        cat << 'EOF' | docker config create prometheus_config -
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'swarm-nodes'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: nodes
    relabel_configs:
      - source_labels: [__meta_dockerswarm_node_address]
        target_label: __address__
        replacement: ${1}:9100
  
  - job_name: 'swarm-services'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: services
EOF
        success "Created config: prometheus_config"
    else
        warn "Config prometheus_config already exists"
    fi
    
    # Fluentd config
    if ! docker config ls | grep -q "fluentd_config"; then
        cat << 'EOF' | docker config create fluentd_config -
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match **>
  @type file
  path /var/log/fluentd/docker-logs
  append true
  time_slice_format %Y%m%d%H
  <format>
    @type json
  </format>
  <buffer time>
    timekey 3600
    timekey_wait 1m
    flush_mode interval
    flush_interval 10s
  </buffer>
</match>
EOF
        success "Created config: fluentd_config"
    else
        warn "Config fluentd_config already exists"
    fi
}

add_node_labels() {
    log "Adding node labels..."
    
    # Get current node ID
    NODE_ID=$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null)
    
    if [ -n "$NODE_ID" ]; then
        # Add labels to manager node
        docker node update --label-add zone=zone1 "$NODE_ID" 2>/dev/null || true
        docker node update --label-add storage=ssd "$NODE_ID" 2>/dev/null || true
        docker node update --label-add environment=production "$NODE_ID" 2>/dev/null || true
        success "Added labels to manager node"
    else
        warn "Could not get node ID"
    fi
}

show_cluster_info() {
    echo -e "\n${BLUE}=== Swarm Cluster Information ===${NC}"
    
    echo -e "\n${YELLOW}Nodes:${NC}"
    docker node ls 2>/dev/null || warn "Could not list nodes"
    
    echo -e "\n${YELLOW}Networks:${NC}"
    docker network ls --filter driver=overlay
    
    echo -e "\n${YELLOW}Secrets:${NC}"
    docker secret ls 2>/dev/null || warn "Could not list secrets"
    
    echo -e "\n${YELLOW}Configs:${NC}"
    docker config ls 2>/dev/null || warn "Could not list configs"
    
    echo -e "\n${YELLOW}Services:${NC}"
    docker service ls 2>/dev/null || echo "No services deployed yet"
}

deploy_stack() {
    if [ -f "docker-compose.yml" ]; then
        echo -e "\n${BLUE}=== Deploying Demo Stack ===${NC}"
        read -p "Would you like to deploy the demo stack? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Deploying stack..."
            docker stack deploy -c docker-compose.yml demo-app
            success "Stack deployed successfully"
            
            echo -e "\n${YELLOW}Services:${NC}"
            docker service ls
            
            echo -e "\n${YELLOW}Access URLs:${NC}"
            echo "- Application: http://localhost"
            echo "- Traefik Dashboard: http://localhost:8080"
            echo "- API Health: http://localhost/api/health"
        fi
    fi
}

show_helpful_commands() {
    echo -e "\n${BLUE}=== Helpful Commands ===${NC}"
    
    cat << 'EOF'

# View cluster status
docker node ls
docker service ls
docker stack ls

# Scale services
docker service scale demo-app_web=5
docker service scale demo-app_api=3

# View service details
docker service ps demo-app_web
docker service logs demo-app_web

# Deploy/update stack
docker stack deploy -c docker-compose.yml demo-app

# Remove stack
docker stack rm demo-app

# Join additional nodes (run on other machines)
# For managers:
EOF

    echo "docker swarm join --token $(docker swarm join-token manager -q 2>/dev/null) $(docker info --format '{{.Swarm.NodeAddr}}' 2>/dev/null):2377"
    
    echo "# For workers:"
    echo "docker swarm join --token $(docker swarm join-token worker -q 2>/dev/null) $(docker info --format '{{.Swarm.NodeAddr}}' 2>/dev/null):2377"
    
    cat << 'EOF'

# Leave swarm (on worker nodes)
docker swarm leave

# Leave swarm (on manager nodes)  
docker swarm leave --force

# Remove node (from manager)
docker node rm <node-name>
EOF
}

main() {
    echo -e "${BLUE}Docker Swarm Setup Script${NC}"
    echo "=========================="
    
    check_docker
    init_swarm
    create_networks
    create_secrets
    create_configs
    add_node_labels
    get_join_tokens
    show_cluster_info
    deploy_stack
    show_helpful_commands
    
    echo -e "\n${GREEN}Swarm cluster setup complete!${NC}"
}

# Handle script arguments
case "${1:-}" in
    "init")
        init_swarm
        ;;
    "networks")
        create_networks
        ;;
    "secrets")
        create_secrets
        ;;
    "configs")
        create_configs
        ;;
    "info")
        show_cluster_info
        ;;
    "tokens")
        get_join_tokens
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo "Commands:"
        echo "  init     - Initialize swarm cluster"
        echo "  networks - Create overlay networks"
        echo "  secrets  - Create secrets"
        echo "  configs  - Create configs"
        echo "  info     - Show cluster information"
        echo "  tokens   - Show join tokens"
        echo "  help     - Show this help message"
        echo ""
        echo "Run without arguments to perform full setup"
        ;;
    *)
        main
        ;;
esac