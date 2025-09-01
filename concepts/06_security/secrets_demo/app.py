# File Location: concepts/06_security/secrets_demo/app.py

import os
import logging
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor
import jwt
from datetime import datetime, timedelta
import hashlib

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecureSecretManager:
    """Secure secret management class"""
    
    @staticmethod
    def read_secret(secret_name, default=None):
        """Read secret from Docker secrets mount point"""
        secret_path = f"/run/secrets/{secret_name}"
        try:
            with open(secret_path, 'r') as f:
                secret = f.read().strip()
                logger.info(f"Successfully loaded secret: {secret_name}")
                return secret
        except FileNotFoundError:
            logger.warning(f"Secret not found: {secret_name}")
            # Fallback to environment variable (not recommended for production)
            return os.getenv(secret_name.upper(), default)
        except Exception as e:
            logger.error(f"Error reading secret {secret_name}: {e}")
            return default
    
    @staticmethod
    def mask_secret(secret, visible_chars=4):
        """Mask secret for logging purposes"""
        if not secret or len(secret) <= visible_chars:
            return "***"
        return secret[:visible_chars] + "***"

# Initialize secret manager
secret_manager = SecureSecretManager()

# Load secrets
DB_PASSWORD = secret_manager.read_secret('db_password')
API_KEY = secret_manager.read_secret('api_key')
JWT_SECRET = secret_manager.read_secret('jwt_secret')

# Validate required secrets
required_secrets = {'db_password': DB_PASSWORD, 'api_key': API_KEY, 'jwt_secret': JWT_SECRET}
missing_secrets = [name for name, value in required_secrets.items() if not value]

if missing_secrets:
    logger.error(f"Missing required secrets: {missing_secrets}")
else:
    logger.info("All required secrets loaded successfully")

# Database connection with secrets
def get_db_connection():
    """Get database connection using secrets"""
    try:
        conn = psycopg2.connect(
            host="database",
            database="secretsdb",
            user="dbuser",
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None

@app.route('/')
def home():
    return jsonify({
        'message': 'Secure App with Docker Secrets',
        'secrets_loaded': len([s for s in required_secrets.values() if s]),
        'missing_secrets': len(missing_secrets),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    db_status = "connected" if get_db_connection() else "failed"
    secrets_status = "ok" if not missing_secrets else "missing"
    
    return jsonify({
        'status': 'healthy' if db_status == "connected" and secrets_status == "ok" else 'unhealthy',
        'database': db_status,
        'secrets': secrets_status,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/token', methods=['POST'])
def generate_token():
    """Generate JWT token using secret"""
    if not JWT_SECRET:
        return jsonify({'error': 'JWT secret not available'}), 500
    
    data = request.get_json() or {}
    user_id = data.get('user_id', 'anonymous')
    
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(hours=1),
        'iat': datetime.utcnow()
    }
    
    token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
    
    return jsonify({
        'token': token,
        'expires_in': 3600,
        'user_id': user_id
    })

@app.route('/api/protected')
def protected():
    """Protected endpoint requiring API key"""
    auth_header = request.headers.get('Authorization')
    
    if not auth_header:
        return jsonify({'error': 'Authorization header required'}), 401
    
    try:
        scheme, token = auth_header.split(' ', 1)
        if scheme.lower() != 'bearer':
            return jsonify({'error': 'Invalid authorization scheme'}), 401
    except ValueError:
        return jsonify({'error': 'Invalid authorization format'}), 401
    
    if not API_KEY or token != API_KEY:
        return jsonify({'error': 'Invalid API key'}), 401
    
    return jsonify({
        'message': 'Access granted to protected resource',
        'user': 'authenticated',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/secrets/status')
def secrets_status():
    """Show status of loaded secrets (masked)"""
    status = {}
    
    for secret_name in ['db_password', 'api_key', 'jwt_secret']:
        secret_value = secret_manager.read_secret(secret_name)
        status[secret_name] = {
            'loaded': bool(secret_value),
            'length': len(secret_value) if secret_value else 0,
            'masked': secret_manager.mask_secret(secret_value) if secret_value else None
        }
    
    return jsonify({
        'secrets': status,
        'total_loaded': sum(1 for s in status.values() if s['loaded']),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/database/test')
def test_database():
    """Test database connection using secrets"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT version() as version, current_database() as database, current_user as user")
            result = cur.fetchone()
            
        conn.close()
        
        return jsonify({
            'database_info': dict(result),
            'connection': 'successful',
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Database test failed: {e}")
        return jsonify({'error': 'Database test failed'}), 500

if __name__ == '__main__':
    # Log secret status (masked) on startup
    logger.info("=== Secret Manager Status ===")
    for secret_name in ['db_password', 'api_key', 'jwt_secret']:
        secret_value = secret_manager.read_secret(secret_name)
        masked_value = secret_manager.mask_secret(secret_value)
        logger.info(f"{secret_name}: {'LOADED' if secret_value else 'MISSING'} ({masked_value})")
    
    app.run(host='0.0.0.0', port=5000, debug=False)