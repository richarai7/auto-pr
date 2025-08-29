"""
MySQL Connection Manager for Python Applications

This module provides a robust MySQL connection management system with
connection pooling, error handling, and security best practices.

Features:
- Connection pooling for optimal performance
- Automatic retry logic for transient failures
- SQL injection protection via parameterized queries
- Comprehensive logging and monitoring
- Environment-based configuration
- Support for multiple database environments

Author: MySQL Architecture Team
Version: 1.0
Last Updated: 2024
"""

import os
import logging
import time
from contextlib import contextmanager
from typing import Optional, Dict, List, Any, Union
from dataclasses import dataclass
import mysql.connector
from mysql.connector import pooling, Error, InterfaceError, OperationalError
import json
from datetime import datetime, timedelta

# Configure logging
logger = logging.getLogger(__name__)


@dataclass
class DatabaseConfig:
    """Database configuration settings"""
    host: str
    port: int
    database: str
    user: str
    password: str
    pool_name: str = 'default_pool'
    pool_size: int = 10
    pool_reset_session: bool = True
    autocommit: bool = False
    charset: str = 'utf8mb4'
    collation: str = 'utf8mb4_unicode_ci'
    use_ssl: bool = True
    ssl_verify_cert: bool = False
    connection_timeout: int = 30
    
    @classmethod
    def from_environment(cls, env_prefix: str = 'MYSQL') -> 'DatabaseConfig':
        """Create configuration from environment variables"""
        return cls(
            host=os.getenv(f'{env_prefix}_HOST', 'localhost'),
            port=int(os.getenv(f'{env_prefix}_PORT', '3306')),
            database=os.getenv(f'{env_prefix}_DATABASE', 'myapp'),
            user=os.getenv(f'{env_prefix}_USER', 'app_user'),
            password=os.getenv(f'{env_prefix}_PASSWORD', ''),
            pool_name=os.getenv(f'{env_prefix}_POOL_NAME', 'myapp_pool'),
            pool_size=int(os.getenv(f'{env_prefix}_POOL_SIZE', '10')),
            pool_reset_session=os.getenv(f'{env_prefix}_POOL_RESET', 'true').lower() == 'true',
            autocommit=os.getenv(f'{env_prefix}_AUTOCOMMIT', 'false').lower() == 'true',
            charset=os.getenv(f'{env_prefix}_CHARSET', 'utf8mb4'),
            collation=os.getenv(f'{env_prefix}_COLLATION', 'utf8mb4_unicode_ci'),
            use_ssl=os.getenv(f'{env_prefix}_USE_SSL', 'true').lower() == 'true',
            ssl_verify_cert=os.getenv(f'{env_prefix}_SSL_VERIFY', 'false').lower() == 'true',
            connection_timeout=int(os.getenv(f'{env_prefix}_TIMEOUT', '30'))
        )


class MySQLConnectionManager:
    """
    MySQL connection manager with pooling and error handling
    
    This class provides a high-level interface for MySQL database operations
    with built-in connection pooling, retry logic, and security features.
    """
    
    def __init__(self, config: DatabaseConfig):
        """
        Initialize the connection manager
        
        Args:
            config: Database configuration object
        """
        self.config = config
        self.connection_pool: Optional[pooling.MySQLConnectionPool] = None
        self._initialize_pool()
        
        # Connection statistics
        self.stats = {
            'connections_created': 0,
            'connections_closed': 0,
            'queries_executed': 0,
            'query_errors': 0,
            'pool_exhaustions': 0,
            'last_error': None,
            'start_time': datetime.now()
        }
    
    def _initialize_pool(self) -> None:
        """Initialize MySQL connection pool with configuration"""
        try:
            pool_config = {
                'user': self.config.user,
                'password': self.config.password,
                'host': self.config.host,
                'port': self.config.port,
                'database': self.config.database,
                'pool_name': self.config.pool_name,
                'pool_size': self.config.pool_size,
                'pool_reset_session': self.config.pool_reset_session,
                'autocommit': self.config.autocommit,
                'charset': self.config.charset,
                'collation': self.config.collation,
                'connection_timeout': self.config.connection_timeout,
                'raise_on_warnings': True,
                'sql_mode': 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO'
            }
            
            # Add SSL configuration if enabled
            if self.config.use_ssl:
                pool_config.update({
                    'use_ssl': True,
                    'ssl_verify_cert': self.config.ssl_verify_cert
                })
            
            self.connection_pool = pooling.MySQLConnectionPool(**pool_config)
            logger.info(f"MySQL connection pool '{self.config.pool_name}' initialized successfully")
            
        except Error as e:
            logger.error(f"Failed to initialize MySQL connection pool: {e}")
            raise
    
    @contextmanager
    def get_connection(self):
        """
        Context manager for getting database connections
        
        Yields:
            mysql.connector.MySQLConnection: Database connection
            
        Example:
            with db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM users")
                results = cursor.fetchall()
        """
        connection = None
        try:
            connection = self.connection_pool.get_connection()
            self.stats['connections_created'] += 1
            yield connection
            
        except pooling.PoolError:
            self.stats['pool_exhaustions'] += 1
            logger.warning("Connection pool exhausted, waiting for available connection")
            # Retry after brief delay
            time.sleep(0.1)
            connection = self.connection_pool.get_connection()
            self.stats['connections_created'] += 1
            yield connection
            
        except Error as e:
            self.stats['query_errors'] += 1
            self.stats['last_error'] = str(e)
            logger.error(f"Database connection error: {e}")
            raise
            
        finally:
            if connection and connection.is_connected():
                connection.close()
                self.stats['connections_closed'] += 1
    
    def execute_query(self, 
                     query: str, 
                     params: Optional[Union[tuple, dict]] = None,
                     fetch: str = 'all') -> Union[List[Dict], Dict, int]:
        """
        Execute a SQL query with proper error handling and logging
        
        Args:
            query: SQL query string (use %s for parameters)
            params: Query parameters (tuple or dict)
            fetch: Fetch mode ('all', 'one', 'none' for non-SELECT queries)
            
        Returns:
            Query results based on fetch mode:
            - 'all': List of dictionaries
            - 'one': Single dictionary or None
            - 'none': Number of affected rows
            
        Example:
            # Select query
            users = db.execute_query(
                "SELECT * FROM users WHERE email = %s", 
                ('user@example.com',)
            )
            
            # Insert query
            rows_affected = db.execute_query(
                "INSERT INTO users (username, email) VALUES (%s, %s)",
                ('newuser', 'new@example.com'),
                fetch='none'
            )
        """
        start_time = time.time()
        
        with self.get_connection() as connection:
            cursor = connection.cursor(dictionary=True, buffered=True)
            
            try:
                # Log query (sanitized)
                sanitized_query = query.replace('%s', '?') if params else query
                logger.debug(f"Executing query: {sanitized_query}")
                
                cursor.execute(query, params or ())
                self.stats['queries_executed'] += 1
                
                # Handle different fetch modes
                if fetch == 'all':
                    result = cursor.fetchall()
                elif fetch == 'one':
                    result = cursor.fetchone()
                elif fetch == 'none':
                    connection.commit()
                    result = cursor.rowcount
                else:
                    raise ValueError(f"Invalid fetch mode: {fetch}")
                
                execution_time = time.time() - start_time
                logger.debug(f"Query executed in {execution_time:.3f}s")
                
                return result
                
            except Error as e:
                connection.rollback()
                self.stats['query_errors'] += 1
                self.stats['last_error'] = str(e)
                logger.error(f"Query execution failed: {e}")
                logger.error(f"Query: {query}")
                logger.error(f"Params: {params}")
                raise
                
            finally:
                cursor.close()
    
    def execute_transaction(self, operations: List[Dict[str, Any]]) -> bool:
        """
        Execute multiple operations in a single transaction
        
        Args:
            operations: List of operation dictionaries with 'query' and 'params' keys
            
        Returns:
            bool: True if transaction successful, False otherwise
            
        Example:
            operations = [
                {
                    'query': 'INSERT INTO users (username, email) VALUES (%s, %s)',
                    'params': ('user1', 'user1@example.com')
                },
                {
                    'query': 'INSERT INTO user_profiles (user_id, first_name) VALUES (%s, %s)',
                    'params': (None, 'John')  # user_id will be set to LAST_INSERT_ID()
                }
            ]
            success = db.execute_transaction(operations)
        """
        with self.get_connection() as connection:
            cursor = connection.cursor()
            
            try:
                # Start transaction
                connection.start_transaction()
                
                last_insert_id = None
                
                for operation in operations:
                    query = operation['query']
                    params = operation.get('params', ())
                    
                    # Replace None with last_insert_id for foreign key relationships
                    if params and last_insert_id is not None:
                        params = tuple(
                            last_insert_id if param is None else param 
                            for param in params
                        )
                    
                    cursor.execute(query, params)
                    
                    # Store last insert ID for subsequent operations
                    if cursor.lastrowid:
                        last_insert_id = cursor.lastrowid
                
                # Commit transaction
                connection.commit()
                logger.debug(f"Transaction completed successfully with {len(operations)} operations")
                return True
                
            except Error as e:
                connection.rollback()
                self.stats['query_errors'] += 1
                self.stats['last_error'] = str(e)
                logger.error(f"Transaction failed: {e}")
                return False
                
            finally:
                cursor.close()
    
    def call_procedure(self, proc_name: str, args: tuple = ()) -> List[Any]:
        """
        Call a stored procedure
        
        Args:
            proc_name: Name of the stored procedure
            args: Procedure arguments
            
        Returns:
            List of result sets from the procedure
        """
        with self.get_connection() as connection:
            cursor = connection.cursor(dictionary=True)
            
            try:
                cursor.callproc(proc_name, args)
                
                # Fetch all result sets
                results = []
                for result in cursor.stored_results():
                    results.append(result.fetchall())
                
                connection.commit()
                logger.debug(f"Procedure {proc_name} executed successfully")
                return results
                
            except Error as e:
                connection.rollback()
                logger.error(f"Procedure {proc_name} failed: {e}")
                raise
                
            finally:
                cursor.close()
    
    def bulk_insert(self, table: str, columns: List[str], data: List[tuple]) -> int:
        """
        Perform bulk insert operation for better performance
        
        Args:
            table: Target table name
            columns: List of column names
            data: List of tuples containing row data
            
        Returns:
            Number of rows inserted
        """
        if not data:
            return 0
        
        placeholders = ', '.join(['%s'] * len(columns))
        column_list = ', '.join(columns)
        query = f"INSERT INTO {table} ({column_list}) VALUES ({placeholders})"
        
        with self.get_connection() as connection:
            cursor = connection.cursor()
            
            try:
                cursor.executemany(query, data)
                connection.commit()
                
                rows_inserted = cursor.rowcount
                logger.info(f"Bulk insert: {rows_inserted} rows inserted into {table}")
                return rows_inserted
                
            except Error as e:
                connection.rollback()
                logger.error(f"Bulk insert failed for table {table}: {e}")
                raise
                
            finally:
                cursor.close()
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """
        Get connection pool statistics
        
        Returns:
            Dictionary containing connection and query statistics
        """
        pool_info = {
            'pool_name': self.config.pool_name,
            'pool_size': self.config.pool_size,
            'connections_in_use': 0,
            'connections_available': 0
        }
        
        if self.connection_pool:
            try:
                # This is an approximation as mysql-connector-python doesn't expose detailed pool stats
                pool_info['connections_available'] = self.config.pool_size
            except:
                pass
        
        uptime = datetime.now() - self.stats['start_time']
        
        return {
            'pool_info': pool_info,
            'statistics': {
                **self.stats,
                'uptime_seconds': int(uptime.total_seconds()),
                'queries_per_second': self.stats['queries_executed'] / max(uptime.total_seconds(), 1),
                'error_rate': self.stats['query_errors'] / max(self.stats['queries_executed'], 1)
            }
        }
    
    def health_check(self) -> Dict[str, Any]:
        """
        Perform database health check
        
        Returns:
            Dictionary with health check results
        """
        try:
            start_time = time.time()
            result = self.execute_query("SELECT 1 as health_check", fetch='one')
            response_time = time.time() - start_time
            
            return {
                'status': 'healthy',
                'response_time_ms': round(response_time * 1000, 2),
                'database': self.config.database,
                'host': self.config.host,
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'status': 'unhealthy',
                'error': str(e),
                'database': self.config.database,
                'host': self.config.host,
                'timestamp': datetime.now().isoformat()
            }
    
    def close_pool(self) -> None:
        """Close the connection pool and cleanup resources"""
        if self.connection_pool:
            # mysql-connector-python doesn't have an explicit close_pool method
            # Connections will be closed when they go out of scope
            self.connection_pool = None
            logger.info(f"Connection pool '{self.config.pool_name}' closed")


# Convenience functions for common database operations
class DatabaseOperations:
    """High-level database operations using the connection manager"""
    
    def __init__(self, connection_manager: MySQLConnectionManager):
        self.db = connection_manager
    
    def get_user_by_email(self, email: str) -> Optional[Dict]:
        """Get user by email address"""
        return self.db.execute_query(
            """
            SELECT u.user_id, u.username, u.email, u.is_active, u.created_at,
                   p.first_name, p.last_name, p.display_name
            FROM users u
            LEFT JOIN user_profiles p ON u.user_id = p.user_id
            WHERE u.email = %s AND u.is_active = TRUE
            """,
            (email,),
            fetch='one'
        )
    
    def create_user_with_profile(self, username: str, email: str, 
                                first_name: str, last_name: str) -> Optional[int]:
        """Create a new user with profile in a transaction"""
        operations = [
            {
                'query': '''
                    INSERT INTO users (username, email, password_hash, email_verified)
                    VALUES (%s, %s, %s, %s)
                ''',
                'params': (username, email, '$2y$10$default.hash', False)
            },
            {
                'query': '''
                    INSERT INTO user_profiles (user_id, first_name, last_name, display_name)
                    VALUES (%s, %s, %s, %s)
                ''',
                'params': (None, first_name, last_name, f"{first_name} {last_name}")
            }
        ]
        
        if self.db.execute_transaction(operations):
            # Get the created user ID
            user = self.get_user_by_email(email)
            return user['user_id'] if user else None
        return None
    
    def log_user_activity(self, user_id: int, activity_type: str, details: Dict) -> bool:
        """Log user activity for audit purposes"""
        try:
            self.db.execute_query(
                """
                CALL audit_db.log_audit_event(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                """,
                (
                    'myapp', 'user_activity', activity_type, str(user_id),
                    None, json.dumps(details), f"user_{user_id}", 
                    None, 'python_app'
                ),
                fetch='none'
            )
            return True
        except Exception as e:
            logger.error(f"Failed to log user activity: {e}")
            return False


# Example usage and configuration
if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)
    
    # Create database configuration from environment
    config = DatabaseConfig.from_environment()
    
    # Initialize connection manager
    db_manager = MySQLConnectionManager(config)
    
    # Initialize high-level operations
    db_ops = DatabaseOperations(db_manager)
    
    try:
        # Health check
        health = db_manager.health_check()
        print(f"Database health: {health}")
        
        # Example queries
        users = db_manager.execute_query(
            "SELECT COUNT(*) as user_count FROM users WHERE is_active = %s",
            (True,),
            fetch='one'
        )
        print(f"Active users: {users['user_count']}")
        
        # Get connection statistics
        stats = db_manager.get_connection_stats()
        print(f"Connection stats: {stats}")
        
    except Exception as e:
        logger.error(f"Database operation failed: {e}")
    
    finally:
        # Cleanup
        db_manager.close_pool()