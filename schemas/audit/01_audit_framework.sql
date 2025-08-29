-- ============================================================================
-- Audit Logging Framework
-- ============================================================================
-- This script creates the foundational audit logging infrastructure
-- for tracking all database changes across the enterprise.
--
-- Author: MySQL Architecture Team
-- Version: 1.0
-- Last Updated: 2024
-- ============================================================================

-- Create audit database schema if it doesn't exist
CREATE DATABASE IF NOT EXISTS audit_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE audit_db;

-- ============================================================================
-- Main Audit Log Table
-- ============================================================================
-- Centralized table for capturing all database operations
-- Supports JSON storage for flexible data capture
CREATE TABLE IF NOT EXISTS audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique audit record identifier',
    table_name VARCHAR(64) NOT NULL COMMENT 'Name of the table being audited',
    schema_name VARCHAR(64) NOT NULL DEFAULT 'myapp' COMMENT 'Database schema name',
    operation_type ENUM('INSERT', 'UPDATE', 'DELETE', 'SELECT') NOT NULL COMMENT 'Type of database operation',
    primary_key_value VARCHAR(255) NOT NULL COMMENT 'Primary key value of affected record',
    old_values JSON COMMENT 'Original values before change (UPDATE/DELETE)',
    new_values JSON COMMENT 'New values after change (INSERT/UPDATE)',
    changed_by VARCHAR(64) NOT NULL COMMENT 'User who made the change',
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When the change occurred',
    ip_address VARCHAR(45) COMMENT 'IP address of the client',
    application VARCHAR(64) COMMENT 'Application that made the change',
    session_id VARCHAR(128) COMMENT 'Database session identifier',
    transaction_id VARCHAR(64) COMMENT 'Transaction identifier for grouping changes',
    
    -- Indexes for optimal query performance
    INDEX idx_table_operation (table_name, operation_type),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by),
    INDEX idx_schema_table (schema_name, table_name),
    INDEX idx_transaction_id (transaction_id)
) ENGINE=InnoDB 
COMMENT='Central audit log for tracking all database changes'
PARTITION BY RANGE (YEAR(changed_at)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- ============================================================================
-- Audit Configuration Table
-- ============================================================================
-- Controls which tables and operations are audited
CREATE TABLE IF NOT EXISTS audit_config (
    config_id INT AUTO_INCREMENT PRIMARY KEY,
    schema_name VARCHAR(64) NOT NULL,
    table_name VARCHAR(64) NOT NULL,
    audit_insert BOOLEAN DEFAULT TRUE,
    audit_update BOOLEAN DEFAULT TRUE,
    audit_delete BOOLEAN DEFAULT TRUE,
    audit_select BOOLEAN DEFAULT FALSE,
    exclude_columns JSON COMMENT 'Columns to exclude from audit (e.g., passwords)',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_schema_table (schema_name, table_name)
) ENGINE=InnoDB 
COMMENT='Configuration for audit logging per table';

-- ============================================================================
-- Audit Helper Functions and Procedures
-- ============================================================================

DELIMITER $$

-- Function to generate transaction ID
CREATE FUNCTION IF NOT EXISTS generate_transaction_id() 
RETURNS VARCHAR(64) 
READS SQL DATA 
DETERMINISTIC
BEGIN
    RETURN CONCAT(CONNECTION_ID(), '-', UNIX_TIMESTAMP(NOW(6)));
END$$

-- Procedure to log audit events
CREATE PROCEDURE IF NOT EXISTS log_audit_event(
    IN p_schema_name VARCHAR(64),
    IN p_table_name VARCHAR(64),
    IN p_operation_type VARCHAR(10),
    IN p_primary_key_value VARCHAR(255),
    IN p_old_values JSON,
    IN p_new_values JSON,
    IN p_changed_by VARCHAR(64),
    IN p_ip_address VARCHAR(45),
    IN p_application VARCHAR(64)
)
BEGIN
    DECLARE v_audit_enabled BOOLEAN DEFAULT FALSE;
    DECLARE v_exclude_columns JSON DEFAULT NULL;
    
    -- Check if auditing is enabled for this table
    SELECT 
        CASE p_operation_type
            WHEN 'INSERT' THEN audit_insert
            WHEN 'UPDATE' THEN audit_update
            WHEN 'DELETE' THEN audit_delete
            WHEN 'SELECT' THEN audit_select
            ELSE FALSE
        END,
        exclude_columns
    INTO v_audit_enabled, v_exclude_columns
    FROM audit_config
    WHERE schema_name = p_schema_name 
    AND table_name = p_table_name 
    AND is_active = TRUE;
    
    -- Insert audit record if enabled
    IF v_audit_enabled THEN
        INSERT INTO audit_log (
            schema_name, table_name, operation_type, primary_key_value,
            old_values, new_values, changed_by, ip_address, application,
            session_id, transaction_id
        ) VALUES (
            p_schema_name, p_table_name, p_operation_type, p_primary_key_value,
            p_old_values, p_new_values, p_changed_by, p_ip_address, p_application,
            CONNECTION_ID(), generate_transaction_id()
        );
    END IF;
END$$

-- Procedure to clean up old audit records
CREATE PROCEDURE IF NOT EXISTS cleanup_audit_logs(
    IN p_retention_days INT DEFAULT 90
)
BEGIN
    DECLARE v_cutoff_date DATE;
    DECLARE v_deleted_count BIGINT;
    
    SET v_cutoff_date = DATE_SUB(CURDATE(), INTERVAL p_retention_days DAY);
    
    -- Delete old audit records
    DELETE FROM audit_log 
    WHERE changed_at < v_cutoff_date;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Log the cleanup operation
    INSERT INTO audit_log (
        schema_name, table_name, operation_type, primary_key_value,
        new_values, changed_by, application
    ) VALUES (
        'audit_db', 'audit_log', 'DELETE', 'CLEANUP',
        JSON_OBJECT('deleted_count', v_deleted_count, 'cutoff_date', v_cutoff_date),
        'system', 'audit_cleanup'
    );
    
    SELECT CONCAT('Deleted ', v_deleted_count, ' audit records older than ', v_cutoff_date) AS result;
END$$

DELIMITER ;

-- ============================================================================
-- Default Audit Configuration
-- ============================================================================
-- Enable auditing for common application tables
INSERT INTO audit_config (schema_name, table_name, audit_select, exclude_columns) VALUES
('myapp', 'users', FALSE, JSON_ARRAY('password_hash')),
('myapp', 'user_profiles', FALSE, NULL),
('myapp', 'orders', FALSE, NULL),
('myapp', 'order_items', FALSE, NULL),
('myapp', 'customers', FALSE, NULL),
('myapp', 'products', FALSE, NULL);

-- ============================================================================
-- Views for Audit Reporting
-- ============================================================================

-- Recent changes view
CREATE VIEW IF NOT EXISTS v_recent_changes AS
SELECT 
    a.audit_id,
    a.schema_name,
    a.table_name,
    a.operation_type,
    a.primary_key_value,
    a.changed_by,
    a.changed_at,
    a.ip_address,
    a.application,
    CASE 
        WHEN a.old_values IS NULL AND a.new_values IS NOT NULL THEN 'CREATED'
        WHEN a.old_values IS NOT NULL AND a.new_values IS NULL THEN 'DELETED'
        WHEN a.old_values IS NOT NULL AND a.new_values IS NOT NULL THEN 'MODIFIED'
        ELSE 'ACCESSED'
    END AS change_type
FROM audit_log a
WHERE a.changed_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY a.changed_at DESC;

-- User activity summary view
CREATE VIEW IF NOT EXISTS v_user_activity_summary AS
SELECT 
    changed_by,
    DATE(changed_at) AS activity_date,
    COUNT(*) AS total_operations,
    COUNT(DISTINCT table_name) AS tables_accessed,
    COUNT(DISTINCT CONCAT(schema_name, '.', table_name)) AS distinct_tables,
    GROUP_CONCAT(DISTINCT operation_type) AS operations_performed
FROM audit_log
WHERE changed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY changed_by, DATE(changed_at)
ORDER BY activity_date DESC, total_operations DESC;

-- ============================================================================
-- Grants and Permissions
-- ============================================================================
-- Create audit user with limited permissions
-- CREATE USER IF NOT EXISTS 'audit_user'@'%' IDENTIFIED BY 'secure_audit_password';
-- GRANT SELECT, INSERT ON audit_db.* TO 'audit_user'@'%';
-- GRANT EXECUTE ON PROCEDURE audit_db.log_audit_event TO 'audit_user'@'%';

-- Grant read access to application users for audit queries
-- GRANT SELECT ON audit_db.v_recent_changes TO 'app_read'@'%';
-- GRANT SELECT ON audit_db.v_user_activity_summary TO 'app_read'@'%';