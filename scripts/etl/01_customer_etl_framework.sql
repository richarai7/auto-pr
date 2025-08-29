-- ============================================================================
-- ETL Framework for Customer Data Processing
-- ============================================================================
-- This script demonstrates a comprehensive ETL (Extract, Transform, Load)
-- process for customer data using staging tables and stored procedures.
--
-- Author: MySQL Architecture Team
-- Version: 1.0
-- Last Updated: 2024
-- ============================================================================

-- Create staging schema for ETL operations
CREATE DATABASE IF NOT EXISTS staging 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE staging;

-- ============================================================================
-- Staging Tables
-- ============================================================================

-- Customer data staging table
CREATE TABLE IF NOT EXISTS customer_staging (
    staging_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique staging record ID',
    batch_id VARCHAR(50) NOT NULL COMMENT 'ETL batch identifier',
    source_system VARCHAR(50) NOT NULL COMMENT 'Source system identifier',
    
    -- Raw customer data
    source_customer_id VARCHAR(50) COMMENT 'Customer ID from source system',
    customer_username VARCHAR(50) COMMENT 'Username from source',
    customer_email VARCHAR(100) COMMENT 'Email from source',
    first_name VARCHAR(50) COMMENT 'First name from source',
    last_name VARCHAR(50) COMMENT 'Last name from source',
    phone VARCHAR(20) COMMENT 'Phone from source',
    date_of_birth VARCHAR(20) COMMENT 'DOB as string (needs parsing)',
    address_line1 VARCHAR(255) COMMENT 'Address line 1',
    address_line2 VARCHAR(255) COMMENT 'Address line 2',
    city VARCHAR(100) COMMENT 'City name',
    state VARCHAR(100) COMMENT 'State/province',
    postal_code VARCHAR(20) COMMENT 'Postal code',
    country VARCHAR(50) COMMENT 'Country name or code',
    
    -- Metadata
    raw_data JSON COMMENT 'Complete raw record in JSON format',
    
    -- Processing status
    status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT 'Processing status',
    processed_at TIMESTAMP NULL COMMENT 'When record was processed',
    error_message TEXT NULL COMMENT 'Error details if processing failed',
    target_user_id INT NULL COMMENT 'Target user_id after successful processing',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for ETL processing
    INDEX idx_batch_id (batch_id),
    INDEX idx_status (status),
    INDEX idx_source_system (source_system),
    INDEX idx_source_customer_id (source_customer_id),
    INDEX idx_processed_at (processed_at)
) ENGINE=InnoDB 
COMMENT='Staging table for customer data ETL processing';

-- Order data staging table
CREATE TABLE IF NOT EXISTS order_staging (
    staging_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique staging record ID',
    batch_id VARCHAR(50) NOT NULL COMMENT 'ETL batch identifier',
    source_system VARCHAR(50) NOT NULL COMMENT 'Source system identifier',
    
    -- Raw order data
    source_order_id VARCHAR(50) COMMENT 'Order ID from source system',
    source_customer_id VARCHAR(50) COMMENT 'Customer ID from source system',
    order_date VARCHAR(50) COMMENT 'Order date as string (needs parsing)',
    order_status VARCHAR(50) COMMENT 'Order status from source',
    payment_status VARCHAR(50) COMMENT 'Payment status from source',
    payment_method VARCHAR(50) COMMENT 'Payment method',
    
    -- Financial data (as strings for validation)
    subtotal_str VARCHAR(20) COMMENT 'Subtotal as string',
    tax_amount_str VARCHAR(20) COMMENT 'Tax amount as string',
    shipping_cost_str VARCHAR(20) COMMENT 'Shipping cost as string',
    discount_amount_str VARCHAR(20) COMMENT 'Discount amount as string',
    total_amount_str VARCHAR(20) COMMENT 'Total amount as string',
    
    -- Order details
    item_count_str VARCHAR(10) COMMENT 'Item count as string',
    currency_code VARCHAR(3) COMMENT 'Currency code',
    
    -- Metadata
    raw_data JSON COMMENT 'Complete raw record in JSON format',
    
    -- Processing status
    status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT 'Processing status',
    processed_at TIMESTAMP NULL COMMENT 'When record was processed',
    error_message TEXT NULL COMMENT 'Error details if processing failed',
    target_order_id INT NULL COMMENT 'Target order_id after successful processing',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for ETL processing
    INDEX idx_batch_id (batch_id),
    INDEX idx_status (status),
    INDEX idx_source_system (source_system),
    INDEX idx_source_order_id (source_order_id),
    INDEX idx_source_customer_id (source_customer_id),
    INDEX idx_processed_at (processed_at)
) ENGINE=InnoDB 
COMMENT='Staging table for order data ETL processing';

-- ============================================================================
-- ETL Control Tables
-- ============================================================================

-- ETL batch tracking table
CREATE TABLE IF NOT EXISTS etl_batch_log (
    batch_id VARCHAR(50) PRIMARY KEY COMMENT 'Unique batch identifier',
    batch_type ENUM('customer', 'order', 'product', 'full_sync') NOT NULL COMMENT 'Type of ETL batch',
    source_system VARCHAR(50) NOT NULL COMMENT 'Source system identifier',
    
    -- Batch metrics
    total_records INT DEFAULT 0 COMMENT 'Total records in batch',
    processed_records INT DEFAULT 0 COMMENT 'Successfully processed records',
    failed_records INT DEFAULT 0 COMMENT 'Failed records',
    skipped_records INT DEFAULT 0 COMMENT 'Skipped records',
    
    -- Timing
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Batch start time',
    completed_at TIMESTAMP NULL COMMENT 'Batch completion time',
    duration_seconds INT NULL COMMENT 'Batch duration in seconds',
    
    -- Status
    status ENUM('running', 'completed', 'failed', 'cancelled') DEFAULT 'running' COMMENT 'Batch status',
    error_message TEXT NULL COMMENT 'Error details if batch failed',
    
    -- Configuration
    config_json JSON COMMENT 'ETL configuration parameters',
    
    INDEX idx_batch_type (batch_type),
    INDEX idx_source_system (source_system),
    INDEX idx_status (status),
    INDEX idx_started_at (started_at)
) ENGINE=InnoDB 
COMMENT='ETL batch execution tracking and metrics';

-- ============================================================================
-- ETL Stored Procedures
-- ============================================================================

DELIMITER $$

-- Generate unique batch ID
CREATE FUNCTION IF NOT EXISTS generate_batch_id(p_batch_type VARCHAR(20))
RETURNS VARCHAR(50)
READS SQL DATA
DETERMINISTIC
BEGIN
    RETURN CONCAT(p_batch_type, '_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'), '_', CONNECTION_ID());
END$$

-- Validate email format
CREATE FUNCTION IF NOT EXISTS validate_email(p_email VARCHAR(100))
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    RETURN p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';
END$$

-- Convert string to decimal safely
CREATE FUNCTION IF NOT EXISTS safe_to_decimal(p_value VARCHAR(20), p_default DECIMAL(10,2))
RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_result DECIMAL(10,2) DEFAULT p_default;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_result = p_default;
    
    IF p_value IS NOT NULL AND TRIM(p_value) != '' THEN
        SET v_result = CAST(REPLACE(REPLACE(p_value, '$', ''), ',', '') AS DECIMAL(10,2));
    END IF;
    
    RETURN v_result;
END$$

-- Process customer staging records
CREATE PROCEDURE IF NOT EXISTS process_customer_batch(IN p_batch_id VARCHAR(50))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_staging_id INT;
    DECLARE v_target_user_id INT;
    DECLARE v_error_msg TEXT;
    DECLARE v_processed_count INT DEFAULT 0;
    DECLARE v_failed_count INT DEFAULT 0;
    
    -- Cursor for unprocessed customer records
    DECLARE customer_cursor CURSOR FOR 
        SELECT staging_id 
        FROM customer_staging 
        WHERE batch_id = p_batch_id 
        AND status = 'pending'
        ORDER BY staging_id;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Update batch status to running
    UPDATE etl_batch_log 
    SET status = 'running', 
        started_at = NOW() 
    WHERE batch_id = p_batch_id;
    
    OPEN customer_cursor;
    
    read_loop: LOOP
        FETCH customer_cursor INTO v_staging_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Process individual customer record
        SET v_error_msg = NULL;
        SET v_target_user_id = NULL;
        
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                GET DIAGNOSTICS CONDITION 1
                    v_error_msg = MESSAGE_TEXT;
                
                UPDATE customer_staging 
                SET status = 'failed',
                    error_message = v_error_msg,
                    processed_at = NOW()
                WHERE staging_id = v_staging_id;
                
                SET v_failed_count = v_failed_count + 1;
            END;
            
            -- Update staging record to processing
            UPDATE customer_staging 
            SET status = 'processing' 
            WHERE staging_id = v_staging_id;
            
            -- Call procedure to process individual customer
            CALL process_single_customer(v_staging_id, v_target_user_id, v_error_msg);
            
            IF v_error_msg IS NULL THEN
                -- Success
                UPDATE customer_staging 
                SET status = 'completed',
                    target_user_id = v_target_user_id,
                    processed_at = NOW()
                WHERE staging_id = v_staging_id;
                
                SET v_processed_count = v_processed_count + 1;
            ELSE
                -- Error occurred
                UPDATE customer_staging 
                SET status = 'failed',
                    error_message = v_error_msg,
                    processed_at = NOW()
                WHERE staging_id = v_staging_id;
                
                SET v_failed_count = v_failed_count + 1;
            END IF;
        END;
        
    END LOOP;
    
    CLOSE customer_cursor;
    
    -- Update batch completion
    UPDATE etl_batch_log 
    SET status = 'completed',
        processed_records = v_processed_count,
        failed_records = v_failed_count,
        completed_at = NOW(),
        duration_seconds = TIMESTAMPDIFF(SECOND, started_at, NOW())
    WHERE batch_id = p_batch_id;
    
    -- Log completion
    SELECT CONCAT('Batch ', p_batch_id, ' completed. Processed: ', v_processed_count, ', Failed: ', v_failed_count) AS result;
    
END$$

-- Process individual customer record
CREATE PROCEDURE IF NOT EXISTS process_single_customer(
    IN p_staging_id INT,
    OUT p_target_user_id INT,
    OUT p_error_msg TEXT
)
BEGIN
    DECLARE v_username VARCHAR(50);
    DECLARE v_email VARCHAR(100);
    DECLARE v_first_name VARCHAR(50);
    DECLARE v_last_name VARCHAR(50);
    DECLARE v_phone VARCHAR(20);
    DECLARE v_date_of_birth DATE;
    DECLARE v_existing_user_id INT DEFAULT NULL;
    
    -- Get staging data
    SELECT 
        customer_username,
        customer_email,
        first_name,
        last_name,
        phone,
        STR_TO_DATE(date_of_birth, '%Y-%m-%d')
    INTO 
        v_username,
        v_email,
        v_first_name,
        v_last_name,
        v_phone,
        v_date_of_birth
    FROM customer_staging
    WHERE staging_id = p_staging_id;
    
    -- Validate required fields
    IF v_username IS NULL OR TRIM(v_username) = '' THEN
        SET p_error_msg = 'Username is required';
        LEAVE sp;
    END IF;
    
    IF v_email IS NULL OR NOT validate_email(v_email) THEN
        SET p_error_msg = 'Valid email is required';
        LEAVE sp;
    END IF;
    
    -- Check for existing user
    SELECT user_id INTO v_existing_user_id
    FROM myapp.users
    WHERE username = v_username OR email = v_email
    LIMIT 1;
    
    IF v_existing_user_id IS NOT NULL THEN
        SET p_error_msg = 'User already exists with this username or email';
        SET p_target_user_id = v_existing_user_id;
        LEAVE sp;
    END IF;
    
    -- Insert new user
    INSERT INTO myapp.users (username, email, password_hash, email_verified)
    VALUES (v_username, v_email, '$2y$10$default.hash.for.imported.users', FALSE);
    
    SET p_target_user_id = LAST_INSERT_ID();
    
    -- Insert user profile
    INSERT INTO myapp.user_profiles (user_id, first_name, last_name, phone, date_of_birth)
    VALUES (p_target_user_id, v_first_name, v_last_name, v_phone, v_date_of_birth);
    
    -- Insert address if available
    IF EXISTS (
        SELECT 1 FROM customer_staging 
        WHERE staging_id = p_staging_id 
        AND (address_line1 IS NOT NULL OR city IS NOT NULL)
    ) THEN
        INSERT INTO myapp.user_addresses (
            user_id, address_type, address_line1, address_line2, 
            city, state_province, postal_code, country_code, is_default
        )
        SELECT 
            p_target_user_id,
            'home',
            address_line1,
            address_line2,
            city,
            state,
            postal_code,
            CASE 
                WHEN country IN ('US', 'USA', 'United States') THEN 'US'
                WHEN country IN ('CA', 'Canada') THEN 'CA'
                WHEN country IN ('GB', 'UK', 'United Kingdom') THEN 'GB'
                ELSE 'US'
            END,
            TRUE
        FROM customer_staging
        WHERE staging_id = p_staging_id;
    END IF;
    
    sp: BEGIN END;
    
END$$

-- Cleanup old staging data
CREATE PROCEDURE IF NOT EXISTS cleanup_staging_data(IN p_retention_days INT DEFAULT 30)
BEGIN
    DECLARE v_cutoff_date DATE;
    DECLARE v_deleted_customers BIGINT;
    DECLARE v_deleted_orders BIGINT;
    DECLARE v_deleted_batches BIGINT;
    
    SET v_cutoff_date = DATE_SUB(CURDATE(), INTERVAL p_retention_days DAY);
    
    -- Delete old customer staging records
    DELETE FROM customer_staging 
    WHERE created_at < v_cutoff_date 
    AND status IN ('completed', 'failed');
    GET DIAGNOSTICS v_deleted_customers = ROW_COUNT;
    
    -- Delete old order staging records
    DELETE FROM order_staging 
    WHERE created_at < v_cutoff_date 
    AND status IN ('completed', 'failed');
    GET DIAGNOSTICS v_deleted_orders = ROW_COUNT;
    
    -- Delete old batch logs
    DELETE FROM etl_batch_log 
    WHERE started_at < v_cutoff_date 
    AND status IN ('completed', 'failed', 'cancelled');
    GET DIAGNOSTICS v_deleted_batches = ROW_COUNT;
    
    SELECT 
        v_deleted_customers AS deleted_customer_records,
        v_deleted_orders AS deleted_order_records,
        v_deleted_batches AS deleted_batch_logs,
        v_cutoff_date AS cutoff_date;
        
END$$

DELIMITER ;

-- ============================================================================
-- ETL Views for Monitoring
-- ============================================================================

-- ETL batch summary view
CREATE VIEW IF NOT EXISTS v_etl_batch_summary AS
SELECT 
    b.batch_id,
    b.batch_type,
    b.source_system,
    b.status,
    b.total_records,
    b.processed_records,
    b.failed_records,
    b.skipped_records,
    ROUND((b.processed_records / NULLIF(b.total_records, 0)) * 100, 2) AS success_rate_pct,
    b.duration_seconds,
    b.started_at,
    b.completed_at,
    CASE 
        WHEN b.status = 'running' THEN TIMESTAMPDIFF(SECOND, b.started_at, NOW())
        ELSE b.duration_seconds
    END AS elapsed_seconds
FROM etl_batch_log b
ORDER BY b.started_at DESC;

-- Failed records view for troubleshooting
CREATE VIEW IF NOT EXISTS v_etl_failed_records AS
SELECT 
    'customer' AS record_type,
    c.batch_id,
    c.staging_id,
    c.source_customer_id AS source_id,
    c.customer_email AS identifier,
    c.error_message,
    c.processed_at,
    c.raw_data
FROM customer_staging c
WHERE c.status = 'failed'

UNION ALL

SELECT 
    'order' AS record_type,
    o.batch_id,
    o.staging_id,
    o.source_order_id AS source_id,
    o.source_customer_id AS identifier,
    o.error_message,
    o.processed_at,
    o.raw_data
FROM order_staging o
WHERE o.status = 'failed'

ORDER BY processed_at DESC;

-- ============================================================================
-- Sample ETL Process Usage
-- ============================================================================
/*
-- Example: Process a batch of customer data

-- 1. Start a new batch
SET @batch_id = generate_batch_id('customer');
INSERT INTO etl_batch_log (batch_id, batch_type, source_system, total_records)
VALUES (@batch_id, 'customer', 'legacy_crm', 0);

-- 2. Load data into staging (example)
INSERT INTO customer_staging (
    batch_id, source_system, source_customer_id, customer_username, 
    customer_email, first_name, last_name, phone, date_of_birth,
    address_line1, city, state, postal_code, country, raw_data
) VALUES 
(@batch_id, 'legacy_crm', 'CRM001', 'jsmith', 'john.smith@example.com', 
 'John', 'Smith', '555-1234', '1985-06-15',
 '123 Main St', 'Anytown', 'CA', '12345', 'US',
 JSON_OBJECT('import_date', NOW(), 'source', 'legacy_crm')),
(@batch_id, 'legacy_crm', 'CRM002', 'mjones', 'mary.jones@example.com',
 'Mary', 'Jones', '555-5678', '1990-03-22',
 '456 Oak Ave', 'Somewhere', 'NY', '67890', 'US',
 JSON_OBJECT('import_date', NOW(), 'source', 'legacy_crm'));

-- 3. Update total count
UPDATE etl_batch_log 
SET total_records = (
    SELECT COUNT(*) FROM customer_staging WHERE batch_id = @batch_id
)
WHERE batch_id = @batch_id;

-- 4. Process the batch
CALL process_customer_batch(@batch_id);

-- 5. Check results
SELECT * FROM v_etl_batch_summary WHERE batch_id = @batch_id;
SELECT * FROM v_etl_failed_records WHERE batch_id = @batch_id;

-- 6. Cleanup old data (run periodically)
CALL cleanup_staging_data(30);
*/