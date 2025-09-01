-- File Location: labs/lab_05_microservices_demo/database/postgres/init-order-db.sql

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table for reference
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_is_active ON products(is_active);

-- Insert sample products
INSERT INTO products (name, description, price, stock_quantity, category) VALUES 
('Docker T-Shirt', 'Official Docker branded t-shirt', 25.99, 100, 'apparel'),
('Kubernetes Mug', 'Coffee mug with Kubernetes logo', 15.99, 50, 'accessories'),
('DevOps Handbook', 'Essential guide to DevOps practices', 39.99, 25, 'books'),
('Container Stickers Pack', 'Set of container technology stickers', 9.99, 200, 'accessories')
ON CONFLICT DO NOTHING;