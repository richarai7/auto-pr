#!/bin/bash
# ============================================================================
# MySQL Database Automation and Maintenance Script
# ============================================================================
# This script provides automated database maintenance tasks including
# backups, optimization, cleanup, and deployment automation.
#
# Author: MySQL Architecture Team
# Version: 1.0
# Last Updated: 2024
# ============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BACKUP_DIR="${PROJECT_ROOT}/backups"
LOGS_DIR="${PROJECT_ROOT}/logs/automation"
CONFIG_FILE="${SCRIPT_DIR}/automation.conf"

# Create necessary directories
mkdir -p "${BACKUP_DIR}" "${LOGS_DIR}"

# Default configuration
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-app_admin}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-Admin\$ecure2024!}"
MYSQL_DATABASE="${MYSQL_DATABASE:-myapp}"

# Backup configuration
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
COMPRESS_BACKUPS="${COMPRESS_BACKUPS:-true}"
BACKUP_ENCRYPTION="${BACKUP_ENCRYPTION:-false}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

# Maintenance configuration
AUTO_OPTIMIZE_TABLES="${AUTO_OPTIMIZE_TABLES:-true}"
AUTO_CLEANUP_LOGS="${AUTO_CLEANUP_LOGS:-true}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"
STAGING_RETENTION_DAYS="${STAGING_RETENTION_DAYS:-30}"

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
    local log_file="${LOGS_DIR}/automation_$(date +%Y%m%d).log"
    
    echo "${timestamp} [${level}] ${message}" | tee -a "${log_file}"
    
    # Console output with color
    case "${level}" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${message}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${message}"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} ${message}"
            ;;
    esac
}

# Execute MySQL command
mysql_exec() {
    local query="$1"
    local database="${2:-${MYSQL_DATABASE}}"
    
    mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
          "${database}" -e "${query}" 2>/dev/null
}

# Execute MySQL command and return result
mysql_query() {
    local query="$1"
    local database="${2:-${MYSQL_DATABASE}}"
    
    mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
          -s -N "${database}" -e "${query}" 2>/dev/null
}

# Test MySQL connection
test_connection() {
    mysql_query "SELECT 1;" >/dev/null 2>&1
    return $?
}

# Create database backup
create_backup() {
    local backup_type="${1:-full}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${MYSQL_DATABASE}_${backup_type}_${timestamp}.sql"
    
    log "INFO" "Starting ${backup_type} backup for database: ${MYSQL_DATABASE}"
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for backup"
        return 1
    fi
    
    # Determine mysqldump options based on backup type
    local dump_options="--single-transaction --routines --triggers --events --add-drop-database"
    
    case "${backup_type}" in
        "full")
            dump_options="${dump_options} --all-databases"
            backup_file="${BACKUP_DIR}/full_backup_${timestamp}.sql"
            ;;
        "schema")
            dump_options="${dump_options} --no-data"
            ;;
        "data")
            dump_options="${dump_options} --no-create-info"
            ;;
        *)
            # Standard database backup
            ;;
    esac
    
    # Perform backup
    if [[ "${backup_type}" == "full" ]]; then
        mysqldump -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
                  ${dump_options} > "${backup_file}"
    else
        mysqldump -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
                  ${dump_options} "${MYSQL_DATABASE}" > "${backup_file}"
    fi
    
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        local file_size=$(du -h "${backup_file}" | cut -f1)
        log "INFO" "Backup completed successfully: ${backup_file} (${file_size})"
        
        # Compress backup if enabled
        if [[ "${COMPRESS_BACKUPS}" == "true" ]]; then
            log "INFO" "Compressing backup file..."
            gzip "${backup_file}"
            backup_file="${backup_file}.gz"
            local compressed_size=$(du -h "${backup_file}" | cut -f1)
            log "INFO" "Backup compressed: ${compressed_size}"
        fi
        
        # Encrypt backup if enabled
        if [[ "${BACKUP_ENCRYPTION}" == "true" ]] && [[ -n "${BACKUP_ENCRYPTION_KEY}" ]]; then
            log "INFO" "Encrypting backup file..."
            openssl enc -aes-256-cbc -salt -in "${backup_file}" -out "${backup_file}.enc" -k "${BACKUP_ENCRYPTION_KEY}"
            if [[ $? -eq 0 ]]; then
                rm "${backup_file}"
                backup_file="${backup_file}.enc"
                log "INFO" "Backup encrypted successfully"
            else
                log "ERROR" "Backup encryption failed"
            fi
        fi
        
        echo "${backup_file}"
        return 0
    else
        log "ERROR" "Backup failed with exit code: ${exit_code}"
        rm -f "${backup_file}"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than ${BACKUP_RETENTION_DAYS} days..."
    
    local deleted_count=0
    
    # Find and delete old backup files
    while IFS= read -r -d '' file; do
        log "DEBUG" "Deleting old backup: $(basename "${file}")"
        rm -f "${file}"
        ((deleted_count++))
    done < <(find "${BACKUP_DIR}" -name "*.sql*" -type f -mtime +${BACKUP_RETENTION_DAYS} -print0)
    
    log "INFO" "Cleaned up ${deleted_count} old backup files"
}

# Optimize database tables
optimize_tables() {
    log "INFO" "Starting table optimization for database: ${MYSQL_DATABASE}"
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for optimization"
        return 1
    fi
    
    # Get list of tables that need optimization
    local tables=$(mysql_query "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = '${MYSQL_DATABASE}' 
        AND table_type = 'BASE TABLE'
        AND engine = 'InnoDB'
    ")
    
    if [[ -z "${tables}" ]]; then
        log "WARN" "No tables found for optimization"
        return 0
    fi
    
    local optimized_count=0
    local failed_count=0
    
    while IFS= read -r table; do
        log "DEBUG" "Optimizing table: ${table}"
        
        if mysql_exec "OPTIMIZE TABLE \`${table}\`;" "${MYSQL_DATABASE}"; then
            ((optimized_count++))
        else
            log "WARN" "Failed to optimize table: ${table}"
            ((failed_count++))
        fi
    done <<< "${tables}"
    
    log "INFO" "Table optimization completed. Optimized: ${optimized_count}, Failed: ${failed_count}"
}

# Analyze database tables
analyze_tables() {
    log "INFO" "Starting table analysis for database: ${MYSQL_DATABASE}"
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for analysis"
        return 1
    fi
    
    # Get list of tables
    local tables=$(mysql_query "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = '${MYSQL_DATABASE}' 
        AND table_type = 'BASE TABLE'
    ")
    
    if [[ -z "${tables}" ]]; then
        log "WARN" "No tables found for analysis"
        return 0
    fi
    
    local analyzed_count=0
    
    while IFS= read -r table; do
        log "DEBUG" "Analyzing table: ${table}"
        
        if mysql_exec "ANALYZE TABLE \`${table}\`;" "${MYSQL_DATABASE}"; then
            ((analyzed_count++))
        else
            log "WARN" "Failed to analyze table: ${table}"
        fi
    done <<< "${tables}"
    
    log "INFO" "Table analysis completed. Analyzed: ${analyzed_count} tables"
}

# Cleanup staging data
cleanup_staging_data() {
    log "INFO" "Cleaning up staging data older than ${STAGING_RETENTION_DAYS} days..."
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for staging cleanup"
        return 1
    fi
    
    # Check if staging database exists
    local staging_exists=$(mysql_query "
        SELECT COUNT(*) 
        FROM information_schema.schemata 
        WHERE schema_name = 'staging'
    ")
    
    if [[ "${staging_exists}" != "1" ]]; then
        log "INFO" "Staging database does not exist, skipping cleanup"
        return 0
    fi
    
    # Cleanup ETL staging data
    local deleted_customers=$(mysql_query "
        SELECT COUNT(*) 
        FROM staging.customer_staging 
        WHERE created_at < DATE_SUB(NOW(), INTERVAL ${STAGING_RETENTION_DAYS} DAY)
        AND status IN ('completed', 'failed')
    ")
    
    if [[ "${deleted_customers}" -gt 0 ]]; then
        mysql_exec "
            DELETE FROM staging.customer_staging 
            WHERE created_at < DATE_SUB(NOW(), INTERVAL ${STAGING_RETENTION_DAYS} DAY)
            AND status IN ('completed', 'failed')
        " "staging"
        
        log "INFO" "Deleted ${deleted_customers} old customer staging records"
    fi
    
    # Cleanup ETL batch logs
    local deleted_batches=$(mysql_query "
        SELECT COUNT(*) 
        FROM staging.etl_batch_log 
        WHERE started_at < DATE_SUB(NOW(), INTERVAL ${STAGING_RETENTION_DAYS} DAY)
        AND status IN ('completed', 'failed', 'cancelled')
    ")
    
    if [[ "${deleted_batches}" -gt 0 ]]; then
        mysql_exec "
            DELETE FROM staging.etl_batch_log 
            WHERE started_at < DATE_SUB(NOW(), INTERVAL ${STAGING_RETENTION_DAYS} DAY)
            AND status IN ('completed', 'failed', 'cancelled')
        " "staging"
        
        log "INFO" "Deleted ${deleted_batches} old ETL batch log records"
    fi
}

# Cleanup audit logs
cleanup_audit_logs() {
    log "INFO" "Cleaning up audit logs older than ${LOG_RETENTION_DAYS} days..."
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for audit cleanup"
        return 1
    fi
    
    # Check if audit database exists
    local audit_exists=$(mysql_query "
        SELECT COUNT(*) 
        FROM information_schema.schemata 
        WHERE schema_name = 'audit_db'
    ")
    
    if [[ "${audit_exists}" != "1" ]]; then
        log "INFO" "Audit database does not exist, skipping cleanup"
        return 0
    fi
    
    # Call the audit cleanup procedure if it exists
    local procedure_exists=$(mysql_query "
        SELECT COUNT(*) 
        FROM information_schema.routines 
        WHERE routine_schema = 'audit_db' 
        AND routine_name = 'cleanup_audit_logs'
    ")
    
    if [[ "${procedure_exists}" == "1" ]]; then
        mysql_exec "CALL audit_db.cleanup_audit_logs(${LOG_RETENTION_DAYS});" "audit_db"
        log "INFO" "Audit log cleanup procedure executed"
    else
        # Manual cleanup if procedure doesn't exist
        local deleted_count=$(mysql_query "
            SELECT COUNT(*) 
            FROM audit_db.audit_log 
            WHERE changed_at < DATE_SUB(NOW(), INTERVAL ${LOG_RETENTION_DAYS} DAY)
        ")
        
        if [[ "${deleted_count}" -gt 0 ]]; then
            mysql_exec "
                DELETE FROM audit_db.audit_log 
                WHERE changed_at < DATE_SUB(NOW(), INTERVAL ${LOG_RETENTION_DAYS} DAY)
            " "audit_db"
            
            log "INFO" "Deleted ${deleted_count} old audit log records"
        fi
    fi
}

# Update analytics summaries
update_analytics() {
    log "INFO" "Updating analytics summaries..."
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for analytics update"
        return 1
    fi
    
    # Update customer analytics summary (example - would need actual ETL logic)
    log "DEBUG" "Updating customer analytics summary..."
    mysql_exec "
        INSERT INTO customer_analytics_summary (
            customer_id, username, email, first_name, last_name, full_name,
            registration_date, email_verified, total_orders, total_revenue,
            data_as_of_date
        )
        SELECT 
            u.user_id,
            u.username,
            u.email,
            p.first_name,
            p.last_name,
            CONCAT(COALESCE(p.first_name, ''), ' ', COALESCE(p.last_name, '')) as full_name,
            DATE(u.created_at),
            u.email_verified,
            0 as total_orders,
            0.00 as total_revenue,
            CURDATE()
        FROM users u
        LEFT JOIN user_profiles p ON u.user_id = p.user_id
        WHERE u.is_active = TRUE
        AND u.user_id NOT IN (
            SELECT customer_id FROM customer_analytics_summary 
            WHERE data_as_of_date = CURDATE()
        )
        ON DUPLICATE KEY UPDATE
            data_as_of_date = CURDATE(),
            updated_at = NOW()
    " "${MYSQL_DATABASE}"
    
    log "INFO" "Analytics summaries updated"
}

# Deploy schema changes
deploy_schema() {
    local migration_dir="${PROJECT_ROOT}/scripts/migration"
    
    log "INFO" "Deploying schema changes from: ${migration_dir}"
    
    if [[ ! -d "${migration_dir}" ]]; then
        log "WARN" "Migration directory does not exist: ${migration_dir}"
        return 0
    fi
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for schema deployment"
        return 1
    fi
    
    # Create migration tracking table if it doesn't exist
    mysql_exec "
        CREATE TABLE IF NOT EXISTS schema_migrations (
            migration_id VARCHAR(100) PRIMARY KEY,
            filename VARCHAR(255) NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            checksum VARCHAR(64)
        )
    " "${MYSQL_DATABASE}"
    
    # Find and apply new migrations
    local applied_count=0
    
    for migration_file in "${migration_dir}"/*.sql; do
        if [[ -f "${migration_file}" ]]; then
            local filename=$(basename "${migration_file}")
            local migration_id="${filename%.*}"
            local checksum=$(md5sum "${migration_file}" | cut -d' ' -f1)
            
            # Check if migration was already applied
            local is_applied=$(mysql_query "
                SELECT COUNT(*) 
                FROM schema_migrations 
                WHERE migration_id = '${migration_id}'
            ")
            
            if [[ "${is_applied}" == "0" ]]; then
                log "INFO" "Applying migration: ${filename}"
                
                if mysql_exec "source ${migration_file}" "${MYSQL_DATABASE}"; then
                    # Record successful migration
                    mysql_exec "
                        INSERT INTO schema_migrations (migration_id, filename, checksum)
                        VALUES ('${migration_id}', '${filename}', '${checksum}')
                    " "${MYSQL_DATABASE}"
                    
                    ((applied_count++))
                    log "INFO" "Migration applied successfully: ${filename}"
                else
                    log "ERROR" "Migration failed: ${filename}"
                fi
            else
                log "DEBUG" "Migration already applied: ${filename}"
            fi
        fi
    done
    
    log "INFO" "Schema deployment completed. Applied: ${applied_count} migrations"
}

# Generate database statistics
generate_statistics() {
    local stats_file="${LOGS_DIR}/db_statistics_$(date +%Y%m%d_%H%M%S).txt"
    
    log "INFO" "Generating database statistics..."
    
    if ! test_connection; then
        log "ERROR" "Cannot connect to MySQL server for statistics"
        return 1
    fi
    
    {
        echo "MySQL Database Statistics"
        echo "========================="
        echo "Generated: $(date)"
        echo "Server: ${MYSQL_HOST}:${MYSQL_PORT}"
        echo "Database: ${MYSQL_DATABASE}"
        echo ""
        
        echo "Database Size:"
        echo "-------------"
        mysql_query "
            SELECT 
                table_schema as 'Database',
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
            FROM information_schema.tables 
            WHERE table_schema = '${MYSQL_DATABASE}'
            GROUP BY table_schema
        "
        
        echo ""
        echo "Table Information:"
        echo "-----------------"
        mysql_query "
            SELECT 
                table_name as 'Table',
                table_rows as 'Rows',
                ROUND((data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)',
                engine as 'Engine'
            FROM information_schema.tables 
            WHERE table_schema = '${MYSQL_DATABASE}'
            AND table_type = 'BASE TABLE'
            ORDER BY (data_length + index_length) DESC
        "
        
        echo ""
        echo "Index Usage:"
        echo "-----------"
        mysql_query "
            SELECT 
                table_name as 'Table',
                index_name as 'Index',
                cardinality as 'Cardinality'
            FROM information_schema.statistics 
            WHERE table_schema = '${MYSQL_DATABASE}'
            AND cardinality > 0
            ORDER BY table_name, cardinality DESC
        "
        
    } > "${stats_file}"
    
    log "INFO" "Database statistics saved to: ${stats_file}"
    echo "${stats_file}"
}

# Run daily maintenance tasks
run_daily_maintenance() {
    log "INFO" "Starting daily maintenance tasks..."
    
    # Create daily backup
    create_backup "full"
    
    # Optimize tables if enabled
    if [[ "${AUTO_OPTIMIZE_TABLES}" == "true" ]]; then
        optimize_tables
    fi
    
    # Analyze tables
    analyze_tables
    
    # Cleanup old data if enabled
    if [[ "${AUTO_CLEANUP_LOGS}" == "true" ]]; then
        cleanup_staging_data
        cleanup_audit_logs
    fi
    
    # Update analytics
    update_analytics
    
    # Generate statistics
    generate_statistics
    
    # Cleanup old backups
    cleanup_old_backups
    
    log "INFO" "Daily maintenance tasks completed"
}

# Show help information
show_help() {
    cat << EOF
MySQL Database Automation Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    backup [TYPE]           Create database backup (full, schema, data)
    optimize               Optimize database tables
    analyze                Analyze database tables
    cleanup                Cleanup old data and logs
    deploy                 Deploy schema migrations
    stats                  Generate database statistics
    maintenance            Run daily maintenance tasks
    help                   Show this help message

Options:
    --host HOST            MySQL host (default: ${MYSQL_HOST})
    --port PORT            MySQL port (default: ${MYSQL_PORT})
    --user USER            MySQL user (default: ${MYSQL_USER})
    --database DB          MySQL database (default: ${MYSQL_DATABASE})
    --config FILE          Use custom configuration file

Examples:
    $0 backup full         # Create full database backup
    $0 optimize            # Optimize all tables
    $0 maintenance         # Run daily maintenance
    $0 deploy              # Deploy schema changes
    $0 stats               # Generate statistics report

Configuration:
    Create ${CONFIG_FILE} to override default settings.

Log files are stored in: ${LOGS_DIR}
Backups are stored in: ${BACKUP_DIR}

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    COMMAND="$1"
    SUBCOMMAND="$2"
}

# Main execution
main() {
    case "${COMMAND}" in
        "backup")
            create_backup "${SUBCOMMAND:-full}"
            ;;
        "optimize")
            optimize_tables
            ;;
        "analyze")
            analyze_tables
            ;;
        "cleanup")
            cleanup_staging_data
            cleanup_audit_logs
            cleanup_old_backups
            ;;
        "deploy")
            deploy_schema
            ;;
        "stats")
            generate_statistics
            ;;
        "maintenance")
            run_daily_maintenance
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            log "ERROR" "No command specified"
            show_help
            exit 1
            ;;
        *)
            log "ERROR" "Unknown command: ${COMMAND}"
            show_help
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi