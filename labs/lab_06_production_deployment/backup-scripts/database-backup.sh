#!/bin/bash
# Location: labs/lab_06_production_deployment/backup-scripts/database-backup.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/backups}"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.prod.yml"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Database configuration
POSTGRES_USER_DB="userdb"
POSTGRES_ORDER_DB="orderdb"
POSTGRES_GRAFANA_DB="grafanadb"
MONGODB_DB="notifydb"

# Backup retention (days)
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# S3 Configuration (optional)
S3_BUCKET="${S3_BUCKET:-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

# Notification configuration
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/postgres"
mkdir -p "${BACKUP_DIR}/mongodb"

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    send_notification "Database Backup Failed" "Database backup failed: $1" "ERROR"
    exit 1
}

# Send notification
send_notification() {
    local subject="$1"
    local message="$2"
    local level="${3:-INFO}"
    
    # Email notification
    if [[ -n "${NOTIFICATION_EMAIL}" ]] && command -v mail >/dev/null 2>&1; then
        echo "${message}" | mail -s "${subject}" "${NOTIFICATION_EMAIL}"
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK}" ]]; then
        local color="#36a64f"
        case $level in
            ERROR) color="#ff0000" ;;
            WARN) color="#ffaa00" ;;
        esac
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"${color}\",\"title\":\"${subject}\",\"text\":\"${message}\"}]}" \
            "${SLACK_WEBHOOK}" >/dev/null 2>&1 || true
    fi
}

# Backup PostgreSQL databases
backup_postgres() {
    local db_name="$1"
    local container_name="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/postgres/${db_name}_${timestamp}.sql.gz"
    
    log "Starting PostgreSQL backup for ${db_name}"
    
    if docker-compose -f "${COMPOSE_FILE}" exec -T "${container_name}" pg_dump -U "${db_name}_user" "${db_name}" | gzip > "${backup_file}"; then
        log "PostgreSQL backup completed: ${backup_file}"
        
        # Verify backup
        if [[ -s "${backup_file}" ]]; then
            local size=$(du -h "${backup_file}" | cut -f1)
            log "Backup file size: ${size}"
            return 0
        else
            error_exit "Backup file is empty: ${backup_file}"
        fi
    else
        error_exit "Failed to create PostgreSQL backup for ${db_name}"
    fi
}

# Backup MongoDB database
backup_mongodb() {
    local db_name="$1"
    local container_name="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${BACKUP_DIR}/mongodb/${db_name}_${timestamp}"
    
    log "Starting MongoDB backup for ${db_name}"
    
    # Create backup directory
    mkdir -p "${backup_dir}"
    
    if docker-compose -f "${COMPOSE_FILE}" exec -T "${container_name}" mongodump --db "${db_name}" --out /tmp/backup; then
        # Copy backup from container
        docker cp "$(docker-compose -f "${COMPOSE_FILE}" ps -q "${container_name}"):/tmp/backup/${db_name}" "${backup_dir}/"
        
        # Compress backup
        tar -czf "${backup_dir}.tar.gz" -C "$(dirname "${backup_dir}")" "$(basename "${backup_dir}")"
        rm -rf "${backup_dir}"
        
        log "MongoDB backup completed: ${backup_dir}.tar.gz"
        
        # Verify backup
        if [[ -s "${backup_dir}.tar.gz" ]]; then
            local size=$(du -h "${backup_dir}.tar.gz" | cut -f1)
            log "Backup file size: ${size}"
            return 0
        else
            error_exit "Backup file is empty: ${backup_dir}.tar.gz"
        fi
    else
        error_exit "Failed to create MongoDB backup for ${db_name}"
    fi
}

# Upload to S3
upload_to_s3() {
    local file_path="$1"
    local s3_path="database-backups/$(basename "${file_path}")"
    
    if [[ -n "${S3_BUCKET}" ]] && [[ -n "${AWS_ACCESS_KEY_ID}" ]]; then
        log "Uploading ${file_path} to S3..."
        
        if aws s3 cp "${file_path}" "s3://${S3_BUCKET}/${s3_path}"; then
            log "Successfully uploaded to S3: s3://${S3_BUCKET}/${s3_path}"
        else
            log "WARNING: Failed to upload to S3"
        fi
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days"
    
    find "${BACKUP_DIR}" -type f -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
    find "${BACKUP_DIR}" -type f -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
    
    log "Cleanup completed"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    local db_type="$2"
    
    case $db_type in
        postgres)
            if gzip -t "${backup_file}"; then
                log "PostgreSQL backup integrity verified: ${backup_file}"
                return 0
            else
                log "WARNING: PostgreSQL backup integrity check failed: ${backup_file}"
                return 1
            fi
            ;;
        mongodb)
            if tar -tzf "${backup_file}" >/dev/null 2>&1; then
                log "MongoDB backup integrity verified: ${backup_file}"
                return 0
            else
                log "WARNING: MongoDB backup integrity check failed: ${backup_file}"
                return 1
            fi
            ;;
    esac
}

# Main backup process
main() {
    log "Starting database backup process"
    
    local start_time=$(date +%s)
    local backup_summary=""
    local failed_backups=""
    
    # Check if Docker Compose services are running
    if ! docker-compose -f "${COMPOSE_FILE}" ps | grep -q "Up"; then
        error_exit "Docker Compose services are not running"
    fi
    
    # Backup PostgreSQL databases
    for db_info in "userdb:postgres-user" "orderdb:postgres-order" "grafanadb:postgres-grafana"; do
        db_name=$(echo $db_info | cut -d: -f1)
        container_name=$(echo $db_info | cut -d: -f2)
        
        if backup_postgres "${db_name}" "${container_name}"; then
            backup_file=$(find "${BACKUP_DIR}/postgres" -name "${db_name}_*.sql.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
            
            if verify_backup "${backup_file}" "postgres"; then
                upload_to_s3 "${backup_file}"
                backup_summary="${backup_summary}\n✓ ${db_name}: $(basename "${backup_file}")"
            else
                failed_backups="${failed_backups}\n✗ ${db_name}: Verification failed"
            fi
        else
            failed_backups="${failed_backups}\n✗ ${db_name}: Backup failed"
        fi
    done
    
    # Backup MongoDB database
    if backup_mongodb "${MONGODB_DB}" "mongodb"; then
        backup_file=$(find "${BACKUP_DIR}/mongodb" -name "${MONGODB_DB}_*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
        
        if verify_backup "${backup_file}" "mongodb"; then
            upload_to_s3 "${backup_file}"
            backup_summary="${backup_summary}\n✓ ${MONGODB_DB}: $(basename "${backup_file}")"
        else
            failed_backups="${failed_backups}\n✗ ${MONGODB_DB}: Verification failed"
        fi
    else
        failed_backups="${failed_backups}\n✗ ${MONGODB_DB}: Backup failed"
    fi
    
    # Clean old backups
    cleanup_old_backups
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Database backup process completed in ${duration} seconds"
    
    # Send summary notification
    local message="Database backup completed in ${duration} seconds"
    if [[ -n "${backup_summary}" ]]; then
        message="${message}\n\nSuccessful backups:${backup_summary}"
    fi
    if [[ -n "${failed_backups}" ]]; then
        message="${message}\n\nFailed backups:${failed_backups}"
        send_notification "Database Backup Completed with Warnings" "${message}" "WARN"
    else
        send_notification "Database Backup Completed Successfully" "${message}" "SUCCESS"
    fi
    
    log "Backup summary sent"
}

# Handle command line arguments
case "${1:-}" in
    --postgres-only)
        log "Backing up PostgreSQL databases only"
        for db_info in "userdb:postgres-user" "orderdb:postgres-order" "grafanadb:postgres-grafana"; do
            db_name=$(echo $db_info | cut -d: -f1)
            container_name=$(echo $db_info | cut -d: -f2)
            backup_postgres "${db_name}" "${container_name}"
        done
        ;;
    --mongodb-only)
        log "Backing up MongoDB database only"
        backup_mongodb "${MONGODB_DB}" "mongodb"
        ;;
    --verify)
        log "Verifying existing backups"
        find "${BACKUP_DIR}" -name "*.sql.gz" -exec bash -c 'verify_backup "$0" "postgres"' {} \;
        find "${BACKUP_DIR}" -name "*.tar.gz" -exec bash -c 'verify_backup "$0" "mongodb"' {} \;
        ;;
    --cleanup)
        cleanup_old_backups
        ;;
    --help|-h)
        echo "Database Backup Script"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --postgres-only   Backup PostgreSQL databases only"
        echo "  --mongodb-only    Backup MongoDB database only"
        echo "  --verify         Verify existing backup files"
        echo "  --cleanup        Clean up old backup files"
        echo "  --help           Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  BACKUP_DIR           Backup directory (default: ./backups)"
        echo "  RETENTION_DAYS       Backup retention in days (default: 30)"
        echo "  S3_BUCKET           S3 bucket for remote backups"
        echo "  AWS_ACCESS_KEY_ID   AWS access key"
        echo "  AWS_SECRET_ACCESS_KEY AWS secret key"
        echo "  NOTIFICATION_EMAIL   Email for backup notifications"
        echo "  SLACK_WEBHOOK       Slack webhook for notifications"
        ;;
    "")
        main
        ;;
    *)
        error_exit "Unknown option: $1. Use --help for usage information"
        ;;
esac