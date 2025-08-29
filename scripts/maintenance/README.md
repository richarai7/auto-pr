# Database Maintenance Scripts

This directory contains essential database maintenance scripts for keeping your MySQL enterprise environment healthy and optimized.

## Available Scripts

### 1. Table Optimization Script
**Purpose**: Optimize database tables to improve query performance and reclaim unused space.

**Usage**:
```bash
# Basic optimization for all tables
./optimize_tables.sh

# Optimize specific database
./optimize_tables.sh --database myapp

# Dry run to see what would be optimized
./optimize_tables.sh --dry-run
```

### 2. Index Analysis Script
**Purpose**: Analyze index usage and identify unused or redundant indexes.

**Usage**:
```bash
# Analyze all databases
./analyze_indexes.sh

# Generate index usage report
./analyze_indexes.sh --report

# Show unused indexes
./analyze_indexes.sh --unused
```

### 3. Log Rotation Script
**Purpose**: Rotate and compress old MySQL log files to manage disk space.

**Usage**:
```bash
# Rotate all log files
./rotate_logs.sh

# Rotate with custom retention (days)
./rotate_logs.sh --retention 30
```

### 4. Statistics Update Script
**Purpose**: Update table statistics to help the query optimizer make better decisions.

**Usage**:
```bash
# Update statistics for all tables
./update_statistics.sh

# Update for specific database
./update_statistics.sh --database myapp
```

## Scheduling Maintenance

### Recommended Schedule

Add these entries to your crontab for automated maintenance:

```bash
# Edit crontab
crontab -e

# Add these lines:

# Daily backup at 2 AM
0 2 * * * /path/to/mysql-project/automation/mysql_automation.sh backup full

# Weekly table optimization on Sundays at 3 AM
0 3 * * 0 /path/to/mysql-project/scripts/maintenance/optimize_tables.sh

# Daily statistics update at 1 AM
0 1 * * * /path/to/mysql-project/scripts/maintenance/update_statistics.sh

# Weekly log rotation on Saturdays at 11 PM
0 23 * * 6 /path/to/mysql-project/scripts/maintenance/rotate_logs.sh

# Monthly index analysis on the 1st at 4 AM
0 4 1 * * /path/to/mysql-project/scripts/maintenance/analyze_indexes.sh --report
```

### Alternative: Using systemd timers

Create systemd timer files for more sophisticated scheduling:

```bash
# Create timer for daily backup
sudo systemctl edit --force --full mysql-backup.timer

# Create service for backup
sudo systemctl edit --force --full mysql-backup.service
```

## Monitoring Maintenance

### Log Files

All maintenance scripts log their activities to:
- `/path/to/mysql-project/logs/maintenance/`
- Individual script logs: `script_name_YYYYMMDD.log`
- Summary logs: `maintenance_summary.log`

### Health Checks

Run regular health checks to ensure maintenance is working:

```bash
# Check backup status
./automation/mysql_automation.sh backup --verify

# Check database health
./monitoring/mysql_monitor.sh --check

# Generate maintenance report
./scripts/maintenance/generate_report.sh
```

## Best Practices

### 1. Backup Before Maintenance
Always ensure recent backups exist before running maintenance operations:

```bash
# Create backup before maintenance
./automation/mysql_automation.sh backup full

# Run maintenance
./scripts/maintenance/optimize_tables.sh

# Verify database health
./monitoring/mysql_monitor.sh --check
```

### 2. Monitor Performance Impact
Run maintenance during low-traffic periods and monitor:
- Query response times
- CPU and I/O usage
- Active connections
- Lock wait times

### 3. Test in Non-Production First
Always test maintenance scripts in development/staging environments:

```bash
# Test with dry-run options
./scripts/maintenance/optimize_tables.sh --dry-run

# Test on staging database
./scripts/maintenance/optimize_tables.sh --database staging_myapp
```

### 4. Gradual Rollout
For large databases, process tables gradually:

```bash
# Optimize one table at a time
./optimize_tables.sh --table users
./optimize_tables.sh --table orders

# Use rate limiting for large operations
./optimize_tables.sh --rate-limit 5
```

## Troubleshooting

### Common Issues

1. **Long-running operations**
   - Monitor progress with `SHOW PROCESSLIST`
   - Consider breaking large operations into smaller chunks
   - Ensure adequate disk space for temporary files

2. **Lock contention**
   - Run maintenance during low-traffic periods
   - Use online operations when possible (MySQL 5.6+)
   - Monitor lock wait statistics

3. **Disk space issues**
   - Ensure 2x table size free space for OPTIMIZE operations
   - Use `ANALYZE TABLE` instead of `OPTIMIZE TABLE` if space is limited
   - Clean up old backup files and logs

### Recovery Procedures

If maintenance operations fail:

1. **Check error logs**:
   ```bash
   tail -f /var/log/mysql/error.log
   ```

2. **Verify table integrity**:
   ```sql
   CHECK TABLE table_name;
   REPAIR TABLE table_name;
   ```

3. **Restore from backup if needed**:
   ```bash
   ./automation/mysql_automation.sh restore latest
   ```

## Custom Maintenance Scripts

### Creating Custom Scripts

Follow this template for new maintenance scripts:

```bash
#!/bin/bash
# Custom maintenance script template

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/../logs/maintenance/custom_$(date +%Y%m%d).log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "${LOG_FILE}"
}

# Main function
main() {
    log "INFO" "Starting custom maintenance task"
    
    # Your maintenance logic here
    
    log "INFO" "Custom maintenance task completed"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Integration with Existing Scripts

New scripts should integrate with the existing automation framework:

```bash
# Add to main automation script
./automation/mysql_automation.sh custom-task

# Add monitoring for new tasks
./monitoring/mysql_monitor.sh --custom-check
```

## Performance Considerations

### Resource Usage

Monitor resource usage during maintenance:

```bash
# CPU usage
top -p $(pgrep mysqld)

# I/O statistics
iostat -x 1

# Memory usage
free -h

# Database metrics
./monitoring/mysql_monitor.sh --stats
```

### Optimization Tips

1. **Batch operations** for better efficiency
2. **Use appropriate MySQL versions** with online DDL support
3. **Schedule during maintenance windows**
4. **Monitor replication lag** on slave servers
5. **Use compression** for backup operations

This maintenance framework ensures your MySQL enterprise environment remains healthy, performant, and reliable.