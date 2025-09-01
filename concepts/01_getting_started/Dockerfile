# File Location: concepts/01_getting_started/Dockerfile
# Minimal "hello world" container

FROM alpine:latest

# Install basic utilities
RUN apk add --no-cache \
    curl \
    wget \
    ca-certificates

# Create a simple script
RUN echo '#!/bin/sh' > /hello.sh && \
    echo 'echo "Hello from Docker!"' >> /hello.sh && \
    echo 'echo "Container ID: $(hostname)"' >> /hello.sh && \
    echo 'echo "Current time: $(date)"' >> /hello.sh && \
    echo 'echo "OS Info:"' >> /hello.sh && \
    echo 'cat /etc/os-release | head -5' >> /hello.sh && \
    chmod +x /hello.sh

# Set the default command
CMD ["/hello.sh"]