-- ============================================================================
-- Security and Access Control Framework
-- ============================================================================
-- This script implements a comprehensive role-based access control (RBAC)
-- system following the principle of least privilege.
--
-- Author: MySQL Architecture Team
-- Version: 1.0
-- Last Updated: 2024
-- ============================================================================

-- ============================================================================
-- Database Users Creation
-- ============================================================================
-- Create application-specific database users with secure passwords
-- Note: In production, use strong passwords and consider external authentication

-- Read-only user for reporting and analytics
CREATE USER IF NOT EXISTS 'app_read'@'%' IDENTIFIED BY 'ReadOnly$ecure2024!';
CREATE USER IF NOT EXISTS 'app_read'@'localhost' IDENTIFIED BY 'ReadOnly$ecure2024!';

-- Read-write user for application operations
CREATE USER IF NOT EXISTS 'app_write'@'%' IDENTIFIED BY 'ReadWrite$ecure2024!';
CREATE USER IF NOT EXISTS 'app_write'@'localhost' IDENTIFIED BY 'ReadWrite$ecure2024!';

-- Administrative user for maintenance and schema changes
CREATE USER IF NOT EXISTS 'app_admin'@'%' IDENTIFIED BY 'Admin$ecure2024!';
CREATE USER IF NOT EXISTS 'app_admin'@'localhost' IDENTIFIED BY 'Admin$ecure2024!';

-- ETL user for data processing and batch operations
CREATE USER IF NOT EXISTS 'app_etl'@'%' IDENTIFIED BY 'ETL$ecure2024!';
CREATE USER IF NOT EXISTS 'app_etl'@'localhost' IDENTIFIED BY 'ETL$ecure2024!';

-- Monitoring user for health checks and metrics collection
CREATE USER IF NOT EXISTS 'app_monitor'@'%' IDENTIFIED BY 'Monitor$ecure2024!';
CREATE USER IF NOT EXISTS 'app_monitor'@'localhost' IDENTIFIED BY 'Monitor$ecure2024!';

-- Backup user for database backups
CREATE USER IF NOT EXISTS 'app_backup'@'%' IDENTIFIED BY 'Backup$ecure2024!';
CREATE USER IF NOT EXISTS 'app_backup'@'localhost' IDENTIFIED BY 'Backup$ecure2024!';

-- ============================================================================
-- Role Definitions
-- ============================================================================
-- Create roles for different access levels and use cases

-- Read-only role for reporting and analytics
CREATE ROLE IF NOT EXISTS 'read_only_role';

-- Read-write role for standard application operations
CREATE ROLE IF NOT EXISTS 'read_write_role';

-- Administrative role for schema management
CREATE ROLE IF NOT EXISTS 'admin_role';

-- ETL role for data processing operations
CREATE ROLE IF NOT EXISTS 'etl_role';

-- Monitoring role for system health checks
CREATE ROLE IF NOT EXISTS 'monitor_role';

-- Backup role for database backup operations
CREATE ROLE IF NOT EXISTS 'backup_role';

-- Analytics role with specific permissions for reporting
CREATE ROLE IF NOT EXISTS 'analytics_role';

-- ============================================================================
-- Permission Grants - Read Only Role
-- ============================================================================
-- Grant read-only permissions to core application tables

-- Core application data
GRANT SELECT ON myapp.users TO 'read_only_role';
GRANT SELECT ON myapp.user_profiles TO 'read_only_role';
GRANT SELECT ON myapp.user_addresses TO 'read_only_role';
GRANT SELECT ON myapp.user_preferences TO 'read_only_role';
GRANT SELECT ON myapp.user_sessions TO 'read_only_role';

-- Analytics and reporting tables
GRANT SELECT ON myapp.orders_summary TO 'read_only_role';
GRANT SELECT ON myapp.product_performance_summary TO 'read_only_role';
GRANT SELECT ON myapp.customer_analytics_summary TO 'read_only_role';
GRANT SELECT ON myapp.daily_sales_summary TO 'read_only_role';

-- Views
GRANT SELECT ON myapp.v_user_details TO 'read_only_role';
GRANT SELECT ON myapp.v_active_sessions TO 'read_only_role';
GRANT SELECT ON myapp.v_top_customers_90d TO 'read_only_role';
GRANT SELECT ON myapp.v_bestselling_products_30d TO 'read_only_role';
GRANT SELECT ON myapp.v_sales_trend_30d TO 'read_only_role';

-- Audit data (read-only)
GRANT SELECT ON audit_db.audit_log TO 'read_only_role';
GRANT SELECT ON audit_db.v_recent_changes TO 'read_only_role';
GRANT SELECT ON audit_db.v_user_activity_summary TO 'read_only_role';

-- ============================================================================
-- Permission Grants - Read Write Role
-- ============================================================================
-- Grant read-write permissions for standard application operations

-- Core tables - full access for application operations
GRANT SELECT, INSERT, UPDATE ON myapp.users TO 'read_write_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.user_profiles TO 'read_write_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.user_addresses TO 'read_write_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.user_preferences TO 'read_write_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.user_sessions TO 'read_write_role';

-- Analytical tables - read only for application users
GRANT SELECT ON myapp.orders_summary TO 'read_write_role';
GRANT SELECT ON myapp.product_performance_summary TO 'read_write_role';
GRANT SELECT ON myapp.customer_analytics_summary TO 'read_write_role';
GRANT SELECT ON myapp.daily_sales_summary TO 'read_write_role';

-- Views access
GRANT SELECT ON myapp.v_user_details TO 'read_write_role';
GRANT SELECT ON myapp.v_active_sessions TO 'read_write_role';

-- Limited audit access (insert only for logging)
GRANT INSERT ON audit_db.audit_log TO 'read_write_role';
GRANT EXECUTE ON PROCEDURE audit_db.log_audit_event TO 'read_write_role';

-- ============================================================================
-- Permission Grants - Admin Role
-- ============================================================================
-- Grant administrative permissions for schema management and maintenance

-- Full access to all application schemas
GRANT ALL PRIVILEGES ON myapp.* TO 'admin_role';
GRANT ALL PRIVILEGES ON audit_db.* TO 'admin_role';

-- System-level permissions for administration
GRANT CREATE USER ON *.* TO 'admin_role';
GRANT RELOAD ON *.* TO 'admin_role';
GRANT PROCESS ON *.* TO 'admin_role';
GRANT SHOW DATABASES ON *.* TO 'admin_role';

-- Replication permissions (if needed)
GRANT REPLICATION SLAVE ON *.* TO 'admin_role';
GRANT REPLICATION CLIENT ON *.* TO 'admin_role';

-- ============================================================================
-- Permission Grants - ETL Role
-- ============================================================================
-- Grant permissions needed for ETL operations and data processing

-- Read access to source data
GRANT SELECT ON myapp.* TO 'etl_role';

-- Write access to analytical tables
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.orders_summary TO 'etl_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.product_performance_summary TO 'etl_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.customer_analytics_summary TO 'etl_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.daily_sales_summary TO 'etl_role';

-- Staging table permissions (when created)
-- GRANT ALL PRIVILEGES ON staging.* TO 'etl_role';

-- Audit logging for ETL operations
GRANT INSERT ON audit_db.audit_log TO 'etl_role';
GRANT EXECUTE ON PROCEDURE audit_db.log_audit_event TO 'etl_role';

-- Temporary table creation for ETL processing
GRANT CREATE TEMPORARY TABLES ON myapp.* TO 'etl_role';

-- ============================================================================
-- Permission Grants - Monitor Role
-- ============================================================================
-- Grant permissions for monitoring and health checks

-- Performance schema access for monitoring
GRANT SELECT ON performance_schema.* TO 'monitor_role';

-- Information schema access for metadata
GRANT SELECT ON information_schema.* TO 'monitor_role';

-- Basic read access for health checks
GRANT SELECT ON myapp.users TO 'monitor_role';
GRANT SELECT ON myapp.v_active_sessions TO 'monitor_role';
GRANT SELECT ON audit_db.audit_log TO 'monitor_role';

-- System-level monitoring permissions
GRANT PROCESS ON *.* TO 'monitor_role';
GRANT SHOW DATABASES ON *.* TO 'monitor_role';

-- ============================================================================
-- Permission Grants - Backup Role
-- ============================================================================
-- Grant permissions needed for database backups

-- Read access to all data for backup
GRANT SELECT ON myapp.* TO 'backup_role';
GRANT SELECT ON audit_db.* TO 'backup_role';

-- System permissions for backup operations
GRANT RELOAD ON *.* TO 'backup_role';
GRANT LOCK TABLES ON myapp.* TO 'backup_role';
GRANT LOCK TABLES ON audit_db.* TO 'backup_role';
GRANT SHOW DATABASES ON *.* TO 'backup_role';
GRANT PROCESS ON *.* TO 'backup_role';

-- Binary log access for point-in-time recovery
GRANT REPLICATION CLIENT ON *.* TO 'backup_role';

-- ============================================================================
-- Permission Grants - Analytics Role
-- ============================================================================
-- Specialized role for business intelligence and advanced analytics

-- Read access to all analytical data
GRANT SELECT ON myapp.orders_summary TO 'analytics_role';
GRANT SELECT ON myapp.product_performance_summary TO 'analytics_role';
GRANT SELECT ON myapp.customer_analytics_summary TO 'analytics_role';
GRANT SELECT ON myapp.daily_sales_summary TO 'analytics_role';

-- Access to analytical views
GRANT SELECT ON myapp.v_top_customers_90d TO 'analytics_role';
GRANT SELECT ON myapp.v_bestselling_products_30d TO 'analytics_role';
GRANT SELECT ON myapp.v_sales_trend_30d TO 'analytics_role';

-- Limited access to core data for context
GRANT SELECT ON myapp.v_user_details TO 'analytics_role';

-- Audit data for compliance reporting
GRANT SELECT ON audit_db.audit_log TO 'analytics_role';
GRANT SELECT ON audit_db.v_user_activity_summary TO 'analytics_role';

-- Permission to create temporary tables for analysis
GRANT CREATE TEMPORARY TABLES ON myapp.* TO 'analytics_role';

-- ============================================================================
-- Role Assignments
-- ============================================================================
-- Assign roles to users

-- Read-only user assignments
GRANT 'read_only_role' TO 'app_read'@'%';
GRANT 'read_only_role' TO 'app_read'@'localhost';

-- Read-write user assignments
GRANT 'read_write_role' TO 'app_write'@'%';
GRANT 'read_write_role' TO 'app_write'@'localhost';

-- Administrative user assignments
GRANT 'admin_role' TO 'app_admin'@'%';
GRANT 'admin_role' TO 'app_admin'@'localhost';

-- ETL user assignments
GRANT 'etl_role' TO 'app_etl'@'%';
GRANT 'etl_role' TO 'app_etl'@'localhost';

-- Monitoring user assignments
GRANT 'monitor_role' TO 'app_monitor'@'%';
GRANT 'monitor_role' TO 'app_monitor'@'localhost';

-- Backup user assignments
GRANT 'backup_role' TO 'app_backup'@'%';
GRANT 'backup_role' TO 'app_backup'@'localhost';

-- ============================================================================
-- Set Default Roles
-- ============================================================================
-- Set default roles for users (MySQL 8.0+)

SET DEFAULT ROLE 'read_only_role' TO 'app_read'@'%', 'app_read'@'localhost';
SET DEFAULT ROLE 'read_write_role' TO 'app_write'@'%', 'app_write'@'localhost';
SET DEFAULT ROLE 'admin_role' TO 'app_admin'@'%', 'app_admin'@'localhost';
SET DEFAULT ROLE 'etl_role' TO 'app_etl'@'%', 'app_etl'@'localhost';
SET DEFAULT ROLE 'monitor_role' TO 'app_monitor'@'%', 'app_monitor'@'localhost';
SET DEFAULT ROLE 'backup_role' TO 'app_backup'@'%', 'app_backup'@'localhost';

-- ============================================================================
-- Security Configuration
-- ============================================================================

-- Password validation settings (MySQL 8.0+)
-- Uncomment and adjust as needed for your security requirements
/*
SET GLOBAL validate_password.policy = MEDIUM;
SET GLOBAL validate_password.length = 12;
SET GLOBAL validate_password.mixed_case_count = 1;
SET GLOBAL validate_password.number_count = 1;
SET GLOBAL validate_password.special_char_count = 1;
*/

-- Connection limits per user
ALTER USER 'app_read'@'%' WITH MAX_CONNECTIONS_PER_HOUR 1000;
ALTER USER 'app_write'@'%' WITH MAX_CONNECTIONS_PER_HOUR 2000;
ALTER USER 'app_admin'@'%' WITH MAX_CONNECTIONS_PER_HOUR 100;
ALTER USER 'app_etl'@'%' WITH MAX_CONNECTIONS_PER_HOUR 500;
ALTER USER 'app_monitor'@'%' WITH MAX_CONNECTIONS_PER_HOUR 200;
ALTER USER 'app_backup'@'%' WITH MAX_CONNECTIONS_PER_HOUR 50;

-- ============================================================================
-- Security Audit Functions
-- ============================================================================

USE myapp;

DELIMITER $$

-- Function to check user permissions
CREATE FUNCTION IF NOT EXISTS check_user_permissions(
    p_username VARCHAR(50),
    p_host VARCHAR(50),
    p_database VARCHAR(50)
) 
RETURNS TEXT
READS SQL DATA
BEGIN
    DECLARE v_permissions TEXT DEFAULT '';
    
    SELECT GROUP_CONCAT(
        DISTINCT CONCAT(privilege_type, ' ON ', table_schema, '.', table_name)
        SEPARATOR ', '
    ) INTO v_permissions
    FROM information_schema.table_privileges
    WHERE grantee = CONCAT("'", p_username, "'@'", p_host, "'")
    AND table_schema = p_database;
    
    RETURN COALESCE(v_permissions, 'No permissions found');
END$$

-- Procedure to audit role assignments
CREATE PROCEDURE IF NOT EXISTS audit_role_assignments()
BEGIN
    SELECT 
        user AS username,
        host,
        default_role,
        CASE 
            WHEN account_locked = 'Y' THEN 'LOCKED'
            ELSE 'ACTIVE'
        END AS account_status,
        password_expired,
        password_last_changed
    FROM mysql.user
    WHERE user LIKE 'app_%'
    ORDER BY user, host;
    
    -- Show role grants
    SELECT 
        from_user AS role_name,
        to_user AS username,
        to_host AS host,
        with_admin_option
    FROM mysql.role_edges
    WHERE to_user LIKE 'app_%'
    ORDER BY role_name, username;
END$$

DELIMITER ;

-- ============================================================================
-- Security Views
-- ============================================================================

-- View for monitoring active database connections
CREATE VIEW IF NOT EXISTS v_active_connections AS
SELECT 
    id AS connection_id,
    user AS username,
    host,
    db AS current_database,
    command,
    time AS connection_time_seconds,
    state,
    info AS current_query
FROM information_schema.processlist
WHERE user NOT IN ('system user', 'event_scheduler')
ORDER BY time DESC;

-- View for monitoring user privileges
CREATE VIEW IF NOT EXISTS v_user_privileges AS
SELECT DISTINCT
    grantee AS user_host,
    table_schema AS database_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges
WHERE grantee LIKE '%app_%'
UNION
SELECT DISTINCT
    grantee AS user_host,
    'GLOBAL' AS database_name,
    privilege_type,
    is_grantable
FROM information_schema.user_privileges
WHERE grantee LIKE '%app_%'
ORDER BY user_host, database_name, privilege_type;

-- ============================================================================
-- Sample Security Queries
-- ============================================================================
/*
-- Check permissions for a specific user
SELECT check_user_permissions('app_read', '%', 'myapp') AS permissions;

-- Audit all role assignments
CALL audit_role_assignments();

-- View active connections
SELECT * FROM v_active_connections;

-- View user privileges
SELECT * FROM v_user_privileges WHERE user_host LIKE '%app_read%';

-- Check for users with dangerous privileges
SELECT grantee, privilege_type 
FROM information_schema.user_privileges 
WHERE privilege_type IN ('CREATE USER', 'GRANT OPTION', 'SUPER', 'FILE', 'SHUTDOWN');
*/

-- ============================================================================
-- Security Hardening Recommendations
-- ============================================================================
/*
Additional security measures to implement:

1. Network Security:
   - Use SSL/TLS for all database connections
   - Implement firewall rules to restrict database access
   - Use VPN for administrative access

2. Authentication:
   - Consider external authentication (LDAP, Active Directory)
   - Implement multi-factor authentication for admin users
   - Regular password rotation

3. Monitoring:
   - Enable general query log for auditing (with log rotation)
   - Monitor failed login attempts
   - Set up alerts for privileged operations

4. Backup Security:
   - Encrypt backup files
   - Store backups in secure, separate location
   - Test backup restoration regularly

5. Regular Maintenance:
   - Review and audit user permissions quarterly
   - Remove unused user accounts
   - Update MySQL to latest secure version
   - Monitor security advisories

Example SSL configuration in my.cnf:
[mysqld]
ssl-ca=/path/to/ca-cert.pem
ssl-cert=/path/to/server-cert.pem
ssl-key=/path/to/server-key.pem
require_secure_transport=ON

[client]
ssl-ca=/path/to/ca-cert.pem
ssl-cert=/path/to/client-cert.pem
ssl-key=/path/to/client-key.pem
*/