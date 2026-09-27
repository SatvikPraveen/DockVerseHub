#!/usr/bin/env python3
# Automated secret rotation service

import docker
import json
import time
import logging
import hashlib
import os
from datetime import datetime, timedelta

class SecretRotator:
    def __init__(self):
        self.client = docker.from_env()
        self.config = self.load_config()
        self.setup_logging()
        
    def load_config(self):
        """Load rotation configuration"""
        config_file = os.getenv('CONFIG_FILE', '/run/secrets/rotation_config')
        with open(config_file) as f:
            return json.load(f)
    
    def setup_logging(self):
        """Setup logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def generate_password(self, length=32):
        """Generate secure password"""
        import secrets
        import string
        
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def rotate_secret(self, secret_name, secret_config):
        """Rotate a specific secret"""
        try:
            self.logger.info(f"Rotating secret: {secret_name}")
            
            # Generate new secret value
            if secret_config['type'] == 'password':
                new_value = self.generate_password(secret_config.get('length', 32))
            elif secret_config['type'] == 'api_key':
                new_value = f"ak_{self.generate_password(48)}"
            else:
                self.logger.warning(f"Unknown secret type: {secret_config['type']}")
                return False
            
            # Create new secret
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            new_secret_name = f"{secret_name}_{timestamp}"
            
            self.client.secrets.create(
                name=new_secret_name,
                data=new_value.encode('utf-8'),
                labels={'rotated_from': secret_name, 'created': timestamp}
            )
            
            # Update services
            services_updated = []
            for service_name in secret_config.get('services', []):
                try:
                    service = self.client.services.get(service_name)
                    
                    # Update service secret
                    service.update(
                        secrets=[
                            docker.types.SecretReference(
                                secret_id=new_secret_name,
                                secret_name=secret_name
                            )
                        ]
                    )
                    services_updated.append(service_name)
                    self.logger.info(f"Updated service: {service_name}")
                    
                except Exception as e:
                    self.logger.error(f"Failed to update service {service_name}: {e}")
            
            # Wait for services to update
            time.sleep(60)
            
            # Remove old secret
            try:
                old_secret = self.client.secrets.get(secret_name)
                old_secret.remove()
                self.logger.info(f"Removed old secret: {secret_name}")
            except Exception as e:
                self.logger.warning(f"Could not remove old secret: {e}")
            
            self.logger.info(f"Successfully rotated secret: {secret_name}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to rotate secret {secret_name}: {e}")
            return False
    
    def should_rotate(self, secret_name, secret_config):
        """Check if secret should be rotated"""
        try:
            secret = self.client.secrets.get(secret_name)
            created_at = secret.attrs['CreatedAt']
            created_time = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            
            rotation_days = secret_config.get('rotation_days', 30)
            rotation_threshold = datetime.now() - timedelta(days=rotation_days)
            
            return created_time < rotation_threshold
            
        except Exception as e:
            self.logger.error(f"Could not check rotation status for {secret_name}: {e}")
            return False
    
    def run_rotation_cycle(self):
        """Run one rotation cycle"""
        self.logger.info("Starting secret rotation cycle")
        
        for secret_name, secret_config in self.config.get('secrets', {}).items():
            if secret_config.get('auto_rotate', False):
                if self.should_rotate(secret_name, secret_config):
                    self.rotate_secret(secret_name, secret_config)
                else:
                    self.logger.info(f"Secret {secret_name} does not need rotation")
    
    def run(self):
        """Run the rotation service"""
        self.logger.info("Starting secret rotation service")
        
        while True:
            try:
                self.run_rotation_cycle()
                
                # Sleep for configured interval
                interval = self.config.get('check_interval_hours', 24) * 3600
                self.logger.info(f"Sleeping for {interval} seconds")
                time.sleep(interval)
                
            except KeyboardInterrupt:
                self.logger.info("Received interrupt signal, shutting down")
                break
            except Exception as e:
                self.logger.error(f"Error in rotation cycle: {e}")
                time.sleep(300)  # Wait 5 minutes before retry

if __name__ == "__main__":
    rotator = SecretRotator()
    rotator.run()
