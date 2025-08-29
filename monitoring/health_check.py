#!/usr/bin/env python3
"""
Database Health Check Script
============================
Purpose: Comprehensive database health monitoring for MySQL
Based on: mysql-instructions.md monitoring guidelines
Usage: Run periodically via cron or monitoring system
"""

import sys
import os
import json
import argparse
from datetime import datetime
import mysql.connector
from mysql.connector import Error
import subprocess

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.connection.python_database_manager import create_database_manager


class DatabaseHealthChecker:
    """Comprehensive database health monitoring"""
    
    def __init__(self, environment='development'):
        self.environment = environment
        self.db = None
        self.health_status = {
            'overall': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'environment': environment,
            'checks': {}
        }
    
    def connect(self):
        """Establish database connection"""
        try:
            self.db = create_database_manager(self.environment)
            return True
        except Exception as e:
            self.health_status['overall'] = 'critical'
            self.health_status['checks']['connection'] = {
                'status': 'failed',
                'error': str(e)
            }
            return False
    
    def check_connection_pool(self):
        """Check database connection pool status"""
        try:
            pool_status = self.db.getPoolStatus()
            
            # Calculate connection utilization
            total_connections = pool_status.get('totalConnections', 0)
            connection_limit = pool_status.get('config', {}).get('connectionLimit', 10)
            utilization = (total_connections / connection_limit) * 100 if connection_limit > 0 else 0
            
            status = 'healthy'
            if utilization > 80:
                status = 'warning'
            if utilization > 95:
                status = 'critical'
            
            self.health_status['checks']['connection_pool'] = {
                'status': status,
                'total_connections': total_connections,
                'connection_limit': connection_limit,
                'utilization_percent': round(utilization, 2),
                'queued_requests': pool_status.get('queuedRequests', 0)
            }
            
        except Exception as e:
            self.health_status['checks']['connection_pool'] = {
                'status': 'failed',
                'error': str(e)
            }
            if self.health_status['overall'] == 'healthy':
                self.health_status['overall'] = 'warning'
    
    def check_query_performance(self):
        """Check query performance metrics"""
        try:
            stats = self.db.get_performance_stats()
            
            # Determine status based on performance metrics
            status = 'healthy'
            if stats['error_rate'] > 1.0:  # > 1% error rate
                status = 'warning'
            if stats['error_rate'] > 5.0:  # > 5% error rate
                status = 'critical'
            
            if stats['slow_query_rate'] > 10.0:  # > 10% slow queries
                status = 'warning'
            if stats['slow_query_rate'] > 25.0:  # > 25% slow queries
                status = 'critical'
            
            self.health_status['checks']['query_performance'] = {
                'status': status,
                'total_queries': stats['total_queries'],
                'error_rate': stats['error_rate'],
                'slow_query_rate': stats['slow_query_rate'],
                'average_execution_time': stats['average_execution_time']
            }
            
        except Exception as e:
            self.health_status['checks']['query_performance'] = {
                'status': 'failed',
                'error': str(e)
            }
    
    def check_database_size(self):
        """Check database and table sizes"""
        try:
            query = """
            SELECT 
                table_schema as database_name,
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as total_size_mb,
                COUNT(*) as table_count
            FROM information_schema.tables 
            WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
            GROUP BY table_schema
            """
            
            results, _ = self.db.execute_query(query)
            
            total_size = sum(row['total_size_mb'] for row in results)
            
            # Simple size check (adjust thresholds as needed)
            status = 'healthy'
            if total_size > 10000:  # > 10GB
                status = 'warning'
            if total_size > 50000:  # > 50GB
                status = 'critical'
            
            self.health_status['checks']['database_size'] = {
                'status': status,
                'total_size_mb': total_size,
                'databases': results
            }
            
        except Exception as e:
            self.health_status['checks']['database_size'] = {
                'status': 'failed',
                'error': str(e)
            }
    
    def check_replication_lag(self):
        """Check replication lag (if applicable)"""
        try:
            # Check if this is a replica
            show_slave_query = "SHOW SLAVE STATUS"
            results, _ = self.db.execute_query(show_slave_query)
            
            if results:
                # This is a replica, check lag
                slave_status = results[0]
                seconds_behind_master = slave_status.get('Seconds_Behind_Master')
                
                if seconds_behind_master is None:
                    status = 'critical'  # Replication broken
                elif seconds_behind_master > 300:  # > 5 minutes
                    status = 'critical'
                elif seconds_behind_master > 60:   # > 1 minute
                    status = 'warning'
                else:
                    status = 'healthy'
                
                self.health_status['checks']['replication'] = {
                    'status': status,
                    'seconds_behind_master': seconds_behind_master,
                    'slave_io_running': slave_status.get('Slave_IO_Running'),
                    'slave_sql_running': slave_status.get('Slave_SQL_Running')
                }
            else:
                # Not a replica
                self.health_status['checks']['replication'] = {
                    'status': 'not_applicable',
                    'message': 'This server is not configured as a replica'
                }
                
        except Exception as e:
            # Might not have replication permissions
            self.health_status['checks']['replication'] = {
                'status': 'unknown',
                'error': str(e)
            }
    
    def check_audit_log_health(self):
        """Check audit log table health"""
        try:
            # Check audit log growth
            query = """
            SELECT 
                COUNT(*) as total_records,
                COUNT(CASE WHEN changed_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN 1 END) as last_hour,
                COUNT(CASE WHEN changed_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) THEN 1 END) as last_day,
                MIN(changed_at) as oldest_record,
                MAX(changed_at) as newest_record
            FROM audit_log
            """
            
            results, _ = self.db.execute_query(query)
            audit_stats = results[0] if results else {}
            
            # Check if audit log is growing (should have recent entries)
            last_hour_count = audit_stats.get('last_hour', 0)
            
            status = 'healthy'
            if last_hour_count == 0:
                status = 'warning'  # No recent audit entries
            
            self.health_status['checks']['audit_log'] = {
                'status': status,
                'total_records': audit_stats.get('total_records', 0),
                'last_hour_records': last_hour_count,
                'last_day_records': audit_stats.get('last_day', 0),
                'oldest_record': str(audit_stats.get('oldest_record', '')),
                'newest_record': str(audit_stats.get('newest_record', ''))
            }
            
        except Exception as e:
            self.health_status['checks']['audit_log'] = {
                'status': 'failed',
                'error': str(e)
            }
    
    def check_backup_status(self):
        """Check recent backup status"""
        try:
            # Look for recent backup files
            backup_dir = "/var/backups/mysql"  # Default backup directory
            
            if os.path.exists(backup_dir):
                # Find most recent backup
                backup_files = []
                for file in os.listdir(backup_dir):
                    if file.endswith(('.sql', '.sql.gz')):
                        file_path = os.path.join(backup_dir, file)
                        stat = os.stat(file_path)
                        backup_files.append({
                            'filename': file,
                            'size_mb': round(stat.st_size / 1024 / 1024, 2),
                            'modified': datetime.fromtimestamp(stat.st_mtime)
                        })
                
                if backup_files:
                    # Sort by modification time, most recent first
                    backup_files.sort(key=lambda x: x['modified'], reverse=True)
                    latest_backup = backup_files[0]
                    
                    # Check if backup is recent (within last 24 hours)
                    hours_since_backup = (datetime.now() - latest_backup['modified']).total_seconds() / 3600
                    
                    status = 'healthy'
                    if hours_since_backup > 48:  # > 48 hours
                        status = 'critical'
                    elif hours_since_backup > 25:  # > 25 hours
                        status = 'warning'
                    
                    self.health_status['checks']['backup'] = {
                        'status': status,
                        'latest_backup': latest_backup['filename'],
                        'hours_since_backup': round(hours_since_backup, 1),
                        'backup_size_mb': latest_backup['size_mb'],
                        'total_backups': len(backup_files)
                    }
                else:
                    self.health_status['checks']['backup'] = {
                        'status': 'critical',
                        'message': 'No backup files found'
                    }
            else:
                self.health_status['checks']['backup'] = {
                    'status': 'warning',
                    'message': f'Backup directory not found: {backup_dir}'
                }
                
        except Exception as e:
            self.health_status['checks']['backup'] = {
                'status': 'failed',
                'error': str(e)
            }
    
    def determine_overall_status(self):
        """Determine overall health status based on individual checks"""
        has_critical = False
        has_warning = False
        
        for check_name, check_result in self.health_status['checks'].items():
            status = check_result.get('status', 'unknown')
            
            if status == 'critical' or status == 'failed':
                has_critical = True
            elif status == 'warning':
                has_warning = True
        
        if has_critical:
            self.health_status['overall'] = 'critical'
        elif has_warning:
            self.health_status['overall'] = 'warning'
        else:
            self.health_status['overall'] = 'healthy'
    
    def run_all_checks(self):
        """Run all health checks"""
        if not self.connect():
            return self.health_status
        
        try:
            self.check_connection_pool()
            self.check_query_performance()
            self.check_database_size()
            self.check_replication_lag()
            self.check_audit_log_health()
            self.check_backup_status()
            
            self.determine_overall_status()
            
        except Exception as e:
            self.health_status['overall'] = 'critical'
            self.health_status['error'] = str(e)
        
        finally:
            if self.db:
                self.db.close()
        
        return self.health_status


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description='MySQL Database Health Checker')
    parser.add_argument('--environment', '-e', default='development',
                      choices=['development', 'staging', 'production'],
                      help='Database environment to check')
    parser.add_argument('--output', '-o', choices=['json', 'text'], default='text',
                      help='Output format')
    parser.add_argument('--quiet', '-q', action='store_true',
                      help='Only output errors and warnings')
    
    args = parser.parse_args()
    
    # Run health checks
    checker = DatabaseHealthChecker(args.environment)
    health_status = checker.run_all_checks()
    
    # Output results
    if args.output == 'json':
        print(json.dumps(health_status, indent=2, default=str))
    else:
        # Text output
        print(f"Database Health Check - {args.environment.upper()}")
        print("=" * 50)
        print(f"Overall Status: {health_status['overall'].upper()}")
        print(f"Timestamp: {health_status['timestamp']}")
        print()
        
        for check_name, check_result in health_status['checks'].items():
            status = check_result.get('status', 'unknown')
            
            # Skip healthy checks if quiet mode
            if args.quiet and status == 'healthy':
                continue
            
            print(f"{check_name.replace('_', ' ').title()}: {status.upper()}")
            
            if status in ['warning', 'critical', 'failed']:
                if 'error' in check_result:
                    print(f"  Error: {check_result['error']}")
                if 'message' in check_result:
                    print(f"  Message: {check_result['message']}")
                
                # Print relevant metrics
                for key, value in check_result.items():
                    if key not in ['status', 'error', 'message']:
                        print(f"  {key}: {value}")
            print()
    
    # Set exit code based on health status
    if health_status['overall'] == 'critical':
        sys.exit(2)
    elif health_status['overall'] == 'warning':
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()