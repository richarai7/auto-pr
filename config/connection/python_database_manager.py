#!/usr/bin/env python3
"""
MySQL Database Connection Manager for Python
=============================================
Purpose: Enterprise-grade MySQL connection management for Python applications
Based on: mysql-instructions.md connection guidelines
Features: Connection pooling, error handling, query optimization, monitoring
"""

import os
import logging
import time
import threading
from contextlib import contextmanager
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime, timedelta
import mysql.connector
from mysql.connector import pooling, Error
import yaml
import json
from dataclasses import dataclass, asdict
from collections import defaultdict

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class DatabaseConfig:
    """Database configuration with validation"""
    host: str = 'localhost'
    port: int = 3306
    database: str = 'app_db'
    user: str = 'app_user'
    password: str = ''
    
    # Pool settings
    pool_name: str = 'mysql_pool'
    pool_size: int = 10
    pool_reset_session: bool = True
    
    # Connection settings
    autocommit: bool = False
    charset: str = 'utf8mb4'
    collation: str = 'utf8mb4_unicode_ci'
    time_zone: str = '+00:00'
    
    # SSL settings
    ssl_disabled: bool = True
    ssl_ca: Optional[str] = None
    ssl_cert: Optional[str] = None
    ssl_key: Optional[str] = None
    
    # Timeout settings
    connection_timeout: int = 60
    auth_plugin: str = 'mysql_native_password'
    
    # Application context
    application_name: str = 'Python-App'
    environment: str = 'development'
    version: str = '1.0.0'
    
    @classmethod
    def from_environment(cls, environment: str = 'development') -> 'DatabaseConfig':
        """Create configuration from environment variables"""
        config = cls()
        
        # Load from environment variables
        config.host = os.getenv('DB_HOST', config.host)
        config.port = int(os.getenv('DB_PORT', config.port))
        config.database = os.getenv('DB_NAME', config.database)
        config.user = os.getenv('DB_USER', config.user)
        config.password = os.getenv('DB_PASSWORD', config.password)
        config.environment = environment
        
        # Environment-specific settings
        if environment == 'production':
            config.pool_size = 20
            config.ssl_disabled = False
            config.ssl_ca = os.getenv('DB_SSL_CA')
            config.ssl_cert = os.getenv('DB_SSL_CERT')
            config.ssl_key = os.getenv('DB_SSL_KEY')
        elif environment == 'staging':
            config.pool_size = 15
            config.ssl_disabled = os.getenv('DB_SSL', 'false').lower() != 'true'
        else:  # development
            config.pool_size = 5
            config.password = config.password or 'SecureAppPassword123!'
            
        return config
    
    @classmethod
    def from_yaml(cls, config_file: str) -> 'DatabaseConfig':
        """Load configuration from YAML file"""
        try:
            with open(config_file, 'r') as file:
                data = yaml.safe_load(file)
                return cls(**data)
        except FileNotFoundError:
            logger.warning(f"Config file {config_file} not found, using defaults")
            return cls()


class QueryMetrics:
    """Track query performance metrics"""
    
    def __init__(self):
        self.total_queries = 0
        self.slow_queries = 0
        self.errors = 0
        self.total_execution_time = 0
        self.slow_query_threshold = 1.0  # 1 second
        self.query_history = []
        self.lock = threading.Lock()
    
    def record_query(self, sql: str, execution_time: float, success: bool = True):
        """Record query execution metrics"""
        with self.lock:
            self.total_queries += 1
            self.total_execution_time += execution_time
            
            if not success:
                self.errors += 1
            
            if execution_time > self.slow_query_threshold:
                self.slow_queries += 1
                logger.warning(f"Slow query detected ({execution_time:.3f}s): {sql[:100]}...")
            
            # Keep last 100 queries for analysis
            self.query_history.append({
                'sql': sql[:200],  # Truncate for memory
                'execution_time': execution_time,
                'success': success,
                'timestamp': datetime.now()
            })
            
            if len(self.query_history) > 100:
                self.query_history.pop(0)
    
    @property
    def average_execution_time(self) -> float:
        """Calculate average query execution time"""
        return self.total_execution_time / self.total_queries if self.total_queries > 0 else 0
    
    @property
    def error_rate(self) -> float:
        """Calculate error rate percentage"""
        return (self.errors / self.total_queries * 100) if self.total_queries > 0 else 0
    
    @property
    def slow_query_rate(self) -> float:
        """Calculate slow query rate percentage"""
        return (self.slow_queries / self.total_queries * 100) if self.total_queries > 0 else 0
    
    def get_stats(self) -> Dict[str, Any]:
        """Get comprehensive statistics"""
        return {
            'total_queries': self.total_queries,
            'slow_queries': self.slow_queries,
            'errors': self.errors,
            'average_execution_time': self.average_execution_time,
            'error_rate': self.error_rate,
            'slow_query_rate': self.slow_query_rate,
            'slow_query_threshold': self.slow_query_threshold
        }


class DatabaseManager:
    """
    Enterprise-grade MySQL database manager with connection pooling,
    monitoring, and error handling capabilities.
    """
    
    def __init__(self, config: DatabaseConfig):
        self.config = config
        self.pool = None
        self.metrics = QueryMetrics()
        self.is_connected = False
        
        # Audit context for tracking operations
        self.audit_context = {
            'application_name': config.application_name,
            'environment': config.environment,
            'version': config.version,
            'session_id': f"python_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        }
    
    def initialize(self) -> None:
        """Initialize database connection pool"""
        try:
            pool_config = {
                'pool_name': self.config.pool_name,
                'pool_size': self.config.pool_size,
                'pool_reset_session': self.config.pool_reset_session,
                'host': self.config.host,
                'port': self.config.port,
                'database': self.config.database,
                'user': self.config.user,
                'password': self.config.password,
                'autocommit': self.config.autocommit,
                'charset': self.config.charset,
                'collation': self.config.collation,
                'time_zone': self.config.time_zone,
                'connection_timeout': self.config.connection_timeout,
                'auth_plugin': self.config.auth_plugin
            }
            
            # Add SSL configuration if not disabled
            if not self.config.ssl_disabled:
                ssl_config = {}
                if self.config.ssl_ca:
                    ssl_config['ca'] = self.config.ssl_ca
                if self.config.ssl_cert:
                    ssl_config['cert'] = self.config.ssl_cert
                if self.config.ssl_key:
                    ssl_config['key'] = self.config.ssl_key
                
                if ssl_config:
                    pool_config['ssl'] = ssl_config
            
            self.pool = pooling.MySQLConnectionPool(**pool_config)
            
            # Test connection
            self._test_connection()
            
            self.is_connected = True
            logger.info(f"Database connection pool initialized: {self.config.host}:{self.config.port}/{self.config.database}")
            
        except Error as e:
            logger.error(f"Failed to initialize database pool: {e}")
            raise
    
    def _test_connection(self) -> None:
        """Test database connectivity"""
        try:
            with self.get_connection() as connection:
                cursor = connection.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
                cursor.close()
            logger.info("Database connection test successful")
        except Error as e:
            logger.error(f"Database connection test failed: {e}")
            raise
    
    @contextmanager
    def get_connection(self):
        """
        Context manager for database connections with audit context setup
        """
        if not self.is_connected:
            raise RuntimeError("Database not initialized. Call initialize() first.")
        
        connection = None
        try:
            connection = self.pool.get_connection()
            
            # Set audit context variables
            cursor = connection.cursor()
            cursor.execute("SET @audit_user = %s", (self.config.user,))
            cursor.execute("SET @audit_app = %s", (self.audit_context['application_name'],))
            cursor.execute("SET @audit_session = %s", (self.audit_context['session_id'],))
            cursor.execute("SET @audit_env = %s", (self.audit_context['environment'],))
            cursor.close()
            
            yield connection
            
        except Error as e:
            if connection:
                connection.rollback()
            logger.error(f"Database connection error: {e}")
            raise
        finally:
            if connection:
                connection.close()
    
    def execute_query(self, sql: str, params: Optional[Tuple] = None, 
                     fetch_all: bool = True) -> Tuple[List, float]:
        """
        Execute SQL query with performance monitoring
        
        Args:
            sql: SQL query string
            params: Query parameters
            fetch_all: Whether to fetch all results
            
        Returns:
            Tuple of (results, execution_time)
        """
        start_time = time.time()
        success = True
        results = []
        
        try:
            with self.get_connection() as connection:
                cursor = connection.cursor(dictionary=True)
                cursor.execute(sql, params or ())
                
                if cursor.description:  # SELECT query
                    results = cursor.fetchall() if fetch_all else cursor.fetchone()
                else:  # INSERT/UPDATE/DELETE
                    results = {
                        'affected_rows': cursor.rowcount,
                        'last_insert_id': cursor.lastrowid
                    }
                
                cursor.close()
                
        except Error as e:
            success = False
            logger.error(f"Query execution failed: {e}")
            logger.error(f"SQL: {sql}")
            logger.error(f"Params: {params}")
            raise
        finally:
            execution_time = time.time() - start_time
            self.metrics.record_query(sql, execution_time, success)
        
        return results, execution_time
    
    def execute_transaction(self, queries: List[Tuple[str, Optional[Tuple]]]) -> Dict[str, Any]:
        """
        Execute multiple queries in a transaction
        
        Args:
            queries: List of (sql, params) tuples
            
        Returns:
            Transaction execution summary
        """
        start_time = time.time()
        results = []
        
        try:
            with self.get_connection() as connection:
                cursor = connection.cursor(dictionary=True)
                
                # Begin transaction
                connection.start_transaction()
                
                for sql, params in queries:
                    query_start = time.time()
                    cursor.execute(sql, params or ())
                    
                    if cursor.description:
                        result = cursor.fetchall()
                    else:
                        result = {
                            'affected_rows': cursor.rowcount,
                            'last_insert_id': cursor.lastrowid
                        }
                    
                    results.append({
                        'sql': sql,
                        'result': result,
                        'execution_time': time.time() - query_start
                    })
                
                # Commit transaction
                connection.commit()
                cursor.close()
                
                logger.info(f"Transaction completed successfully with {len(queries)} queries")
                
        except Error as e:
            connection.rollback()
            logger.error(f"Transaction failed, rolled back: {e}")
            raise
        
        total_time = time.time() - start_time
        return {
            'success': True,
            'total_execution_time': total_time,
            'query_count': len(queries),
            'results': results
        }
    
    def batch_insert(self, table: str, columns: List[str], rows: List[Tuple], 
                    batch_size: int = 1000, on_duplicate_update: bool = False) -> Dict[str, Any]:
        """
        Perform batch insert operation
        
        Args:
            table: Target table name
            columns: Column names
            rows: Row data
            batch_size: Number of rows per batch
            on_duplicate_update: Use ON DUPLICATE KEY UPDATE
            
        Returns:
            Insert operation summary
        """
        if not rows:
            raise ValueError("No data provided for batch insert")
        
        total_inserted = 0
        batches_processed = 0
        start_time = time.time()
        
        try:
            # Create base query
            placeholders = ', '.join(['%s'] * len(columns))
            base_sql = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders})"
            
            if on_duplicate_update:
                update_clause = ', '.join([f"{col} = VALUES({col})" for col in columns])
                base_sql += f" ON DUPLICATE KEY UPDATE {update_clause}"
            
            with self.get_connection() as connection:
                cursor = connection.cursor()
                
                # Process in batches
                for i in range(0, len(rows), batch_size):
                    batch = rows[i:i + batch_size]
                    
                    cursor.executemany(base_sql, batch)
                    total_inserted += cursor.rowcount
                    batches_processed += 1
                    
                    if batches_processed % 10 == 0:
                        logger.info(f"Batch insert progress: {i + len(batch)}/{len(rows)} rows")
                
                connection.commit()
                cursor.close()
                
        except Error as e:
            logger.error(f"Batch insert failed for table {table}: {e}")
            raise
        
        execution_time = time.time() - start_time
        logger.info(f"Batch insert completed: {total_inserted} rows in {execution_time:.2f}s")
        
        return {
            'table': table,
            'total_rows': len(rows),
            'inserted_rows': total_inserted,
            'batches_processed': batches_processed,
            'execution_time': execution_time
        }
    
    # Business logic methods
    
    def get_customer_order_summary(self, customer_id: int) -> Optional[Dict]:
        """Get customer order summary"""
        sql = """
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
        WHERE customer_id = %s
        """
        
        results, _ = self.execute_query(sql, (customer_id,), fetch_all=False)
        return results
    
    def get_product_inventory(self, sku: Optional[str] = None) -> List[Dict]:
        """Get product inventory status"""
        sql = """
        SELECT 
            product_id,
            sku,
            product_name,
            system_stock,
            calculated_stock,
            reorder_level,
            stock_status
        FROM product_inventory
        """
        
        params = ()
        if sku:
            sql += " WHERE sku = %s"
            params = (sku,)
        
        sql += " ORDER BY product_name"
        
        results, _ = self.execute_query(sql, params)
        return results
    
    def get_daily_sales_summary(self, start_date: str, end_date: str) -> List[Dict]:
        """Get daily sales summary for date range"""
        sql = """
        SELECT 
            summary_date,
            total_orders,
            total_order_value,
            avg_order_value,
            total_customers,
            new_customers,
            day_of_week,
            is_weekend
        FROM daily_sales_summary
        WHERE summary_date BETWEEN %s AND %s
        ORDER BY summary_date DESC
        """
        
        results, _ = self.execute_query(sql, (start_date, end_date))
        return results
    
    def health_check(self) -> Dict[str, Any]:
        """Perform comprehensive health check"""
        try:
            start_time = time.time()
            
            # Test basic connectivity
            self._test_connection()
            connection_time = time.time() - start_time
            
            # Get pool status
            pool_status = {
                'pool_name': self.config.pool_name,
                'pool_size': self.config.pool_size,
                'host': self.config.host,
                'database': self.config.database,
                'user': self.config.user
            }
            
            # Get performance metrics
            performance_stats = self.metrics.get_stats()
            
            return {
                'status': 'healthy',
                'connection_time': connection_time,
                'pool_status': pool_status,
                'performance_stats': performance_stats,
                'audit_context': self.audit_context,
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get detailed performance statistics"""
        return self.metrics.get_stats()
    
    def close(self) -> None:
        """Close database connection pool"""
        if self.pool:
            # MySQL connector doesn't have explicit pool close method
            # Connections will be closed when pool goes out of scope
            self.pool = None
            self.is_connected = False
            logger.info("Database connection pool closed")


# Configuration factory functions

def create_database_manager(environment: str = 'development', 
                          config_file: Optional[str] = None) -> DatabaseManager:
    """
    Factory function to create configured DatabaseManager
    
    Args:
        environment: Target environment (development, staging, production)
        config_file: Optional YAML config file path
        
    Returns:
        Configured DatabaseManager instance
    """
    if config_file:
        config = DatabaseConfig.from_yaml(config_file)
    else:
        config = DatabaseConfig.from_environment(environment)
    
    db_manager = DatabaseManager(config)
    db_manager.initialize()
    
    return db_manager


# Example usage and testing
if __name__ == "__main__":
    import asyncio
    
    def example_usage():
        """Example of using the DatabaseManager"""
        try:
            # Create database manager
            db = create_database_manager('development')
            
            # Test basic query
            customers, exec_time = db.execute_query(
                "SELECT customer_id, email, first_name, last_name FROM customers LIMIT 5"
            )
            print(f"Found {len(customers)} customers in {exec_time:.3f}s")
            
            # Test transaction
            transaction_queries = [
                ("INSERT INTO audit_log (table_name, operation, changed_by) VALUES (%s, %s, %s)",
                 ('customers', 'SELECT', 'test_user')),
                ("SELECT COUNT(*) as customer_count FROM customers", None)
            ]
            
            result = db.execute_transaction(transaction_queries)
            print(f"Transaction completed in {result['total_execution_time']:.3f}s")
            
            # Health check
            health = db.health_check()
            print(f"Database health: {health['status']}")
            
            # Performance stats
            stats = db.get_performance_stats()
            print(f"Query stats: {stats}")
            
        except Exception as e:
            logger.error(f"Example failed: {e}")
        finally:
            if 'db' in locals():
                db.close()
    
    example_usage()