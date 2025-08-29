-- =============================================================================
-- Sample Data Initialization Script
-- =============================================================================
-- Purpose: Insert sample data for testing and demonstration
-- Based on: mysql-instructions.md schema examples
-- Usage: Run after schema creation to populate with test data
-- =============================================================================

-- Set session variables for audit tracking
SET @audit_user = 'data_init_script';
SET @audit_app = 'Sample_Data_Init';
SET @audit_session = 'init_20240101';

-- =============================================================================
-- 1. CATEGORIES DATA
-- =============================================================================

INSERT INTO categories (category_name, category_slug, description, parent_category_id, sort_order) VALUES
('Electronics', 'electronics', 'Electronic devices and accessories', NULL, 1),
('Computers', 'computers', 'Desktop and laptop computers', NULL, 2),
('Smartphones', 'smartphones', 'Mobile phones and accessories', NULL, 3),
('Books', 'books', 'Physical and digital books', NULL, 4),
('Clothing', 'clothing', 'Apparel and fashion items', NULL, 5),
('Home & Garden', 'home-garden', 'Home improvement and garden supplies', NULL, 6);

-- Create subcategories
INSERT INTO categories (category_name, category_slug, description, parent_category_id, sort_order) VALUES
('Laptops', 'laptops', 'Portable computers', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'computers'), 1),
('Desktops', 'desktops', 'Desktop computers', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'computers'), 2),
('Tablets', 'tablets', 'Tablet devices', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'electronics'), 1),
('Audio', 'audio', 'Audio equipment and accessories', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'electronics'), 2),
('iPhone', 'iphone', 'Apple iPhone devices', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'smartphones'), 1),
('Android', 'android', 'Android smartphones', (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'smartphones'), 2);

-- =============================================================================
-- 2. CUSTOMERS DATA
-- =============================================================================

INSERT INTO customers (email, first_name, last_name, phone, date_of_birth, customer_status) VALUES
('john.doe@example.com', 'John', 'Doe', '+1-555-0123', '1985-06-15', 'active'),
('jane.smith@example.com', 'Jane', 'Smith', '+1-555-0124', '1992-03-22', 'active'),
('bob.johnson@example.com', 'Bob', 'Johnson', '+1-555-0125', '1978-11-08', 'active'),
('alice.brown@example.com', 'Alice', 'Brown', '+1-555-0126', '1988-09-12', 'active'),
('charlie.wilson@example.com', 'Charlie', 'Wilson', '+1-555-0127', '1995-01-30', 'active'),
('diana.garcia@example.com', 'Diana', 'Garcia', '+1-555-0128', '1983-07-18', 'active'),
('edward.davis@example.com', 'Edward', 'Davis', '+1-555-0129', '1990-12-05', 'active'),
('fiona.miller@example.com', 'Fiona', 'Miller', '+1-555-0130', '1987-04-25', 'active'),
('george.taylor@example.com', 'George', 'Taylor', '+1-555-0131', '1982-10-14', 'active'),
('helen.martinez@example.com', 'Helen', 'Martinez', '+1-555-0132', '1994-08-07', 'active'),
('test.inactive@example.com', 'Test', 'Inactive', '+1-555-0199', '1980-01-01', 'inactive'),
('test.suspended@example.com', 'Test', 'Suspended', '+1-555-0198', '1980-01-01', 'suspended');

-- =============================================================================
-- 3. ADDRESSES DATA
-- =============================================================================

INSERT INTO addresses (customer_id, address_type, street_address, city, state, postal_code, country, is_default) VALUES
-- John Doe addresses
(1, 'billing', '123 Main Street', 'New York', 'NY', '10001', 'US', TRUE),
(1, 'shipping', '123 Main Street', 'New York', 'NY', '10001', 'US', TRUE),

-- Jane Smith addresses
(2, 'billing', '456 Oak Avenue', 'Los Angeles', 'CA', '90210', 'US', TRUE),
(2, 'shipping', '789 Pine Road', 'Los Angeles', 'CA', '90211', 'US', TRUE),

-- Bob Johnson addresses
(3, 'billing', '321 Elm Street', 'Chicago', 'IL', '60601', 'US', TRUE),
(3, 'shipping', '321 Elm Street', 'Chicago', 'IL', '60601', 'US', TRUE),

-- Alice Brown addresses
(4, 'billing', '654 Maple Drive', 'Houston', 'TX', '77001', 'US', TRUE),
(4, 'shipping', '654 Maple Drive', 'Houston', 'TX', '77001', 'US', TRUE),

-- Charlie Wilson addresses
(5, 'billing', '987 Cedar Lane', 'Phoenix', 'AZ', '85001', 'US', TRUE),
(5, 'shipping', '987 Cedar Lane', 'Phoenix', 'AZ', '85001', 'US', TRUE),

-- Diana Garcia addresses
(6, 'billing', '147 Birch Court', 'Philadelphia', 'PA', '19101', 'US', TRUE),
(6, 'shipping', '258 Willow Way', 'Philadelphia', 'PA', '19102', 'US', TRUE),

-- Edward Davis addresses
(7, 'billing', '369 Spruce Street', 'San Antonio', 'TX', '78201', 'US', TRUE),
(7, 'shipping', '369 Spruce Street', 'San Antonio', 'TX', '78201', 'US', TRUE),

-- Fiona Miller addresses
(8, 'billing', '741 Redwood Avenue', 'San Diego', 'CA', '92101', 'US', TRUE),
(8, 'shipping', '741 Redwood Avenue', 'San Diego', 'CA', '92101', 'US', TRUE),

-- George Taylor addresses
(9, 'billing', '852 Poplar Place', 'Dallas', 'TX', '75201', 'US', TRUE),
(9, 'shipping', '852 Poplar Place', 'Dallas', 'TX', '75201', 'US', TRUE),

-- Helen Martinez addresses
(10, 'billing', '963 Hickory Hill', 'San Jose', 'CA', '95101', 'US', TRUE),
(10, 'shipping', '963 Hickory Hill', 'San Jose', 'CA', '95101', 'US', TRUE);

-- =============================================================================
-- 4. PRODUCTS DATA
-- =============================================================================

INSERT INTO products (category_id, sku, product_name, product_slug, description, price, cost, weight, stock_quantity, reorder_level) VALUES
-- Laptops
((SELECT category_id FROM categories WHERE category_slug = 'laptops'), 'LAP-001', 'MacBook Pro 16"', 'macbook-pro-16', 'Apple MacBook Pro with M2 chip, 16GB RAM, 512GB SSD', 2499.00, 1800.00, 2.1, 15, 5),
((SELECT category_id FROM categories WHERE category_slug = 'laptops'), 'LAP-002', 'Dell XPS 15', 'dell-xps-15', 'Dell XPS 15 laptop with Intel i7, 16GB RAM, 1TB SSD', 1899.00, 1400.00, 2.0, 12, 5),
((SELECT category_id FROM categories WHERE category_slug = 'laptops'), 'LAP-003', 'HP Spectre x360', 'hp-spectre-x360', 'HP Spectre x360 convertible laptop, Intel i5, 8GB RAM', 1299.00, 950.00, 1.8, 8, 3),

-- Desktops
((SELECT category_id FROM categories WHERE category_slug = 'desktops'), 'DT-001', 'iMac 24"', 'imac-24', 'Apple iMac 24-inch with M1 chip, 8GB RAM, 256GB SSD', 1299.00, 950.00, 4.5, 10, 3),
((SELECT category_id FROM categories WHERE category_slug = 'desktops'), 'DT-002', 'HP Pavilion Desktop', 'hp-pavilion-desktop', 'HP Pavilion desktop with AMD Ryzen 5, 16GB RAM, 1TB HDD', 699.00, 500.00, 6.2, 15, 5),

-- Smartphones
((SELECT category_id FROM categories WHERE category_slug = 'iphone'), 'IP-001', 'iPhone 15 Pro', 'iphone-15-pro', 'Apple iPhone 15 Pro, 128GB, Titanium Natural', 999.00, 650.00, 0.187, 25, 10),
((SELECT category_id FROM categories WHERE category_slug = 'iphone'), 'IP-002', 'iPhone 15', 'iphone-15', 'Apple iPhone 15, 128GB, Pink', 799.00, 520.00, 0.171, 30, 10),
((SELECT category_id FROM categories WHERE category_slug = 'android'), 'AND-001', 'Samsung Galaxy S24', 'samsung-galaxy-s24', 'Samsung Galaxy S24, 256GB, Phantom Black', 899.00, 580.00, 0.168, 20, 8),
((SELECT category_id FROM categories WHERE category_slug = 'android'), 'AND-002', 'Google Pixel 8', 'google-pixel-8', 'Google Pixel 8, 128GB, Obsidian', 699.00, 450.00, 0.187, 18, 7),

-- Audio Equipment
((SELECT category_id FROM categories WHERE category_slug = 'audio'), 'AUD-001', 'AirPods Pro', 'airpods-pro', 'Apple AirPods Pro with Active Noise Cancellation', 249.00, 150.00, 0.056, 50, 20),
((SELECT category_id FROM categories WHERE category_slug = 'audio'), 'AUD-002', 'Sony WH-1000XM5', 'sony-wh-1000xm5', 'Sony WH-1000XM5 Wireless Noise Canceling Headphones', 399.00, 250.00, 0.254, 25, 10),
((SELECT category_id FROM categories WHERE category_slug = 'audio'), 'AUD-003', 'Bose SoundLink Flex', 'bose-soundlink-flex', 'Bose SoundLink Flex Bluetooth speaker', 149.00, 90.00, 0.58, 35, 15),

-- Tablets
((SELECT category_id FROM categories WHERE category_slug = 'tablets'), 'TAB-001', 'iPad Pro 12.9"', 'ipad-pro-12-9', 'Apple iPad Pro 12.9-inch with M2 chip, 128GB WiFi', 1099.00, 750.00, 0.682, 20, 8),
((SELECT category_id FROM categories WHERE category_slug = 'tablets'), 'TAB-002', 'Samsung Galaxy Tab S9', 'samsung-galaxy-tab-s9', 'Samsung Galaxy Tab S9, 128GB, Graphite', 799.00, 520.00, 0.498, 15, 6),

-- Books
((SELECT category_id FROM categories WHERE category_slug = 'books'), 'BOOK-001', 'Clean Code', 'clean-code', 'Clean Code: A Handbook of Agile Software Craftsmanship by Robert C. Martin', 35.99, 20.00, 0.7, 100, 25),
((SELECT category_id FROM categories WHERE category_slug = 'books'), 'BOOK-002', 'Design Patterns', 'design-patterns', 'Design Patterns: Elements of Reusable Object-Oriented Software', 42.99, 25.00, 0.8, 80, 20),
((SELECT category_id FROM categories WHERE category_slug = 'books'), 'BOOK-003', 'The Pragmatic Programmer', 'pragmatic-programmer', 'The Pragmatic Programmer: Your Journey to Mastery', 39.99, 22.00, 0.6, 75, 20);

-- =============================================================================
-- 5. ORDERS DATA
-- =============================================================================

-- Generate order numbers and insert orders
INSERT INTO orders (customer_id, order_number, order_status, billing_address_id, shipping_address_id, subtotal, tax_amount, shipping_amount, total_amount, payment_status, payment_method, created_at) VALUES
-- Recent orders (last 30 days)
(1, 'ORD-20240101-001', 'delivered', 1, 2, 2499.00, 199.92, 0.00, 2698.92, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(2, 'ORD-20240102-001', 'shipped', 3, 4, 1148.00, 91.84, 15.99, 1255.83, 'paid', 'paypal', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(3, 'ORD-20240103-001', 'processing', 5, 6, 699.00, 55.92, 9.99, 764.91, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 'ORD-20240104-001', 'delivered', 7, 8, 1299.00, 103.92, 0.00, 1402.92, 'paid', 'bank_transfer', DATE_SUB(NOW(), INTERVAL 7 DAY)),
(5, 'ORD-20240105-001', 'delivered', 9, 10, 249.00, 19.92, 5.99, 274.91, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 10 DAY)),

-- Older orders (for historical data)
(6, 'ORD-20231201-001', 'delivered', 11, 12, 1598.00, 127.84, 19.99, 1745.83, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 35 DAY)),
(7, 'ORD-20231115-001', 'delivered', 13, 14, 999.00, 79.92, 0.00, 1078.92, 'paid', 'paypal', DATE_SUB(NOW(), INTERVAL 50 DAY)),
(8, 'ORD-20231102-001', 'delivered', 15, 16, 799.00, 63.92, 12.99, 875.91, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 65 DAY)),
(9, 'ORD-20231020-001', 'delivered', 17, 18, 2897.99, 231.84, 0.00, 3129.83, 'paid', 'bank_transfer', DATE_SUB(NOW(), INTERVAL 80 DAY)),
(10, 'ORD-20231005-001', 'delivered', 19, 20, 149.00, 11.92, 7.99, 168.91, 'paid', 'credit_card', DATE_SUB(NOW(), INTERVAL 95 DAY)),

-- Mix of recent orders with different statuses
(1, 'ORD-20240106-001', 'pending', 1, 2, 399.00, 31.92, 9.99, 440.91, 'pending', 'credit_card', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(2, 'ORD-20240107-001', 'cancelled', 3, 4, 699.00, 55.92, 12.99, 767.91, 'refunded', 'paypal', DATE_SUB(NOW(), INTERVAL 6 HOUR));

-- =============================================================================
-- 6. ORDER ITEMS DATA
-- =============================================================================

-- Order 1: MacBook Pro
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(1, (SELECT product_id FROM products WHERE sku = 'LAP-001'), 1, 2499.00, 2499.00);

-- Order 2: Bose Speaker + AirPods Pro + Book
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(2, (SELECT product_id FROM products WHERE sku = 'AUD-003'), 1, 149.00, 149.00),
(2, (SELECT product_id FROM products WHERE sku = 'AUD-001'), 1, 249.00, 249.00),
(2, (SELECT product_id FROM products WHERE sku = 'BOOK-001'), 20, 35.99, 719.80),
(2, (SELECT product_id FROM products WHERE sku = 'BOOK-002'), 1, 42.99, 42.99);

-- Order 3: HP Desktop
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(3, (SELECT product_id FROM products WHERE sku = 'DT-002'), 1, 699.00, 699.00);

-- Order 4: iMac
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(4, (SELECT product_id FROM products WHERE sku = 'DT-001'), 1, 1299.00, 1299.00);

-- Order 5: AirPods Pro
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(5, (SELECT product_id FROM products WHERE sku = 'AUD-001'), 1, 249.00, 249.00);

-- Order 6: iPhone + Samsung Galaxy Tab
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(6, (SELECT product_id FROM products WHERE sku = 'IP-001'), 1, 999.00, 999.00),
(6, (SELECT product_id FROM products WHERE sku = 'TAB-002'), 1, 799.00, 799.00);

-- Order 7: iPhone 15
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(7, (SELECT product_id FROM products WHERE sku = 'IP-002'), 1, 799.00, 799.00);

-- Order 8: Samsung Galaxy S24
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(8, (SELECT product_id FROM products WHERE sku = 'AND-001'), 1, 899.00, 899.00);

-- Order 9: MacBook Pro + iPad Pro + Sony Headphones
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(9, (SELECT product_id FROM products WHERE sku = 'LAP-001'), 1, 2499.00, 2499.00),
(9, (SELECT product_id FROM products WHERE sku = 'TAB-001'), 1, 1099.00, 1099.00),
(9, (SELECT product_id FROM products WHERE sku = 'AUD-002'), 1, 399.00, 399.00);

-- Order 10: Bose Speaker
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(10, (SELECT product_id FROM products WHERE sku = 'AUD-003'), 1, 149.00, 149.00);

-- Order 11: Sony Headphones
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(11, (SELECT product_id FROM products WHERE sku = 'AUD-002'), 1, 399.00, 399.00);

-- Order 12: Google Pixel (cancelled order)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price) VALUES
(12, (SELECT product_id FROM products WHERE sku = 'AND-002'), 1, 699.00, 699.00);

-- =============================================================================
-- 7. INVENTORY MOVEMENTS DATA
-- =============================================================================

-- Initial stock entries
INSERT INTO inventory_movements (product_id, movement_type, quantity, reference_type, reference_id, notes, movement_date, created_by) VALUES
-- Stock receipts for all products
((SELECT product_id FROM products WHERE sku = 'LAP-001'), 'in', 15, 'purchase', 1001, 'Initial stock - MacBook Pro 16"', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'LAP-002'), 'in', 12, 'purchase', 1002, 'Initial stock - Dell XPS 15', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'LAP-003'), 'in', 8, 'purchase', 1003, 'Initial stock - HP Spectre x360', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'DT-001'), 'in', 10, 'purchase', 1004, 'Initial stock - iMac 24"', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'DT-002'), 'in', 15, 'purchase', 1005, 'Initial stock - HP Pavilion Desktop', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'IP-001'), 'in', 25, 'purchase', 1006, 'Initial stock - iPhone 15 Pro', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'IP-002'), 'in', 30, 'purchase', 1007, 'Initial stock - iPhone 15', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'AND-001'), 'in', 20, 'purchase', 1008, 'Initial stock - Samsung Galaxy S24', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'AND-002'), 'in', 18, 'purchase', 1009, 'Initial stock - Google Pixel 8', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'AUD-001'), 'in', 50, 'purchase', 1010, 'Initial stock - AirPods Pro', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'AUD-002'), 'in', 25, 'purchase', 1011, 'Initial stock - Sony WH-1000XM5', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'AUD-003'), 'in', 35, 'purchase', 1012, 'Initial stock - Bose SoundLink Flex', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'TAB-001'), 'in', 20, 'purchase', 1013, 'Initial stock - iPad Pro 12.9"', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'TAB-002'), 'in', 15, 'purchase', 1014, 'Initial stock - Samsung Galaxy Tab S9', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'BOOK-001'), 'in', 100, 'purchase', 1015, 'Initial stock - Clean Code book', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'BOOK-002'), 'in', 80, 'purchase', 1016, 'Initial stock - Design Patterns book', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager'),
((SELECT product_id FROM products WHERE sku = 'BOOK-003'), 'in', 75, 'purchase', 1017, 'Initial stock - Pragmatic Programmer book', DATE_SUB(NOW(), INTERVAL 30 DAY), 'inventory_manager');

-- Sales movements (out) corresponding to orders
INSERT INTO inventory_movements (product_id, movement_type, quantity, reference_type, reference_id, notes, movement_date, created_by) VALUES
-- Order 1: MacBook Pro
((SELECT product_id FROM products WHERE sku = 'LAP-001'), 'out', -1, 'sale', 1, 'Sold to customer - Order ORD-20240101-001', DATE_SUB(NOW(), INTERVAL 5 DAY), 'order_fulfillment'),

-- Order 2: Multiple items
((SELECT product_id FROM products WHERE sku = 'AUD-003'), 'out', -1, 'sale', 2, 'Sold to customer - Order ORD-20240102-001', DATE_SUB(NOW(), INTERVAL 3 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'AUD-001'), 'out', -1, 'sale', 2, 'Sold to customer - Order ORD-20240102-001', DATE_SUB(NOW(), INTERVAL 3 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'BOOK-001'), 'out', -20, 'sale', 2, 'Bulk sale - Order ORD-20240102-001', DATE_SUB(NOW(), INTERVAL 3 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'BOOK-002'), 'out', -1, 'sale', 2, 'Sold to customer - Order ORD-20240102-001', DATE_SUB(NOW(), INTERVAL 3 DAY), 'order_fulfillment'),

-- Order 3: HP Desktop
((SELECT product_id FROM products WHERE sku = 'DT-002'), 'out', -1, 'sale', 3, 'Sold to customer - Order ORD-20240103-001', DATE_SUB(NOW(), INTERVAL 2 DAY), 'order_fulfillment'),

-- Additional sales movements for other orders...
((SELECT product_id FROM products WHERE sku = 'DT-001'), 'out', -1, 'sale', 4, 'Sold to customer - Order ORD-20240104-001', DATE_SUB(NOW(), INTERVAL 7 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'AUD-001'), 'out', -1, 'sale', 5, 'Sold to customer - Order ORD-20240105-001', DATE_SUB(NOW(), INTERVAL 10 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'IP-001'), 'out', -1, 'sale', 6, 'Sold to customer - Order ORD-20231201-001', DATE_SUB(NOW(), INTERVAL 35 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'TAB-002'), 'out', -1, 'sale', 6, 'Sold to customer - Order ORD-20231201-001', DATE_SUB(NOW(), INTERVAL 35 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'IP-002'), 'out', -1, 'sale', 7, 'Sold to customer - Order ORD-20231115-001', DATE_SUB(NOW(), INTERVAL 50 DAY), 'order_fulfillment'),
((SELECT product_id FROM products WHERE sku = 'AND-001'), 'out', -1, 'sale', 8, 'Sold to customer - Order ORD-20231102-001', DATE_SUB(NOW(), INTERVAL 65 DAY), 'order_fulfillment');

-- =============================================================================
-- 8. AUDIT CONFIGURATION DATA
-- =============================================================================

-- Configure audit settings for main tables
INSERT INTO audit_config (table_name, excluded_columns, retention_days) VALUES
('customers', JSON_ARRAY('password_hash', 'remember_token'), 2555),
('orders', NULL, 2555),
('order_items', NULL, 1825),
('products', NULL, 1825),
('addresses', NULL, 2555),
('categories', NULL, 1825),
('inventory_movements', NULL, 1095),
('customer_order_summary', NULL, 365),
('daily_sales_summary', NULL, 1095),
('product_performance_summary', NULL, 730);

-- =============================================================================
-- DATA VERIFICATION QUERIES
-- =============================================================================

-- Verify data insertion
SELECT 'Categories' as table_name, COUNT(*) as record_count FROM categories
UNION ALL
SELECT 'Customers', COUNT(*) FROM customers
UNION ALL
SELECT 'Addresses', COUNT(*) FROM addresses  
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items', COUNT(*) FROM order_items
UNION ALL
SELECT 'Inventory Movements', COUNT(*) FROM inventory_movements
UNION ALL
SELECT 'Audit Config', COUNT(*) FROM audit_config;

-- Show sample of created data
SELECT 
    c.first_name,
    c.last_name,
    c.email,
    COUNT(o.order_id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
ORDER BY total_spent DESC;