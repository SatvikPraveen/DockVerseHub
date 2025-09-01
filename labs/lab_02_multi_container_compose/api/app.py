# File Location: labs/lab_02_multi_container_compose/api/app.py

from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
import redis
import os
import logging
import datetime
from functools import wraps
import json

app = Flask(__name__)
CORS(app)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.getenv('API_SECRET_KEY', 'dev-secret-key')

# Initialize extensions
db = SQLAlchemy(app)
migrate = Migrate(app, db)

# Redis connection
redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
redis_client = redis.from_url(redis_url, decode_responses=True)

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Models
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }

# Cache decorator
def cache_result(timeout=300):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            cache_key = f"api:{f.__name__}:{hash(str(args) + str(kwargs))}"
            try:
                cached_result = redis_client.get(cache_key)
                if cached_result:
                    logger.info(f"Cache hit for {cache_key}")
                    return json.loads(cached_result)
            except Exception as e:
                logger.error(f"Redis error: {e}")
            
            result = f(*args, **kwargs)
            
            try:
                redis_client.setex(cache_key, timeout, json.dumps(result, default=str))
                logger.info(f"Cached result for {cache_key}")
            except Exception as e:
                logger.error(f"Redis caching error: {e}")
            
            return result
        return decorated_function
    return decorator

# Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
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
    
    return jsonify({
        'status': 'healthy' if db_status == 'healthy' and redis_status == 'healthy' else 'unhealthy',
        'timestamp': datetime.datetime.utcnow().isoformat(),
        'services': {
            'database': db_status,
            'redis': redis_status
        },
        'version': '1.0.0'
    })

@app.route('/api/users', methods=['GET'])
@cache_result(timeout=60)
def get_users():
    """Get all users"""
    try:
        users = User.query.all()
        return jsonify({
            'users': [user.to_dict() for user in users],
            'count': len(users),
            'status': 'success'
        })
    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        return jsonify({'error': str(e), 'status': 'error'}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('email'):
            return jsonify({'error': 'Username and email are required', 'status': 'error'}), 400
        
        # Check if user already exists
        existing_user = User.query.filter(
            (User.username == data['username']) | (User.email == data['email'])
        ).first()
        
        if existing_user:
            return jsonify({'error': 'User already exists', 'status': 'error'}), 409
        
        user = User(username=data['username'], email=data['email'])
        db.session.add(user)
        db.session.commit()
        
        # Clear cache
        try:
            keys = redis_client.keys("api:get_users:*")
            if keys:
                redis_client.delete(*keys)
        except Exception as e:
            logger.error(f"Error clearing cache: {e}")
        
        logger.info(f"Created user: {user.username}")
        return jsonify({
            'user': user.to_dict(),
            'status': 'success',
            'message': 'User created successfully'
        }), 201
        
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        db.session.rollback()
        return jsonify({'error': str(e), 'status': 'error'}), 500

@app.route('/api/users/<int:user_id>', methods=['GET'])
@cache_result(timeout=300)
def get_user(user_id):
    """Get user by ID"""
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found', 'status': 'error'}), 404
        
        return jsonify({
            'user': user.to_dict(),
            'status': 'success'
        })
    except Exception as e:
        logger.error(f"Error fetching user {user_id}: {e}")
        return jsonify({'error': str(e), 'status': 'error'}), 500

@app.route('/api/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update user"""
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found', 'status': 'error'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided', 'status': 'error'}), 400
        
        if 'username' in data:
            user.username = data['username']
        if 'email' in data:
            user.email = data['email']
        
        user.updated_at = datetime.datetime.utcnow()
        db.session.commit()
        
        # Clear cache
        try:
            keys = redis_client.keys("api:*")
            if keys:
                redis_client.delete(*keys)
        except Exception as e:
            logger.error(f"Error clearing cache: {e}")
        
        logger.info(f"Updated user: {user.username}")
        return jsonify({
            'user': user.to_dict(),
            'status': 'success',
            'message': 'User updated successfully'
        })
        
    except Exception as e:
        logger.error(f"Error updating user {user_id}: {e}")
        db.session.rollback()
        return jsonify({'error': str(e), 'status': 'error'}), 500

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Delete user"""
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({'error': 'User not found', 'status': 'error'}), 404
        
        username = user.username
        db.session.delete(user)
        db.session.commit()
        
        # Clear cache
        try:
            keys = redis_client.keys("api:*")
            if keys:
                redis_client.delete(*keys)
        except Exception as e:
            logger.error(f"Error clearing cache: {e}")
        
        logger.info(f"Deleted user: {username}")
        return jsonify({
            'status': 'success',
            'message': f'User {username} deleted successfully'
        })
        
    except Exception as e:
        logger.error(f"Error deleting user {user_id}: {e}")
        db.session.rollback()
        return jsonify({'error': str(e), 'status': 'error'}), 500

@app.route('/api/metrics', methods=['GET'])
def get_metrics():
    """Get application metrics"""
    try:
        user_count = User.query.count()
        
        # Get Redis info
        redis_info = {}
        try:
            redis_info = redis_client.info()
        except:
            redis_info = {'status': 'unavailable'}
        
        return jsonify({
            'metrics': {
                'total_users': user_count,
                'redis_connected_clients': redis_info.get('connected_clients', 0),
                'redis_used_memory': redis_info.get('used_memory_human', '0B'),
                'uptime': redis_info.get('uptime_in_seconds', 0)
            },
            'timestamp': datetime.datetime.utcnow().isoformat(),
            'status': 'success'
        })
    except Exception as e:
        logger.error(f"Error fetching metrics: {e}")
        return jsonify({'error': str(e), 'status': 'error'}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found', 'status': 'error'}), 404

@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return jsonify({'error': 'Internal server error', 'status': 'error'}), 500

# Create tables
@app.before_first_request
def create_tables():
    db.create_all()
    logger.info("Database tables created")

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    logger.info(f"Starting Flask API on port {port}")
    logger.info(f"Debug mode: {debug}")
    logger.info(f"Database URL: {os.getenv('DATABASE_URL')}")
    logger.info(f"Redis URL: {redis_url}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)