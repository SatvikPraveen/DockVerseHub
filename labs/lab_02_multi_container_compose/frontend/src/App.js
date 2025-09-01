// File Location: labs/lab_02_multi_container_compose/frontend/src/App.js

import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';

function App() {
  const [users, setUsers] = useState([]);
  const [newUser, setNewUser] = useState({ username: '', email: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [healthStatus, setHealthStatus] = useState({});

  // Fetch users on component mount
  useEffect(() => {
    fetchUsers();
    checkHealth();
    
    // Hide loading screen
    const loadingScreen = document.getElementById('loading-screen');
    if (loadingScreen) {
      setTimeout(() => {
        loadingScreen.style.display = 'none';
      }, 1000);
    }
  }, []);

  // Check API health
  const checkHealth = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/health`);
      setHealthStatus(response.data);
    } catch (err) {
      setHealthStatus({ status: 'unhealthy', error: err.message });
    }
  };

  // Fetch all users
  const fetchUsers = async () => {
    setLoading(true);
    setError('');
    
    try {
      const response = await axios.get(`${API_BASE_URL}/api/users`);
      setUsers(response.data.users || []);
    } catch (err) {
      setError('Failed to fetch users: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  // Create new user
  const createUser = async (e) => {
    e.preventDefault();
    
    if (!newUser.username || !newUser.email) {
      setError('Username and email are required');
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const response = await axios.post(`${API_BASE_URL}/api/users`, newUser);
      setUsers([...users, response.data.user]);
      setNewUser({ username: '', email: '' });
      setSuccess('User created successfully!');
      
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to create user: ' + (err.response?.data?.error || err.message));
    } finally {
      setLoading(false);
    }
  };

  // Delete user
  const deleteUser = async (userId) => {
    if (!window.confirm('Are you sure you want to delete this user?')) {
      return;
    }

    setLoading(true);
    setError('');

    try {
      await axios.delete(`${API_BASE_URL}/api/users/${userId}`);
      setUsers(users.filter(user => user.id !== userId));
      setSuccess('User deleted successfully!');
      
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to delete user: ' + (err.response?.data?.error || err.message));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <div className="container">
          <h1>🐳 DockVerseHub - Full Stack App</h1>
          <p>Multi-container application with Docker Compose</p>
          
          {/* Health Status */}
          <div className={`health-status ${healthStatus.status}`}>
            <strong>API Status:</strong> {healthStatus.status || 'checking...'}
            {healthStatus.services && (
              <div className="services-status">
                <small>
                  Database: {healthStatus.services.database} | 
                  Redis: {healthStatus.services.redis}
                </small>
              </div>
            )}
          </div>
        </div>
      </header>

      <main className="App-main">
        <div className="container">
          {/* Alerts */}
          {error && <div className="alert alert-error">{error}</div>}
          {success && <div className="alert alert-success">{success}</div>}

          {/* User Creation Form */}
          <section className="user-form-section">
            <h2>➕ Add New User</h2>
            <form onSubmit={createUser} className="user-form">
              <div className="form-group">
                <input
                  type="text"
                  placeholder="Username"
                  value={newUser.username}
                  onChange={(e) => setNewUser({...newUser, username: e.target.value})}
                  disabled={loading}
                />
              </div>
              <div className="form-group">
                <input
                  type="email"
                  placeholder="Email"
                  value={newUser.email}
                  onChange={(e) => setNewUser({...newUser, email: e.target.value})}
                  disabled={loading}
                />
              </div>
              <button type="submit" disabled={loading} className="btn-primary">
                {loading ? '⏳ Creating...' : '✨ Create User'}
              </button>
            </form>
          </section>

          {/* Users List */}
          <section className="users-section">
            <div className="section-header">
              <h2>👥 Users ({users.length})</h2>
              <button onClick={fetchUsers} disabled={loading} className="btn-refresh">
                {loading ? '⏳' : '🔄'} Refresh
              </button>
            </div>

            {loading && users.length === 0 ? (
              <div className="loading">Loading users...</div>
            ) : users.length === 0 ? (
              <div className="empty-state">
                <p>No users found. Create the first user above!</p>
              </div>
            ) : (
              <div className="users-grid">
                {users.map(user => (
                  <div key={user.id} className="user-card">
                    <div className="user-info">
                      <h3>{user.username}</h3>
                      <p>{user.email}</p>
                      <div className="user-meta">
                        <small>ID: {user.id}</small>
                        <small>Created: {new Date(user.created_at).toLocaleDateString()}</small>
                      </div>
                    </div>
                    <div className="user-actions">
                      <button 
                        onClick={() => deleteUser(user.id)}
                        disabled={loading}
                        className="btn-danger"
                        title="Delete user"
                      >
                        🗑️
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* API Information */}
          <section className="api-info">
            <h3>🔧 API Information</h3>
            <div className="info-grid">
              <div className="info-card">
                <h4>Available Endpoints</h4>
                <ul>
                  <li><code>GET /api/users</code> - List all users</li>
                  <li><code>POST /api/users</code> - Create user</li>
                  <li><code>DELETE /api/users/:id</code> - Delete user</li>
                  <li><code>GET /api/health</code> - Health check</li>
                  <li><code>GET /api/metrics</code> - Application metrics</li>
                </ul>
              </div>
              <div className="info-card">
                <h4>Technology Stack</h4>
                <ul>
                  <li>🐳 Docker & Docker Compose</li>
                  <li>⚛️ React 18 Frontend</li>
                  <li>🐍 Python Flask API</li>
                  <li>🐘 PostgreSQL Database</li>
                  <li>⚡ Redis Cache</li>
                  <li>🌐 Nginx Reverse Proxy</li>
                </ul>
              </div>
            </div>
          </section>
        </div>
      </main>

      <footer className="App-footer">
        <div className="container">
          <p>
            🎓 <strong>DockVerseHub Lab 02</strong> - Multi-Container Application Demo
          </p>
          <p>
            <a href="https://github.com/dockversehub" target="_blank" rel="noopener noreferrer">
              GitHub
            </a> | 
            <a href={`${API_BASE_URL}/api/health`} target="_blank" rel="noopener noreferrer">
              API Health
            </a>
          </p>
        </div>
      </footer>
    </div>
  );
}

export default App;