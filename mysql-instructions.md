# MySQL Enterprise Architecture Guidelines

## Overview

This document provides comprehensive guidelines for designing and implementing enterprise-ready MySQL database architectures. It serves as the foundational reference for all MySQL projects, including schemas, scripts, configurations, and best practices.

## Architectural Principles

### 1. Database Design Principles
- **Normalization**: Use 3NF for OLTP systems to ensure data integrity
- **Denormalization**: Strategic denormalization for read-heavy OLAP workloads
- **Audit Trail**: Implement comprehensive audit logging for all critical tables
- **Security**: Role-based access control with principle of least privilege
- **Scalability**: Design for horizontal and vertical scaling from the start

### 2. Schema Organization
- **Logical Separation**: Separate schemas for different business domains
- **Environment Isolation**: Clear separation between dev, staging, and production
- **Version Control**: All schema changes must be versioned and scripted

## Directory Structure

```
mysql-project/
├── schemas/           # Database schemas and table definitions
│   ├── core/         # Core business tables
│   ├── audit/        # Audit and logging tables
│   ├── security/     # User roles and permissions
│   └── analytics/    # Data warehouse and reporting tables
├── scripts/          # Database scripts and procedures
│   ├── etl/          # Extract, Transform, Load scripts
│   ├── maintenance/  # Database maintenance scripts
│   └── migration/    # Schema migration scripts
├── config/           # Configuration files
│   ├── connection/   # Database connection configurations
│   └── performance/  # Performance tuning configurations
├── docs/             # Documentation
├── automation/       # Automated scripts and CI/CD
└── monitoring/       # Monitoring and alerting setup
```

## Foundational Components

### 1. Audit Logging Framework

Every enterprise database must implement comprehensive audit logging:

```sql
-- Audit table template
CREATE TABLE audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    operation_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    primary_key_value VARCHAR(255) NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(64) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    application VARCHAR(64),
    INDEX idx_table_operation (table_name, operation_type),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by)
);
```

### 2. Normalized Schema Example

```sql
-- Users table (normalized)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- User profiles (1:1 relationship)
CREATE TABLE user_profiles (
    profile_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    address TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
```

### 3. Denormalized Schema Example

```sql
-- Orders summary (denormalized for reporting)
CREATE TABLE orders_summary (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    customer_name VARCHAR(100), -- Denormalized from customers table
    customer_email VARCHAR(100), -- Denormalized from customers table
    order_date DATE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    item_count INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer (customer_id),
    INDEX idx_order_date (order_date),
    INDEX idx_status (status)
);
```

### 4. Role-Based Access Control

```sql
-- Create application-specific database users
CREATE USER 'app_read'@'%' IDENTIFIED BY 'secure_password_read';
CREATE USER 'app_write'@'%' IDENTIFIED BY 'secure_password_write';
CREATE USER 'app_admin'@'%' IDENTIFIED BY 'secure_password_admin';

-- Read-only role
CREATE ROLE 'read_only_role';
GRANT SELECT ON myapp.* TO 'read_only_role';

-- Read-write role
CREATE ROLE 'read_write_role';
GRANT SELECT, INSERT, UPDATE ON myapp.* TO 'read_write_role';

-- Admin role
CREATE ROLE 'admin_role';
GRANT ALL PRIVILEGES ON myapp.* TO 'admin_role';

-- Assign roles to users
GRANT 'read_only_role' TO 'app_read'@'%';
GRANT 'read_write_role' TO 'app_write'@'%';
GRANT 'admin_role' TO 'app_admin'@'%';
```

## ETL Framework

### ETL Process Template

```sql
-- ETL staging table example
CREATE TABLE staging_customer_data (
    staging_id INT AUTO_INCREMENT PRIMARY KEY,
    source_customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    raw_data JSON,
    processed_at TIMESTAMP NULL,
    error_message TEXT NULL,
    batch_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ETL stored procedure example
DELIMITER $$
CREATE PROCEDURE ProcessCustomerData(IN batch_id VARCHAR(50))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE staging_record_id INT;
    
    -- Cursor for unprocessed records
    DECLARE staging_cursor CURSOR FOR 
        SELECT staging_id FROM staging_customer_data 
        WHERE batch_id = batch_id AND processed_at IS NULL;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    OPEN staging_cursor;
    
    read_loop: LOOP
        FETCH staging_cursor INTO staging_record_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Process individual record here
        -- Update processed_at timestamp
        UPDATE staging_customer_data 
        SET processed_at = NOW() 
        WHERE staging_id = staging_record_id;
        
    END LOOP;
    
    CLOSE staging_cursor;
    COMMIT;
END$$
DELIMITER ;
```

## Connection Configuration Examples

### Python Connection Configuration

```python
# config/connection/mysql_config.py
import mysql.connector
from mysql.connector import pooling
import os
from typing import Optional

class MySQLConnectionManager:
    def __init__(self):
        self.connection_pool = None
        self._initialize_pool()
    
    def _initialize_pool(self):
        """Initialize MySQL connection pool"""
        config = {
            'user': os.getenv('MYSQL_USER', 'app_user'),
            'password': os.getenv('MYSQL_PASSWORD'),
            'host': os.getenv('MYSQL_HOST', 'localhost'),
            'port': int(os.getenv('MYSQL_PORT', 3306)),
            'database': os.getenv('MYSQL_DATABASE', 'myapp'),
            'pool_name': 'myapp_pool',
            'pool_size': int(os.getenv('MYSQL_POOL_SIZE', 10)),
            'pool_reset_session': True,
            'autocommit': False,
            'charset': 'utf8mb4',
            'collation': 'utf8mb4_unicode_ci'
        }
        
        self.connection_pool = pooling.MySQLConnectionPool(**config)
    
    def get_connection(self):
        """Get connection from pool"""
        return self.connection_pool.get_connection()
    
    def execute_query(self, query: str, params: Optional[tuple] = None):
        """Execute query with proper connection handling"""
        connection = None
        try:
            connection = self.get_connection()
            cursor = connection.cursor(dictionary=True)
            cursor.execute(query, params)
            
            if query.strip().upper().startswith('SELECT'):
                result = cursor.fetchall()
            else:
                connection.commit()
                result = cursor.rowcount
            
            return result
        except Exception as e:
            if connection:
                connection.rollback()
            raise e
        finally:
            if connection:
                connection.close()
```

### Node.js Connection Configuration

```javascript
// config/connection/mysql_config.js
const mysql = require('mysql2/promise');

class MySQLConnectionManager {
    constructor() {
        this.pool = null;
        this.initializePool();
    }
    
    initializePool() {
        this.pool = mysql.createPool({
            host: process.env.MYSQL_HOST || 'localhost',
            port: process.env.MYSQL_PORT || 3306,
            user: process.env.MYSQL_USER || 'app_user',
            password: process.env.MYSQL_PASSWORD,
            database: process.env.MYSQL_DATABASE || 'myapp',
            waitForConnections: true,
            connectionLimit: parseInt(process.env.MYSQL_POOL_SIZE) || 10,
            queueLimit: 0,
            charset: 'utf8mb4',
            timezone: '+00:00',
            acquireTimeout: 60000,
            timeout: 60000
        });
    }
    
    async executeQuery(query, params = []) {
        try {
            const [rows] = await this.pool.execute(query, params);
            return rows;
        } catch (error) {
            console.error('Database query error:', error);
            throw error;
        }
    }
    
    async getConnection() {
        return await this.pool.getConnection();
    }
    
    async close() {
        if (this.pool) {
            await this.pool.end();
        }
    }
}

module.exports = MySQLConnectionManager;
```

## Performance Optimization Guidelines

### Index Strategy
- Primary keys on all tables
- Foreign key indexes for join performance
- Composite indexes for multi-column queries
- Covering indexes for read-heavy queries

### Query Optimization
- Use EXPLAIN to analyze query execution plans
- Avoid SELECT * in production code
- Implement proper pagination with LIMIT and OFFSET
- Use prepared statements to prevent SQL injection

### Configuration Tuning
```ini
# my.cnf performance settings
[mysqld]
innodb_buffer_pool_size = 70% of RAM
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
query_cache_type = 1
query_cache_size = 64M
max_connections = 200
```

## Monitoring and Alerting

### Key Metrics to Monitor
- Connection count and utilization
- Query response times
- Slow query log analysis
- Disk I/O and storage usage
- Replication lag (if applicable)

### Alerting Thresholds
- Connection usage > 80%
- Query response time > 1 second
- Disk usage > 85%
- Replication lag > 30 seconds

## Backup and Recovery Strategy

### Backup Types
- **Full Backup**: Complete database backup (weekly)
- **Incremental Backup**: Changes since last backup (daily)
- **Binary Log Backup**: Transaction log backup (continuous)

### Recovery Procedures
- Point-in-time recovery using binary logs
- Table-level recovery for specific data corruption
- Cross-region backup for disaster recovery

## Security Best Practices

### Data Protection
- Encrypt data at rest and in transit
- Implement column-level encryption for sensitive data
- Regular security audits and penetration testing

### Access Control
- Principle of least privilege
- Regular user access reviews
- Multi-factor authentication for administrative access
- Network-level security with VPNs and firewalls

## Conclusion

This MySQL enterprise architecture framework provides a solid foundation for building scalable, secure, and maintainable database systems. All implementations should follow these guidelines and be adapted to specific business requirements while maintaining these core principles.