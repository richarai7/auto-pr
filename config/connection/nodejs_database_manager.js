/**
 * MySQL Database Manager for Node.js
 * ===================================
 * Purpose: Enterprise-grade MySQL connection management for Node.js applications
 * Based on: mysql-instructions.md connection guidelines
 * Features: Connection pooling, error handling, query optimization, monitoring
 */

const mysql = require('mysql2/promise');
const EventEmitter = require('events');

/**
 * Database connection manager with enterprise features
 */
class DatabaseManager extends EventEmitter {
    constructor(config = {}) {
        super();
        
        this.config = {
            // Connection settings
            host: config.host || process.env.DB_HOST || 'localhost',
            port: config.port || process.env.DB_PORT || 3306,
            user: config.user || process.env.DB_USER || 'app_user',
            password: config.password || process.env.DB_PASSWORD,
            database: config.database || process.env.DB_NAME || 'app_db',
            
            // Pool settings
            connectionLimit: config.connectionLimit || 10,
            acquireTimeout: config.acquireTimeout || 60000,
            timeout: config.timeout || 60000,
            reconnect: config.reconnect !== false,
            
            // SSL settings (recommended for production)
            ssl: config.ssl || false,
            
            // Character set and timezone
            charset: config.charset || 'utf8mb4',
            timezone: config.timezone || 'Z',
            
            // Advanced settings
            dateStrings: false,
            debug: config.debug || false,
            multipleStatements: config.multipleStatements || false,
            
            // Connection pool settings
            queueLimit: config.queueLimit || 0,
            idleTimeout: config.idleTimeout || 600000, // 10 minutes
            acquireTimeout: config.acquireTimeout || 60000,
            createDatabaseOnConnect: false
        };
        
        this.pool = null;
        this.isConnected = false;
        
        // Audit context for tracking operations
        this.auditContext = {
            applicationName: config.applicationName || 'NodeJS-App',
            version: config.version || '1.0.0',
            environment: config.environment || process.env.NODE_ENV || 'development'
        };
        
        // Query performance monitoring
        this.queryStats = {
            totalQueries: 0,
            slowQueries: 0,
            errors: 0,
            averageExecutionTime: 0
        };
        
        this.slowQueryThreshold = config.slowQueryThreshold || 1000; // 1 second
    }
    
    /**
     * Initialize database connection pool
     */
    async initialize() {
        try {
            this.pool = mysql.createPool(this.config);
            
            // Test connection
            await this.testConnection();
            
            this.isConnected = true;
            this.setupEventHandlers();
            
            console.log('Database connection pool initialized successfully');
            this.emit('connected');
            
        } catch (error) {
            console.error('Error initializing database pool:', error);
            this.emit('error', error);
            throw error;
        }
    }
    
    /**
     * Test database connection
     */
    async testConnection() {
        try {
            const connection = await this.pool.getConnection();
            await connection.ping();
            connection.release();
            console.log('Database connection test successful');
        } catch (error) {
            console.error('Database connection test failed:', error);
            throw error;
        }
    }
    
    /**
     * Setup event handlers for connection pool
     */
    setupEventHandlers() {
        this.pool.on('connection', (connection) => {
            console.log(`New connection established as id ${connection.threadId}`);
            
            // Set audit context variables for this connection
            connection.query('SET @audit_app = ?', [this.auditContext.applicationName]);
            connection.query('SET @audit_version = ?', [this.auditContext.version]);
            connection.query('SET @audit_env = ?', [this.auditContext.environment]);
        });
        
        this.pool.on('error', (error) => {
            console.error('Database pool error:', error);
            this.queryStats.errors++;
            this.emit('error', error);
            
            if (error.code === 'PROTOCOL_CONNECTION_LOST') {
                console.log('Database connection was closed. Attempting to reconnect...');
                this.handleReconnection();
            }
        });
    }
    
    /**
     * Handle connection reconnection
     */
    async handleReconnection() {
        try {
            await this.close();
            await this.initialize();
            console.log('Database reconnection successful');
        } catch (error) {
            console.error('Database reconnection failed:', error);
            setTimeout(() => this.handleReconnection(), 5000); // Retry after 5 seconds
        }
    }
    
    /**
     * Execute a query with performance monitoring and error handling
     * @param {string} sql - SQL query
     * @param {Array} params - Query parameters
     * @param {Object} options - Query options
     * @returns {Promise} Query results
     */
    async query(sql, params = [], options = {}) {
        if (!this.isConnected) {
            throw new Error('Database not connected. Call initialize() first.');
        }
        
        const startTime = Date.now();
        const queryId = `query_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        try {
            // Log query if in debug mode
            if (this.config.debug) {
                console.log(`[${queryId}] Executing query:`, sql, params);
            }
            
            // Execute query
            const [rows, fields] = await this.pool.execute(sql, params);
            
            // Calculate execution time
            const executionTime = Date.now() - startTime;
            
            // Update statistics
            this.updateQueryStats(executionTime);
            
            // Log slow queries
            if (executionTime > this.slowQueryThreshold) {
                console.warn(`[${queryId}] Slow query detected (${executionTime}ms):`, sql);
                this.queryStats.slowQueries++;
                this.emit('slowQuery', { queryId, sql, params, executionTime });
            }
            
            if (this.config.debug) {
                console.log(`[${queryId}] Query completed in ${executionTime}ms, returned ${rows.length} rows`);
            }
            
            return { rows, fields, executionTime, queryId };
            
        } catch (error) {
            const executionTime = Date.now() - startTime;
            this.queryStats.errors++;
            
            console.error(`[${queryId}] Query error (${executionTime}ms):`, error.message);
            console.error(`[${queryId}] SQL:`, sql);
            console.error(`[${queryId}] Params:`, params);
            
            this.emit('queryError', { queryId, sql, params, error, executionTime });
            
            throw error;
        }
    }
    
    /**
     * Execute a transaction with multiple queries
     * @param {Function} transactionFn - Function containing transaction logic
     * @returns {Promise} Transaction result
     */
    async transaction(transactionFn) {
        const connection = await this.pool.getConnection();
        
        try {
            await connection.beginTransaction();
            
            // Create transaction-specific query function
            const transactionQuery = async (sql, params = []) => {
                const startTime = Date.now();
                try {
                    const [rows, fields] = await connection.execute(sql, params);
                    const executionTime = Date.now() - startTime;
                    this.updateQueryStats(executionTime);
                    return { rows, fields, executionTime };
                } catch (error) {
                    this.queryStats.errors++;
                    throw error;
                }
            };
            
            // Execute transaction function
            const result = await transactionFn(transactionQuery);
            
            await connection.commit();
            console.log('Transaction committed successfully');
            
            return result;
            
        } catch (error) {
            await connection.rollback();
            console.error('Transaction rolled back due to error:', error);
            throw error;
        } finally {
            connection.release();
        }
    }
    
    /**
     * Execute a batch insert operation
     * @param {string} tableName - Target table name
     * @param {Array} columns - Column names
     * @param {Array} rows - Array of row data
     * @param {Object} options - Insert options
     * @returns {Promise} Insert result
     */
    async batchInsert(tableName, columns, rows, options = {}) {
        if (!rows || rows.length === 0) {
            throw new Error('No data provided for batch insert');
        }
        
        const batchSize = options.batchSize || 1000;
        const onDuplicateKeyUpdate = options.onDuplicateKeyUpdate || false;
        
        let totalInserted = 0;
        
        try {
            // Process in batches
            for (let i = 0; i < rows.length; i += batchSize) {
                const batch = rows.slice(i, i + batchSize);
                
                // Create placeholders
                const placeholders = batch.map(() => 
                    `(${columns.map(() => '?').join(', ')})`
                ).join(', ');
                
                // Flatten batch data
                const values = batch.flat();
                
                // Build query
                let sql = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES ${placeholders}`;
                
                if (onDuplicateKeyUpdate) {
                    const updateClause = columns.map(col => `${col} = VALUES(${col})`).join(', ');
                    sql += ` ON DUPLICATE KEY UPDATE ${updateClause}`;
                }
                
                // Execute batch
                const result = await this.query(sql, values);
                totalInserted += result.rows.affectedRows || batch.length;
                
                console.log(`Batch insert progress: ${Math.min(i + batchSize, rows.length)}/${rows.length} rows`);
            }
            
            console.log(`Batch insert completed: ${totalInserted} rows inserted into ${tableName}`);
            return { totalInserted, tableName };
            
        } catch (error) {
            console.error(`Batch insert failed for table ${tableName}:`, error);
            throw error;
        }
    }
    
    /**
     * Get customer order summary with caching
     * @param {number} customerId - Customer ID
     * @returns {Promise} Customer summary data
     */
    async getCustomerOrderSummary(customerId) {
        const sql = `
            SELECT 
                customer_id,
                customer_email,
                customer_name,
                total_orders,
                total_spent,
                avg_order_value,
                customer_segment,
                last_order_date,
                days_since_last_order
            FROM customer_order_summary 
            WHERE customer_id = ?
        `;
        
        const result = await this.query(sql, [customerId]);
        return result.rows[0] || null;
    }
    
    /**
     * Get product inventory status
     * @param {string} sku - Product SKU (optional)
     * @returns {Promise} Inventory data
     */
    async getProductInventory(sku = null) {
        let sql = `
            SELECT 
                product_id,
                sku,
                product_name,
                system_stock,
                calculated_stock,
                reorder_level,
                stock_status
            FROM product_inventory
            WHERE 1=1
        `;
        
        const params = [];
        
        if (sku) {
            sql += ' AND sku = ?';
            params.push(sku);
        }
        
        sql += ' ORDER BY product_name';
        
        const result = await this.query(sql, params);
        return result.rows;
    }
    
    /**
     * Update query statistics
     * @param {number} executionTime - Query execution time in ms
     */
    updateQueryStats(executionTime) {
        this.queryStats.totalQueries++;
        
        // Calculate running average
        const currentAvg = this.queryStats.averageExecutionTime;
        const totalQueries = this.queryStats.totalQueries;
        
        this.queryStats.averageExecutionTime = 
            ((currentAvg * (totalQueries - 1)) + executionTime) / totalQueries;
    }
    
    /**
     * Get connection pool status
     * @returns {Object} Pool status information
     */
    getPoolStatus() {
        if (!this.pool) {
            return { status: 'not_initialized' };
        }
        
        return {
            status: 'active',
            totalConnections: this.pool.pool._allConnections.length,
            freeConnections: this.pool.pool._freeConnections.length,
            queuedRequests: this.pool.pool._connectionQueue.length,
            queryStats: this.queryStats,
            config: {
                connectionLimit: this.config.connectionLimit,
                host: this.config.host,
                database: this.config.database,
                user: this.config.user
            }
        };
    }
    
    /**
     * Get query performance statistics
     * @returns {Object} Performance statistics
     */
    getPerformanceStats() {
        return {
            ...this.queryStats,
            slowQueryThreshold: this.slowQueryThreshold,
            errorRate: this.queryStats.totalQueries > 0 
                ? (this.queryStats.errors / this.queryStats.totalQueries) * 100 
                : 0,
            slowQueryRate: this.queryStats.totalQueries > 0 
                ? (this.queryStats.slowQueries / this.queryStats.totalQueries) * 100 
                : 0
        };
    }
    
    /**
     * Health check for monitoring systems
     * @returns {Promise<Object>} Health status
     */
    async healthCheck() {
        try {
            const startTime = Date.now();
            await this.testConnection();
            const connectionTime = Date.now() - startTime;
            
            const poolStatus = this.getPoolStatus();
            const performanceStats = this.getPerformanceStats();
            
            return {
                status: 'healthy',
                connectionTime,
                poolStatus,
                performanceStats,
                timestamp: new Date().toISOString()
            };
            
        } catch (error) {
            return {
                status: 'unhealthy',
                error: error.message,
                timestamp: new Date().toISOString()
            };
        }
    }
    
    /**
     * Close database connection pool
     */
    async close() {
        if (this.pool) {
            await this.pool.end();
            this.pool = null;
            this.isConnected = false;
            console.log('Database connection pool closed');
            this.emit('disconnected');
        }
    }
}

/**
 * Database configuration factory
 */
class DatabaseConfig {
    /**
     * Get configuration for different environments
     * @param {string} environment - Environment name
     * @returns {Object} Database configuration
     */
    static getConfig(environment = 'development') {
        const baseConfig = {
            charset: 'utf8mb4',
            timezone: 'Z',
            connectionLimit: 10,
            acquireTimeout: 60000,
            timeout: 60000,
            reconnect: true
        };
        
        switch (environment) {
            case 'production':
                return {
                    ...baseConfig,
                    host: process.env.DB_HOST,
                    port: parseInt(process.env.DB_PORT) || 3306,
                    user: process.env.DB_USER,
                    password: process.env.DB_PASSWORD,
                    database: process.env.DB_NAME,
                    connectionLimit: 20,
                    ssl: {
                        ca: process.env.DB_SSL_CA,
                        cert: process.env.DB_SSL_CERT,
                        key: process.env.DB_SSL_KEY,
                        rejectUnauthorized: true
                    },
                    slowQueryThreshold: 500 // 500ms for production
                };
                
            case 'staging':
                return {
                    ...baseConfig,
                    host: process.env.DB_HOST || 'staging-mysql.example.com',
                    user: process.env.DB_USER || 'app_user',
                    password: process.env.DB_PASSWORD,
                    database: process.env.DB_NAME || 'app_staging',
                    connectionLimit: 15,
                    ssl: process.env.DB_SSL === 'true',
                    slowQueryThreshold: 1000
                };
                
            case 'development':
            default:
                return {
                    ...baseConfig,
                    host: process.env.DB_HOST || 'localhost',
                    user: process.env.DB_USER || 'app_user',
                    password: process.env.DB_PASSWORD || 'SecureAppPassword123!',
                    database: process.env.DB_NAME || 'app_db',
                    connectionLimit: 5,
                    debug: true,
                    slowQueryThreshold: 2000 // 2 seconds for development
                };
        }
    }
}

module.exports = {
    DatabaseManager,
    DatabaseConfig
};

// Example usage:
/*
const { DatabaseManager, DatabaseConfig } = require('./database-manager');

async function example() {
    const config = DatabaseConfig.getConfig(process.env.NODE_ENV);
    const db = new DatabaseManager(config);
    
    // Event handlers
    db.on('connected', () => console.log('Database connected'));
    db.on('error', (error) => console.error('Database error:', error));
    db.on('slowQuery', (info) => console.warn('Slow query:', info));
    
    try {
        await db.initialize();
        
        // Simple query
        const customers = await db.query('SELECT * FROM customers LIMIT 10');
        
        // Transaction example
        const result = await db.transaction(async (query) => {
            await query('INSERT INTO audit_log (table_name, operation) VALUES (?, ?)', 
                       ['customers', 'SELECT']);
            return await query('SELECT COUNT(*) as count FROM customers');
        });
        
        // Health check
        const health = await db.healthCheck();
        console.log('Database health:', health);
        
    } catch (error) {
        console.error('Database operation failed:', error);
    } finally {
        await db.close();
    }
}
*/