-- =============================================================================
-- Denormalized Reporting Schema
-- =============================================================================
-- Purpose: Optimized denormalized tables for analytics and reporting
-- Based on: mysql-instructions.md guidelines
-- Use Case: Fast aggregations, dashboards, and business intelligence
-- =============================================================================

-- Customer order summary table (denormalized for reporting)
CREATE TABLE customer_order_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique summary record identifier',
    customer_id INT NOT NULL COMMENT 'Customer identifier',
    customer_email VARCHAR(255) NOT NULL COMMENT 'Customer email (denormalized)',
    customer_name VARCHAR(201) NOT NULL COMMENT 'Full customer name (first + last)',
    customer_phone VARCHAR(20) COMMENT 'Customer phone (denormalized)',
    customer_created_date DATE COMMENT 'When customer account was created',
    
    -- Order aggregates
    total_orders INT DEFAULT 0 COMMENT 'Total number of orders placed',
    total_spent DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total amount spent across all orders',
    avg_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average order value',
    min_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Smallest order value',
    max_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Largest order value',
    
    -- Temporal data
    first_order_date TIMESTAMP NULL COMMENT 'Date of first order',
    last_order_date TIMESTAMP NULL COMMENT 'Date of most recent order',
    days_since_last_order INT COMMENT 'Days since last order (for churn analysis)',
    
    -- Customer segmentation
    customer_segment ENUM('new', 'regular', 'vip', 'churned', 'at_risk') DEFAULT 'new' COMMENT 'Customer segment classification',
    lifetime_value_tier ENUM('low', 'medium', 'high', 'premium') DEFAULT 'low' COMMENT 'Customer value tier',
    
    -- Geographic data (denormalized)
    primary_shipping_city VARCHAR(100) COMMENT 'Most frequently used shipping city',
    primary_shipping_state VARCHAR(50) COMMENT 'Most frequently used shipping state',
    primary_shipping_country VARCHAR(50) COMMENT 'Most frequently used shipping country',
    
    -- Behavioral metrics
    favorite_category VARCHAR(100) COMMENT 'Most purchased product category',
    total_products_purchased INT DEFAULT 0 COMMENT 'Total number of individual products purchased',
    unique_products_purchased INT DEFAULT 0 COMMENT 'Number of unique products purchased',
    
    -- Update tracking
    last_calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When this summary was last calculated',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for reporting queries
    INDEX idx_customer_id (customer_id),
    INDEX idx_customer_segment (customer_segment),
    INDEX idx_lifetime_value_tier (lifetime_value_tier),
    INDEX idx_total_spent (total_spent),
    INDEX idx_last_order_date (last_order_date),
    INDEX idx_days_since_last_order (days_since_last_order),
    INDEX idx_total_orders (total_orders),
    INDEX idx_geographic (primary_shipping_state, primary_shipping_city),
    INDEX idx_customer_email (customer_email)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Denormalized customer summary for reporting and analytics';

-- Product performance summary (denormalized for analytics)
CREATE TABLE product_performance_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique summary record identifier',
    product_id INT NOT NULL COMMENT 'Product identifier',
    sku VARCHAR(50) NOT NULL COMMENT 'Product SKU (denormalized)',
    product_name VARCHAR(255) NOT NULL COMMENT 'Product name (denormalized)',
    category_name VARCHAR(100) COMMENT 'Category name (denormalized)',
    category_hierarchy VARCHAR(255) COMMENT 'Full category path (denormalized)',
    
    -- Sales metrics
    total_quantity_sold INT DEFAULT 0 COMMENT 'Total units sold',
    total_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total revenue generated',
    total_cost DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total cost of goods sold',
    total_profit DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total profit (revenue - cost)',
    profit_margin_percent DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Profit margin percentage',
    
    -- Order metrics
    total_orders INT DEFAULT 0 COMMENT 'Number of orders containing this product',
    unique_customers INT DEFAULT 0 COMMENT 'Number of unique customers who bought this product',
    avg_quantity_per_order DECIMAL(8,2) DEFAULT 0.00 COMMENT 'Average quantity per order',
    avg_revenue_per_order DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average revenue per order',
    
    -- Temporal metrics
    first_sale_date TIMESTAMP NULL COMMENT 'Date of first sale',
    last_sale_date TIMESTAMP NULL COMMENT 'Date of most recent sale',
    days_since_last_sale INT COMMENT 'Days since last sale',
    
    -- Performance categorization
    performance_tier ENUM('low', 'medium', 'high', 'top') DEFAULT 'low' COMMENT 'Performance tier based on sales',
    velocity_category ENUM('slow', 'normal', 'fast', 'very_fast') DEFAULT 'normal' COMMENT 'Sales velocity category',
    
    -- Current data (denormalized for quick access)
    current_price DECIMAL(10,2) COMMENT 'Current product price',
    current_stock INT COMMENT 'Current stock level',
    reorder_level INT COMMENT 'Reorder level',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Whether product is currently active',
    
    -- Time period for this summary
    summary_period_start DATE COMMENT 'Start date for this summary period',
    summary_period_end DATE COMMENT 'End date for this summary period',
    last_calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When this summary was calculated',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for reporting
    INDEX idx_product_id (product_id),
    INDEX idx_sku (sku),
    INDEX idx_category_name (category_name),
    INDEX idx_performance_tier (performance_tier),
    INDEX idx_velocity_category (velocity_category),
    INDEX idx_total_revenue (total_revenue DESC),
    INDEX idx_total_quantity_sold (total_quantity_sold DESC),
    INDEX idx_profit_margin (profit_margin_percent DESC),
    INDEX idx_last_sale_date (last_sale_date),
    INDEX idx_summary_period (summary_period_start, summary_period_end)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Denormalized product performance metrics for reporting';

-- Daily sales summary (time-based denormalized reporting)
CREATE TABLE daily_sales_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique daily summary identifier',
    summary_date DATE NOT NULL COMMENT 'Date for this summary',
    
    -- Order metrics
    total_orders INT DEFAULT 0 COMMENT 'Total orders placed',
    total_order_value DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total order value',
    avg_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average order value',
    median_order_value DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Median order value',
    
    -- Product metrics
    total_products_sold INT DEFAULT 0 COMMENT 'Total product units sold',
    unique_products_sold INT DEFAULT 0 COMMENT 'Number of unique products sold',
    
    -- Customer metrics
    total_customers INT DEFAULT 0 COMMENT 'Total customers who placed orders',
    new_customers INT DEFAULT 0 COMMENT 'New customers acquired',
    returning_customers INT DEFAULT 0 COMMENT 'Returning customers',
    
    -- Geographic breakdown (top locations)
    top_city VARCHAR(100) COMMENT 'City with most orders',
    top_city_orders INT DEFAULT 0 COMMENT 'Number of orders from top city',
    top_state VARCHAR(50) COMMENT 'State with most orders',
    top_state_orders INT DEFAULT 0 COMMENT 'Number of orders from top state',
    
    -- Category performance
    top_category VARCHAR(100) COMMENT 'Best performing category by revenue',
    top_category_revenue DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Revenue from top category',
    top_category_orders INT DEFAULT 0 COMMENT 'Orders containing top category products',
    
    -- Payment and status breakdown
    paid_orders INT DEFAULT 0 COMMENT 'Orders with completed payment',
    pending_orders INT DEFAULT 0 COMMENT 'Orders with pending payment',
    cancelled_orders INT DEFAULT 0 COMMENT 'Orders cancelled on this date',
    refunded_orders INT DEFAULT 0 COMMENT 'Orders refunded on this date',
    
    -- Operational metrics
    avg_processing_time_hours DECIMAL(8,2) COMMENT 'Average order processing time in hours',
    same_day_shipments INT DEFAULT 0 COMMENT 'Orders shipped same day',
    
    -- Day type classification
    day_of_week ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday') 
        COMMENT 'Day of the week',
    is_weekend BOOLEAN DEFAULT FALSE COMMENT 'Whether this is a weekend day',
    is_holiday BOOLEAN DEFAULT FALSE COMMENT 'Whether this is a holiday',
    
    -- Update tracking
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for time-series reporting
    UNIQUE INDEX idx_summary_date (summary_date),
    INDEX idx_day_of_week (day_of_week),
    INDEX idx_total_order_value (total_order_value DESC),
    INDEX idx_total_orders (total_orders DESC),
    INDEX idx_date_range (summary_date, total_order_value),
    INDEX idx_weekend_holiday (is_weekend, is_holiday)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Daily aggregated sales metrics for reporting dashboards';

-- Customer cohort analysis table (denormalized for retention analysis)
CREATE TABLE customer_cohort_analysis (
    cohort_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique cohort record identifier',
    cohort_month DATE NOT NULL COMMENT 'Month when customers first ordered (cohort identifier)',
    period_number INT NOT NULL COMMENT 'Number of months since cohort month (0 = acquisition month)',
    
    -- Cohort metrics
    customers_in_cohort INT DEFAULT 0 COMMENT 'Total customers in this cohort',
    active_customers INT DEFAULT 0 COMMENT 'Active customers in this period',
    retention_rate DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Retention rate for this period',
    
    -- Revenue metrics for the cohort
    total_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Total revenue from cohort in this period',
    avg_revenue_per_customer DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Average revenue per customer in cohort',
    cumulative_revenue DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Cumulative revenue from cohort',
    
    -- Order metrics
    total_orders INT DEFAULT 0 COMMENT 'Total orders from cohort in this period',
    avg_orders_per_customer DECIMAL(8,2) DEFAULT 0.00 COMMENT 'Average orders per customer',
    
    -- Customer lifecycle metrics
    new_customers_this_period INT DEFAULT 0 COMMENT 'New customers acquired in this period',
    churned_customers_this_period INT DEFAULT 0 COMMENT 'Customers who churned in this period',
    
    -- Update tracking
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When this cohort analysis was calculated',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for cohort analysis queries
    UNIQUE INDEX idx_cohort_period (cohort_month, period_number),
    INDEX idx_cohort_month (cohort_month),
    INDEX idx_period_number (period_number),
    INDEX idx_retention_rate (retention_rate DESC),
    INDEX idx_revenue_metrics (cohort_month, total_revenue)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Customer cohort analysis for retention and lifetime value tracking';

-- Views for common reporting queries

-- Customer segment distribution view
CREATE VIEW customer_segment_distribution AS
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_order_summary), 2) as percentage,
    AVG(total_spent) as avg_total_spent,
    AVG(total_orders) as avg_total_orders,
    AVG(days_since_last_order) as avg_days_since_last_order
FROM customer_order_summary
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- Monthly sales trend view
CREATE VIEW monthly_sales_trend AS
SELECT 
    DATE_FORMAT(summary_date, '%Y-%m') as month,
    SUM(total_orders) as monthly_orders,
    SUM(total_order_value) as monthly_revenue,
    AVG(avg_order_value) as avg_monthly_order_value,
    SUM(new_customers) as new_customers_acquired,
    AVG(total_customers) as avg_daily_customers
FROM daily_sales_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 24 MONTH)
GROUP BY DATE_FORMAT(summary_date, '%Y-%m')
ORDER BY month DESC;

-- Top performing products view
CREATE VIEW top_performing_products AS
SELECT 
    product_id,
    sku,
    product_name,
    category_name,
    total_quantity_sold,
    total_revenue,
    total_profit,
    profit_margin_percent,
    performance_tier,
    velocity_category,
    unique_customers,
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    RANK() OVER (ORDER BY total_quantity_sold DESC) as quantity_rank
FROM product_performance_summary
WHERE is_active = TRUE
ORDER BY total_revenue DESC;

-- Sample procedure to refresh denormalized tables
DELIMITER $$

CREATE PROCEDURE RefreshCustomerOrderSummary()
BEGIN
    -- Refresh customer order summary table
    TRUNCATE TABLE customer_order_summary;
    
    INSERT INTO customer_order_summary (
        customer_id,
        customer_email,
        customer_name,
        customer_phone,
        customer_created_date,
        total_orders,
        total_spent,
        avg_order_value,
        min_order_value,
        max_order_value,
        first_order_date,
        last_order_date,
        days_since_last_order,
        total_products_purchased,
        last_calculated_at
    )
    SELECT 
        c.customer_id,
        c.email,
        CONCAT(c.first_name, ' ', c.last_name),
        c.phone,
        DATE(c.created_at),
        COUNT(o.order_id),
        COALESCE(SUM(o.total_amount), 0),
        COALESCE(AVG(o.total_amount), 0),
        COALESCE(MIN(o.total_amount), 0),
        COALESCE(MAX(o.total_amount), 0),
        MIN(o.created_at),
        MAX(o.created_at),
        DATEDIFF(NOW(), MAX(o.created_at)),
        COALESCE(SUM(oi.quantity), 0),
        NOW()
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status NOT IN ('cancelled')
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.email, c.first_name, c.last_name, c.phone, c.created_at;
    
    -- Update customer segments based on business rules
    UPDATE customer_order_summary 
    SET customer_segment = CASE
        WHEN total_orders = 0 THEN 'new'
        WHEN days_since_last_order > 365 THEN 'churned'
        WHEN days_since_last_order > 180 THEN 'at_risk'
        WHEN total_spent > 5000 OR total_orders > 20 THEN 'vip'
        WHEN total_orders > 1 THEN 'regular'
        ELSE 'new'
    END;
    
    -- Update lifetime value tiers
    UPDATE customer_order_summary 
    SET lifetime_value_tier = CASE
        WHEN total_spent >= 10000 THEN 'premium'
        WHEN total_spent >= 2500 THEN 'high'
        WHEN total_spent >= 500 THEN 'medium'
        ELSE 'low'
    END;
END$$

DELIMITER ;