-- =============================================================================
-- Normalized E-commerce Schema (3NF)
-- =============================================================================
-- Purpose: Demonstrates proper normalization techniques for transactional systems
-- Based on: mysql-instructions.md guidelines
-- Normalization Level: Third Normal Form (3NF)
-- =============================================================================

-- Customer information table
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique customer identifier',
    email VARCHAR(255) UNIQUE NOT NULL COMMENT 'Customer email address (unique)',
    first_name VARCHAR(100) NOT NULL COMMENT 'Customer first name',
    last_name VARCHAR(100) NOT NULL COMMENT 'Customer last name',
    phone VARCHAR(20) COMMENT 'Customer phone number',
    date_of_birth DATE COMMENT 'Customer date of birth',
    customer_status ENUM('active', 'inactive', 'suspended') DEFAULT 'active' COMMENT 'Customer account status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When customer was created',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for performance
    INDEX idx_email (email),
    INDEX idx_name (last_name, first_name),
    INDEX idx_status (customer_status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer master data';

-- Customer addresses (normalized - separate from customer)
CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique address identifier',
    customer_id INT NOT NULL COMMENT 'Reference to customer',
    address_type ENUM('billing', 'shipping', 'both') NOT NULL COMMENT 'Type of address',
    street_address VARCHAR(255) NOT NULL COMMENT 'Street address line 1',
    street_address_2 VARCHAR(255) COMMENT 'Street address line 2 (optional)',
    city VARCHAR(100) NOT NULL COMMENT 'City name',
    state VARCHAR(50) NOT NULL COMMENT 'State or province',
    postal_code VARCHAR(20) NOT NULL COMMENT 'Postal/ZIP code',
    country VARCHAR(50) NOT NULL DEFAULT 'US' COMMENT 'Country code',
    is_default BOOLEAN DEFAULT FALSE COMMENT 'Default address for this type',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    
    -- Indexes
    INDEX idx_customer_type (customer_id, address_type),
    INDEX idx_postal_code (postal_code),
    INDEX idx_city_state (city, state)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer addresses normalized from customer table';

-- Product categories (hierarchical structure)
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique category identifier',
    parent_category_id INT NULL COMMENT 'Parent category for hierarchy',
    category_name VARCHAR(100) NOT NULL COMMENT 'Category name',
    category_slug VARCHAR(100) NOT NULL UNIQUE COMMENT 'URL-friendly category name',
    description TEXT COMMENT 'Category description',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Whether category is active',
    sort_order INT DEFAULT 0 COMMENT 'Sort order for display',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Self-referencing foreign key for hierarchy
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_parent (parent_category_id),
    INDEX idx_slug (category_slug),
    INDEX idx_active_sort (is_active, sort_order)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Product category hierarchy';

-- Products table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique product identifier',
    category_id INT NOT NULL COMMENT 'Product category',
    sku VARCHAR(50) UNIQUE NOT NULL COMMENT 'Stock Keeping Unit (unique)',
    product_name VARCHAR(255) NOT NULL COMMENT 'Product name',
    product_slug VARCHAR(255) NOT NULL UNIQUE COMMENT 'URL-friendly product name',
    description TEXT COMMENT 'Product description',
    price DECIMAL(10,2) NOT NULL COMMENT 'Product price',
    cost DECIMAL(10,2) COMMENT 'Product cost (for margin calculation)',
    weight DECIMAL(8,3) COMMENT 'Product weight in kg',
    dimensions JSON COMMENT 'Product dimensions (length, width, height)',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Whether product is active',
    stock_quantity INT DEFAULT 0 COMMENT 'Current stock quantity',
    reorder_level INT DEFAULT 10 COMMENT 'Reorder level for inventory',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    
    -- Indexes
    INDEX idx_category (category_id),
    INDEX idx_sku (sku),
    INDEX idx_slug (product_slug),
    INDEX idx_active_price (is_active, price),
    INDEX idx_stock (stock_quantity)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Product master data';

-- Orders table
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique order identifier',
    customer_id INT NOT NULL COMMENT 'Customer who placed the order',
    order_number VARCHAR(50) UNIQUE NOT NULL COMMENT 'Human-readable order number',
    order_status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') 
        DEFAULT 'pending' COMMENT 'Current order status',
    billing_address_id INT NOT NULL COMMENT 'Billing address for this order',
    shipping_address_id INT NOT NULL COMMENT 'Shipping address for this order',
    subtotal DECIMAL(10,2) NOT NULL COMMENT 'Order subtotal (before tax/shipping)',
    tax_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Tax amount',
    shipping_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Shipping cost',
    discount_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Total discount amount',
    total_amount DECIMAL(10,2) NOT NULL COMMENT 'Final order total',
    payment_status ENUM('pending', 'paid', 'failed', 'refunded') DEFAULT 'pending' COMMENT 'Payment status',
    payment_method VARCHAR(50) COMMENT 'Payment method used',
    notes TEXT COMMENT 'Order notes',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When order was created',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id),
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id),
    
    -- Indexes
    INDEX idx_customer (customer_id),
    INDEX idx_order_number (order_number),
    INDEX idx_status (order_status),
    INDEX idx_payment_status (payment_status),
    INDEX idx_created_at (created_at),
    INDEX idx_total_amount (total_amount)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer orders';

-- Order items (normalized from orders)
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique order item identifier',
    order_id INT NOT NULL COMMENT 'Reference to parent order',
    product_id INT NOT NULL COMMENT 'Product being ordered',
    quantity INT NOT NULL COMMENT 'Quantity ordered',
    unit_price DECIMAL(10,2) NOT NULL COMMENT 'Price per unit at time of order',
    total_price DECIMAL(10,2) NOT NULL COMMENT 'Total price (quantity * unit_price)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    -- Indexes
    INDEX idx_order (order_id),
    INDEX idx_product (product_id),
    
    -- Ensure total_price calculation is correct
    CHECK (total_price = quantity * unit_price)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Individual items within orders';

-- Inventory tracking table
CREATE TABLE inventory_movements (
    movement_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique movement identifier',
    product_id INT NOT NULL COMMENT 'Product being moved',
    movement_type ENUM('in', 'out', 'adjustment') NOT NULL COMMENT 'Type of inventory movement',
    quantity INT NOT NULL COMMENT 'Quantity moved (positive for in, negative for out)',
    reference_type ENUM('purchase', 'sale', 'adjustment', 'damage', 'return') COMMENT 'Reason for movement',
    reference_id INT COMMENT 'ID of related record (order_id, etc.)',
    notes TEXT COMMENT 'Additional notes about the movement',
    movement_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When movement occurred',
    created_by VARCHAR(64) COMMENT 'User who created the movement',
    
    -- Foreign key constraints
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    
    -- Indexes
    INDEX idx_product_date (product_id, movement_date),
    INDEX idx_movement_type (movement_type),
    INDEX idx_reference (reference_type, reference_id)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Inventory movement tracking';

-- View for current product inventory
CREATE VIEW product_inventory AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.stock_quantity as system_stock,
    COALESCE(SUM(im.quantity), 0) as calculated_stock,
    p.reorder_level,
    CASE 
        WHEN COALESCE(SUM(im.quantity), 0) <= p.reorder_level THEN 'reorder'
        WHEN COALESCE(SUM(im.quantity), 0) <= 0 THEN 'out_of_stock'
        ELSE 'in_stock'
    END as stock_status
FROM products p
LEFT JOIN inventory_movements im ON p.product_id = im.product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.sku, p.product_name, p.stock_quantity, p.reorder_level
ORDER BY p.product_name;

-- Example data for testing
INSERT INTO categories (category_name, category_slug, description) VALUES 
('Electronics', 'electronics', 'Electronic devices and accessories'),
('Computers', 'computers', 'Desktop and laptop computers'),
('Smartphones', 'smartphones', 'Mobile phones and accessories'),
('Books', 'books', 'Physical and digital books');

-- Set up hierarchical relationships
UPDATE categories SET parent_category_id = (SELECT category_id FROM (SELECT * FROM categories) AS c WHERE c.category_slug = 'electronics') 
WHERE category_slug IN ('computers', 'smartphones');

INSERT INTO customers (email, first_name, last_name, phone) VALUES
('john.doe@example.com', 'John', 'Doe', '+1-555-0123'),
('jane.smith@example.com', 'Jane', 'Smith', '+1-555-0124'),
('admin@example.com', 'Admin', 'User', '+1-555-0100');