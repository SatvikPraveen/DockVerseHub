# File Location: labs/lab_05_microservices_demo/user-service/app.py

from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
import redis
import os
import datetime
import logging
from functools import wraps
import json
import requests

app = Flask(__name__)
CORS(app)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.getenv('JWT_SECRET', 'your-secret-key')
app.config['JWT_EXPIRATION_DELTA'] = datetime.timedelta(hours=24)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file upload

# Initialize extensions
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Redis connection for caching and sessions
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/0'), decode_responses=True)

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/user-service.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Import models
from models.user import User
from models.profile import UserProfile

# Jaeger tracing setup
JAEGER_ENDPOINT = os.getenv('JAEGER_ENDPOINT')

def create_span(operation_name, trace_id=None):
    """Simple span creation for tracing"""
    return {
        'operation_name': operation_name,
        'trace_id': trace_id or request.headers.get('X-Trace-Id'),
        'span_id': datetime.datetime.now().isoformat(),
        'start_time': datetime.datetime.now()
    }

def send_to_jaeger(span):
    """Send span data to Jaeger"""
    if JAEGER_ENDPOINT:
        try:
            requests.post(f"{JAEGER_ENDPOINT}/api/traces", json=span, timeout=1)
        except:
            pass  # Don't fail if tracing is unavailable

# Authentication decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        auth_header = request.headers.get('Authorization')
        
        if auth_header:
            try:
                token = auth_header.split(" ")[1]
            except IndexError:
                return jsonify({'message': 'Invalid token format'}), 401
        
        if not token:
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.filter_by(id=data['user_id']).first()
            
            if not current_user:
                return jsonify({'message': 'Invalid token'}), 401
                
            # Check if token is blacklisted
            if redis_client.get(f"blacklist:{token}"):
                return jsonify({'message': 'Token has been revoked'}), 401
                
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Routes
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    span = create_span('health_check')
    
    try:
        # Test database connection
        db.session.execute('SELECT 1')
        db_status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"
    
    try:
        # Test Redis connection
        redis_client.ping()
        redis_status = "healthy"
    except Exception as e:
        redis_status = f"unhealthy: {str(e)}"
    
    span['end_time'] = datetime.datetime.now()
    send_to_jaeger(span)
    
    return jsonify({
        'status': 'healthy' if db_status == 'healthy' and redis_status == 'healthy' else 'degraded',
        'service': 'user-service',
        'version': '1.0.0',
        'timestamp': datetime.datetime.utcnow().isoformat(),
        'dependencies': {
            'database': db_status,
            'redis': redis_status
        }
    })

@app.route('/api/auth/register', methods=['POST'])
def register():
    """User registration endpoint"""
    span = create_span('user_register')
    
    try:
        data = request.get_json()
        
        # Validate input
        if not data or not data.get('email') or not data.get('password') or not data.get('username'):
            return jsonify({'error': 'Email, username, and password are required'}), 400
        
        # Check if user already exists
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'error': 'Email already registered'}), 409
        
        if User.query.filter_by(username=data['username']).first():
            return jsonify({'error': 'Username already taken'}), 409
        
        # Create new user
        user = User(
            email=data['email'],
            username=data['username'],
            password_hash=generate_password_hash(data['password']),
            role=data.get('role', 'user')
        )
        
        db.session.add(user)
        db.session.commit()
        
        # Create user profile
        profile = UserProfile(
            user_id=user.id,
            first_name=data.get('first_name', ''),
            last_name=data.get('last_name', ''),
            phone=data.get('phone', '')
        )
        
        db.session.add(profile)
        db.session.commit()
        
        logger.info(f"New user registered: {user.email}")
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({
            'message': 'User registered successfully',
            'user_id': user.id,
            'username': user.username
        }), 201
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Registration error: {str(e)}")
        return jsonify({'error': 'Registration failed'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """User login endpoint"""
    span = create_span('user_login')
    
    try:
        data = request.get_json()
        
        if not data or not data.get('email') or not data.get('password'):
            return jsonify({'error': 'Email and password are required'}), 400
        
        user = User.query.filter_by(email=data['email']).first()
        
        if not user or not check_password_hash(user.password_hash, data['password']):
            logger.warning(f"Failed login attempt for email: {data['email']}")
            return jsonify({'error': 'Invalid credentials'}), 401
        
        if not user.is_active:
            return jsonify({'error': 'Account is deactivated'}), 401
        
        # Generate JWT token
        token_payload = {
            'user_id': user.id,
            'email': user.email,
            'username': user.username,
            'role': user.role,
            'exp': datetime.datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
        }
        
        token = jwt.encode(token_payload, app.config['SECRET_KEY'], algorithm='HS256')
        
        # Cache user session
        redis_client.setex(f"session:{user.id}", 86400, json.dumps({
            'user_id': user.id,
            'email': user.email,
            'role': user.role,
            'last_login': datetime.datetime.utcnow().isoformat()
        }))
        
        # Update last login
        user.last_login = datetime.datetime.utcnow()
        db.session.commit()
        
        logger.info(f"User logged in: {user.email}")
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({
            'token': token,
            'user': {
                'id': user.id,
                'email': user.email,
                'username': user.username,
                'role': user.role
            }
        })
        
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({'error': 'Login failed'}), 500

@app.route('/api/auth/logout', methods=['POST'])
@token_required
def logout(current_user):
    """User logout endpoint"""
    span = create_span('user_logout')
    
    try:
        token = request.headers.get('Authorization').split(" ")[1]
        
        # Add token to blacklist
        decoded_token = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        expires_in = decoded_token['exp'] - datetime.datetime.utcnow().timestamp()
        
        if expires_in > 0:
            redis_client.setex(f"blacklist:{token}", int(expires_in), "true")
        
        # Remove user session
        redis_client.delete(f"session:{current_user.id}")
        
        logger.info(f"User logged out: {current_user.email}")
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({'message': 'Logged out successfully'})
        
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return jsonify({'error': 'Logout failed'}), 500

@app.route('/api/users/me', methods=['GET'])
@token_required
def get_current_user(current_user):
    """Get current user information"""
    span = create_span('get_current_user')
    
    try:
        profile = UserProfile.query.filter_by(user_id=current_user.id).first()
        
        user_data = {
            'id': current_user.id,
            'email': current_user.email,
            'username': current_user.username,
            'role': current_user.role,
            'is_active': current_user.is_active,
            'created_at': current_user.created_at.isoformat(),
            'last_login': current_user.last_login.isoformat() if current_user.last_login else None,
            'profile': {
                'first_name': profile.first_name if profile else '',
                'last_name': profile.last_name if profile else '',
                'phone': profile.phone if profile else '',
                'avatar_url': profile.avatar_url if profile else None
            }
        }
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({'user': user_data})
        
    except Exception as e:
        logger.error(f"Get current user error: {str(e)}")
        return jsonify({'error': 'Failed to get user information'}), 500

@app.route('/api/users/<int:user_id>', methods=['GET'])
@token_required
def get_user(current_user, user_id):
    """Get user by ID"""
    span = create_span('get_user')
    
    try:
        # Check if user can access this information
        if current_user.id != user_id and current_user.role != 'admin':
            return jsonify({'error': 'Insufficient privileges'}), 403
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        profile = UserProfile.query.filter_by(user_id=user.id).first()
        
        user_data = {
            'id': user.id,
            'email': user.email,
            'username': user.username,
            'role': user.role,
            'is_active': user.is_active,
            'created_at': user.created_at.isoformat(),
            'profile': {
                'first_name': profile.first_name if profile else '',
                'last_name': profile.last_name if profile else '',
                'phone': profile.phone if profile else ''
            }
        }
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({'user': user_data})
        
    except Exception as e:
        logger.error(f"Get user error: {str(e)}")
        return jsonify({'error': 'Failed to get user information'}), 500

@app.route('/api/users/<int:user_id>', methods=['PUT'])
@token_required
def update_user(current_user, user_id):
    """Update user information"""
    span = create_span('update_user')
    
    try:
        # Check if user can update this information
        if current_user.id != user_id and current_user.role != 'admin':
            return jsonify({'error': 'Insufficient privileges'}), 403
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        
        # Update user fields
        if 'email' in data:
            if User.query.filter_by(email=data['email']).filter(User.id != user_id).first():
                return jsonify({'error': 'Email already in use'}), 409
            user.email = data['email']
        
        if 'username' in data:
            if User.query.filter_by(username=data['username']).filter(User.id != user_id).first():
                return jsonify({'error': 'Username already taken'}), 409
            user.username = data['username']
        
        if 'password' in data:
            user.password_hash = generate_password_hash(data['password'])
        
        db.session.commit()
        
        logger.info(f"User updated: {user.email}")
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({'message': 'User updated successfully'})
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Update user error: {str(e)}")
        return jsonify({'error': 'Failed to update user'}), 500

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
@token_required
def delete_user(current_user, user_id):
    """Delete user"""
    span = create_span('delete_user')
    
    try:
        # Only admins can delete users, or users can delete themselves
        if current_user.id != user_id and current_user.role != 'admin':
            return jsonify({'error': 'Insufficient privileges'}), 403
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Soft delete - deactivate account
        user.is_active = False
        db.session.commit()
        
        logger.info(f"User deleted: {user.email}")
        
        span['end_time'] = datetime.datetime.now()
        send_to_jaeger(span)
        
        return jsonify({'message': 'User deleted successfully'})
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Delete user error: {str(e)}")
        return jsonify({'error': 'Failed to delete user'}), 500

@app.errorhandler(404)
def not_found(error):
    """404 error handler"""
    return jsonify({'error': 'Resource not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    """500 error handler"""
    db.session.rollback()
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    print(f"Starting User Service on port {port}")
    print(f"Debug mode: {debug}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)