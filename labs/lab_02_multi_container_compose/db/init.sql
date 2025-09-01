-- File Location: labs/lab_02_multi_container_compose/db/init.sql

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS fullstack_app;

-- Connect to the database
\c fullstack_app;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Create function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data
INSERT INTO users (username, email) VALUES 
('john_doe', 'john@example.com'),
('jane_smith', 'jane@example.com'),
('bob_wilson', 'bob@example.com'),
('alice_brown', 'alice@example.com')
ON CONFLICT (username) DO NOTHING;

-- Create sessions table for future use
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for sessions
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

-- Create posts table for future use
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for posts
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_published ON posts(published);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at);

-- Create trigger for posts updated_at
DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample posts
INSERT INTO posts (user_id, title, content, published) VALUES 
((SELECT id FROM users WHERE username = 'john_doe'), 'My First Post', 'This is the content of my first post.', true),
((SELECT id FROM users WHERE username = 'jane_smith'), 'Hello World', 'Welcome to my blog!', true),
((SELECT id FROM users WHERE username = 'bob_wilson'), 'Docker Tutorial', 'Learning Docker with containers...', false)
ON CONFLICT DO NOTHING;

-- Create database statistics view
CREATE OR REPLACE VIEW database_stats AS
SELECT 
    'users' as table_name,
    COUNT(*) as row_count,
    MAX(created_at) as last_created
FROM users
UNION ALL
SELECT 
    'posts' as table_name,
    COUNT(*) as row_count,
    MAX(created_at) as last_created
FROM posts
UNION ALL
SELECT 
    'sessions' as table_name,
    COUNT(*) as row_count,
    MAX(created_at) as last_created
FROM sessions;

-- Grant privileges
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Create read-only user for reporting
CREATE USER IF NOT EXISTS readonly_user WITH ENCRYPTED PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE fullstack_app TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO readonly_user;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Database initialization completed successfully';
    RAISE NOTICE 'Users table: % rows', (SELECT COUNT(*) FROM users);
    RAISE NOTICE 'Posts table: % rows', (SELECT COUNT(*) FROM posts);
    RAISE NOTICE 'Sessions table: % rows', (SELECT COUNT(*) FROM sessions);
END
$$;