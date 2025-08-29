-- ============================================================================
-- Sample Schema Migration: Add User Login Tracking
-- ============================================================================
-- Migration ID: 001_add_user_login_tracking
-- Description: Add login tracking columns to users table and create login_history table
-- Author: MySQL Architecture Team
-- Created: 2024-01-01
-- ============================================================================

-- This migration adds enhanced login tracking functionality to the user management system

USE myapp;

-- ============================================================================
-- 1. Add new columns to users table for login tracking
-- ============================================================================

-- Add failed login attempt tracking columns
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS failed_login_attempts INT DEFAULT 0 COMMENT 'Number of consecutive failed login attempts',
ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP NULL COMMENT 'Account lock expiration time',
ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Last password change timestamp';

-- ============================================================================
-- 2. Create login history table for detailed tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS login_history (
    login_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique login event identifier',
    user_id INT NOT NULL COMMENT 'Reference to users table',
    login_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When the login attempt occurred',
    login_status ENUM('success', 'failed', 'blocked') NOT NULL COMMENT 'Login attempt result',
    ip_address VARCHAR(45) NOT NULL COMMENT 'IP address of login attempt',
    user_agent TEXT COMMENT 'Browser/client user agent string',
    failure_reason VARCHAR(100) COMMENT 'Reason for login failure (if applicable)',
    session_duration INT COMMENT 'Session duration in seconds (for successful logins)',
    
    -- Geographic information (optional)
    country_code CHAR(2) COMMENT 'Country code based on IP',
    city VARCHAR(100) COMMENT 'City based on IP geolocation',
    
    -- Security flags
    is_suspicious BOOLEAN DEFAULT FALSE COMMENT 'Flagged as suspicious activity',
    risk_score DECIMAL(3,2) DEFAULT 0.00 COMMENT 'Risk score (0.00-10.00)',
    
    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Indexes for query performance
    INDEX idx_user_id (user_id),
    INDEX idx_login_timestamp (login_timestamp),
    INDEX idx_login_status (login_status),
    INDEX idx_ip_address (ip_address),
    INDEX idx_user_timestamp (user_id, login_timestamp),
    INDEX idx_suspicious (is_suspicious),
    INDEX idx_risk_score (risk_score)
) ENGINE=InnoDB 
COMMENT='Detailed login attempt history for security and analytics'
PARTITION BY RANGE (YEAR(login_timestamp)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- ============================================================================
-- 3. Create stored procedures for login management
-- ============================================================================

DELIMITER $$

-- Procedure to record login attempt
CREATE PROCEDURE IF NOT EXISTS record_login_attempt(
    IN p_user_id INT,
    IN p_login_status VARCHAR(10),
    IN p_ip_address VARCHAR(45),
    IN p_user_agent TEXT,
    IN p_failure_reason VARCHAR(100)
)
BEGIN
    DECLARE v_risk_score DECIMAL(3,2) DEFAULT 0.00;
    DECLARE v_is_suspicious BOOLEAN DEFAULT FALSE;
    
    -- Calculate risk score based on recent failed attempts
    SELECT 
        CASE 
            WHEN COUNT(*) >= 5 THEN 8.00
            WHEN COUNT(*) >= 3 THEN 5.00
            WHEN COUNT(*) >= 1 THEN 2.00
            ELSE 0.00
        END,
        CASE WHEN COUNT(*) >= 3 THEN TRUE ELSE FALSE END
    INTO v_risk_score, v_is_suspicious
    FROM login_history 
    WHERE user_id = p_user_id 
    AND login_status = 'failed' 
    AND login_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR);
    
    -- Insert login history record
    INSERT INTO login_history (
        user_id, login_status, ip_address, user_agent, 
        failure_reason, is_suspicious, risk_score
    ) VALUES (
        p_user_id, p_login_status, p_ip_address, p_user_agent,
        p_failure_reason, v_is_suspicious, v_risk_score
    );
    
    -- Update user table based on login result
    IF p_login_status = 'success' THEN
        UPDATE users 
        SET last_login = NOW(), 
            failed_login_attempts = 0,
            locked_until = NULL
        WHERE user_id = p_user_id;
    ELSEIF p_login_status = 'failed' THEN
        UPDATE users 
        SET failed_login_attempts = failed_login_attempts + 1,
            locked_until = CASE 
                WHEN failed_login_attempts >= 4 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
                ELSE locked_until
            END
        WHERE user_id = p_user_id;
    END IF;
    
END$$

-- Procedure to clean up old login history
CREATE PROCEDURE IF NOT EXISTS cleanup_login_history(
    IN p_retention_days INT DEFAULT 90
)
BEGIN
    DECLARE v_cutoff_date DATE;
    DECLARE v_deleted_count BIGINT;
    
    SET v_cutoff_date = DATE_SUB(CURDATE(), INTERVAL p_retention_days DAY);
    
    -- Delete old login history records
    DELETE FROM login_history 
    WHERE login_timestamp < v_cutoff_date;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    SELECT CONCAT('Deleted ', v_deleted_count, ' login history records older than ', v_cutoff_date) AS result;
END$$

-- Function to check if user account is locked
CREATE FUNCTION IF NOT EXISTS is_user_locked(p_user_id INT)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_locked_until TIMESTAMP DEFAULT NULL;
    
    SELECT locked_until INTO v_locked_until
    FROM users 
    WHERE user_id = p_user_id;
    
    RETURN (v_locked_until IS NOT NULL AND v_locked_until > NOW());
END$$

DELIMITER ;

-- ============================================================================
-- 4. Create views for login analytics
-- ============================================================================

-- View for recent login activity
CREATE VIEW IF NOT EXISTS v_recent_login_activity AS
SELECT 
    lh.login_id,
    lh.user_id,
    u.username,
    u.email,
    lh.login_timestamp,
    lh.login_status,
    lh.ip_address,
    lh.failure_reason,
    lh.is_suspicious,
    lh.risk_score,
    CASE 
        WHEN lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN 'Last Hour'
        WHEN lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR) THEN 'Last 24 Hours'
        WHEN lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 'Last Week'
        ELSE 'Older'
    END AS time_period
FROM login_history lh
JOIN users u ON lh.user_id = u.user_id
WHERE lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY lh.login_timestamp DESC;

-- View for suspicious login summary
CREATE VIEW IF NOT EXISTS v_suspicious_logins AS
SELECT 
    DATE(lh.login_timestamp) AS login_date,
    COUNT(*) AS total_attempts,
    COUNT(CASE WHEN lh.login_status = 'failed' THEN 1 END) AS failed_attempts,
    COUNT(CASE WHEN lh.is_suspicious = TRUE THEN 1 END) AS suspicious_attempts,
    COUNT(DISTINCT lh.user_id) AS unique_users,
    COUNT(DISTINCT lh.ip_address) AS unique_ips,
    AVG(lh.risk_score) AS avg_risk_score
FROM login_history lh
WHERE lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(lh.login_timestamp)
ORDER BY login_date DESC;

-- View for user login statistics
CREATE VIEW IF NOT EXISTS v_user_login_stats AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.last_login,
    u.failed_login_attempts,
    u.locked_until,
    COUNT(lh.login_id) AS total_login_attempts,
    COUNT(CASE WHEN lh.login_status = 'success' THEN 1 END) AS successful_logins,
    COUNT(CASE WHEN lh.login_status = 'failed' THEN 1 END) AS failed_logins,
    MAX(lh.login_timestamp) AS last_attempt,
    COUNT(DISTINCT lh.ip_address) AS unique_ip_count
FROM users u
LEFT JOIN login_history lh ON u.user_id = lh.user_id 
    AND lh.login_timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
WHERE u.is_active = TRUE
GROUP BY u.user_id, u.username, u.email, u.last_login, u.failed_login_attempts, u.locked_until
ORDER BY total_login_attempts DESC;

-- ============================================================================
-- 5. Add audit configuration for new table
-- ============================================================================

-- Add login_history to audit configuration
INSERT INTO audit_db.audit_config (schema_name, table_name, audit_select, exclude_columns) 
VALUES ('myapp', 'login_history', FALSE, JSON_ARRAY('user_agent'))
ON DUPLICATE KEY UPDATE 
    audit_select = FALSE,
    exclude_columns = JSON_ARRAY('user_agent'),
    updated_at = NOW();

-- ============================================================================
-- 6. Create indexes for existing data optimization
-- ============================================================================

-- Add composite index for better query performance on users table
CREATE INDEX IF NOT EXISTS idx_users_login_status ON users (is_active, email_verified, failed_login_attempts);

-- Add index for session management
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions (user_id, is_active, expires_at);

-- ============================================================================
-- 7. Update existing user records (data migration)
-- ============================================================================

-- Set password_changed_at for existing users (one-time update)
UPDATE users 
SET password_changed_at = created_at 
WHERE password_changed_at IS NULL;

-- ============================================================================
-- 8. Create triggers for automatic login tracking
-- ============================================================================

DELIMITER $$

-- Trigger to automatically log when user records are updated with login info
CREATE TRIGGER IF NOT EXISTS tr_users_login_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    -- Only log if last_login was updated (indicates a successful login)
    IF NEW.last_login != OLD.last_login AND NEW.last_login IS NOT NULL THEN
        INSERT INTO login_history (user_id, login_status, ip_address, user_agent)
        VALUES (NEW.user_id, 'success', '127.0.0.1', 'trigger-generated');
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- Migration Completion Log
-- ============================================================================

-- Log the completion of this migration
INSERT INTO audit_db.audit_log (
    schema_name, table_name, operation_type, primary_key_value,
    new_values, changed_by, application
) VALUES (
    'myapp', 'schema_migrations', 'INSERT', '001_add_user_login_tracking',
    JSON_OBJECT(
        'migration_id', '001_add_user_login_tracking',
        'description', 'Add user login tracking functionality',
        'tables_created', JSON_ARRAY('login_history'),
        'columns_added', JSON_ARRAY('failed_login_attempts', 'locked_until', 'password_changed_at'),
        'procedures_created', JSON_ARRAY('record_login_attempt', 'cleanup_login_history'),
        'views_created', JSON_ARRAY('v_recent_login_activity', 'v_suspicious_logins', 'v_user_login_stats')
    ),
    'migration_system',
    'schema_migration'
);

-- ============================================================================
-- Verification Queries (for testing)
-- ============================================================================

/*
-- Verify table structure
DESCRIBE login_history;
DESCRIBE users;

-- Test stored procedures
CALL record_login_attempt(1, 'success', '192.168.1.100', 'Mozilla/5.0...', NULL);
CALL record_login_attempt(1, 'failed', '192.168.1.100', 'Mozilla/5.0...', 'Invalid password');

-- Test views
SELECT * FROM v_recent_login_activity LIMIT 10;
SELECT * FROM v_suspicious_logins;
SELECT * FROM v_user_login_stats LIMIT 5;

-- Test functions
SELECT is_user_locked(1);

-- Check audit configuration
SELECT * FROM audit_db.audit_config WHERE table_name = 'login_history';
*/