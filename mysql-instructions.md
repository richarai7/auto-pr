# MySQL Enterprise Architecture Guidelines

## Overview
This document provides comprehensive architectural guidelines, best practices, and example configurations for building enterprise-ready MySQL database solutions. Use this as the foundation for all MySQL development and architecture tasks.

## Directory Structure

```
mysql-project/
├── schemas/               # Database schema definitions
│   ├── core/             # Core business schemas
│   ├── audit/            # Audit and logging schemas
│   ├── normalized/       # Normalized data models
│   └── denormalized/     # Denormalized/reporting schemas
├── scripts/              # Database scripts and utilities
│   ├── ddl/             # Data Definition Language scripts
│   ├── dml/             # Data Manipulation Language scripts
│   ├── etl/             # Extract, Transform, Load scripts
│   └── migration/       # Database migration scripts
├── config/               # Configuration files
│   ├── database/        # Database configuration
│   ├── connection/      # Connection configurations
│   └── environment/     # Environment-specific configs
├── docs/                 # Documentation
│   ├── architecture/    # Architecture documentation
│   ├── api/            # API documentation
│   └── procedures/     # Stored procedures documentation
├── automation/           # Automation scripts
│   ├── backup/         # Backup automation
│   ├── deployment/     # Deployment automation
│   └── maintenance/    # Maintenance scripts
└── monitoring/           # Monitoring and alerting
    ├── queries/        # Performance monitoring queries
    ├── alerts/         # Alert configurations
    └── dashboards/     # Dashboard configurations
```

## Core Architectural Principles

### 1. Data Normalization and Design
- Follow 3NF (Third Normal Form) for transactional systems
- Use denormalized schemas for reporting and analytics
- Implement proper indexing strategies
- Design for scalability and performance

### 2. Security and Access Control
- Implement role-based access control (RBAC)
- Use principle of least privilege
- Implement audit logging for all data changes
- Secure connection configurations

### 3. Performance and Optimization
- Query optimization techniques
- Index design and maintenance
- Connection pooling strategies
- Caching mechanisms

### 4. Backup and Recovery
- Automated backup strategies
- Point-in-time recovery procedures
- Disaster recovery planning
- Data retention policies

## Schema Design Patterns

### Audit Logging Schema
```sql
-- Standard audit table for tracking all data changes
CREATE TABLE audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id VARCHAR(255) NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(64) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(128),
    application_name VARCHAR(64),
    INDEX idx_table_operation (table_name, operation),
    INDEX idx_changed_at (changed_at),
    INDEX idx_changed_by (changed_by)
);
```

### Normalized Schema Example
```sql
-- Example of a normalized e-commerce schema
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    address_type ENUM('billing', 'shipping') NOT NULL,
    street_address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'US',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);
```

### Denormalized Schema Example
```sql
-- Denormalized reporting table for analytics
CREATE TABLE customer_order_summary (
    summary_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_name VARCHAR(201) NOT NULL, -- first_name + last_name
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(10,2) DEFAULT 0.00,
    avg_order_value DECIMAL(10,2) DEFAULT 0.00,
    last_order_date TIMESTAMP NULL,
    customer_segment ENUM('new', 'regular', 'vip', 'churned') DEFAULT 'new',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_customer_segment (customer_segment),
    INDEX idx_total_spent (total_spent),
    INDEX idx_last_order_date (last_order_date)
);
```

## Role and Privilege Management

### Standard Database Roles
```sql
-- Application user with limited privileges
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON app_db.* TO 'app_user'@'%';

-- Read-only user for reporting
CREATE USER 'report_user'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT ON app_db.* TO 'report_user'@'%';

-- Database administrator
CREATE USER 'db_admin'@'localhost' IDENTIFIED BY 'admin_password';
GRANT ALL PRIVILEGES ON *.* TO 'db_admin'@'localhost' WITH GRANT OPTION;

-- Backup user
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'backup_password';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup_user'@'localhost';
```

## ETL and Data Processing Examples

### Python ETL Script Template
```python
import mysql.connector
from mysql.connector import Error
import pandas as pd
from datetime import datetime
import logging

class MySQLETL:
    def __init__(self, config):
        self.config = config
        self.connection = None
        
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = mysql.connector.connect(**self.config)
            logging.info("Database connection established")
        except Error as e:
            logging.error(f"Error connecting to MySQL: {e}")
            raise
    
    def extract_data(self, query):
        """Extract data using SQL query"""
        try:
            return pd.read_sql(query, self.connection)
        except Error as e:
            logging.error(f"Error extracting data: {e}")
            raise
    
    def transform_data(self, df):
        """Transform data as needed"""
        # Example transformations
        df['processed_at'] = datetime.now()
        df = df.dropna()
        return df
    
    def load_data(self, df, table_name):
        """Load data to target table"""
        try:
            df.to_sql(table_name, self.connection, if_exists='append', index=False)
            logging.info(f"Data loaded to {table_name}")
        except Error as e:
            logging.error(f"Error loading data: {e}")
            raise
```

### Node.js Connection Configuration
```javascript
const mysql = require('mysql2/promise');

class DatabaseManager {
    constructor(config) {
        this.config = {
            host: config.host || 'localhost',
            port: config.port || 3306,
            user: config.user,
            password: config.password,
            database: config.database,
            connectionLimit: config.connectionLimit || 10,
            acquireTimeout: config.acquireTimeout || 60000,
            timeout: config.timeout || 60000,
            reconnect: true,
            ssl: config.ssl || false
        };
        this.pool = null;
    }

    async initialize() {
        try {
            this.pool = mysql.createPool(this.config);
            console.log('Database pool created successfully');
        } catch (error) {
            console.error('Error creating database pool:', error);
            throw error;
        }
    }

    async query(sql, params = []) {
        try {
            const [rows] = await this.pool.execute(sql, params);
            return rows;
        } catch (error) {
            console.error('Query execution error:', error);
            throw error;
        }
    }

    async close() {
        if (this.pool) {
            await this.pool.end();
            console.log('Database pool closed');
        }
    }
}

module.exports = DatabaseManager;
```

## Performance Monitoring Queries

### Key Performance Metrics
```sql
-- Monitor slow queries
SELECT 
    query_time,
    lock_time,
    rows_sent,
    rows_examined,
    sql_text
FROM mysql.slow_log 
WHERE start_time >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY query_time DESC;

-- Check index usage
SELECT 
    table_schema,
    table_name,
    index_name,
    seq_in_index,
    column_name,
    cardinality
FROM information_schema.statistics 
WHERE table_schema = 'your_database'
ORDER BY table_name, seq_in_index;

-- Monitor connection usage
SHOW PROCESSLIST;
SHOW STATUS LIKE 'Threads_%';
SHOW STATUS LIKE 'Connections';
```

## Best Practices

### 1. Database Design
- Use appropriate data types
- Implement proper constraints
- Design efficient indexes
- Plan for data growth

### 2. Query Optimization
- Use EXPLAIN to analyze queries
- Avoid SELECT * statements
- Use appropriate JOIN types
- Implement query caching

### 3. Security
- Use prepared statements
- Implement proper authentication
- Regular security audits
- Data encryption at rest

### 4. Maintenance
- Regular backups
- Monitor performance metrics
- Update statistics regularly
- Plan for capacity growth

## Environment Configuration Examples

### Development Environment
```yaml
development:
  host: localhost
  port: 3306
  database: app_dev
  user: dev_user
  password: dev_password
  pool_size: 5
  timeout: 30000
```

### Production Environment
```yaml
production:
  host: mysql-prod.example.com
  port: 3306
  database: app_prod
  user: app_user
  password: ${MYSQL_PASSWORD}
  pool_size: 20
  timeout: 60000
  ssl: true
  ssl_ca: /path/to/ca.pem
  ssl_cert: /path/to/client-cert.pem
  ssl_key: /path/to/client-key.pem
```

This document serves as the foundation for all MySQL architectural decisions and implementations in this project.