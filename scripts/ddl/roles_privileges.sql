-- =============================================================================
-- Database Roles and Privileges Setup
-- =============================================================================
-- Purpose: Implement role-based access control (RBAC) following security best practices
-- Based on: mysql-instructions.md security guidelines
-- Security Principle: Least privilege access
-- =============================================================================

-- Drop users if they exist (for clean setup)
DROP USER IF EXISTS 'app_user'@'%';
DROP USER IF EXISTS 'app_user'@'localhost';
DROP USER IF EXISTS 'report_user'@'%';
DROP USER IF EXISTS 'report_user'@'localhost';
DROP USER IF EXISTS 'etl_user'@'%';
DROP USER IF EXISTS 'etl_user'@'localhost';
DROP USER IF EXISTS 'backup_user'@'localhost';
DROP USER IF EXISTS 'monitoring_user'@'localhost';
DROP USER IF EXISTS 'db_admin'@'localhost';
DROP USER IF EXISTS 'api_readonly'@'%';
DROP USER IF EXISTS 'analytics_user'@'%';

-- =============================================================================
-- 1. Application User (Primary application database access)
-- =============================================================================
-- Used by: Main application servers
-- Permissions: CRUD operations on application tables, no DDL
CREATE USER 'app_user'@'%' IDENTIFIED BY 'SecureAppPassword123!';
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'SecureAppPassword123!';

-- Grant basic application permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.customers TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.addresses TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.orders TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.order_items TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.products TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.categories TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.inventory_movements TO 'app_user'@'%';

-- Grant audit logging permissions
GRANT INSERT ON app_db.audit_log TO 'app_user'@'%';
GRANT SELECT, INSERT, UPDATE ON app_db.audit_config TO 'app_user'@'%';

-- Grant access to views
GRANT SELECT ON app_db.audit_trail TO 'app_user'@'%';
GRANT SELECT ON app_db.product_inventory TO 'app_user'@'%';

-- Allow stored procedure execution for business logic
GRANT EXECUTE ON app_db.* TO 'app_user'@'%';

-- Copy permissions to localhost
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.customers TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.addresses TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.orders TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.order_items TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.products TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.categories TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.inventory_movements TO 'app_user'@'localhost';
GRANT INSERT ON app_db.audit_log TO 'app_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON app_db.audit_config TO 'app_user'@'localhost';
GRANT SELECT ON app_db.audit_trail TO 'app_user'@'localhost';
GRANT SELECT ON app_db.product_inventory TO 'app_user'@'localhost';
GRANT EXECUTE ON app_db.* TO 'app_user'@'localhost';

-- =============================================================================
-- 2. Reporting User (Read-only access for reports and analytics)
-- =============================================================================
-- Used by: Business intelligence tools, reporting applications
-- Permissions: Read-only access to all tables and views
CREATE USER 'report_user'@'%' IDENTIFIED BY 'SecureReportPassword123!';
CREATE USER 'report_user'@'localhost' IDENTIFIED BY 'SecureReportPassword123!';

-- Grant read-only access to all application tables
GRANT SELECT ON app_db.* TO 'report_user'@'%';
GRANT SELECT ON app_db.* TO 'report_user'@'localhost';

-- Special permissions for performance schema (monitoring)
GRANT SELECT ON performance_schema.* TO 'report_user'@'%';
GRANT SELECT ON performance_schema.* TO 'report_user'@'localhost';

-- =============================================================================
-- 3. ETL User (Extract, Transform, Load operations)
-- =============================================================================
-- Used by: Data pipeline processes, batch jobs
-- Permissions: Full access to staging tables, read access to source tables
CREATE USER 'etl_user'@'%' IDENTIFIED BY 'SecureETLPassword123!';
CREATE USER 'etl_user'@'localhost' IDENTIFIED BY 'SecureETLPassword123!';

-- Read access to source data
GRANT SELECT ON app_db.customers TO 'etl_user'@'%';
GRANT SELECT ON app_db.orders TO 'etl_user'@'%';
GRANT SELECT ON app_db.order_items TO 'etl_user'@'%';
GRANT SELECT ON app_db.products TO 'etl_user'@'%';
GRANT SELECT ON app_db.categories TO 'etl_user'@'%';

-- Full access to denormalized/reporting tables
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.customer_order_summary TO 'etl_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.product_performance_summary TO 'etl_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.daily_sales_summary TO 'etl_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.customer_cohort_analysis TO 'etl_user'@'%';

-- Temporary table permissions for ETL processes
GRANT CREATE TEMPORARY TABLES ON app_db.* TO 'etl_user'@'%';

-- Copy permissions to localhost
GRANT SELECT ON app_db.customers TO 'etl_user'@'localhost';
GRANT SELECT ON app_db.orders TO 'etl_user'@'localhost';
GRANT SELECT ON app_db.order_items TO 'etl_user'@'localhost';
GRANT SELECT ON app_db.products TO 'etl_user'@'localhost';
GRANT SELECT ON app_db.categories TO 'etl_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.customer_order_summary TO 'etl_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.product_performance_summary TO 'etl_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.daily_sales_summary TO 'etl_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON app_db.customer_cohort_analysis TO 'etl_user'@'localhost';
GRANT CREATE TEMPORARY TABLES ON app_db.* TO 'etl_user'@'localhost';

-- =============================================================================
-- 4. Analytics User (Specialized read-only for data science)
-- =============================================================================
-- Used by: Data scientists, advanced analytics tools
-- Permissions: Read-only with special analytics permissions
CREATE USER 'analytics_user'@'%' IDENTIFIED BY 'SecureAnalyticsPassword123!';

-- Read access to all tables
GRANT SELECT ON app_db.* TO 'analytics_user'@'%';

-- Performance schema access for query optimization
GRANT SELECT ON performance_schema.* TO 'analytics_user'@'%';

-- Information schema access for metadata analysis
GRANT SELECT ON information_schema.* TO 'analytics_user'@'%';

-- =============================================================================
-- 5. API Read-Only User (External API access)
-- =============================================================================
-- Used by: Third-party integrations, public APIs
-- Permissions: Very limited read-only access
CREATE USER 'api_readonly'@'%' IDENTIFIED BY 'SecureAPIPassword123!';

-- Limited read access to specific tables only
GRANT SELECT (product_id, sku, product_name, price, is_active) ON app_db.products TO 'api_readonly'@'%';
GRANT SELECT (category_id, category_name, is_active) ON app_db.categories TO 'api_readonly'@'%';
GRANT SELECT ON app_db.product_inventory TO 'api_readonly'@'%';

-- =============================================================================
-- 6. Backup User (Database backup operations)
-- =============================================================================
-- Used by: Backup scripts and tools
-- Permissions: Special backup-related permissions
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'SecureBackupPassword123!';

-- Required permissions for consistent backups
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, PROCESS ON *.* TO 'backup_user'@'localhost';
GRANT REPLICATION CLIENT ON *.* TO 'backup_user'@'localhost';

-- For InnoDB hot backup
GRANT BACKUP_ADMIN ON *.* TO 'backup_user'@'localhost';

-- =============================================================================
-- 7. Monitoring User (Performance monitoring and health checks)
-- =============================================================================
-- Used by: Monitoring tools, health check scripts
-- Permissions: Read-only access to system information
CREATE USER 'monitoring_user'@'localhost' IDENTIFIED BY 'SecureMonitoringPassword123!';

-- System monitoring permissions
GRANT SELECT ON performance_schema.* TO 'monitoring_user'@'localhost';
GRANT SELECT ON information_schema.* TO 'monitoring_user'@'localhost';
GRANT PROCESS ON *.* TO 'monitoring_user'@'localhost';
GRANT REPLICATION CLIENT ON *.* TO 'monitoring_user'@'localhost';

-- Basic health check access
GRANT SELECT ON app_db.audit_config TO 'monitoring_user'@'localhost';

-- =============================================================================
-- 8. Database Administrator (Full administrative access)
-- =============================================================================
-- Used by: Database administrators, emergency access
-- Permissions: Full administrative privileges
CREATE USER 'db_admin'@'localhost' IDENTIFIED BY 'SecureAdminPassword123!';

-- Full administrative access
GRANT ALL PRIVILEGES ON *.* TO 'db_admin'@'localhost' WITH GRANT OPTION;

-- =============================================================================
-- Security Configurations
-- =============================================================================

-- Set password validation (if available)
-- INSTALL COMPONENT 'file://component_validate_password';
-- SET GLOBAL validate_password.policy = STRONG;
-- SET GLOBAL validate_password.length = 12;

-- Connection limits to prevent abuse
ALTER USER 'app_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 1000;
ALTER USER 'app_user'@'localhost' WITH MAX_CONNECTIONS_PER_HOUR 1000;
ALTER USER 'report_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 200;
ALTER USER 'report_user'@'localhost' WITH MAX_CONNECTIONS_PER_HOUR 200;
ALTER USER 'etl_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 50;
ALTER USER 'etl_user'@'localhost' WITH MAX_CONNECTIONS_PER_HOUR 50;
ALTER USER 'api_readonly'@'%' WITH MAX_CONNECTIONS_PER_HOUR 500;
ALTER USER 'analytics_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 100;

-- Password expiration policy
ALTER USER 'app_user'@'%' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'app_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'report_user'@'%' PASSWORD EXPIRE INTERVAL 180 DAY;
ALTER USER 'report_user'@'localhost' PASSWORD EXPIRE INTERVAL 180 DAY;
ALTER USER 'db_admin'@'localhost' PASSWORD EXPIRE INTERVAL 60 DAY;

-- =============================================================================
-- Verification Queries
-- =============================================================================

-- Show all users and their hosts
SELECT User, Host, account_locked, password_expired FROM mysql.user 
WHERE User IN ('app_user', 'report_user', 'etl_user', 'backup_user', 'monitoring_user', 'db_admin', 'api_readonly', 'analytics_user')
ORDER BY User, Host;

-- Show grants for application user
SHOW GRANTS FOR 'app_user'@'%';

-- =============================================================================
-- Security Best Practices Comments
-- =============================================================================

/*
SECURITY BEST PRACTICES IMPLEMENTED:

1. Principle of Least Privilege:
   - Each user has only the minimum permissions needed
   - Specific table-level permissions instead of database-wide access
   - Column-level restrictions for API users

2. Strong Password Policy:
   - Complex passwords with minimum 12 characters
   - Regular password expiration
   - Different passwords for each user type

3. Connection Limits:
   - Per-hour connection limits to prevent resource abuse
   - Different limits based on user type and expected usage

4. Network Access Control:
   - Localhost-only access for administrative users
   - Wildcard (%) access only for application users that need it
   - Separate users for different network access patterns

5. Audit and Monitoring:
   - Special monitoring user with limited system access
   - Audit logging permissions properly configured
   - No DDL permissions for application users

6. Backup Security:
   - Dedicated backup user with specific backup permissions
   - No unnecessary privileges beyond backup requirements

7. Role Separation:
   - Different users for different functions (app, reporting, ETL, etc.)
   - No shared accounts between different system components

ADDITIONAL SECURITY RECOMMENDATIONS:

1. Use SSL/TLS connections in production
2. Implement certificate-based authentication where possible
3. Regular password rotation
4. Monitor failed login attempts
5. Use encrypted connections for all remote access
6. Implement IP whitelist restrictions in production
7. Regular privilege audits
8. Use dedicated service accounts for each application

*/