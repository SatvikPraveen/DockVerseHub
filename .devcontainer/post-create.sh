#!/bin/bash
# File: .devcontainer/post-create.sh

set -e

echo "🐳 Setting up DockVerseHub Development Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set up Git configuration (if not already set)
if [ -z "$(git config --global user.name)" ]; then
    print_warning "Git user.name not set. Please configure it:"
    echo "  git config --global user.name 'Your Name'"
fi

if [ -z "$(git config --global user.email)" ]; then
    print_warning "Git user.email not set. Please configure it:"
    echo "  git config --global user.email 'your.email@example.com'"
fi

# Set up Git hooks directory
print_status "Setting up Git hooks..."
mkdir -p .git/hooks
chmod +x .git/hooks/* 2>/dev/null || true

# Install additional Python packages for development
print_status "Installing additional Python packages..."
pip3 install --user --no-warn-script-location \
    pre-commit \
    commitizen \
    docker-compose-viz \
    mkdocs-mermaid2-plugin \
    mkdocs-git-revision-date-localized-plugin

# Set up pre-commit hooks
print_status "Setting up pre-commit hooks..."
if [ -f ".pre-commit-config.yaml" ]; then
    pre-commit install
    print_status "Pre-commit hooks installed"
else
    print_warning "No .pre-commit-config.yaml found. Creating basic configuration..."
    cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
  
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker
        args: [--ignore, DL3008, --ignore, DL3009]

  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
EOF
    pre-commit install
fi

# Create useful aliases and functions
print_status "Setting up Docker aliases and functions..."
cat >> ~/.bashrc << 'EOF'

# Docker aliases and functions
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias di='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"'
alias dv='docker volume ls'
alias dn='docker network ls'
alias dc='docker-compose'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
alias dcb='docker-compose build'
alias dclogs='docker-compose logs -f'

# Docker cleanup functions
dcleanup() {
    echo "Cleaning up unused Docker resources..."
    docker system prune -f
    docker volume prune -f
    docker network prune -f
}

dnuke() {
    read -p "This will remove ALL containers, images, volumes, and networks. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker rmi $(docker images -q) 2>/dev/null || true
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        docker network rm $(docker network ls -q) 2>/dev/null || true
        echo "Docker environment nuked!"
    fi
}

# Container inspection functions
dinspect() {
    if [ $# -eq 0 ]; then
        echo "Usage: dinspect <container_name_or_id>"
        return 1
    fi
    docker inspect $1 | jq '.[0] | {Name, Image, State, NetworkSettings, Mounts}'
}

dlogs() {
    if [ $# -eq 0 ]; then
        echo "Usage: dlogs <container_name_or_id> [lines]"
        return 1
    fi
    local lines=${2:-100}
    docker logs --tail $lines -f $1
}

# Quick container exec
dexec() {
    if [ $# -eq 0 ]; then
        echo "Usage: dexec <container_name_or_id> [command]"
        return 1
    fi
    local cmd=${2:-/bin/bash}
    docker exec -it $1 $cmd
}

EOF

# Create development configuration files
print_status "Creating development configuration files..."

# Create Prometheus config
mkdir -p prometheus
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Create Grafana datasource config
mkdir -p grafana/datasources
cat > grafana/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus-dev:9090
    isDefault: true
EOF

# Create Grafana dashboards config
mkdir -p grafana/dashboards
cat > grafana/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create database initialization scripts
mkdir -p init-db
cat > init-db/01-init.sql << 'EOF'
-- Initialize development database
CREATE SCHEMA IF NOT EXISTS dockverse;

-- Create a sample table for demonstrations
CREATE TABLE IF NOT EXISTS dockverse.containers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    image VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO dockverse.containers (name, image, status) VALUES
('web-server', 'nginx:alpine', 'running'),
('database', 'postgres:15', 'running'),
('cache', 'redis:7-alpine', 'running');
EOF

mkdir -p mongo-init
cat > mongo-init/01-init.js << 'EOF'
// Initialize MongoDB development database
db = db.getSiblingDB('dockversehub');

// Create collections and insert sample data
db.containers.insertMany([
  {
    name: 'web-server',
    image: 'nginx:alpine',
    status: 'running',
    created: new Date()
  },
  {
    name: 'database',
    image: 'postgres:15',
    status: 'running',
    created: new Date()
  }
]);

print('Database initialized successfully');
EOF

# Set up useful VS Code workspace settings
print_status "Creating VS Code workspace settings..."
mkdir -p .vscode
cat > .vscode/settings.json << 'EOF'
{
  "docker.defaultRegistryPath": "docker.io",
  "docker.showStartPage": false,
  "files.associations": {
    "Dockerfile*": "dockerfile",
    "docker-compose*.yml": "yaml",
    "docker-compose*.yaml": "yaml"
  },
  "yaml.schemas": {
    "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json": [
      "docker-compose.yml",
      "docker-compose.yaml",
      "docker-compose.*.yml",
      "docker-compose.*.yaml"
    ]
  },
  "markdown.preview.fontSize": 14,
  "markdown.preview.lineHeight": 1.6,
  "markdownlint.config": {
    "MD013": false,
    "MD033": false
  }
}
EOF

# Create useful development scripts
print_status "Creating development scripts..."
mkdir -p scripts
cat > scripts/dev-setup.sh << 'EOF'
#!/bin/bash
# Development environment setup

set -e

echo "🚀 Starting DockVerseHub development environment..."

# Start all development services
docker-compose -f .devcontainer/docker-compose.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🔍 Checking service health..."
docker-compose -f .devcontainer/docker-compose.yml ps

echo "✅ Development environment is ready!"
echo "🌐 Access points:"
echo "  - Grafana: http://localhost:3001 (admin/admin)"
echo "  - Kibana: http://localhost:5601"
echo "  - Prometheus: http://localhost:9090"
echo "  - Elasticsearch: http://localhost:9200"

EOF

chmod +x scripts/dev-setup.sh

# Install Oh My Zsh themes and plugins if zsh is available
if command -v zsh &> /dev/null; then
    print_status "Setting up Zsh improvements..."
    
    # Add Docker aliases to zsh
    cat >> ~/.zshrc << 'EOF'

# Docker aliases and functions (same as bash)
source ~/.bashrc
EOF
fi

# Create a welcome message
print_status "Creating welcome message..."
cat > ~/.welcome.txt << 'EOF'
🐳 Welcome to DockVerseHub Development Environment!

Quick Start Commands:
├── dps              - List running containers
├── di               - List Docker images
├── dc up            - Start services with docker-compose
├── dcleanup         - Clean unused Docker resources
├── lazydocker       - Launch Docker TUI manager
├── ctop             - Container monitoring
└── dive <image>     - Analyze Docker image layers

Development Services:
├── PostgreSQL:      localhost:5432 (devuser/devpass)
├── Redis:           localhost:6379
├── Elasticsearch:   localhost:9200
├── Kibana:          localhost:5601
├── Prometheus:      localhost:9090
├── Grafana:         localhost:3001 (admin/admin)
└── MongoDB:         localhost:27017 (root/rootpass)

📚 Documentation: /workspace/docs/
🧪 Labs: /workspace/labs/
🔧 Utilities: /workspace/utilities/

Happy containerizing! 🚀
EOF

echo "cat ~/.welcome.txt" >> ~/.bashrc

# Set permissions
chmod +x prometheus/prometheus.yml 2>/dev/null || true

print_status "Development environment setup complete!"
print_status "Restart your terminal or run 'source ~/.bashrc' to load new aliases."

# Display welcome message
cat ~/.welcome.txt