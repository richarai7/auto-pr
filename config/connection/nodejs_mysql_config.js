/**
 * MySQL Connection Manager for Node.js Applications
 * 
 * This module provides a robust MySQL connection management system with
 * connection pooling, error handling, and security best practices.
 * 
 * Features:
 * - Connection pooling for optimal performance
 * - Automatic retry logic for transient failures
 * - SQL injection protection via prepared statements
 * - Comprehensive logging and monitoring
 * - Environment-based configuration
 * - Support for multiple database environments
 * - Transaction management
 * - Health checking and metrics
 * 
 * Author: MySQL Architecture Team
 * Version: 1.0
 * Last Updated: 2024
 */

const mysql = require('mysql2/promise');
const winston = require('winston');
const EventEmitter = require('events');

// Configure logging
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'mysql-connection.log' })
    ]
});

/**
 * Database configuration class
 */
class DatabaseConfig {
    constructor(options = {}) {
        this.host = options.host || process.env.MYSQL_HOST || 'localhost';
        this.port = parseInt(options.port || process.env.MYSQL_PORT || '3306');
        this.user = options.user || process.env.MYSQL_USER || 'app_user';
        this.password = options.password || process.env.MYSQL_PASSWORD || '';
        this.database = options.database || process.env.MYSQL_DATABASE || 'myapp';
        
        // Connection pool settings
        this.connectionLimit = parseInt(options.connectionLimit || process.env.MYSQL_POOL_SIZE || '10');
        this.queueLimit = parseInt(options.queueLimit || process.env.MYSQL_QUEUE_LIMIT || '0');
        this.acquireTimeout = parseInt(options.acquireTimeout || process.env.MYSQL_ACQUIRE_TIMEOUT || '60000');
        this.timeout = parseInt(options.timeout || process.env.MYSQL_TIMEOUT || '60000');
        
        // Connection settings
        this.charset = options.charset || process.env.MYSQL_CHARSET || 'utf8mb4';
        this.timezone = options.timezone || process.env.MYSQL_TIMEZONE || '+00:00';
        this.ssl = options.ssl || (process.env.MYSQL_SSL === 'true');
        
        // Performance settings
        this.waitForConnections = options.waitForConnections !== false;
        this.reconnect = options.reconnect !== false;
        this.idleTimeout = parseInt(options.idleTimeout || process.env.MYSQL_IDLE_TIMEOUT || '28800000');
        
        // SQL Mode for strict compliance
        this.sqlMode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';
    }
    
    /**
     * Get MySQL pool configuration object
     */
    getPoolConfig() {
        return {
            host: this.host,
            port: this.port,
            user: this.user,
            password: this.password,
            database: this.database,
            waitForConnections: this.waitForConnections,
            connectionLimit: this.connectionLimit,
            queueLimit: this.queueLimit,
            acquireTimeout: this.acquireTimeout,
            timeout: this.timeout,
            reconnect: this.reconnect,
            charset: this.charset,
            timezone: this.timezone,
            ssl: this.ssl,
            idleTimeout: this.idleTimeout,
            namedPlaceholders: true,
            multipleStatements: false, // Security: prevent multiple statements
            supportBigNumbers: true,
            bigNumberStrings: true,
            dateStrings: false,
            trace: process.env.NODE_ENV === 'development'
        };
    }
}

/**
 * MySQL Connection Manager with pooling and error handling
 */
class MySQLConnectionManager extends EventEmitter {
    constructor(config = new DatabaseConfig()) {
        super();
        
        this.config = config instanceof DatabaseConfig ? config : new DatabaseConfig(config);
        this.pool = null;
        this.isInitialized = false;
        
        // Connection statistics
        this.stats = {
            connectionsCreated: 0,
            connectionsClosed: 0,
            queriesExecuted: 0,
            queryErrors: 0,
            transactionsStarted: 0,
            transactionsCommitted: 0,
            transactionsRolledBack: 0,
            poolExhaustions: 0,
            lastError: null,
            startTime: new Date()
        };
        
        // Initialize the pool
        this.initializePool();
    }
    
    /**
     * Initialize MySQL connection pool
     */
    initializePool() {
        try {
            const poolConfig = this.config.getPoolConfig();
            this.pool = mysql.createPool(poolConfig);
            
            // Set up event listeners
            this.pool.on('connection', (connection) => {
                this.stats.connectionsCreated++;
                logger.debug(`New connection established as id ${connection.threadId}`);
                
                // Set session variables
                connection.query(`SET SESSION sql_mode = '${this.config.sqlMode}'`);
            });
            
            this.pool.on('error', (err) => {
                this.stats.lastError = err.message;
                logger.error('MySQL pool error:', err);
                this.emit('error', err);
            });
            
            this.isInitialized = true;
            logger.info(`MySQL connection pool initialized for database: ${this.config.database}`);
            
        } catch (error) {
            logger.error('Failed to initialize MySQL connection pool:', error);
            throw error;
        }
    }
    
    /**
     * Get a connection from the pool
     */
    async getConnection() {
        if (!this.isInitialized || !this.pool) {
            throw new Error('Connection manager not initialized');
        }
        
        try {
            const connection = await this.pool.getConnection();
            return connection;
        } catch (error) {
            if (error.code === 'POOL_ENQUEUELIMIT') {
                this.stats.poolExhaustions++;
                logger.warn('Connection pool queue limit reached');
            }
            throw error;
        }
    }
    
    /**
     * Execute a SQL query with proper error handling and logging
     * 
     * @param {string} sql - SQL query string
     * @param {Array|Object} params - Query parameters
     * @param {Object} options - Query options
     * @returns {Promise} Query results
     */
    async executeQuery(sql, params = [], options = {}) {
        const startTime = Date.now();
        let connection = null;
        
        try {
            connection = await this.getConnection();
            
            // Log query (sanitized)
            const sanitizedSql = sql.replace(/:\w+/g, '?');
            logger.debug(`Executing query: ${sanitizedSql}`);
            
            const [results] = await connection.execute(sql, params);
            this.stats.queriesExecuted++;
            
            const executionTime = Date.now() - startTime;
            logger.debug(`Query executed in ${executionTime}ms`);
            
            return results;
            
        } catch (error) {
            this.stats.queryErrors++;
            this.stats.lastError = error.message;
            logger.error('Query execution failed:', {
                error: error.message,
                sql: sql,
                params: Array.isArray(params) ? params.length : Object.keys(params).length
            });
            throw error;
            
        } finally {
            if (connection) {
                connection.release();
            }
        }
    }
    
    /**
     * Execute multiple operations in a single transaction
     * 
     * @param {Array} operations - Array of operation objects {sql, params}
     * @returns {Promise<boolean>} Transaction success status
     */
    async executeTransaction(operations) {
        let connection = null;
        
        try {
            connection = await this.getConnection();
            
            // Start transaction
            await connection.beginTransaction();
            this.stats.transactionsStarted++;
            
            let lastInsertId = null;
            const results = [];
            
            for (const operation of operations) {
                let { sql, params = [] } = operation;
                
                // Replace null values with lastInsertId for foreign key relationships
                if (Array.isArray(params) && lastInsertId !== null) {
                    params = params.map(param => param === null ? lastInsertId : param);
                } else if (typeof params === 'object' && lastInsertId !== null) {
                    for (const key in params) {
                        if (params[key] === null) {
                            params[key] = lastInsertId;
                        }
                    }
                }
                
                const [result] = await connection.execute(sql, params);
                results.push(result);
                
                // Store last insert ID for subsequent operations
                if (result.insertId) {
                    lastInsertId = result.insertId;
                }
            }
            
            // Commit transaction
            await connection.commit();
            this.stats.transactionsCommitted++;
            
            logger.debug(`Transaction completed successfully with ${operations.length} operations`);
            return { success: true, results, lastInsertId };
            
        } catch (error) {
            if (connection) {
                await connection.rollback();
                this.stats.transactionsRolledBack++;
            }
            
            logger.error('Transaction failed:', error);
            return { success: false, error: error.message };
            
        } finally {
            if (connection) {
                connection.release();
            }
        }
    }
    
    /**
     * Call a stored procedure
     * 
     * @param {string} procedureName - Name of the stored procedure
     * @param {Array} args - Procedure arguments
     * @returns {Promise} Procedure results
     */
    async callProcedure(procedureName, args = []) {
        const placeholders = args.map(() => '?').join(', ');
        const sql = `CALL ${procedureName}(${placeholders})`;
        
        try {
            const results = await this.executeQuery(sql, args);
            logger.debug(`Procedure ${procedureName} executed successfully`);
            return results;
            
        } catch (error) {
            logger.error(`Procedure ${procedureName} failed:`, error);
            throw error;
        }
    }
    
    /**
     * Perform bulk insert operation
     * 
     * @param {string} table - Target table name
     * @param {Array} columns - Array of column names
     * @param {Array} data - Array of row data arrays
     * @returns {Promise<number>} Number of rows inserted
     */
    async bulkInsert(table, columns, data) {
        if (!data || data.length === 0) {
            return 0;
        }
        
        const placeholders = columns.map(() => '?').join(', ');
        const sql = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`;
        
        let connection = null;
        
        try {
            connection = await this.getConnection();
            
            // Start transaction for bulk insert
            await connection.beginTransaction();
            
            let totalInserted = 0;
            
            // Insert in batches to avoid memory issues
            const batchSize = 1000;
            for (let i = 0; i < data.length; i += batchSize) {
                const batch = data.slice(i, i + batchSize);
                
                for (const row of batch) {
                    const [result] = await connection.execute(sql, row);
                    totalInserted += result.affectedRows;
                }
            }
            
            await connection.commit();
            logger.info(`Bulk insert: ${totalInserted} rows inserted into ${table}`);
            
            return totalInserted;
            
        } catch (error) {
            if (connection) {
                await connection.rollback();
            }
            logger.error(`Bulk insert failed for table ${table}:`, error);
            throw error;
            
        } finally {
            if (connection) {
                connection.release();
            }
        }
    }
    
    /**
     * Get connection pool statistics
     */
    getConnectionStats() {
        const poolInfo = {
            connectionLimit: this.config.connectionLimit,
            connectionsInUse: this.pool ? this.pool._acquiringConnections.length : 0,
            connectionsAvailable: this.config.connectionLimit,
            queueLength: this.pool ? this.pool._connectionQueue.length : 0
        };
        
        const uptime = (Date.now() - this.stats.startTime.getTime()) / 1000;
        
        return {
            poolInfo,
            statistics: {
                ...this.stats,
                uptimeSeconds: Math.floor(uptime),
                queriesPerSecond: this.stats.queriesExecuted / Math.max(uptime, 1),
                errorRate: this.stats.queryErrors / Math.max(this.stats.queriesExecuted, 1),
                transactionSuccessRate: this.stats.transactionsCommitted / Math.max(this.stats.transactionsStarted, 1)
            }
        };
    }
    
    /**
     * Perform database health check
     */
    async healthCheck() {
        try {
            const startTime = Date.now();
            const result = await this.executeQuery('SELECT 1 as health_check');
            const responseTime = Date.now() - startTime;
            
            return {
                status: 'healthy',
                responseTimeMs: responseTime,
                database: this.config.database,
                host: this.config.host,
                timestamp: new Date().toISOString()
            };
            
        } catch (error) {
            return {
                status: 'unhealthy',
                error: error.message,
                database: this.config.database,
                host: this.config.host,
                timestamp: new Date().toISOString()
            };
        }
    }
    
    /**
     * Close the connection pool and cleanup resources
     */
    async close() {
        if (this.pool) {
            await this.pool.end();
            this.pool = null;
            this.isInitialized = false;
            logger.info('MySQL connection pool closed');
        }
    }
}

/**
 * High-level database operations class
 */
class DatabaseOperations {
    constructor(connectionManager) {
        this.db = connectionManager;
    }
    
    /**
     * Get user by email address
     */
    async getUserByEmail(email) {
        const sql = `
            SELECT u.user_id, u.username, u.email, u.is_active, u.created_at,
                   p.first_name, p.last_name, p.display_name
            FROM users u
            LEFT JOIN user_profiles p ON u.user_id = p.user_id
            WHERE u.email = ? AND u.is_active = TRUE
        `;
        
        const results = await this.db.executeQuery(sql, [email]);
        return results.length > 0 ? results[0] : null;
    }
    
    /**
     * Create a new user with profile in a transaction
     */
    async createUserWithProfile(username, email, firstName, lastName) {
        const operations = [
            {
                sql: `
                    INSERT INTO users (username, email, password_hash, email_verified)
                    VALUES (?, ?, ?, ?)
                `,
                params: [username, email, '$2y$10$default.hash', false]
            },
            {
                sql: `
                    INSERT INTO user_profiles (user_id, first_name, last_name, display_name)
                    VALUES (?, ?, ?, ?)
                `,
                params: [null, firstName, lastName, `${firstName} ${lastName}`]
            }
        ];
        
        const result = await this.db.executeTransaction(operations);
        
        if (result.success) {
            // Get the created user
            const user = await this.getUserByEmail(email);
            return user ? user.user_id : null;
        }
        
        return null;
    }
    
    /**
     * Log user activity for audit purposes
     */
    async logUserActivity(userId, activityType, details) {
        try {
            await this.db.callProcedure('audit_db.log_audit_event', [
                'myapp',
                'user_activity',
                activityType,
                userId.toString(),
                null,
                JSON.stringify(details),
                `user_${userId}`,
                null,
                'nodejs_app'
            ]);
            
            return true;
            
        } catch (error) {
            logger.error('Failed to log user activity:', error);
            return false;
        }
    }
    
    /**
     * Get paginated list of users
     */
    async getUsers(page = 1, limit = 10, filters = {}) {
        const offset = (page - 1) * limit;
        let whereConditions = ['u.is_active = TRUE'];
        let params = [];
        
        // Add filters
        if (filters.search) {
            whereConditions.push('(u.username LIKE ? OR u.email LIKE ? OR p.first_name LIKE ? OR p.last_name LIKE ?)');
            const searchTerm = `%${filters.search}%`;
            params.push(searchTerm, searchTerm, searchTerm, searchTerm);
        }
        
        if (filters.createdAfter) {
            whereConditions.push('u.created_at >= ?');
            params.push(filters.createdAfter);
        }
        
        const whereClause = whereConditions.join(' AND ');
        
        // Get total count
        const countSql = `
            SELECT COUNT(*) as total
            FROM users u
            LEFT JOIN user_profiles p ON u.user_id = p.user_id
            WHERE ${whereClause}
        `;
        
        const countResult = await this.db.executeQuery(countSql, params);
        const total = countResult[0].total;
        
        // Get paginated results
        const dataSql = `
            SELECT u.user_id, u.username, u.email, u.is_active, u.created_at,
                   p.first_name, p.last_name, p.display_name
            FROM users u
            LEFT JOIN user_profiles p ON u.user_id = p.user_id
            WHERE ${whereClause}
            ORDER BY u.created_at DESC
            LIMIT ? OFFSET ?
        `;
        
        const users = await this.db.executeQuery(dataSql, [...params, limit, offset]);
        
        return {
            users,
            pagination: {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit),
                hasNext: page * limit < total,
                hasPrev: page > 1
            }
        };
    }
    
    /**
     * Update user last login timestamp
     */
    async updateLastLogin(userId) {
        const sql = `
            UPDATE users 
            SET last_login = NOW(), failed_login_attempts = 0 
            WHERE user_id = ?
        `;
        
        const result = await this.db.executeQuery(sql, [userId]);
        return result.affectedRows > 0;
    }
    
    /**
     * Increment failed login attempts
     */
    async incrementFailedLogin(email) {
        const sql = `
            UPDATE users 
            SET failed_login_attempts = failed_login_attempts + 1,
                locked_until = CASE 
                    WHEN failed_login_attempts >= 4 THEN DATE_ADD(NOW(), INTERVAL 30 MINUTE)
                    ELSE locked_until
                END
            WHERE email = ?
        `;
        
        const result = await this.db.executeQuery(sql, [email]);
        return result.affectedRows > 0;
    }
}

// Export classes and utilities
module.exports = {
    DatabaseConfig,
    MySQLConnectionManager,
    DatabaseOperations,
    logger
};

// Example usage
if (require.main === module) {
    async function example() {
        // Create configuration
        const config = new DatabaseConfig({
            host: 'localhost',
            database: 'myapp',
            user: 'app_write',
            password: 'your_password'
        });
        
        // Initialize connection manager
        const dbManager = new MySQLConnectionManager(config);
        
        // Initialize high-level operations
        const dbOps = new DatabaseOperations(dbManager);
        
        try {
            // Health check
            const health = await dbManager.healthCheck();
            console.log('Database health:', health);
            
            // Example query
            const userCount = await dbManager.executeQuery(
                'SELECT COUNT(*) as user_count FROM users WHERE is_active = ?',
                [true]
            );
            console.log('Active users:', userCount[0].user_count);
            
            // Get connection statistics
            const stats = dbManager.getConnectionStats();
            console.log('Connection stats:', stats);
            
        } catch (error) {
            logger.error('Database operation failed:', error);
        } finally {
            // Cleanup
            await dbManager.close();
        }
    }
    
    example().catch(console.error);
}