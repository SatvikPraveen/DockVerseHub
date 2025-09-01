# File: .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/base:bullseye

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER_BUILDKIT=1
ENV COMPOSE_DOCKER_CLI_BUILD=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    git \
    vim \
    nano \
    tree \
    jq \
    htop \
    unzip \
    zip \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    make \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (Docker-outside-of-Docker approach)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install additional Docker tools
RUN curl -L "https://github.com/docker/buildx/releases/latest/download/buildx-v$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | jq -r '.tag_name' | cut -d'v' -f2)-linux-$(dpkg --print-architecture)" -o ~/.docker/cli-plugins/docker-buildx \
    && chmod +x ~/.docker/cli-plugins/docker-buildx

# Install container security tools
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin \
    && wget -qO - https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 > /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint

# Install dive for image analysis
RUN wget -q https://github.com/wagoodman/dive/releases/latest/download/dive_$(curl -s https://api.github.com/repos/wagoodman/dive/releases/latest | jq -r '.tag_name' | cut -d'v' -f2)_linux_amd64.deb \
    && dpkg -i dive_*.deb \
    && rm dive_*.deb

# Install ctop for container monitoring
RUN wget -q https://github.com/bcicen/ctop/releases/latest/download/ctop-$(curl -s https://api.github.com/repos/bcicen/ctop/releases/latest | jq -r '.tag_name')-linux-amd64 -O /usr/local/bin/ctop \
    && chmod +x /usr/local/bin/ctop

# Install lazydocker for Docker management TUI
RUN curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Install Python packages for development
RUN pip3 install --no-cache-dir \
    docker \
    docker-compose \
    pyyaml \
    jinja2 \
    requests \
    black \
    flake8 \
    pylint \
    pytest \
    mkdocs \
    mkdocs-material

# Install Node.js packages for documentation and utilities
RUN npm install -g \
    markdownlint-cli \
    prettier \
    @mermaid-js/mermaid-cli \
    dockerfile-language-server-nodejs

# Create workspace directory
WORKDIR /workspace

# Set up shell improvements
RUN echo 'alias ll="ls -alF"' >> /home/vscode/.bashrc \
    && echo 'alias la="ls -A"' >> /home/vscode/.bashrc \
    && echo 'alias l="ls -CF"' >> /home/vscode/.bashrc \
    && echo 'alias dps="docker ps"' >> /home/vscode/.bashrc \
    && echo 'alias di="docker images"' >> /home/vscode/.bashrc \
    && echo 'alias dc="docker-compose"' >> /home/vscode/.bashrc \
    && echo 'alias dcu="docker-compose up"' >> /home/vscode/.bashrc \
    && echo 'alias dcd="docker-compose down"' >> /home/vscode/.bashrc \
    && echo 'alias dcb="docker-compose build"' >> /home/vscode/.bashrc \
    && echo 'alias dclogs="docker-compose logs -f"' >> /home/vscode/.bashrc

# Create directories for tools
RUN mkdir -p /home/vscode/.docker/cli-plugins \
    && chown -R vscode:vscode /home/vscode/.docker

# Copy post-create script
COPY post-create.sh /tmp/post-create.sh
RUN chmod +x /tmp/post-create.sh

# Switch to vscode user
USER vscode

# Set default shell to bash
SHELL ["/bin/bash", "-c"]