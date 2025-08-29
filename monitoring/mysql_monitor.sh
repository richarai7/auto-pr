#!/bin/bash
# ============================================================================
# MySQL Database Monitoring and Health Check Script
# ============================================================================
# This script provides comprehensive monitoring for MySQL database systems
# including performance metrics, health checks, and alerting capabilities.
#
# Author: MySQL Architecture Team
# Version: 1.0
# Last Updated: 2024
# ============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
CONFIG_FILE="${SCRIPT_DIR}/monitoring.conf"
ALERT_LOG="${LOG_DIR}/alerts.log"
METRICS_LOG="${LOG_DIR}/metrics.log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Default configuration (override with monitoring.conf)
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-app_monitor}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-Monitor\$ecure2024!}"
MYSQL_DATABASE="${MYSQL_DATABASE:-myapp}"

# Monitoring thresholds
CONNECTION_THRESHOLD="${CONNECTION_THRESHOLD:-80}"      # % of max connections
SLOW_QUERY_THRESHOLD="${SLOW_QUERY_THRESHOLD:-1000}"   # milliseconds
DISK_USAGE_THRESHOLD="${DISK_USAGE_THRESHOLD:-85}"     # % disk usage
REPLICATION_LAG_THRESHOLD="${REPLICATION_LAG_THRESHOLD:-30}"  # seconds
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"                   # % CPU usage
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-85}"             # % memory usage

# Alert settings
ENABLE_EMAIL_ALERTS="${ENABLE_EMAIL_ALERTS:-false}"
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"
ENABLE_SLACK_ALERTS="${ENABLE_SLACK_ALERTS:-false}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Load configuration file if it exists
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" | tee -a "${METRICS_LOG}"
}

# Alert function
alert() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "${timestamp} [${severity}] ${message}" >> "${ALERT_LOG}"
    
    # Console output with color
    case "${severity}" in
        "CRITICAL")
            echo -e "${RED}[CRITICAL]${NC} ${message}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} ${message}"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        *)
            echo -e "${BLUE}[${severity}]${NC} ${message}"
            ;;
    esac
    
    # Send email alert if enabled
    if [[ "${ENABLE_EMAIL_ALERTS}" == "true" ]] && [[ "${severity}" != "INFO" ]]; then
        send_email_alert "${severity}" "${message}"
    fi
    
    # Send Slack alert if enabled
    if [[ "${ENABLE_SLACK_ALERTS}" == "true" ]] && [[ "${severity}" != "INFO" ]]; then
        send_slack_alert "${severity}" "${message}"
    fi
}

# Email alert function
send_email_alert() {
    local severity="$1"
    local message="$2"
    local subject="MySQL Alert [${severity}] - ${MYSQL_HOST}"
    
    if command -v mail >/dev/null 2>&1; then
        echo "MySQL Database Alert

Server: ${MYSQL_HOST}:${MYSQL_PORT}
Database: ${MYSQL_DATABASE}
Severity: ${severity}
Time: $(date)

Alert Details:
${message}

This is an automated alert from MySQL monitoring system." | mail -s "${subject}" "${ALERT_EMAIL}"
    else
        log "ERROR" "Mail command not available for email alerts"
    fi
}

# Slack alert function
send_slack_alert() {
    local severity="$1"
    local message="$2"
    
    if [[ -n "${SLACK_WEBHOOK_URL}" ]]; then
        local color="good"
        case "${severity}" in
            "CRITICAL") color="danger" ;;
            "WARNING") color="warning" ;;
        esac
        
        local payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${color}",
            "title": "MySQL Alert [${severity}]",
            "fields": [
                {
                    "title": "Server",
                    "value": "${MYSQL_HOST}:${MYSQL_PORT}",
                    "short": true
                },
                {
                    "title": "Database",
                    "value": "${MYSQL_DATABASE}",
                    "short": true
                },
                {
                    "title": "Alert Details",
                    "value": "${message}",
                    "short": false
                }
            ],
            "footer": "MySQL Monitoring",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
        
        curl -X POST -H 'Content-type: application/json' \
             --data "${payload}" \
             "${SLACK_WEBHOOK_URL}" >/dev/null 2>&1
    fi
}

# MySQL connection test
test_mysql_connection() {
    mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
          -e "SELECT 1;" >/dev/null 2>&1
    return $?
}

# Execute MySQL query and return result
mysql_query() {
    local query="$1"
    mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
          -s -N -e "${query}" 2>/dev/null
}

# Get MySQL status variable
get_mysql_status() {
    local variable="$1"
    mysql_query "SHOW GLOBAL STATUS LIKE '${variable}';" | awk '{print $2}'
}

# Get MySQL configuration variable
get_mysql_variable() {
    local variable="$1"
    mysql_query "SHOW GLOBAL VARIABLES LIKE '${variable}';" | awk '{print $2}'
}

# Check database connectivity
check_connectivity() {
    log "INFO" "Checking database connectivity..."
    
    if test_mysql_connection; then
        alert "INFO" "Database connectivity: OK"
        return 0
    else
        alert "CRITICAL" "Database connectivity: FAILED - Cannot connect to MySQL server"
        return 1
    fi
}

# Check connection usage
check_connections() {
    log "INFO" "Checking connection usage..."
    
    local threads_connected=$(get_mysql_status "Threads_connected")
    local max_connections=$(get_mysql_variable "max_connections")
    
    if [[ -n "${threads_connected}" ]] && [[ -n "${max_connections}" ]]; then
        local usage_percent=$((threads_connected * 100 / max_connections))
        
        log "INFO" "Connections: ${threads_connected}/${max_connections} (${usage_percent}%)"
        
        if [[ ${usage_percent} -ge ${CONNECTION_THRESHOLD} ]]; then
            alert "WARNING" "High connection usage: ${usage_percent}% (${threads_connected}/${max_connections})"
        else
            alert "INFO" "Connection usage: ${usage_percent}% - OK"
        fi
    else
        alert "WARNING" "Could not retrieve connection information"
    fi
}

# Check slow queries
check_slow_queries() {
    log "INFO" "Checking slow queries..."
    
    local slow_queries=$(get_mysql_status "Slow_queries")
    local uptime=$(get_mysql_status "Uptime")
    
    if [[ -n "${slow_queries}" ]] && [[ -n "${uptime}" ]] && [[ ${uptime} -gt 0 ]]; then
        local slow_queries_per_hour=$((slow_queries * 3600 / uptime))
        
        log "INFO" "Slow queries: ${slow_queries} total, ${slow_queries_per_hour}/hour"
        
        if [[ ${slow_queries_per_hour} -gt 10 ]]; then
            alert "WARNING" "High slow query rate: ${slow_queries_per_hour} queries/hour"
        else
            alert "INFO" "Slow query rate: ${slow_queries_per_hour} queries/hour - OK"
        fi
    else
        alert "WARNING" "Could not retrieve slow query information"
    fi
}

# Check replication status (if slave)
check_replication() {
    log "INFO" "Checking replication status..."
    
    local replication_info=$(mysql_query "SHOW SLAVE STATUS\\G")
    
    if [[ -n "${replication_info}" ]]; then
        local slave_io_running=$(echo "${replication_info}" | grep "Slave_IO_Running:" | awk '{print $2}')
        local slave_sql_running=$(echo "${replication_info}" | grep "Slave_SQL_Running:" | awk '{print $2}')
        local seconds_behind=$(echo "${replication_info}" | grep "Seconds_Behind_Master:" | awk '{print $2}')
        
        if [[ "${slave_io_running}" == "Yes" ]] && [[ "${slave_sql_running}" == "Yes" ]]; then
            if [[ "${seconds_behind}" == "NULL" ]] || [[ -z "${seconds_behind}" ]]; then
                alert "WARNING" "Replication lag information not available"
            elif [[ ${seconds_behind} -gt ${REPLICATION_LAG_THRESHOLD} ]]; then
                alert "WARNING" "High replication lag: ${seconds_behind} seconds behind master"
            else
                alert "INFO" "Replication status: OK (${seconds_behind}s behind)"
            fi
        else
            alert "CRITICAL" "Replication stopped - IO: ${slave_io_running}, SQL: ${slave_sql_running}"
        fi
    else
        log "INFO" "No replication configured (master server or standalone)"
    fi
}

# Check disk usage
check_disk_usage() {
    log "INFO" "Checking disk usage..."
    
    local datadir=$(get_mysql_variable "datadir")
    
    if [[ -n "${datadir}" ]] && [[ -d "${datadir}" ]]; then
        local disk_usage=$(df "${datadir}" | tail -1 | awk '{print $5}' | sed 's/%//')
        
        log "INFO" "Disk usage for MySQL datadir: ${disk_usage}%"
        
        if [[ ${disk_usage} -ge ${DISK_USAGE_THRESHOLD} ]]; then
            alert "WARNING" "High disk usage: ${disk_usage}% of MySQL datadir"
        else
            alert "INFO" "Disk usage: ${disk_usage}% - OK"
        fi
    else
        alert "WARNING" "Could not determine MySQL data directory"
    fi
}

# Check InnoDB status
check_innodb_status() {
    log "INFO" "Checking InnoDB status..."
    
    local innodb_buffer_pool_pages_total=$(get_mysql_status "Innodb_buffer_pool_pages_total")
    local innodb_buffer_pool_pages_free=$(get_mysql_status "Innodb_buffer_pool_pages_free")
    local innodb_buffer_pool_pages_dirty=$(get_mysql_status "Innodb_buffer_pool_pages_dirty")
    
    if [[ -n "${innodb_buffer_pool_pages_total}" ]] && [[ ${innodb_buffer_pool_pages_total} -gt 0 ]]; then
        local buffer_pool_usage=$((100 - (innodb_buffer_pool_pages_free * 100 / innodb_buffer_pool_pages_total)))
        local dirty_pages_percent=$((innodb_buffer_pool_pages_dirty * 100 / innodb_buffer_pool_pages_total))
        
        log "INFO" "InnoDB buffer pool usage: ${buffer_pool_usage}%"
        log "INFO" "InnoDB dirty pages: ${dirty_pages_percent}%"
        
        if [[ ${buffer_pool_usage} -lt 50 ]]; then
            alert "INFO" "InnoDB buffer pool usage: ${buffer_pool_usage}% - Consider tuning buffer pool size"
        fi
        
        if [[ ${dirty_pages_percent} -gt 75 ]]; then
            alert "WARNING" "High InnoDB dirty pages: ${dirty_pages_percent}%"
        fi
    else
        alert "WARNING" "Could not retrieve InnoDB buffer pool information"
    fi
}

# Check binary log usage
check_binary_logs() {
    log "INFO" "Checking binary log usage..."
    
    local log_bin=$(get_mysql_variable "log_bin")
    
    if [[ "${log_bin}" == "ON" ]]; then
        local binlog_space=$(mysql_query "SELECT ROUND(SUM(File_size)/(1024*1024*1024),2) as binlog_gb FROM information_schema.PROCESSLIST; SELECT ROUND(SUM(File_size)/(1024*1024*1024),2) as binlog_gb FROM INFORMATION_SCHEMA.FILES WHERE TABLESPACE_NAME IS NULL;" 2>/dev/null)
        
        # Alternative method for binary log size
        local binlog_files=$(mysql_query "SHOW BINARY LOGS;" | wc -l)
        
        log "INFO" "Binary logging enabled with ${binlog_files} log files"
        
        if [[ ${binlog_files} -gt 100 ]]; then
            alert "WARNING" "High number of binary log files: ${binlog_files} - Consider log rotation"
        fi
    else
        log "INFO" "Binary logging is disabled"
    fi
}

# Check table locks
check_table_locks() {
    log "INFO" "Checking table locks..."
    
    local table_locks_waited=$(get_mysql_status "Table_locks_waited")
    local table_locks_immediate=$(get_mysql_status "Table_locks_immediate")
    
    if [[ -n "${table_locks_waited}" ]] && [[ -n "${table_locks_immediate}" ]]; then
        local total_locks=$((table_locks_waited + table_locks_immediate))
        
        if [[ ${total_locks} -gt 0 ]]; then
            local lock_wait_ratio=$((table_locks_waited * 100 / total_locks))
            
            log "INFO" "Table lock wait ratio: ${lock_wait_ratio}%"
            
            if [[ ${lock_wait_ratio} -gt 10 ]]; then
                alert "WARNING" "High table lock wait ratio: ${lock_wait_ratio}%"
            fi
        fi
    fi
}

# Generate performance report
generate_performance_report() {
    log "INFO" "Generating performance report..."
    
    local report_file="${LOG_DIR}/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "MySQL Performance Report"
        echo "========================"
        echo "Generated: $(date)"
        echo "Server: ${MYSQL_HOST}:${MYSQL_PORT}"
        echo "Database: ${MYSQL_DATABASE}"
        echo ""
        
        echo "Connection Information:"
        echo "----------------------"
        mysql_query "SELECT 
            VARIABLE_VALUE as max_connections 
            FROM information_schema.GLOBAL_VARIABLES 
            WHERE VARIABLE_NAME='max_connections';"
        
        mysql_query "SELECT 
            VARIABLE_VALUE as threads_connected 
            FROM information_schema.GLOBAL_STATUS 
            WHERE VARIABLE_NAME='Threads_connected';"
        
        echo ""
        echo "Query Performance:"
        echo "-----------------"
        mysql_query "SELECT 
            ROUND(Questions/Uptime,2) as 'Queries per second',
            ROUND(Slow_queries*100/Questions,2) as 'Slow query %'
            FROM (
                SELECT VARIABLE_VALUE as Questions 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Questions'
            ) q,
            (
                SELECT VARIABLE_VALUE as Uptime 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Uptime'
            ) u,
            (
                SELECT VARIABLE_VALUE as Slow_queries 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Slow_queries'
            ) s;"
        
        echo ""
        echo "InnoDB Status:"
        echo "-------------"
        mysql_query "SELECT 
            ROUND(Innodb_buffer_pool_pages_total*16/1024,2) as 'Buffer Pool MB',
            ROUND((Innodb_buffer_pool_pages_total-Innodb_buffer_pool_pages_free)*100/Innodb_buffer_pool_pages_total,2) as 'Buffer Pool Usage %',
            ROUND(Innodb_buffer_pool_pages_dirty*100/Innodb_buffer_pool_pages_total,2) as 'Dirty Pages %'
            FROM (
                SELECT VARIABLE_VALUE as Innodb_buffer_pool_pages_total 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Innodb_buffer_pool_pages_total'
            ) t,
            (
                SELECT VARIABLE_VALUE as Innodb_buffer_pool_pages_free 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Innodb_buffer_pool_pages_free'
            ) f,
            (
                SELECT VARIABLE_VALUE as Innodb_buffer_pool_pages_dirty 
                FROM information_schema.GLOBAL_STATUS 
                WHERE VARIABLE_NAME='Innodb_buffer_pool_pages_dirty'
            ) d;"
        
    } > "${report_file}"
    
    log "INFO" "Performance report saved to: ${report_file}"
}

# Main monitoring function
run_monitoring() {
    log "INFO" "Starting MySQL monitoring check..."
    
    # Basic connectivity check
    if ! check_connectivity; then
        alert "CRITICAL" "Monitoring terminated due to connectivity failure"
        return 1
    fi
    
    # Run all monitoring checks
    check_connections
    check_slow_queries
    check_replication
    check_disk_usage
    check_innodb_status
    check_binary_logs
    check_table_locks
    
    log "INFO" "MySQL monitoring check completed"
}

# Show usage information
show_usage() {
    cat << EOF
MySQL Database Monitoring Script

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -c, --check             Run monitoring checks (default)
    -r, --report            Generate performance report
    -t, --test              Test database connection only
    --config FILE           Use custom configuration file
    --host HOST             MySQL host (default: ${MYSQL_HOST})
    --port PORT             MySQL port (default: ${MYSQL_PORT})
    --user USER             MySQL user (default: ${MYSQL_USER})
    --database DB           MySQL database (default: ${MYSQL_DATABASE})

Examples:
    $0                      # Run standard monitoring
    $0 --report             # Generate performance report
    $0 --test               # Test connection only
    $0 --host mydb.com      # Monitor remote host

Configuration:
    Create ${CONFIG_FILE} to override default settings.
    
Log files:
    Metrics: ${METRICS_LOG}
    Alerts:  ${ALERT_LOG}

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--check)
                ACTION="check"
                shift
                ;;
            -r|--report)
                ACTION="report"
                shift
                ;;
            -t|--test)
                ACTION="test"
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --host)
                MYSQL_HOST="$2"
                shift 2
                ;;
            --port)
                MYSQL_PORT="$2"
                shift 2
                ;;
            --user)
                MYSQL_USER="$2"
                shift 2
                ;;
            --database)
                MYSQL_DATABASE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    local action="${ACTION:-check}"
    
    case "${action}" in
        "check")
            run_monitoring
            ;;
        "report")
            generate_performance_report
            ;;
        "test")
            check_connectivity
            ;;
        *)
            echo "Invalid action: ${action}"
            show_usage
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi