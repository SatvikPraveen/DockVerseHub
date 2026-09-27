#!/bin/bash
# Vault initialization script

set -e

export VAULT_ADDR=http://vault:8200

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status >/dev/null 2>&1; do
    echo "Vault is unavailable - sleeping"
    sleep 2
done

# Check if Vault is already initialized
if vault status | grep -q "Initialized.*true"; then
    echo "Vault is already initialized"
    exit 0
fi

echo "Initializing Vault..."

# Initialize Vault
vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > /vault/keys/init-keys.json

echo "Vault initialized successfully"

# Extract keys
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' /vault/keys/init-keys.json)
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' /vault/keys/init-keys.json)
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' /vault/keys/init-keys.json)
ROOT_TOKEN=$(jq -r '.root_token' /vault/keys/init-keys.json)

# Unseal Vault
echo "Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_2"
vault operator unseal "$UNSEAL_KEY_3"

# Login with root token
vault auth "$ROOT_TOKEN"

# Enable secrets engines
echo "Enabling secrets engines..."
vault secrets enable -path=secret kv-v2
vault secrets enable -path=database database
vault secrets enable -path=pki pki

# Enable auth methods
echo "Enabling authentication methods..."
vault auth enable approle
vault auth enable userpass

# Setup policies
echo "Setting up policies..."
vault policy write app-policy /scripts/app-policy.hcl
vault policy write admin-policy /scripts/admin-policy.hcl

# Create AppRole
echo "Creating AppRole..."
vault write auth/approle/role/app-role \
    token_policies="app-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    bind_secret_id=true

# Get role ID and create secret ID
ROLE_ID=$(vault read -field=role_id auth/approle/role/app-role/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/app-role/secret-id)

# Save credentials for agent
echo "$ROLE_ID" > /vault/keys/role-id
echo "$SECRET_ID" > /vault/keys/secret-id

# Setup some initial secrets
echo "Setting up initial secrets..."
vault kv put secret/app/database \
    host="db.company.com" \
    port="5432" \
    username="app_user" \
    password="secure_password_123"

vault kv put secret/app/api \
    stripe_key="sk_test_123456789" \
    sendgrid_key="SG.123456789" \
    jwt_secret="super_secret_jwt_key"

vault kv put secret/shared/config \
    environment="production" \
    debug="false" \
    log_level="info"

echo "Vault setup completed successfully!"
echo "Root token: $ROOT_TOKEN"
echo "Save this token securely and delete this output!"
