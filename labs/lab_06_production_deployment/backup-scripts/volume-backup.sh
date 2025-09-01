#!/bin/bash
# Location: labs/lab_06_production_deployment/backup-scripts/volume-backup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/volume-backups}"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.prod.yml"
LOG_FILE="${BACKUP_DIR}/volume-backup.log"

# Volume list
VOLUMES=(
    "nginx-logs"
    "postgres-user-data"
    "postgres-order-data"
    "postgres-grafana-data"
    "mongodb-data"
    "redis-data"
    "kafka-data"
    "prometheus-data"
    "grafana-data"
    "elasticsearch-data"
)

RETENTION_DAYS="${RETENTION_DAYS:-7}"
S3_BUCKET="${S3_BUCKET:-}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

mkdir -p "${BACKUP_DIR}"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

send_notification() {
    local subject="$1"
    local message="$2"
    local level="${3:-INFO}"
    
    if [[ -n "${NOTIFICATION_EMAIL}" ]] && command -v mail >/dev/null 2>&1; then
        echo "${message}" | mail -s "${subject}" "${NOTIFICATION_EMAIL}"
    fi
    
    if [[ -n "${SLACK_WEBHOOK}" ]]; then
        local color="#36a64f"
        [[ "$level" == "ERROR" ]] && color="#ff0000"
        [[ "$level" == "WARN" ]] && color="#ffaa00"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"${color}\",\"title\":\"${subject}\",\"text\":\"${message}\"}]}" \
            "${SLACK_WEBHOOK}" >/dev/null 2>&1 || true
    fi
}

backup_volume() {
    local volume_name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${volume_name}_${timestamp}.tar.gz"
    
    log "Backing up volume: ${volume_name}"
    
    if docker run --rm -v "${PROJECT_DIR}_${volume_name}:/volume" -v "${BACKUP_DIR}:/backup" alpine:latest tar -czf "/backup/$(basename "${backup_file}")" -C /volume .; then
        if [[ -s "${backup_file}" ]]; then
            local size=$(du -h "${backup_file}" | cut -f1)
            log "Volume backup completed: ${backup_file} (${size})"
            
            # Upload to S3 if configured
            if [[ -n "${S3_BUCKET}" ]]; then
                aws s3 cp "${backup_file}" "s3://${S3_BUCKET}/volume-backups/" && \
                log "Uploaded to S3: ${backup_file}" || \
                log "WARNING: Failed to upload ${backup_file} to S3"
            fi
            
            return 0
        else
            log "ERROR: Backup file is empty: ${backup_file}"
            return 1
        fi
    else
        log "ERROR: Failed to backup volume: ${volume_name}"
        return 1
    fi
}

cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days"
    find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
    log "Cleanup completed"
}

main() {
    log "Starting volume backup process"
    local start_time=$(date +%s)
    local success_count=0
    local total_count=${#VOLUMES[@]}
    local failed_volumes=""
    
    for volume in "${VOLUMES[@]}"; do
        if backup_volume "${volume}"; then
            ((success_count++))
        else
            failed_volumes="${failed_volumes}\n- ${volume}"
        fi
    done
    
    cleanup_old_backups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Volume backup completed: ${success_count}/${total_count} successful in ${duration}s"
    
    if [[ ${success_count} -eq ${total_count} ]]; then
        send_notification "Volume Backup Successful" "All ${total_count} volumes backed up successfully in ${duration}s" "SUCCESS"
    else
        send_notification "Volume Backup Completed with Errors" "Backed up ${success_count}/${total_count} volumes in ${duration}s. Failed:${failed_volumes}" "WARN"
    fi
}

case "${1:-}" in
    --volume)
        [[ -z "${2:-}" ]] && { echo "Volume name required"; exit 1; }
        backup_volume "$2"
        ;;
    --cleanup)
        cleanup_old_backups
        ;;
    --list)
        echo "Available volumes:"
        printf '%s\n' "${VOLUMES[@]}"
        ;;
    --help|-h)
        echo "Volume Backup Script"
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --volume NAME   Backup specific volume"
        echo "  --cleanup       Clean old backups"
        echo "  --list          List available volumes"
        echo "  --help          Show help"
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1. Use --help for usage."
        exit 1
        ;;
esac