-- =============================================================================
-- MySQL Performance Monitoring Queries
-- =============================================================================
-- Purpose: Essential queries for monitoring MySQL database performance
-- Based on: mysql-instructions.md monitoring guidelines
-- Usage: Run these queries regularly for performance analysis
-- =============================================================================

-- =============================================================================
-- 1. SLOW QUERY ANALYSIS
-- =============================================================================

-- Monitor slow queries from the slow query log
-- Note: Requires slow_query_log = ON and log-slow-queries enabled
SELECT 
    start_time,
    user_host,
    query_time,
    lock_time,
    rows_sent,
    rows_examined,
    db,
    SUBSTRING(sql_text, 1, 200) as sql_preview
FROM mysql.slow_log 
WHERE start_time >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY query_time DESC
LIMIT 20;

-- Performance Schema: Top slow queries by average execution time
SELECT 
    DIGEST_TEXT as query_pattern,
    COUNT_STAR as exec_count,
    AVG_TIMER_WAIT/1000000000 as avg_exec_time_sec,
    MAX_TIMER_WAIT/1000000000 as max_exec_time_sec,
    SUM_ROWS_EXAMINED/COUNT_STAR as avg_rows_examined,
    SUM_ROWS_SENT/COUNT_STAR as avg_rows_sent,
    FIRST_SEEN,
    LAST_SEEN
FROM performance_schema.events_statements_summary_by_digest 
WHERE AVG_TIMER_WAIT > 1000000000  -- More than 1 second
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;

-- =============================================================================
-- 2. INDEX USAGE ANALYSIS
-- =============================================================================

-- Check index usage efficiency
SELECT 
    table_schema,
    table_name,
    index_name,
    seq_in_index,
    column_name,
    cardinality,
    CASE 
        WHEN cardinality = 0 THEN 'No selectivity'
        WHEN cardinality < 10 THEN 'Low selectivity'
        WHEN cardinality < 100 THEN 'Medium selectivity'
        ELSE 'High selectivity'
    END as selectivity_level
FROM information_schema.statistics 
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY table_schema, table_name, index_name, seq_in_index;

-- Find unused indexes (MySQL 5.7+)
SELECT 
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    s.INDEX_NAME,
    s.COLUMN_NAME,
    s.CARDINALITY
FROM information_schema.TABLES t
JOIN information_schema.STATISTICS s ON t.TABLE_SCHEMA = s.TABLE_SCHEMA 
    AND t.TABLE_NAME = s.TABLE_NAME
LEFT JOIN performance_schema.table_io_waits_summary_by_index_usage iu 
    ON iu.OBJECT_SCHEMA = s.TABLE_SCHEMA 
    AND iu.OBJECT_NAME = s.TABLE_NAME 
    AND iu.INDEX_NAME = s.INDEX_NAME
WHERE t.TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
    AND s.INDEX_NAME != 'PRIMARY'
    AND (iu.COUNT_READ IS NULL OR iu.COUNT_READ = 0)
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME, s.INDEX_NAME;

-- =============================================================================
-- 3. CONNECTION AND THREAD MONITORING
-- =============================================================================

-- Current connection status
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status 
WHERE VARIABLE_NAME IN (
    'Threads_connected',
    'Threads_running',
    'Connections',
    'Max_used_connections',
    'Connection_errors_max_connections',
    'Connection_errors_internal',
    'Aborted_connects',
    'Aborted_clients'
);

-- Active connections and their status
SELECT 
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    SUBSTRING(INFO, 1, 100) as QUERY_PREVIEW
FROM information_schema.PROCESSLIST 
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Connection usage by user
SELECT 
    USER,
    COUNT(*) as connection_count,
    SUM(CASE WHEN COMMAND != 'Sleep' THEN 1 ELSE 0 END) as active_connections,
    AVG(TIME) as avg_time,
    MAX(TIME) as max_time
FROM information_schema.PROCESSLIST
GROUP BY USER
ORDER BY connection_count DESC;

-- =============================================================================
-- 4. TABLE AND DATABASE SIZE MONITORING
-- =============================================================================

-- Database sizes
SELECT 
    table_schema as database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as total_size_mb,
    ROUND(SUM(data_length) / 1024 / 1024, 2) as data_size_mb,
    ROUND(SUM(index_length) / 1024 / 1024, 2) as index_size_mb,
    COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
GROUP BY table_schema
ORDER BY total_size_mb DESC;

-- Largest tables by size
SELECT 
    table_schema,
    table_name,
    table_rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) as total_size_mb,
    ROUND((data_length / 1024 / 1024), 2) as data_size_mb,
    ROUND((index_length / 1024 / 1024), 2) as index_size_mb,
    ROUND(index_length / data_length, 2) as index_ratio
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
    AND table_type = 'BASE TABLE'
ORDER BY (data_length + index_length) DESC
LIMIT 20;

-- =============================================================================
-- 5. INNODB MONITORING
-- =============================================================================

-- InnoDB status overview
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status 
WHERE VARIABLE_NAME IN (
    'Innodb_buffer_pool_size',
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_data',
    'Innodb_buffer_pool_pages_dirty',
    'Innodb_buffer_pool_read_requests',
    'Innodb_buffer_pool_reads',
    'Innodb_row_lock_current_waits',
    'Innodb_row_lock_time',
    'Innodb_row_lock_waits'
);

-- InnoDB buffer pool hit ratio (should be > 95%)
SELECT 
    ROUND(
        (1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2
    ) as buffer_pool_hit_ratio_percent;

-- =============================================================================
-- 6. QUERY CACHE MONITORING (MySQL 5.7 and earlier)
-- =============================================================================

-- Query cache statistics (if enabled)
SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status 
WHERE VARIABLE_NAME LIKE 'Qcache%';

-- =============================================================================
-- 7. REPLICATION MONITORING (if applicable)
-- =============================================================================

-- Slave status (if this is a replica)
-- Note: Use SHOW REPLICA STATUS in MySQL 8.0.22+
SHOW SLAVE STATUS\G

-- Master status (if this is a source)
SHOW MASTER STATUS;

-- =============================================================================
-- 8. CUSTOM APPLICATION MONITORING
-- =============================================================================

-- Monitor audit log growth
SELECT 
    COUNT(*) as total_audit_records,
    COUNT(CASE WHEN changed_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN 1 END) as last_hour_records,
    COUNT(CASE WHEN changed_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) THEN 1 END) as last_day_records,
    MIN(changed_at) as oldest_record,
    MAX(changed_at) as newest_record
FROM audit_log;

-- Top tables by audit activity
SELECT 
    table_name,
    COUNT(*) as audit_records,
    COUNT(CASE WHEN operation = 'INSERT' THEN 1 END) as inserts,
    COUNT(CASE WHEN operation = 'UPDATE' THEN 1 END) as updates,
    COUNT(CASE WHEN operation = 'DELETE' THEN 1 END) as deletes
FROM audit_log
WHERE changed_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
GROUP BY table_name
ORDER BY audit_records DESC
LIMIT 10;

-- Customer order summary freshness
SELECT 
    COUNT(*) as total_summaries,
    MIN(last_calculated_at) as oldest_calculation,
    MAX(last_calculated_at) as newest_calculation,
    COUNT(CASE WHEN last_calculated_at < DATE_SUB(NOW(), INTERVAL 1 DAY) THEN 1 END) as stale_summaries
FROM customer_order_summary;

-- =============================================================================
-- 9. HEALTH CHECK QUERIES
-- =============================================================================

-- Quick health check query
SELECT 
    'Database' as component,
    CASE 
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'ERROR' 
    END as status,
    COUNT(*) as test_result
FROM information_schema.tables 
WHERE table_schema = DATABASE()
UNION ALL
SELECT 
    'Connections' as component,
    CASE 
        WHEN CAST(VARIABLE_VALUE AS UNSIGNED) < 
             CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_variables WHERE VARIABLE_NAME = 'max_connections') AS UNSIGNED) * 0.8
        THEN 'OK'
        ELSE 'WARNING'
    END as status,
    VARIABLE_VALUE as test_result
FROM performance_schema.global_status 
WHERE VARIABLE_NAME = 'Threads_connected'
UNION ALL
SELECT 
    'Buffer Pool' as component,
    CASE 
        WHEN ROUND(
            (1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2
        ) > 95 THEN 'OK'
        ELSE 'WARNING'
    END as status,
    ROUND(
        (1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2
    ) as test_result;

-- =============================================================================
-- 10. PERFORMANCE TRENDS (for regular monitoring)
-- =============================================================================

-- Daily query volume trend (from audit log)
SELECT 
    DATE(changed_at) as audit_date,
    COUNT(*) as total_operations,
    COUNT(CASE WHEN operation = 'SELECT' THEN 1 END) as selects,
    COUNT(CASE WHEN operation = 'INSERT' THEN 1 END) as inserts,
    COUNT(CASE WHEN operation = 'UPDATE' THEN 1 END) as updates,
    COUNT(CASE WHEN operation = 'DELETE' THEN 1 END) as deletes
FROM audit_log
WHERE changed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(changed_at)
ORDER BY audit_date DESC;

-- Connection peaks by hour
SELECT 
    HOUR(NOW()) as current_hour,
    (SELECT COUNT(*) FROM information_schema.PROCESSLIST) as current_connections,
    'Monitor throughout the day' as recommendation;

-- =============================================================================
-- MONITORING VIEWS FOR REGULAR USE
-- =============================================================================

-- Create a monitoring dashboard view
CREATE OR REPLACE VIEW database_health_dashboard AS
SELECT 
    'System Status' as category,
    CONCAT(
        'Connections: ', 
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'),
        '/', 
        (SELECT VARIABLE_VALUE FROM performance_schema.global_variables WHERE VARIABLE_NAME = 'max_connections')
    ) as metric,
    CASE 
        WHEN CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected') AS UNSIGNED) < 
             CAST((SELECT VARIABLE_VALUE FROM performance_schema.global_variables WHERE VARIABLE_NAME = 'max_connections') AS UNSIGNED) * 0.8
        THEN 'OK'
        ELSE 'WARNING'
    END as status
UNION ALL
SELECT 
    'Buffer Pool',
    CONCAT(
        ROUND(
            (1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2
        ), '%'
    ),
    CASE 
        WHEN ROUND(
            (1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2
        ) > 95 THEN 'OK'
        ELSE 'WARNING'
    END
UNION ALL
SELECT 
    'Slow Queries',
    CONCAT(
        (SELECT COUNT(*) FROM performance_schema.events_statements_summary_by_digest 
         WHERE AVG_TIMER_WAIT > 1000000000), ' queries > 1s avg'
    ),
    CASE 
        WHEN (SELECT COUNT(*) FROM performance_schema.events_statements_summary_by_digest 
              WHERE AVG_TIMER_WAIT > 1000000000) < 10 
        THEN 'OK'
        ELSE 'WARNING'
    END;