#!/usr/bin/env python3
"""
MySQL ETL Pipeline Implementation
=================================
Purpose: Extract, Transform, Load data pipeline for MySQL databases
Based on: mysql-instructions.md ETL guidelines
Author: Auto-generated from enterprise architecture template
"""

import sys
import os
import logging
import mysql.connector
from mysql.connector import Error, pooling
import pandas as pd
from datetime import datetime, timedelta
import json
import yaml
from typing import Dict, List, Optional, Any
import configparser
from contextlib import contextmanager
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('etl_pipeline.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class MySQLETLPipeline:
    """
    Enterprise-grade ETL Pipeline for MySQL databases
    
    Features:
    - Connection pooling for performance
    - Error handling and retry logic
    - Configurable data transformations
    - Audit logging integration
    - Batch processing capabilities
    """
    
    def __init__(self, config_file: str = 'config/etl_config.yaml'):
        """
        Initialize ETL pipeline with configuration
        
        Args:
            config_file: Path to YAML configuration file
        """
        self.config = self._load_config(config_file)
        self.connection_pool = None
        self.audit_context = {
            'user': 'etl_system',
            'application': 'ETL_Pipeline',
            'session_id': f"etl_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        }
        
    def _load_config(self, config_file: str) -> Dict:
        """Load configuration from YAML file"""
        try:
            with open(config_file, 'r') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            logger.warning(f"Config file {config_file} not found, using defaults")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict:
        """Return default configuration"""
        return {
            'source_database': {
                'host': 'localhost',
                'port': 3306,
                'database': 'app_db',
                'user': 'etl_user',
                'password': 'SecureETLPassword123!',
                'pool_size': 5
            },
            'target_database': {
                'host': 'localhost',
                'port': 3306,
                'database': 'app_db',
                'user': 'etl_user',
                'password': 'SecureETLPassword123!',
                'pool_size': 3
            },
            'batch_size': 1000,
            'retry_attempts': 3,
            'retry_delay': 5
        }
    
    def initialize_connections(self):
        """Initialize database connection pools"""
        try:
            # Source database pool
            source_config = {
                'pool_name': 'source_pool',
                'pool_size': self.config['source_database']['pool_size'],
                'pool_reset_session': True,
                'host': self.config['source_database']['host'],
                'port': self.config['source_database']['port'],
                'database': self.config['source_database']['database'],
                'user': self.config['source_database']['user'],
                'password': self.config['source_database']['password'],
                'autocommit': False,
                'charset': 'utf8mb4',
                'collation': 'utf8mb4_unicode_ci'
            }
            
            self.source_pool = pooling.MySQLConnectionPool(**source_config)
            
            # Target database pool (could be different database)
            target_config = source_config.copy()
            target_config.update({
                'pool_name': 'target_pool',
                'pool_size': self.config['target_database']['pool_size'],
                'host': self.config['target_database']['host'],
                'port': self.config['target_database']['port'],
                'database': self.config['target_database']['database'],
                'user': self.config['target_database']['user'],
                'password': self.config['target_database']['password']
            })
            
            self.target_pool = pooling.MySQLConnectionPool(**target_config)
            
            logger.info("Database connection pools initialized successfully")
            
        except Error as e:
            logger.error(f"Error initializing database connections: {e}")
            raise
    
    @contextmanager
    def get_connection(self, pool_type: str = 'source'):
        """
        Context manager for database connections
        
        Args:
            pool_type: 'source' or 'target' pool
        """
        connection = None
        try:
            if pool_type == 'source':
                connection = self.source_pool.get_connection()
            else:
                connection = self.target_pool.get_connection()
            
            # Set audit context variables
            cursor = connection.cursor()
            cursor.execute("SET @audit_user = %s", (self.audit_context['user'],))
            cursor.execute("SET @audit_app = %s", (self.audit_context['application'],))
            cursor.execute("SET @audit_session = %s", (self.audit_context['session_id'],))
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
    
    def extract_data(self, query: str, params: tuple = None) -> pd.DataFrame:
        """
        Extract data using SQL query
        
        Args:
            query: SQL query to execute
            params: Query parameters
            
        Returns:
            DataFrame with extracted data
        """
        try:
            with self.get_connection('source') as connection:
                df = pd.read_sql(query, connection, params=params)
                logger.info(f"Extracted {len(df)} rows from source database")
                return df
                
        except Exception as e:
            logger.error(f"Error extracting data: {e}")
            raise
    
    def transform_customer_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Transform customer data for reporting
        
        Args:
            df: Raw customer data
            
        Returns:
            Transformed DataFrame
        """
        try:
            # Create full name
            df['customer_name'] = df['first_name'] + ' ' + df['last_name']
            
            # Calculate customer age if date_of_birth exists
            if 'date_of_birth' in df.columns:
                df['age'] = df['date_of_birth'].apply(
                    lambda x: (datetime.now().date() - x).days // 365 if pd.notna(x) else None
                )
            
            # Add processing metadata
            df['processed_at'] = datetime.now()
            df['etl_batch_id'] = self.audit_context['session_id']
            
            # Clean data
            df = df.dropna(subset=['email'])  # Remove customers without email
            df['email'] = df['email'].str.lower()  # Normalize email
            
            logger.info(f"Transformed {len(df)} customer records")
            return df
            
        except Exception as e:
            logger.error(f"Error transforming customer data: {e}")
            raise
    
    def transform_order_summary(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Transform order data for customer summary
        
        Args:
            df: Raw order data with customer information
            
        Returns:
            Transformed customer order summary
        """
        try:
            # Group by customer and calculate aggregates
            summary = df.groupby(['customer_id', 'customer_email', 'customer_name']).agg({
                'order_id': 'count',
                'total_amount': ['sum', 'mean', 'min', 'max'],
                'created_at': ['min', 'max']
            }).reset_index()
            
            # Flatten column names
            summary.columns = [
                'customer_id', 'customer_email', 'customer_name',
                'total_orders', 'total_spent', 'avg_order_value',
                'min_order_value', 'max_order_value',
                'first_order_date', 'last_order_date'
            ]
            
            # Calculate days since last order
            summary['days_since_last_order'] = (
                datetime.now() - summary['last_order_date']
            ).dt.days
            
            # Classify customer segments
            def classify_segment(row):
                if row['total_orders'] == 0:
                    return 'new'
                elif row['days_since_last_order'] > 365:
                    return 'churned'
                elif row['days_since_last_order'] > 180:
                    return 'at_risk'
                elif row['total_spent'] > 5000 or row['total_orders'] > 20:
                    return 'vip'
                elif row['total_orders'] > 1:
                    return 'regular'
                else:
                    return 'new'
            
            summary['customer_segment'] = summary.apply(classify_segment, axis=1)
            
            # Add metadata
            summary['last_calculated_at'] = datetime.now()
            
            logger.info(f"Created order summary for {len(summary)} customers")
            return summary
            
        except Exception as e:
            logger.error(f"Error transforming order summary: {e}")
            raise
    
    def load_data(self, df: pd.DataFrame, table_name: str, 
                  load_method: str = 'replace') -> bool:
        """
        Load data to target table
        
        Args:
            df: DataFrame to load
            table_name: Target table name
            load_method: 'replace', 'append', or 'upsert'
            
        Returns:
            Success status
        """
        try:
            with self.get_connection('target') as connection:
                cursor = connection.cursor()
                
                if load_method == 'replace':
                    # Truncate and insert
                    cursor.execute(f"TRUNCATE TABLE {table_name}")
                    df.to_sql(table_name, connection, if_exists='append', 
                             index=False, method='multi')
                    
                elif load_method == 'append':
                    # Simple append
                    df.to_sql(table_name, connection, if_exists='append', 
                             index=False, method='multi')
                    
                elif load_method == 'upsert':
                    # Insert with ON DUPLICATE KEY UPDATE
                    self._upsert_data(df, table_name, connection)
                
                connection.commit()
                logger.info(f"Loaded {len(df)} rows to {table_name} using {load_method} method")
                return True
                
        except Exception as e:
            logger.error(f"Error loading data to {table_name}: {e}")
            raise
    
    def _upsert_data(self, df: pd.DataFrame, table_name: str, connection):
        """
        Perform upsert operation using INSERT ... ON DUPLICATE KEY UPDATE
        """
        cursor = connection.cursor()
        
        # Get table columns
        cursor.execute(f"DESCRIBE {table_name}")
        columns = [row[0] for row in cursor.fetchall()]
        
        # Filter DataFrame columns to match table
        df_columns = [col for col in df.columns if col in columns]
        df_filtered = df[df_columns]
        
        # Create INSERT statement with ON DUPLICATE KEY UPDATE
        placeholders = ', '.join(['%s'] * len(df_columns))
        columns_str = ', '.join(df_columns)
        
        update_clause = ', '.join([f"{col} = VALUES({col})" for col in df_columns])
        
        query = f"""
        INSERT INTO {table_name} ({columns_str})
        VALUES ({placeholders})
        ON DUPLICATE KEY UPDATE {update_clause}
        """
        
        # Execute batch insert
        batch_size = self.config.get('batch_size', 1000)
        for i in range(0, len(df_filtered), batch_size):
            batch = df_filtered.iloc[i:i+batch_size]
            data = [tuple(row) for row in batch.to_numpy()]
            cursor.executemany(query, data)
            
        cursor.close()
    
    def run_customer_summary_etl(self):
        """
        Complete ETL pipeline for customer order summary
        """
        logger.info("Starting customer summary ETL pipeline")
        
        try:
            # Extract customer and order data
            extract_query = """
            SELECT 
                c.customer_id,
                c.email as customer_email,
                CONCAT(c.first_name, ' ', c.last_name) as customer_name,
                c.phone as customer_phone,
                DATE(c.created_at) as customer_created_date,
                o.order_id,
                o.total_amount,
                o.created_at,
                o.order_status
            FROM customers c
            LEFT JOIN orders o ON c.customer_id = o.customer_id 
                AND o.order_status NOT IN ('cancelled')
            WHERE c.created_at >= %s
            ORDER BY c.customer_id, o.created_at
            """
            
            # Extract data from last 30 days
            cutoff_date = datetime.now() - timedelta(days=30)
            df_raw = self.extract_data(extract_query, (cutoff_date,))
            
            if df_raw.empty:
                logger.warning("No data found for customer summary ETL")
                return
            
            # Transform data
            df_summary = self.transform_order_summary(df_raw)
            
            # Load to target table
            self.load_data(df_summary, 'customer_order_summary', 'upsert')
            
            logger.info("Customer summary ETL pipeline completed successfully")
            
        except Exception as e:
            logger.error(f"Customer summary ETL pipeline failed: {e}")
            raise
    
    def run_daily_sales_summary_etl(self, target_date: datetime = None):
        """
        ETL pipeline for daily sales summary
        
        Args:
            target_date: Date to process (defaults to yesterday)
        """
        if target_date is None:
            target_date = datetime.now().date() - timedelta(days=1)
            
        logger.info(f"Starting daily sales summary ETL for {target_date}")
        
        try:
            # Extract daily sales data
            extract_query = """
            SELECT 
                DATE(o.created_at) as order_date,
                COUNT(DISTINCT o.order_id) as total_orders,
                SUM(o.total_amount) as total_order_value,
                AVG(o.total_amount) as avg_order_value,
                COUNT(DISTINCT o.customer_id) as total_customers,
                COUNT(DISTINCT CASE 
                    WHEN c.created_at >= DATE(o.created_at) - INTERVAL 1 DAY 
                    THEN o.customer_id 
                END) as new_customers,
                DAYNAME(o.created_at) as day_of_week,
                CASE WHEN DAYOFWEEK(o.created_at) IN (1, 7) THEN 1 ELSE 0 END as is_weekend
            FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
            WHERE DATE(o.created_at) = %s
                AND o.order_status NOT IN ('cancelled')
            GROUP BY DATE(o.created_at)
            """
            
            df_daily = self.extract_data(extract_query, (target_date,))
            
            if df_daily.empty:
                logger.warning(f"No sales data found for {target_date}")
                return
            
            # Add calculated fields
            df_daily['summary_date'] = target_date
            df_daily['returning_customers'] = (
                df_daily['total_customers'] - df_daily['new_customers']
            )
            df_daily['last_calculated_at'] = datetime.now()
            
            # Load to target table
            self.load_data(df_daily, 'daily_sales_summary', 'upsert')
            
            logger.info(f"Daily sales summary ETL for {target_date} completed successfully")
            
        except Exception as e:
            logger.error(f"Daily sales summary ETL failed for {target_date}: {e}")
            raise
    
    def run_full_pipeline(self):
        """
        Run complete ETL pipeline
        """
        logger.info("Starting full ETL pipeline")
        
        try:
            self.initialize_connections()
            
            # Run individual ETL processes
            self.run_customer_summary_etl()
            self.run_daily_sales_summary_etl()
            
            # Run for last 7 days of daily summaries
            for i in range(1, 8):
                date = datetime.now().date() - timedelta(days=i)
                self.run_daily_sales_summary_etl(date)
            
            logger.info("Full ETL pipeline completed successfully")
            
        except Exception as e:
            logger.error(f"Full ETL pipeline failed: {e}")
            raise
    
    def cleanup(self):
        """Clean up resources"""
        logger.info("Cleaning up ETL pipeline resources")


def main():
    """
    Main execution function
    """
    try:
        # Initialize ETL pipeline
        etl = MySQLETLPipeline()
        
        # Run pipeline based on command line arguments
        if len(sys.argv) > 1:
            if sys.argv[1] == 'customer-summary':
                etl.initialize_connections()
                etl.run_customer_summary_etl()
            elif sys.argv[1] == 'daily-sales':
                etl.initialize_connections()
                etl.run_daily_sales_summary_etl()
            elif sys.argv[1] == 'full':
                etl.run_full_pipeline()
            else:
                print("Usage: python etl_pipeline.py [customer-summary|daily-sales|full]")
                sys.exit(1)
        else:
            # Default: run full pipeline
            etl.run_full_pipeline()
            
        etl.cleanup()
        
    except Exception as e:
        logger.error(f"ETL pipeline execution failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()