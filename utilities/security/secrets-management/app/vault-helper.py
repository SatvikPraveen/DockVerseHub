import hvac
import json
import os
from pathlib import Path

class VaultHelper:
    def __init__(self):
        self.vault_addr = os.getenv('VAULT_ADDR', 'http://vault:8200')
        self.client = hvac.Client(url=self.vault_addr)
        self.authenticate()
    
    def authenticate(self):
        """Authenticate with Vault using agent token"""
        token_path = Path('/vault/secrets/.vault-token')
        
        if token_path.exists():
            # Use token from Vault Agent
            token = token_path.read_text().strip()
            self.client.token = token
        else:
            # Fallback to AppRole authentication
            role_id = os.getenv('VAULT_ROLE_ID')
            secret_id = os.getenv('VAULT_SECRET_ID')
            
            if role_id and secret_id:
                auth_response = self.client.auth.approle.login(
                    role_id=role_id,
                    secret_id=secret_id
                )
                self.client.token = auth_response['auth']['client_token']
    
    def get_secret(self, path):
        """Get secret from Vault"""
        try:
            response = self.client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point='secret'
            )
            return response['data']['data']
        except Exception as e:
            print(f"Error reading secret {path}: {e}")
            return None
    
    def get_database_credentials(self):
        """Get dynamic database credentials"""
        try:
            response = self.client.secrets.database.generate_credentials(
                name='app-role'
            )
            return response['data']
        except Exception as e:
            print(f"Error getting database credentials: {e}")
            return None

# Usage example:
if __name__ == "__main__":
    vault = VaultHelper()
    
    # Get static secrets
    db_config = vault.get_secret('app/database')
    api_keys = vault.get_secret('app/api')
    
    # Get dynamic database credentials
    db_creds = vault.get_database_credentials()
    
    print("Secrets retrieved successfully!")

# Docker commands for usage:
#
# 1. Start Vault infrastructure:
#    docker-compose up -d vault consul
#
# 2. Initialize Vault:
#    docker-compose --profile init run vault-init
#
# 3. Start Vault Agent:
#    docker-compose up -d vault-agent
#
# 4. Start application:
#    docker-compose up -d app-with-vault
#
# 5. Access Vault UI:
#    http://localhost:8200
#
# 6. Rotate secrets:
#    docker-compose exec vault vault kv put secret/app/database password=new_password
#
# 7. Revoke all tokens:
#    docker-compose exec vault vault auth -method=userpass revoke-all
