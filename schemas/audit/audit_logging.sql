-- =============================================================================
-- Audit Logging Schema
-- =============================================================================
-- Purpose: Track all data changes across the application for compliance,
--          debugging, and security monitoring
-- Author: Auto-generated from mysql-instructions.md
-- Created: $(date)
-- =============================================================================

-- Main audit logging table for tracking all data changes
CREATE TABLE audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique identifier for audit record',
    table_name VARCHAR(64) NOT NULL COMMENT 'Name of the table that was modified',
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL COMMENT 'Type of operation performed',
    record_id VARCHAR(255) NOT NULL COMMENT 'Primary key value of the affected record',
    old_values JSON COMMENT 'Previous values before the change (NULL for INSERT)',
    new_values JSON COMMENT 'New values after the change (NULL for DELETE)',
    changed_by VARCHAR(64) NOT NULL COMMENT 'User who made the change',
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When the change occurred',
    session_id VARCHAR(128) COMMENT 'Session identifier for the user',
    application_name VARCHAR(64) COMMENT 'Name of the application that made the change',
    ip_address VARCHAR(45) COMMENT 'IP address of the client (supports IPv6)',
    user_agent TEXT COMMENT 'User agent string for web requests',
    
    -- Indexes for efficient querying
    INDEX idx_table_operation (table_name, operation),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by),
    INDEX idx_record_tracking (table_name, record_id, changed_at),
    INDEX idx_session_tracking (session_id, changed_at)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Audit trail for all data changes in the system';

-- Table for storing audit configuration
CREATE TABLE audit_config (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL UNIQUE COMMENT 'Table name to audit',
    is_enabled BOOLEAN DEFAULT TRUE COMMENT 'Whether auditing is enabled for this table',
    audit_inserts BOOLEAN DEFAULT TRUE COMMENT 'Track INSERT operations',
    audit_updates BOOLEAN DEFAULT TRUE COMMENT 'Track UPDATE operations', 
    audit_deletes BOOLEAN DEFAULT TRUE COMMENT 'Track DELETE operations',
    excluded_columns JSON COMMENT 'Columns to exclude from audit (e.g., passwords)',
    retention_days INT DEFAULT 2555 COMMENT 'Days to retain audit records (default 7 years)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_table_enabled (table_name, is_enabled)
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Configuration for audit logging per table';

-- View for easy audit trail querying
CREATE VIEW audit_trail AS
SELECT 
    al.id,
    al.table_name,
    al.operation,
    al.record_id,
    al.changed_by,
    al.changed_at,
    al.session_id,
    al.application_name,
    al.ip_address,
    CASE 
        WHEN al.operation = 'INSERT' THEN al.new_values
        WHEN al.operation = 'DELETE' THEN al.old_values
        WHEN al.operation = 'UPDATE' THEN JSON_MERGE_PATCH(
            COALESCE(al.old_values, JSON_OBJECT()),
            COALESCE(al.new_values, JSON_OBJECT())
        )
    END as record_data
FROM audit_log al
WHERE al.changed_at >= DATE_SUB(NOW(), INTERVAL 90 DAY) -- Show last 90 days by default
ORDER BY al.changed_at DESC;

-- Example trigger template for auditing (to be customized per table)
DELIMITER $$

-- Sample trigger for INSERT operations
CREATE TRIGGER tr_audit_example_insert
    AFTER INSERT ON example_table
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (
        table_name, 
        operation, 
        record_id, 
        new_values, 
        changed_by, 
        session_id, 
        application_name,
        ip_address
    ) VALUES (
        'example_table',
        'INSERT',
        NEW.id,
        JSON_OBJECT(
            'id', NEW.id,
            'name', NEW.name,
            'email', NEW.email,
            'created_at', NEW.created_at
        ),
        COALESCE(@audit_user, USER()),
        COALESCE(@audit_session, CONNECTION_ID()),
        COALESCE(@audit_app, 'MySQL-Direct'),
        COALESCE(@audit_ip, 'unknown')
    );
END$$

-- Sample trigger for UPDATE operations
CREATE TRIGGER tr_audit_example_update
    AFTER UPDATE ON example_table
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (
        table_name,
        operation,
        record_id,
        old_values,
        new_values,
        changed_by,
        session_id,
        application_name,
        ip_address
    ) VALUES (
        'example_table',
        'UPDATE',
        NEW.id,
        JSON_OBJECT(
            'id', OLD.id,
            'name', OLD.name,
            'email', OLD.email,
            'updated_at', OLD.updated_at
        ),
        JSON_OBJECT(
            'id', NEW.id,
            'name', NEW.name,
            'email', NEW.email,
            'updated_at', NEW.updated_at
        ),
        COALESCE(@audit_user, USER()),
        COALESCE(@audit_session, CONNECTION_ID()),
        COALESCE(@audit_app, 'MySQL-Direct'),
        COALESCE(@audit_ip, 'unknown')
    );
END$$

-- Sample trigger for DELETE operations
CREATE TRIGGER tr_audit_example_delete
    AFTER DELETE ON example_table
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (
        table_name,
        operation,
        record_id,
        old_values,
        changed_by,
        session_id,
        application_name,
        ip_address
    ) VALUES (
        'example_table',
        'DELETE',
        OLD.id,
        JSON_OBJECT(
            'id', OLD.id,
            'name', OLD.name,
            'email', OLD.email,
            'created_at', OLD.created_at,
            'updated_at', OLD.updated_at
        ),
        COALESCE(@audit_user, USER()),
        COALESCE(@audit_session, CONNECTION_ID()),
        COALESCE(@audit_app, 'MySQL-Direct'),
        COALESCE(@audit_ip, 'unknown')
    );
END$$

DELIMITER ;

-- Insert default audit configuration for common tables
INSERT INTO audit_config (table_name, excluded_columns) VALUES
('users', JSON_ARRAY('password_hash', 'remember_token')),
('customers', JSON_ARRAY('payment_info')),
('orders', NULL),
('products', NULL),
('audit_log', NULL);