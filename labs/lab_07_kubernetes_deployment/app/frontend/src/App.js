import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [formData, setFormData] = useState({ name: '', email: '' });
  const [editingId, setEditingId] = useState(null);

  const apiBaseUrl = process.env.REACT_APP_API_BASE_URL || 'http://localhost:5000';

  // Fetch users on component mount
  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await fetch(`${apiBaseUrl}/api/users`);
      if (!response.ok) throw new Error('Failed to fetch users');
      const data = await response.json();
      setUsers(data.data || []);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name || !formData.email) {
      setError('Name and email are required');
      return;
    }

    try {
      const url = editingId 
        ? `${apiBaseUrl}/api/users/${editingId}`
        : `${apiBaseUrl}/api/users`;
      
      const method = editingId ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });

      if (!response.ok) throw new Error('Failed to save user');

      setFormData({ name: '', email: '' });
      setEditingId(null);
      fetchUsers();
      setError(null);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleEdit = (user) => {
    setFormData({ name: user.name, email: user.email });
    setEditingId(user.id);
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure?')) return;

    try {
      const response = await fetch(`${apiBaseUrl}/api/users/${id}`, {
        method: 'DELETE'
      });

      if (!response.ok) throw new Error('Failed to delete user');
      fetchUsers();
      setError(null);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleCancel = () => {
    setFormData({ name: '', email: '' });
    setEditingId(null);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Lab 07: Kubernetes User Manager</h1>
        <p>Running in: {process.env.NODE_ENV || 'production'}</p>
      </header>

      <main className="container">
        <section className="form-section">
          <h2>{editingId ? 'Edit User' : 'Add New User'}</h2>
          <form onSubmit={handleSubmit}>
            <input
              type="text"
              name="name"
              placeholder="User Name"
              value={formData.name}
              onChange={handleInputChange}
              required
            />
            <input
              type="email"
              name="email"
              placeholder="Email Address"
              value={formData.email}
              onChange={handleInputChange}
              required
            />
            <div className="button-group">
              <button type="submit" className="btn-primary">
                {editingId ? 'Update User' : 'Add User'}
              </button>
              {editingId && (
                <button 
                  type="button" 
                  className="btn-secondary"
                  onClick={handleCancel}
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </section>

        {error && <div className="error">{error}</div>}

        <section className="users-section">
          <h2>Users List</h2>
          {loading ? (
            <p>Loading...</p>
          ) : users.length === 0 ? (
            <p>No users found</p>
          ) : (
            <table className="users-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map(user => (
                  <tr key={user.id}>
                    <td>{user.id}</td>
                    <td>{user.name}</td>
                    <td>{user.email}</td>
                    <td>{new Date(user.created_at).toLocaleDateString()}</td>
                    <td>
                      <button 
                        className="btn-edit"
                        onClick={() => handleEdit(user)}
                      >
                        Edit
                      </button>
                      <button 
                        className="btn-delete"
                        onClick={() => handleDelete(user.id)}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      </main>
    </div>
  );
}

export default App;
