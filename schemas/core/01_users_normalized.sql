-- ============================================================================
-- Core User Management Schema (Normalized Design)
-- ============================================================================
-- This script creates the foundational user management tables using
-- normalized database design principles (3NF) for OLTP systems.
--
-- Author: MySQL Architecture Team
-- Version: 1.0
-- Last Updated: 2024
-- ============================================================================

-- Create main application database
CREATE DATABASE IF NOT EXISTS myapp 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE myapp;

-- ============================================================================
-- Users Table (Core entity)
-- ============================================================================
-- Primary user entity with authentication information
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique user identifier',
    username VARCHAR(50) UNIQUE NOT NULL COMMENT 'Unique username for login',
    email VARCHAR(100) UNIQUE NOT NULL COMMENT 'User email address',
    password_hash VARCHAR(255) NOT NULL COMMENT 'Hashed password (never store plain text)',
    email_verified BOOLEAN DEFAULT FALSE COMMENT 'Email verification status',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Account active status',
    last_login TIMESTAMP NULL COMMENT 'Last successful login timestamp',
    failed_login_attempts INT DEFAULT 0 COMMENT 'Count of consecutive failed logins',
    locked_until TIMESTAMP NULL COMMENT 'Account lock expiration time',
    password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Last password change',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Account creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Indexes for performance
    INDEX idx_email (email),
    INDEX idx_username (username),
    INDEX idx_active_users (is_active, email_verified),
    INDEX idx_last_login (last_login),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB 
COMMENT='Core user authentication and account information';

-- ============================================================================
-- User Profiles Table (1:1 relationship with users)
-- ============================================================================
-- Extended user information separate from authentication data
CREATE TABLE IF NOT EXISTS user_profiles (
    profile_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique profile identifier',
    user_id INT UNIQUE NOT NULL COMMENT 'Reference to users table',
    first_name VARCHAR(50) COMMENT 'User first name',
    last_name VARCHAR(50) COMMENT 'User last name',
    display_name VARCHAR(100) COMMENT 'Public display name',
    phone VARCHAR(20) COMMENT 'Phone number',
    date_of_birth DATE COMMENT 'Date of birth',
    gender ENUM('male', 'female', 'other', 'prefer_not_to_say') COMMENT 'Gender identity',
    timezone VARCHAR(50) DEFAULT 'UTC' COMMENT 'User timezone preference',
    language_code VARCHAR(5) DEFAULT 'en' COMMENT 'Preferred language (ISO 639-1)',
    avatar_url VARCHAR(255) COMMENT 'Profile picture URL',
    bio TEXT COMMENT 'User biography/description',
    website_url VARCHAR(255) COMMENT 'Personal website URL',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Profile creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Indexes
    INDEX idx_user_id (user_id),
    INDEX idx_full_name (first_name, last_name),
    INDEX idx_display_name (display_name)
) ENGINE=InnoDB 
COMMENT='Extended user profile information';

-- ============================================================================
-- User Addresses Table (1:Many relationship)
-- ============================================================================
-- Multiple addresses per user (home, work, billing, shipping, etc.)
CREATE TABLE IF NOT EXISTS user_addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique address identifier',
    user_id INT NOT NULL COMMENT 'Reference to users table',
    address_type ENUM('home', 'work', 'billing', 'shipping', 'other') NOT NULL DEFAULT 'home' COMMENT 'Type of address',
    address_line1 VARCHAR(255) NOT NULL COMMENT 'Primary address line',
    address_line2 VARCHAR(255) COMMENT 'Secondary address line (apt, suite, etc.)',
    city VARCHAR(100) NOT NULL COMMENT 'City name',
    state_province VARCHAR(100) COMMENT 'State or province',
    postal_code VARCHAR(20) COMMENT 'ZIP/postal code',
    country_code CHAR(2) NOT NULL DEFAULT 'US' COMMENT 'ISO 3166-1 alpha-2 country code',
    is_default BOOLEAN DEFAULT FALSE COMMENT 'Default address for this type',
    latitude DECIMAL(10,8) COMMENT 'GPS latitude for mapping',
    longitude DECIMAL(11,8) COMMENT 'GPS longitude for mapping',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Address creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Indexes
    INDEX idx_user_id (user_id),
    INDEX idx_user_type (user_id, address_type),
    INDEX idx_default_addresses (user_id, address_type, is_default),
    INDEX idx_location (latitude, longitude),
    INDEX idx_postal_code (postal_code)
) ENGINE=InnoDB 
COMMENT='User addresses with support for multiple address types';

-- ============================================================================
-- User Preferences Table (Key-Value pairs)
-- ============================================================================
-- Flexible storage for user preferences and settings
CREATE TABLE IF NOT EXISTS user_preferences (
    preference_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique preference identifier',
    user_id INT NOT NULL COMMENT 'Reference to users table',
    preference_key VARCHAR(100) NOT NULL COMMENT 'Preference setting name',
    preference_value TEXT COMMENT 'Preference value (JSON supported)',
    data_type ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string' COMMENT 'Data type for proper parsing',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Preference creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    
    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Unique constraint to prevent duplicate preferences per user
    UNIQUE KEY uk_user_preference (user_id, preference_key),
    
    -- Indexes
    INDEX idx_user_id (user_id),
    INDEX idx_preference_key (preference_key)
) ENGINE=InnoDB 
COMMENT='User preferences and application settings';

-- ============================================================================
-- User Sessions Table
-- ============================================================================
-- Track active user sessions for security and analytics
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id VARCHAR(128) PRIMARY KEY COMMENT 'Unique session identifier',
    user_id INT NOT NULL COMMENT 'Reference to users table',
    ip_address VARCHAR(45) NOT NULL COMMENT 'IP address of the session',
    user_agent TEXT COMMENT 'Browser/client user agent string',
    device_type ENUM('desktop', 'mobile', 'tablet', 'api', 'other') DEFAULT 'other' COMMENT 'Device type classification',
    login_method ENUM('password', 'oauth', 'sso', 'api_key', 'token') DEFAULT 'password' COMMENT 'Authentication method used',
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Session active status',
    expires_at TIMESTAMP NOT NULL COMMENT 'Session expiration time',
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last session activity',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Session creation timestamp',
    
    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Indexes
    INDEX idx_user_id (user_id),
    INDEX idx_active_sessions (is_active, expires_at),
    INDEX idx_last_activity (last_activity),
    INDEX idx_ip_address (ip_address),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB 
COMMENT='Active user sessions for authentication and tracking';

-- ============================================================================
-- Triggers for Audit Logging
-- ============================================================================

DELIMITER $$

-- Trigger for users table INSERT
CREATE TRIGGER IF NOT EXISTS tr_users_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    CALL audit_db.log_audit_event(
        'myapp', 'users', 'INSERT', NEW.user_id,
        NULL, 
        JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'is_active', NEW.is_active),
        USER(), 
        NULL, 
        'myapp'
    );
END$$

-- Trigger for users table UPDATE
CREATE TRIGGER IF NOT EXISTS tr_users_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    CALL audit_db.log_audit_event(
        'myapp', 'users', 'UPDATE', NEW.user_id,
        JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'is_active', OLD.is_active),
        JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'is_active', NEW.is_active),
        USER(), 
        NULL, 
        'myapp'
    );
END$$

-- Trigger for users table DELETE
CREATE TRIGGER IF NOT EXISTS tr_users_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    CALL audit_db.log_audit_event(
        'myapp', 'users', 'DELETE', OLD.user_id,
        JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'is_active', OLD.is_active),
        NULL,
        USER(), 
        NULL, 
        'myapp'
    );
END$$

DELIMITER ;

-- ============================================================================
-- Sample Data (for development/testing)
-- ============================================================================
-- Insert sample users for testing (comment out for production)
/*
INSERT INTO users (username, email, password_hash, email_verified) VALUES
('admin', 'admin@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', TRUE),
('jdoe', 'john.doe@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', TRUE),
('asmith', 'alice.smith@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', FALSE);

INSERT INTO user_profiles (user_id, first_name, last_name, display_name, timezone) VALUES
(1, 'System', 'Administrator', 'Admin', 'UTC'),
(2, 'John', 'Doe', 'John D.', 'America/New_York'),
(3, 'Alice', 'Smith', 'Alice', 'Europe/London');

INSERT INTO user_preferences (user_id, preference_key, preference_value, data_type) VALUES
(1, 'theme', 'dark', 'string'),
(1, 'notifications_enabled', 'true', 'boolean'),
(2, 'language', 'en', 'string'),
(2, 'timezone_auto_detect', 'true', 'boolean'),
(3, 'newsletter_subscription', 'false', 'boolean');
*/

-- ============================================================================
-- Views for Common Queries
-- ============================================================================

-- Complete user information view
CREATE VIEW IF NOT EXISTS v_user_details AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.email_verified,
    u.is_active,
    u.last_login,
    u.created_at,
    p.first_name,
    p.last_name,
    p.display_name,
    p.phone,
    p.timezone,
    p.language_code,
    p.avatar_url,
    CONCAT(p.first_name, ' ', p.last_name) AS full_name
FROM users u
LEFT JOIN user_profiles p ON u.user_id = p.user_id
WHERE u.is_active = TRUE;

-- Active sessions view
CREATE VIEW IF NOT EXISTS v_active_sessions AS
SELECT 
    s.session_id,
    s.user_id,
    u.username,
    u.email,
    s.ip_address,
    s.device_type,
    s.login_method,
    s.last_activity,
    s.expires_at,
    TIMESTAMPDIFF(MINUTE, s.last_activity, NOW()) AS minutes_inactive
FROM user_sessions s
JOIN users u ON s.user_id = u.user_id
WHERE s.is_active = TRUE 
AND s.expires_at > NOW()
ORDER BY s.last_activity DESC;