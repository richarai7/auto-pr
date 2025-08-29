#!/bin/bash

# =============================================================================
# MySQL Database Backup Script
# =============================================================================
# Purpose: Automated MySQL database backup with rotation and monitoring
# Based on: mysql-instructions.md backup guidelines
# Features: Full/incremental backups, compression, encryption, rotation
# =============================================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/backup_config.conf"

# Default configuration (can be overridden by config file)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-backup_user}"
DB_PASSWORD="${DB_PASSWORD:-SecureBackupPassword123!}"
DB_NAME="${DB_NAME:-app_db}"

# Backup settings
BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
COMPRESS_BACKUPS="${COMPRESS_BACKUPS:-true}"
ENCRYPT_BACKUPS="${ENCRYPT_BACKUPS:-false}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-}"

# Monitoring settings
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_ALERTS="${EMAIL_ALERTS:-}"
LOG_FILE="${LOG_FILE:-/var/log/mysql_backup.log}"

# Backup type (full or incremental)
BACKUP_TYPE="${1:-full}"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Load configuration file if it exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "INFO" "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log "WARN" "Configuration file $CONFIG_FILE not found, using defaults"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if mysqldump is available
    if ! command -v mysqldump &> /dev/null; then
        log "ERROR" "mysqldump not found. Please install MySQL client."
        exit 1
    fi
    
    # Check if backup directory exists, create if not
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "INFO" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || {
            log "ERROR" "Failed to create backup directory"
            exit 1
        }
    fi
    
    # Check disk space (require at least 5GB free)
    local available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    local required_space=5242880  # 5GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log "WARN" "Low disk space: ${available_space}KB available, ${required_space}KB recommended"
    fi
    
    # Test database connection
    if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log "ERROR" "Failed to connect to database"
        exit 1
    fi
    
    log "INFO" "Prerequisites check completed successfully"
}

# Create backup filename with timestamp
generate_backup_filename() {
    local backup_type="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename="${DB_NAME}_${backup_type}_${timestamp}.sql"
    
    if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
        filename="${filename}.gz"
    fi
    
    if [[ "$ENCRYPT_BACKUPS" == "true" ]]; then
        filename="${filename}.enc"
    fi
    
    echo "$filename"
}

# Perform full database backup
perform_full_backup() {
    local backup_file="$1"
    local backup_path="${BACKUP_DIR}/${backup_file}"
    
    log "INFO" "Starting full backup to: $backup_path"
    
    # Build mysqldump command
    local dump_cmd="mysqldump"
    dump_cmd+=" --host=$DB_HOST"
    dump_cmd+=" --port=$DB_PORT"
    dump_cmd+=" --user=$DB_USER"
    dump_cmd+=" --password=$DB_PASSWORD"
    dump_cmd+=" --single-transaction"
    dump_cmd+=" --routines"
    dump_cmd+=" --triggers"
    dump_cmd+=" --events"
    dump_cmd+=" --set-gtid-purged=OFF"
    dump_cmd+=" --verbose"
    dump_cmd+=" --lock-tables=false"
    dump_cmd+=" --add-drop-database"
    dump_cmd+=" --complete-insert"
    dump_cmd+=" --hex-blob"
    dump_cmd+=" --databases $DB_NAME"
    
    # Add compression if enabled
    if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
        dump_cmd+=" | gzip"
    fi
    
    # Add encryption if enabled
    if [[ "$ENCRYPT_BACKUPS" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        if [[ "$COMPRESS_BACKUPS" == "true" ]]; then
            dump_cmd+=" | openssl enc -aes-256-cbc -salt -k '$ENCRYPTION_KEY'"
        else
            dump_cmd+=" | openssl enc -aes-256-cbc -salt -k '$ENCRYPTION_KEY'"
        fi
    fi
    
    # Execute backup
    eval "$dump_cmd > '$backup_path'" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        local file_size=$(du -h "$backup_path" | cut -f1)
        log "INFO" "Full backup completed successfully: $backup_file ($file_size)"
        
        # Verify backup integrity
        verify_backup "$backup_path"
        return 0
    else
        log "ERROR" "Full backup failed with exit code: $exit_code"
        return 1
    fi
}

# Perform incremental backup (using binary logs)
perform_incremental_backup() {
    local backup_file="$1"
    local backup_path="${BACKUP_DIR}/${backup_file}"
    
    log "INFO" "Starting incremental backup to: $backup_path"
    
    # Get current binary log position
    local log_info=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SHOW MASTER STATUS;" --batch --skip-column-names)
    local current_log=$(echo "$log_info" | cut -f1)
    local current_pos=$(echo "$log_info" | cut -f2)
    
    if [[ -z "$current_log" ]]; then
        log "ERROR" "Could not determine current binary log position"
        return 1
    fi
    
    log "INFO" "Current binary log: $current_log, position: $current_pos"
    
    # Find last backup's binary log position
    local last_backup_info="${BACKUP_DIR}/last_incremental_position"
    local start_log=""
    local start_pos=""
    
    if [[ -f "$last_backup_info" ]]; then
        source "$last_backup_info"
        start_log="$LAST_BINLOG"
        start_pos="$LAST_POSITION"
    else
        # First incremental backup, start from current position
        start_log="$current_log"
        start_pos="$current_pos"
    fi
    
    # Create incremental backup using mysqlbinlog
    local binlog_cmd="mysqlbinlog"
    binlog_cmd+=" --host=$DB_HOST"
    binlog_cmd+=" --port=$DB_PORT"
    binlog_cmd+=" --user=$DB_USER"
    binlog_cmd+=" --password=$DB_PASSWORD"
    binlog_cmd+=" --start-position=$start_pos"
    binlog_cmd+=" --read-from-remote-server"
    binlog_cmd+=" --raw"
    binlog_cmd+=" --result-file=$backup_path"
    binlog_cmd+=" $start_log"
    
    eval "$binlog_cmd" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        # Update last position file
        echo "LAST_BINLOG=\"$current_log\"" > "$last_backup_info"
        echo "LAST_POSITION=\"$current_pos\"" >> "$last_backup_info"
        
        local file_size=$(du -h "$backup_path" | cut -f1)
        log "INFO" "Incremental backup completed successfully: $backup_file ($file_size)"
        return 0
    else
        log "ERROR" "Incremental backup failed with exit code: $exit_code"
        return 1
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    
    log "INFO" "Verifying backup integrity: $(basename "$backup_path")"
    
    # Basic file existence and size check
    if [[ ! -f "$backup_path" ]]; then
        log "ERROR" "Backup file does not exist: $backup_path"
        return 1
    fi
    
    local file_size=$(stat -c%s "$backup_path")
    if [[ $file_size -eq 0 ]]; then
        log "ERROR" "Backup file is empty: $backup_path"
        return 1
    fi
    
    # Check file format based on extension
    if [[ "$backup_path" == *.gz ]]; then
        if ! gzip -t "$backup_path" 2>/dev/null; then
            log "ERROR" "Backup file is corrupted (gzip test failed): $backup_path"
            return 1
        fi
    fi
    
    # For SQL dumps, check for proper SQL structure
    if [[ "$backup_path" == *.sql* ]] && [[ "$backup_path" != *.enc ]]; then
        local test_cmd="head -n 20"
        
        if [[ "$backup_path" == *.gz ]]; then
            test_cmd="zcat '$backup_path' | head -n 20"
        else
            test_cmd="head -n 20 '$backup_path'"
        fi
        
        if ! eval "$test_cmd" | grep -q "MySQL dump"; then
            log "WARN" "Backup file may not be a valid MySQL dump: $backup_path"
        fi
    fi
    
    log "INFO" "Backup integrity verification completed"
    return 0
}

# Clean up old backups based on retention policy
cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than $BACKUP_RETENTION_DAYS days"
    
    local deleted_count=0
    while IFS= read -r -d '' backup_file; do
        rm "$backup_file"
        ((deleted_count++))
        log "INFO" "Deleted old backup: $(basename "$backup_file")"
    done < <(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql*" -type f -mtime +$BACKUP_RETENTION_DAYS -print0)
    
    log "INFO" "Cleanup completed: $deleted_count old backups deleted"
}

# Send notification about backup status
send_notification() {
    local status="$1"
    local message="$2"
    local backup_file="$3"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    
    # Prepare notification message
    local notification_msg="MySQL Backup $status\n"
    notification_msg+="Host: $hostname\n"
    notification_msg+="Database: $DB_NAME\n"
    notification_msg+="Backup Type: $BACKUP_TYPE\n"
    notification_msg+="Timestamp: $timestamp\n"
    notification_msg+="Message: $message\n"
    
    if [[ -n "$backup_file" ]]; then
        local file_size=$(du -h "${BACKUP_DIR}/${backup_file}" 2>/dev/null | cut -f1 || echo "Unknown")
        notification_msg+="Backup File: $backup_file ($file_size)\n"
    fi
    
    # Send Slack notification if configured
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        if [[ "$status" == "FAILED" ]]; then
            color="danger"
        elif [[ "$status" == "WARNING" ]]; then
            color="warning"
        fi
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$notification_msg\"}]}" \
            "$SLACK_WEBHOOK" &>/dev/null
    fi
    
    # Send email notification if configured
    if [[ -n "$EMAIL_ALERTS" ]]; then
        echo -e "$notification_msg" | mail -s "MySQL Backup $status - $hostname" "$EMAIL_ALERTS" &>/dev/null
    fi
}

# Main backup orchestration function
main_backup() {
    local start_time=$(date '+%s')
    local backup_file=""
    local success=false
    
    log "INFO" "Starting MySQL backup process (type: $BACKUP_TYPE)"
    
    # Generate backup filename
    backup_file=$(generate_backup_filename "$BACKUP_TYPE")
    
    # Perform backup based on type
    case "$BACKUP_TYPE" in
        "full")
            if perform_full_backup "$backup_file"; then
                success=true
            fi
            ;;
        "incremental")
            if perform_incremental_backup "$backup_file"; then
                success=true
            fi
            ;;
        *)
            log "ERROR" "Invalid backup type: $BACKUP_TYPE"
            send_notification "FAILED" "Invalid backup type specified" ""
            exit 1
            ;;
    esac
    
    # Calculate execution time
    local end_time=$(date '+%s')
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    # Send notifications
    if [[ "$success" == true ]]; then
        local message="Backup completed successfully in $duration_formatted"
        log "INFO" "$message"
        send_notification "SUCCESS" "$message" "$backup_file"
        
        # Cleanup old backups on successful backup
        cleanup_old_backups
    else
        local message="Backup failed after $duration_formatted"
        log "ERROR" "$message"
        send_notification "FAILED" "$message" ""
        exit 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Print usage if invalid arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [full|incremental]"
    echo ""
    echo "MySQL Database Backup Script"
    echo ""
    echo "Options:"
    echo "  full         Perform full database backup (default)"
    echo "  incremental  Perform incremental backup using binary logs"
    echo "  --help, -h   Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Edit $CONFIG_FILE or set environment variables"
    echo ""
    exit 0
fi

# Validate backup type
if [[ "$BACKUP_TYPE" != "full" ]] && [[ "$BACKUP_TYPE" != "incremental" ]]; then
    echo "Error: Invalid backup type '$BACKUP_TYPE'. Use 'full' or 'incremental'."
    exit 1
fi

# Main execution
load_config
check_prerequisites
main_backup

log "INFO" "MySQL backup process completed"