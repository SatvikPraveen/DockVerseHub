# File Location: labs/lab_05_microservices_demo/user-service/tests/test_user_api.py

import pytest
import json
from app import app, db, User, UserProfile

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            yield client
            db.drop_all()

@pytest.fixture
def sample_user():
    return {
        'email': 'test@example.com',
        'username': 'testuser',
        'password': 'password123'
    }

def test_health_check(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'status' in data
    assert data['service'] == 'user-service'

def test_user_registration(client, sample_user):
    response = client.post('/api/auth/register', 
                          json=sample_user,
                          content_type='application/json')
    assert response.status_code == 201
    data = json.loads(response.data)
    assert 'user_id' in data
    assert data['username'] == sample_user['username']

def test_user_login(client, sample_user):
    # First register user
    client.post('/api/auth/register', json=sample_user, content_type='application/json')
    
    # Then login
    login_data = {'email': sample_user['email'], 'password': sample_user['password']}
    response = client.post('/api/auth/login', json=login_data, content_type='application/json')
    
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'token' in data
    assert 'user' in data

def test_duplicate_registration(client, sample_user):
    # Register user first time
    client.post('/api/auth/register', json=sample_user, content_type='application/json')
    
    # Try to register same user again
    response = client.post('/api/auth/register', json=sample_user, content_type='application/json')
    assert response.status_code == 409

def test_invalid_login(client):
    login_data = {'email': 'nonexistent@example.com', 'password': 'wrongpassword'}
    response = client.post('/api/auth/login', json=login_data, content_type='application/json')
    assert response.status_code == 401