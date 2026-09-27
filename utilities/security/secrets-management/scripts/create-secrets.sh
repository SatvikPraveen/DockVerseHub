#!/bin/bash
# Create Docker secrets

set -e

echo "Creating Docker secrets..."

# SSL certificates
docker secret create ssl_cert ./secrets/ssl/cert.pem
docker secret create ssl_key ./secrets/ssl/key.pem

# Database password
echo "secure_db_password_$(openssl rand -hex 16)" | docker secret create db_password -

# API key
echo "api_$(openssl rand -hex 32)" | docker secret create api_key -

# Redis password
echo "redis_$(openssl rand -hex 16)" | docker secret create redis_password -

# Vault token
echo "hvs.$(openssl rand -hex 32)" | docker secret create vault_token -

# Backup encryption key
openssl rand -hex 32 | docker secret create backup_key -

echo "All secrets created successfully!"
