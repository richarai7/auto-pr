-- ============================================================================
-- Analytics Schema (Denormalized Design)
-- ============================================================================
-- This script creates denormalized tables optimized for analytical queries,
-- reporting, and business intelligence workloads.
--
-- Author: MySQL Architecture Team
-- Version: 1.0
-- Last Updated: 2024
-- ============================================================================

USE myapp;

-- ============================================================================
-- Orders Summary Table (Denormalized for Reporting)
-- ============================================================================
-- Combines data from multiple normalized tables for fast reporting queries
CREATE TABLE IF NOT EXISTS orders_summary (
    order_id INT PRIMARY KEY COMMENT 'Unique order identifier',
    customer_id INT NOT NULL COMMENT 'Customer identifier',
    
    -- Denormalized customer data
    customer_username VARCHAR(50) COMMENT 'Customer username',
    customer_email VARCHAR(100) COMMENT 'Customer email address',
    customer_first_name VARCHAR(50) COMMENT 'Customer first name',
    customer_last_name VARCHAR(50) COMMENT 'Customer last name',
    customer_full_name VARCHAR(101) COMMENT 'Customer full name (computed)',
    customer_phone VARCHAR(20) COMMENT 'Customer phone number',
    customer_city VARCHAR(100) COMMENT 'Customer city',
    customer_state VARCHAR(100) COMMENT 'Customer state/province',
    customer_country CHAR(2) COMMENT 'Customer country code',
    
    -- Order details
    order_date DATE NOT NULL COMMENT 'Date when order was placed',
    order_datetime TIMESTAMP NOT NULL COMMENT 'Exact timestamp of order',
    order_status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') NOT NULL COMMENT 'Current order status',
    payment_status ENUM('pending', 'paid', 'failed', 'refunded') NOT NULL COMMENT 'Payment status',
    payment_method VARCHAR(50) COMMENT 'Payment method used',
    
    -- Financial data
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Order subtotal before taxes',
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Tax amount',
    shipping_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Shipping cost',
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Total discount applied',
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Final order total',
    
    -- Order metrics
    item_count INT NOT NULL DEFAULT 0 COMMENT 'Total number of items in order',
    unique_product_count INT NOT NULL DEFAULT 0 COMMENT 'Number of unique products',
    total_weight DECIMAL(8,2) COMMENT 'Total weight of all items',
    
    -- Timing metrics
    processing_time_hours INT COMMENT 'Hours from order to processing',
    shipping_time_hours INT COMMENT 'Hours from processing to shipping',
    delivery_time_hours INT COMMENT 'Hours from shipping to delivery',
    total_fulfillment_hours INT COMMENT 'Total hours from order to delivery',
    
    -- Categorization for analytics
    order_size_category ENUM('small', 'medium', 'large', 'bulk') COMMENT 'Order size classification',
    customer_type ENUM('new', 'returning', 'vip', 'wholesale') COMMENT 'Customer type classification',
    sales_channel VARCHAR(50) COMMENT 'Channel where order originated',
    promotional_campaign VARCHAR(100) COMMENT 'Marketing campaign attribution',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes optimized for analytical queries
    INDEX idx_order_date (order_date),
    INDEX idx_customer_id (customer_id),
    INDEX idx_order_status (order_status),
    INDEX idx_payment_status (payment_status),
    INDEX idx_total_amount (total_amount),
    INDEX idx_customer_type (customer_type),
    INDEX idx_sales_channel (sales_channel),
    INDEX idx_order_size (order_size_category),
    INDEX idx_date_status (order_date, order_status),
    INDEX idx_customer_date (customer_id, order_date),
    INDEX idx_amount_range (total_amount, order_date),
    INDEX idx_fulfillment_metrics (processing_time_hours, shipping_time_hours, delivery_time_hours)
) ENGINE=InnoDB 
COMMENT='Denormalized order data optimized for analytical queries'
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- ============================================================================
-- Product Performance Summary (Denormalized)
-- ============================================================================
-- Product analytics with aggregated metrics for business intelligence
CREATE TABLE IF NOT EXISTS product_performance_summary (
    product_id INT PRIMARY KEY COMMENT 'Unique product identifier',
    
    -- Product details (denormalized)
    product_name VARCHAR(255) NOT NULL COMMENT 'Product name',
    product_sku VARCHAR(100) COMMENT 'Product SKU',
    product_category VARCHAR(100) COMMENT 'Product category',
    product_subcategory VARCHAR(100) COMMENT 'Product subcategory',
    product_brand VARCHAR(100) COMMENT 'Product brand',
    product_price DECIMAL(10,2) COMMENT 'Current product price',
    product_cost DECIMAL(10,2) COMMENT 'Product cost',
    product_margin DECIMAL(5,2) COMMENT 'Profit margin percentage',
    
    -- Sales metrics (last 30 days)
    sales_quantity_30d INT DEFAULT 0 COMMENT 'Units sold in last 30 days',
    sales_revenue_30d DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Revenue in last 30 days',
    orders_count_30d INT DEFAULT 0 COMMENT 'Number of orders in last 30 days',
    avg_order_quantity_30d DECIMAL(8,2) DEFAULT 0.00 COMMENT 'Average quantity per order',
    
    -- Sales metrics (last 90 days)
    sales_quantity_90d INT DEFAULT 0 COMMENT 'Units sold in last 90 days',
    sales_revenue_90d DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Revenue in last 90 days',
    orders_count_90d INT DEFAULT 0 COMMENT 'Number of orders in last 90 days',
    
    -- Sales metrics (year to date)
    sales_quantity_ytd INT DEFAULT 0 COMMENT 'Units sold year to date',
    sales_revenue_ytd DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Revenue year to date',
    orders_count_ytd INT DEFAULT 0 COMMENT 'Number of orders year to date',
    
    -- Performance metrics
    conversion_rate DECIMAL(5,2) COMMENT 'View to purchase conversion rate',
    return_rate DECIMAL(5,2) COMMENT 'Product return rate',
    review_count INT DEFAULT 0 COMMENT 'Number of customer reviews',
    average_rating DECIMAL(3,2) COMMENT 'Average customer rating',
    
    -- Inventory metrics
    current_stock INT DEFAULT 0 COMMENT 'Current stock level',
    stock_turnover_rate DECIMAL(5,2) COMMENT 'Inventory turnover rate',
    days_of_supply INT COMMENT 'Days of supply at current sales rate',
    
    -- Ranking and classification
    sales_rank_category INT COMMENT 'Sales rank within category',
    performance_tier ENUM('top', 'high', 'medium', 'low', 'discontinued') COMMENT 'Performance classification',
    is_bestseller BOOLEAN DEFAULT FALSE COMMENT 'Bestseller status',
    is_trending BOOLEAN DEFAULT FALSE COMMENT 'Trending product status',
    
    -- Timestamps
    data_as_of_date DATE NOT NULL COMMENT 'Date when metrics were calculated',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for analytical queries
    INDEX idx_category (product_category),
    INDEX idx_brand (product_brand),
    INDEX idx_performance_tier (performance_tier),
    INDEX idx_sales_revenue_30d (sales_revenue_30d DESC),
    INDEX idx_sales_quantity_30d (sales_quantity_30d DESC),
    INDEX idx_bestseller (is_bestseller),
    INDEX idx_trending (is_trending),
    INDEX idx_category_performance (product_category, performance_tier),
    INDEX idx_data_date (data_as_of_date)
) ENGINE=InnoDB 
COMMENT='Denormalized product performance metrics for analytics';

-- ============================================================================
-- Customer Analytics Summary (Denormalized)
-- ============================================================================
-- Customer behavior and value metrics for CRM and marketing analytics
CREATE TABLE IF NOT EXISTS customer_analytics_summary (
    customer_id INT PRIMARY KEY COMMENT 'Unique customer identifier',
    
    -- Customer details (denormalized)
    username VARCHAR(50) COMMENT 'Customer username',
    email VARCHAR(100) COMMENT 'Customer email',
    first_name VARCHAR(50) COMMENT 'Customer first name',
    last_name VARCHAR(50) COMMENT 'Customer last name',
    full_name VARCHAR(101) COMMENT 'Customer full name',
    registration_date DATE COMMENT 'Customer registration date',
    email_verified BOOLEAN DEFAULT FALSE COMMENT 'Email verification status',
    
    -- Geographic data
    primary_city VARCHAR(100) COMMENT 'Primary city',
    primary_state VARCHAR(100) COMMENT 'Primary state/province',
    primary_country CHAR(2) COMMENT 'Primary country code',
    
    -- Customer lifetime metrics
    total_orders INT DEFAULT 0 COMMENT 'Total number of orders placed',
    total_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total revenue from customer',
    average_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average order value',
    total_items_purchased INT DEFAULT 0 COMMENT 'Total items purchased',
    
    -- Recent activity metrics (last 30 days)
    orders_30d INT DEFAULT 0 COMMENT 'Orders in last 30 days',
    revenue_30d DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Revenue in last 30 days',
    
    -- Recent activity metrics (last 90 days)
    orders_90d INT DEFAULT 0 COMMENT 'Orders in last 90 days',
    revenue_90d DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Revenue in last 90 days',
    
    -- Behavioral metrics
    days_since_last_order INT COMMENT 'Days since last order',
    average_days_between_orders DECIMAL(8,2) COMMENT 'Average days between orders',
    purchase_frequency_score DECIMAL(5,2) COMMENT 'Purchase frequency score (1-10)',
    
    -- Customer value classification
    customer_segment ENUM('new', 'occasional', 'regular', 'loyal', 'vip', 'at_risk', 'inactive') COMMENT 'Customer segmentation',
    lifetime_value_tier ENUM('low', 'medium', 'high', 'premium') COMMENT 'Customer lifetime value tier',
    clv_score DECIMAL(12,2) COMMENT 'Customer lifetime value score',
    
    -- Engagement metrics
    product_categories_purchased INT DEFAULT 0 COMMENT 'Number of different categories purchased',
    brands_purchased INT DEFAULT 0 COMMENT 'Number of different brands purchased',
    review_count INT DEFAULT 0 COMMENT 'Number of reviews written',
    average_rating_given DECIMAL(3,2) COMMENT 'Average rating given by customer',
    
    -- Marketing metrics
    acquisition_channel VARCHAR(50) COMMENT 'Customer acquisition channel',
    last_campaign_interaction VARCHAR(100) COMMENT 'Last marketing campaign interaction',
    email_marketing_engaged BOOLEAN DEFAULT FALSE COMMENT 'Engages with email marketing',
    promotional_responsiveness DECIMAL(5,2) COMMENT 'Response rate to promotions',
    
    -- Risk indicators
    return_rate DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Order return rate',
    chargeback_count INT DEFAULT 0 COMMENT 'Number of chargebacks',
    fraud_risk_score DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Fraud risk score (0-10)',
    
    -- Timestamps
    data_as_of_date DATE NOT NULL COMMENT 'Date when metrics were calculated',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for segmentation and analysis
    INDEX idx_customer_segment (customer_segment),
    INDEX idx_lifetime_value_tier (lifetime_value_tier),
    INDEX idx_total_revenue (total_revenue DESC),
    INDEX idx_last_order_days (days_since_last_order),
    INDEX idx_acquisition_channel (acquisition_channel),
    INDEX idx_registration_date (registration_date),
    INDEX idx_geographic (primary_country, primary_state, primary_city),
    INDEX idx_segment_value (customer_segment, lifetime_value_tier),
    INDEX idx_data_date (data_as_of_date)
) ENGINE=InnoDB 
COMMENT='Denormalized customer analytics and segmentation data';

-- ============================================================================
-- Daily Sales Summary (Time-series data)
-- ============================================================================
-- Daily aggregated sales data for trend analysis and forecasting
CREATE TABLE IF NOT EXISTS daily_sales_summary (
    summary_date DATE PRIMARY KEY COMMENT 'Date of the sales summary',
    
    -- Order metrics
    total_orders INT DEFAULT 0 COMMENT 'Total orders placed',
    total_customers INT DEFAULT 0 COMMENT 'Unique customers who ordered',
    new_customers INT DEFAULT 0 COMMENT 'New customers acquired',
    returning_customers INT DEFAULT 0 COMMENT 'Returning customers',
    
    -- Financial metrics
    gross_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total gross revenue',
    net_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Net revenue after refunds',
    total_discounts DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Total discounts given',
    total_tax DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Total tax collected',
    total_shipping DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Total shipping charges',
    
    -- Product metrics
    total_items_sold INT DEFAULT 0 COMMENT 'Total items sold',
    unique_products_sold INT DEFAULT 0 COMMENT 'Unique products sold',
    average_items_per_order DECIMAL(8,2) DEFAULT 0.00 COMMENT 'Average items per order',
    average_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average order value',
    
    -- Conversion metrics
    website_visitors INT DEFAULT 0 COMMENT 'Website visitors (if tracked)',
    conversion_rate DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Visitor to order conversion rate',
    cart_abandonment_rate DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Shopping cart abandonment rate',
    
    -- Fulfillment metrics
    orders_shipped INT DEFAULT 0 COMMENT 'Orders shipped',
    orders_delivered INT DEFAULT 0 COMMENT 'Orders delivered',
    average_fulfillment_time DECIMAL(8,2) COMMENT 'Average fulfillment time in hours',
    
    -- Return metrics
    returns_processed INT DEFAULT 0 COMMENT 'Returns processed',
    return_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Value of returns',
    return_rate DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Return rate percentage',
    
    -- Day classification
    day_of_week ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday') COMMENT 'Day of the week',
    is_weekend BOOLEAN DEFAULT FALSE COMMENT 'Weekend indicator',
    is_holiday BOOLEAN DEFAULT FALSE COMMENT 'Holiday indicator',
    holiday_name VARCHAR(100) COMMENT 'Holiday name if applicable',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for time-series analysis
    INDEX idx_summary_date (summary_date),
    INDEX idx_day_of_week (day_of_week),
    INDEX idx_is_weekend (is_weekend),
    INDEX idx_is_holiday (is_holiday),
    INDEX idx_gross_revenue (gross_revenue),
    INDEX idx_total_orders (total_orders)
) ENGINE=InnoDB 
COMMENT='Daily aggregated sales metrics for trend analysis'
PARTITION BY RANGE (YEAR(summary_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- ============================================================================
-- Views for Common Analytics Queries
-- ============================================================================

-- Top customers by revenue (last 90 days)
CREATE VIEW IF NOT EXISTS v_top_customers_90d AS
SELECT 
    c.customer_id,
    c.full_name,
    c.email,
    c.customer_segment,
    c.revenue_90d,
    c.orders_90d,
    c.average_order_value,
    c.days_since_last_order
FROM customer_analytics_summary c
WHERE c.revenue_90d > 0
ORDER BY c.revenue_90d DESC
LIMIT 100;

-- Best selling products (last 30 days)
CREATE VIEW IF NOT EXISTS v_bestselling_products_30d AS
SELECT 
    p.product_id,
    p.product_name,
    p.product_category,
    p.product_brand,
    p.sales_quantity_30d,
    p.sales_revenue_30d,
    p.orders_count_30d,
    p.avg_order_quantity_30d,
    p.average_rating,
    p.performance_tier
FROM product_performance_summary p
WHERE p.sales_quantity_30d > 0
ORDER BY p.sales_revenue_30d DESC
LIMIT 50;

-- Sales trend (last 30 days)
CREATE VIEW IF NOT EXISTS v_sales_trend_30d AS
SELECT 
    summary_date,
    total_orders,
    gross_revenue,
    average_order_value,
    total_customers,
    conversion_rate,
    day_of_week,
    is_weekend
FROM daily_sales_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY summary_date DESC;