# File Location: labs/lab_02_multi_container_compose/api/tests/test_app.py

import pytest
import json
import os
from unittest.mock import patch, MagicMock
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app, db, User

@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['WTF_CSRF_ENABLED'] = False
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            yield client
            db.drop_all()

@pytest.fixture
def sample_user():
    """Create a sample user for testing"""
    return {
        'username': 'testuser',
        'email': 'test@example.com'
    }

class TestHealthEndpoint:
    """Test health check endpoint"""
    
    def test_health_check_success(self, client):
        """Test successful health check"""
        response = client.get('/api/health')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert 'status' in data
        assert 'timestamp' in data
        assert 'services' in data
        assert data['version'] == '1.0.0'

    @patch('app.redis_client')
    @patch('app.db')
    def test_health_check_with_service_failures(self, mock_db, mock_redis, client):
        """Test health check with service failures"""
        # Mock database failure
        mock_db.session.execute.side_effect = Exception('Database connection failed')
        
        # Mock Redis failure  
        mock_redis.ping.side_effect = Exception('Redis connection failed')
        
        response = client.get('/api/health')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['status'] == 'unhealthy'
        assert 'Database connection failed' in data['services']['database']
        assert 'Redis connection failed' in data['services']['redis']

class TestUserEndpoints:
    """Test user CRUD operations"""
    
    def test_get_users_empty(self, client):
        """Test getting users when database is empty"""
        response = client.get('/api/users')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['users'] == []
        assert data['count'] == 0
        assert data['status'] == 'success'

    def test_create_user_success(self, client, sample_user):
        """Test successful user creation"""
        response = client.post('/api/users', 
                             json=sample_user,
                             content_type='application/json')
        data = json.loads(response.data)
        
        assert response.status_code == 201
        assert data['status'] == 'success'
        assert data['user']['username'] == sample_user['username']
        assert data['user']['email'] == sample_user['email']
        assert 'id' in data['user']
        assert 'created_at' in data['user']

    def test_create_user_missing_data(self, client):
        """Test user creation with missing data"""
        response = client.post('/api/users',
                             json={'username': 'testuser'},
                             content_type='application/json')
        data = json.loads(response.data)
        
        assert response.status_code == 400
        assert data['status'] == 'error'
        assert 'required' in data['error'].lower()

    def test_create_user_duplicate(self, client, sample_user):
        """Test creating duplicate user"""
        # Create first user
        client.post('/api/users', json=sample_user, content_type='application/json')
        
        # Try to create duplicate
        response = client.post('/api/users', json=sample_user, content_type='application/json')
        data = json.loads(response.data)
        
        assert response.status_code == 409
        assert data['status'] == 'error'
        assert 'already exists' in data['error']

    def test_get_user_by_id_success(self, client, sample_user):
        """Test getting user by ID"""
        # Create user first
        create_response = client.post('/api/users', json=sample_user, content_type='application/json')
        created_user = json.loads(create_response.data)['user']
        
        # Get user by ID
        response = client.get(f'/api/users/{created_user["id"]}')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['status'] == 'success'
        assert data['user']['id'] == created_user['id']
        assert data['user']['username'] == sample_user['username']

    def test_get_user_by_id_not_found(self, client):
        """Test getting non-existent user"""
        response = client.get('/api/users/999')
        data = json.loads(response.data)
        
        assert response.status_code == 404
        assert data['status'] == 'error'
        assert 'not found' in data['error'].lower()

    def test_update_user_success(self, client, sample_user):
        """Test successful user update"""
        # Create user first
        create_response = client.post('/api/users', json=sample_user, content_type='application/json')
        created_user = json.loads(create_response.data)['user']
        
        # Update user
        update_data = {'username': 'updateduser', 'email': 'updated@example.com'}
        response = client.put(f'/api/users/{created_user["id"]}',
                            json=update_data,
                            content_type='application/json')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['status'] == 'success'
        assert data['user']['username'] == update_data['username']
        assert data['user']['email'] == update_data['email']

    def test_update_user_not_found(self, client):
        """Test updating non-existent user"""
        update_data = {'username': 'updateduser'}
        response = client.put('/api/users/999',
                            json=update_data,
                            content_type='application/json')
        data = json.loads(response.data)
        
        assert response.status_code == 404
        assert data['status'] == 'error'

    def test_delete_user_success(self, client, sample_user):
        """Test successful user deletion"""
        # Create user first
        create_response = client.post('/api/users', json=sample_user, content_type='application/json')
        created_user = json.loads(create_response.data)['user']
        
        # Delete user
        response = client.delete(f'/api/users/{created_user["id"]}')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['status'] == 'success'
        assert 'deleted successfully' in data['message']

    def test_delete_user_not_found(self, client):
        """Test deleting non-existent user"""
        response = client.delete('/api/users/999')
        data = json.loads(response.data)
        
        assert response.status_code == 404
        assert data['status'] == 'error'

class TestCacheIntegration:
    """Test Redis caching functionality"""
    
    @patch('app.redis_client')
    def test_cache_hit(self, mock_redis, client, sample_user):
        """Test cache hit scenario"""
        # Mock cache hit
        cached_data = json.dumps({
            'users': [{'id': 1, 'username': 'cached_user', 'email': 'cached@example.com'}],
            'count': 1,
            'status': 'success'
        })
        mock_redis.get.return_value = cached_data
        
        response = client.get('/api/users')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert len(data['users']) == 1
        assert data['users'][0]['username'] == 'cached_user'

    @patch('app.redis_client')
    def test_cache_miss(self, mock_redis, client, sample_user):
        """Test cache miss scenario"""
        # Mock cache miss
        mock_redis.get.return_value = None
        mock_redis.setex.return_value = True
        
        # Create a user first
        client.post('/api/users', json=sample_user, content_type='application/json')
        
        response = client.get('/api/users')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert len(data['users']) == 1
        # Verify cache was called
        mock_redis.setex.assert_called()

class TestMetricsEndpoint:
    """Test metrics endpoint"""
    
    def test_get_metrics_success(self, client, sample_user):
        """Test metrics endpoint"""
        # Create some users first
        client.post('/api/users', json=sample_user, content_type='application/json')
        client.post('/api/users', json={'username': 'user2', 'email': 'user2@example.com'}, content_type='application/json')
        
        response = client.get('/api/metrics')
        data = json.loads(response.data)
        
        assert response.status_code == 200
        assert data['status'] == 'success'
        assert 'metrics' in data
        assert data['metrics']['total_users'] == 2
        assert 'timestamp' in data

class TestErrorHandling:
    """Test error handling scenarios"""
    
    def test_404_error_handler(self, client):
        """Test 404 error handler"""
        response = client.get('/api/nonexistent')
        data = json.loads(response.data)
        
        assert response.status_code == 404
        assert data['status'] == 'error'
        assert 'not found' in data['error'].lower()

    def test_invalid_json(self, client):
        """Test invalid JSON handling"""
        response = client.post('/api/users',
                             data='invalid json',
                             content_type='application/json')
        
        assert response.status_code == 400

class TestDatabaseModels:
    """Test database model functionality"""
    
    def test_user_model_creation(self):
        """Test User model creation"""
        user = User(username='testuser', email='test@example.com')
        
        assert user.username == 'testuser'
        assert user.email == 'test@example.com'
        assert user.created_at is not None
        assert user.updated_at is not None

    def test_user_model_to_dict(self):
        """Test User model to_dict method"""
        user = User(username='testuser', email='test@example.com')
        user.id = 1
        
        user_dict = user.to_dict()
        
        assert user_dict['id'] == 1
        assert user_dict['username'] == 'testuser'
        assert user_dict['email'] == 'test@example.com'
        assert 'created_at' in user_dict
        assert 'updated_at' in user_dict

if __name__ == '__main__':
    pytest.main(['-v', __file__])