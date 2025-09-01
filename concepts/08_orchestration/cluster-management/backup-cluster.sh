#!/bin/bash
# 08_orchestration/cluster-management/backup-cluster.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR=${BACKUP_DIR:-"/opt/docker-swarm-backups"}
RETENTION_DAYS=${RETENTION_DAYS:-7}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="swarm_backup_${TIMESTAMP}"
S3_BUCKET=${S3_BUCKET:-""}
ENCRYPTION_KEY=${ENCRYPTION_KEY:-""}
NOTIFICATION_WEBHOOK=${NOTIFICATION_WEBHOOK:-""}

log() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            2>/dev/null || true
    fi
}

check_swarm_status() {
    log "Checking Docker Swarm status..."
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        return 1
    fi
    
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        error "Node is not part of a swarm cluster"
        return 1
    fi
    
    # Check if current node is manager
    if ! docker info 2>/dev/null | grep -q "Is Manager: true"; then
        error "Backup must be run from a manager node"
        return 1
    fi
    
    success "Swarm status check passed"
}

create_backup_directory() {
    log "Creating backup directory: $BACKUP_DIR/$BACKUP_NAME"
    
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    
    # Create subdirectories
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME/"{cluster,services,networks,volumes,secrets,configs,nodes}
}

backup_cluster_info() {
    log "Backing up cluster information..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/cluster"
    
    # Swarm info
    docker info > "$backup_path/swarm_info.json" 2>/dev/null || true
    
    # Node information
    docker node ls --format json > "$backup_path/nodes.json" 2>/dev/null || true
    
    # Detailed node info
    docker node ls -q | while read -r node_id; do
        docker node inspect "$node_id" > "$backup_path/node_${node_id}.json" 2>/dev/null || true
    done
    
    # Swarm tokens (sensitive - encrypt if possible)
    {
        echo "Manager Token: $(docker swarm join-token manager -q 2>/dev/null)"
        echo "Worker Token: $(docker swarm join-token worker -q 2>/dev/null)"
    } > "$backup_path/join_tokens.txt" 2>/dev/null || true
    
    # Set restricted permissions on sensitive files
    chmod 600 "$backup_path/join_tokens.txt" 2>/dev/null || true
    
    success "Cluster information backup completed"
}

backup_services() {
    log "Backing up services..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/services"
    
    # List all services
    docker service ls --format json > "$backup_path/services_list.json" 2>/dev/null || true
    
    # Backup each service configuration
    docker service ls -q | while read -r service_id; do
        docker service inspect "$service_id" > "$backup_path/service_${service_id}.json" 2>/dev/null || true
        
        # Service logs (last 1000 lines)
        docker service logs --tail 1000 "$service_id" > "$backup_path/service_${service_id}_logs.txt" 2>/dev/null || true
    done
    
    success "Services backup completed"
}

backup_networks() {
    log "Backing up networks..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/networks"
    
    # List all networks
    docker network ls --format json > "$backup_path/networks_list.json" 2>/dev/null || true
    
    # Backup each network configuration
    docker network ls -q | while read -r network_id; do
        docker network inspect "$network_id" > "$backup_path/network_${network_id}.json" 2>/dev/null || true
    done
    
    success "Networks backup completed"
}

backup_volumes() {
    log "Backing up volumes..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/volumes"
    
    # List all volumes
    docker volume ls --format json > "$backup_path/volumes_list.json" 2>/dev/null || true
    
    # Backup volume metadata
    docker volume ls -q | while read -r volume_name; do
        docker volume inspect "$volume_name" > "$backup_path/volume_${volume_name}.json" 2>/dev/null || true
    done
    
    # Backup volume data (if possible)
    log "Creating volume data backups..."
    docker volume ls -q | while read -r volume_name; do
        local volume_path=$(docker volume inspect "$volume_name" --format '{{.Mountpoint}}' 2>/dev/null)
        
        if [ -n "$volume_path" ] && [ -d "$volume_path" ]; then
            log "Backing up volume data: $volume_name"
            
            # Create tarball of volume data
            tar -czf "$backup_path/volume_${volume_name}_data.tar.gz" \
                -C "$(dirname "$volume_path")" \
                "$(basename "$volume_path")" 2>/dev/null || warn "Failed to backup volume data: $volume_name"
        fi
    done
    
    success "Volumes backup completed"
}

backup_secrets() {
    log "Backing up secrets..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/secrets"
    
    # List all secrets (metadata only - secret data cannot be retrieved)
    docker secret ls --format json > "$backup_path/secrets_list.json" 2>/dev/null || true
    
    # Backup secret metadata
    docker secret ls -q | while read -r secret_id; do
        docker secret inspect "$secret_id" > "$backup_path/secret_${secret_id}.json" 2>/dev/null || true
    done
    
    warn "Secret data cannot be backed up - only metadata is saved"
    echo "# Secrets must be recreated manually during restore" > "$backup_path/README.txt"
    
    success "Secrets metadata backup completed"
}

backup_configs() {
    log "Backing up configs..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/configs"
    
    # List all configs
    docker config ls --format json > "$backup_path/configs_list.json" 2>/dev/null || true
    
    # Backup each config
    docker config ls -q | while read -r config_id; do
        docker config inspect "$config_id" > "$backup_path/config_${config_id}.json" 2>/dev/null || true
        
        # Try to get config data (if available)
        local config_name=$(docker config inspect "$config_id" --format '{{.Spec.Name}}' 2>/dev/null)
        docker config inspect "$config_id" --format '{{.Spec.Data}}' | base64 -d > "$backup_path/config_${config_name}_data.txt" 2>/dev/null || true
    done
    
    success "Configs backup completed"
}

backup_stacks() {
    log "Backing up stack information..."
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME/stacks"
    mkdir -p "$backup_path"
    
    # Get stack information from service labels
    docker service ls --format "{{.Name}}" | grep -E '^[^_]+_' | cut -d'_' -f1 | sort -u | while read -r stack_name; do
        if [ -n "$stack_name" ]; then
            echo "Stack: $stack_name" > "$backup_path/stack_${stack_name}.txt"
            docker service ls --filter "label=com.docker.stack.namespace=$stack_name" --format json >> "$backup_path/stack_${stack_name}.txt" 2>/dev/null || true
        fi
    done
    
    success "Stack information backup completed"
}

create_backup_manifest() {
    log "Creating backup manifest..."
    
    local manifest_path="$BACKUP_DIR/$BACKUP_NAME/backup_manifest.json"
    
    cat > "$manifest_path" << EOF
{
    "backup_name": "$BACKUP_NAME",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "docker_version": "$(docker version --format '{{.Server.Version}}' 2>/dev/null)",
    "swarm_id": "$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null)",
    "backup_size": "$(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)",
    "components": [
        "cluster_info",
        "services",
        "networks", 
        "volumes",
        "secrets",
        "configs",
        "stacks"
    ],
    "retention_policy": {
        "retention_days": $RETENTION_DAYS
    },
    "encryption": {
        "enabled": $([ -n "$ENCRYPTION_KEY" ] && echo "true" || echo "false")
    }
}
EOF
    
    success "Backup manifest created"
}

encrypt_backup() {
    if [ -n "$ENCRYPTION_KEY" ]; then
        log "Encrypting backup..."
        
        # Create encrypted archive
        tar -czf - -C "$BACKUP_DIR" "$BACKUP_NAME" | \
        openssl enc -aes-256-cbc -salt -k "$ENCRYPTION_KEY" > "$BACKUP_DIR/${BACKUP_NAME}.tar.gz.enc"
        
        # Remove unencrypted backup
        rm -rf "$BACKUP_DIR/$BACKUP_NAME"
        
        success "Backup encrypted successfully"
    else
        log "Creating compressed archive..."
        
        # Create compressed archive
        tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"
        
        # Remove uncompressed backup
        rm -rf "$BACKUP_DIR/$BACKUP_NAME"
        
        success "Backup compressed successfully"
    fi
}

upload_to_s3() {
    if [ -n "$S3_BUCKET" ]; then
        log "Uploading backup to S3..."
        
        local backup_file
        if [ -n "$ENCRYPTION_KEY" ]; then
            backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz.enc"
        else
            backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        fi
        
        if command -v aws >/dev/null 2>&1; then
            aws s3 cp "$backup_file" "s3://$S3_BUCKET/swarm-backups/" && \
            success "Backup uploaded to S3 successfully" || \
            error "Failed to upload backup to S3"
        else
            warn "AWS CLI not available - skipping S3 upload"
        fi
    fi
}

cleanup_old_backups() {
    log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
    
    # Local cleanup
    find "$BACKUP_DIR" -name "swarm_backup_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # S3 cleanup (if configured)
    if [ -n "$S3_BUCKET" ] && command -v aws >/dev/null 2>&1; then
        local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        aws s3 ls "s3://$S3_BUCKET/swarm-backups/" | \
        awk '$1 < "'$cutoff_date'" {print $4}' | \
        while read -r old_backup; do
            if [ -n "$old_backup" ]; then
                aws s3 rm "s3://$S3_BUCKET/swarm-backups/$old_backup" || true
            fi
        done
    fi
    
    success "Old backups cleaned up"
}

verify_backup() {
    log "Verifying backup integrity..."
    
    local backup_file
    if [ -n "$ENCRYPTION_KEY" ]; then
        backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz.enc"
        
        # Verify encrypted backup
        if openssl enc -d -aes-256-cbc -k "$ENCRYPTION_KEY" -in "$backup_file" | tar -tzf - >/dev/null 2>&1; then
            success "Encrypted backup verification passed"
        else
            error "Encrypted backup verification failed"
            return 1
        fi
    else
        backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        
        # Verify compressed backup
        if tar -tzf "$backup_file" >/dev/null 2>&1; then
            success "Backup verification passed"
        else
            error "Backup verification failed"
            return 1
        fi
    fi
    
    # Check file size
    local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
    if [ "$file_size" -gt 1024 ]; then
        success "Backup file size check passed ($file_size bytes)"
    else
        error "Backup file seems too small ($file_size bytes)"
        return 1
    fi
}

generate_restore_script() {
    log "Generating restore script..."
    
    cat > "$BACKUP_DIR/restore_${BACKUP_NAME}.sh" << 'EOF'
#!/bin/bash
# Auto-generated restore script

set -e

BACKUP_FILE=$1
ENCRYPTION_KEY=${ENCRYPTION_KEY:-""}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file> [encryption_key]"
    exit 1
fi

if [ -n "$2" ]; then
    ENCRYPTION_KEY=$2
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Extracting backup..."

if [[ "$BACKUP_FILE" == *.enc ]]; then
    if [ -z "$ENCRYPTION_KEY" ]; then
        echo "Encryption key required for encrypted backup"
        exit 1
    fi
    openssl enc -d -aes-256-cbc -k "$ENCRYPTION_KEY" -in "$BACKUP_FILE" | tar -xzf - -C "$TEMP_DIR"
else
    tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
fi

BACKUP_NAME=$(ls "$TEMP_DIR" | head -1)
RESTORE_PATH="$TEMP_DIR/$BACKUP_NAME"

echo "Backup extracted to: $RESTORE_PATH"
echo ""
echo "WARNING: This script will help restore configurations but requires manual steps"
echo "Please review the backup contents and restore manually:"
echo ""
echo "1. Cluster info: $RESTORE_PATH/cluster/"
echo "2. Services: $RESTORE_PATH/services/"
echo "3. Networks: $RESTORE_PATH/networks/"
echo "4. Volumes: $RESTORE_PATH/volumes/"
echo "5. Secrets: $RESTORE_PATH/secrets/ (metadata only)"
echo "6. Configs: $RESTORE_PATH/configs/"
echo ""
echo "To view the backup manifest:"
echo "cat $RESTORE_PATH/backup_manifest.json"
echo ""
echo "Restore process must be done manually by recreating:"
echo "- Docker secrets (using backup metadata)"
echo "- Docker configs (using backup data)"
echo "- Docker networks (using backup configurations)"
echo "- Docker services (using backup configurations)"
echo "- Volume data (using backup tarballs)"
EOF
    
    chmod +x "$BACKUP_DIR/restore_${BACKUP_NAME}.sh"
    
    success "Restore script generated: $BACKUP_DIR/restore_${BACKUP_NAME}.sh"
}

show_backup_summary() {
    echo ""
    echo "=== Backup Summary ==="
    echo "Backup Name: $BACKUP_NAME"
    echo "Backup Time: $(date)"
    echo "Backup Location: $BACKUP_DIR"
    
    if [ -n "$ENCRYPTION_KEY" ]; then
        echo "Backup File: ${BACKUP_NAME}.tar.gz.enc (encrypted)"
    else
        echo "Backup File: ${BACKUP_NAME}.tar.gz"
    fi
    
    local backup_file
    if [ -n "$ENCRYPTION_KEY" ]; then
        backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz.enc"
    else
        backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    fi
    
    if [ -f "$backup_file" ]; then
        echo "Backup Size: $(du -sh "$backup_file" | cut -f1)"
    fi
    
    echo "Retention Policy: $RETENTION_DAYS days"
    [ -n "$S3_BUCKET" ] && echo "S3 Bucket: $S3_BUCKET"
    echo "Restore Script: $BACKUP_DIR/restore_${BACKUP_NAME}.sh"
    echo "======================="
}

main() {
    echo "Docker Swarm Cluster Backup"
    echo "==========================="
    
    # Pre-flight checks
    check_swarm_status || exit 1
    
    # Create backup directory
    create_backup_directory
    
    # Start backup process
    send_notification "started" "Docker Swarm backup started: $BACKUP_NAME"
    
    # Perform backups
    backup_cluster_info
    backup_services
    backup_networks
    backup_volumes
    backup_secrets
    backup_configs
    backup_stacks
    
    # Create manifest
    create_backup_manifest
    
    # Encrypt/compress backup
    encrypt_backup
    
    # Verify backup
    if ! verify_backup; then
        send_notification "failed" "Backup verification failed: $BACKUP_NAME"
        exit 1
    fi
    
    # Upload to S3 if configured
    upload_to_s3
    
    # Generate restore script
    generate_restore_script
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Show summary
    show_backup_summary
    
    send_notification "completed" "Docker Swarm backup completed successfully: $BACKUP_NAME"
    success "Backup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "verify")
        if [ -z "$2" ]; then
            echo "Usage: $0 verify <backup_file>"
            exit 1
        fi
        verify_backup "$2"
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "help"|"-h"|"--help")
        echo "Docker Swarm Backup Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (none)    - Perform full backup"
        echo "  verify    - Verify backup integrity"
        echo "  cleanup   - Clean up old backups"
        echo "  help      - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  BACKUP_DIR           - Backup directory (default: /opt/docker-swarm-backups)"
        echo "  RETENTION_DAYS       - Backup retention in days (default: 7)"
        echo "  S3_BUCKET           - S3 bucket for remote backup"
        echo "  ENCRYPTION_KEY      - Encryption key for backup"
        echo "  NOTIFICATION_WEBHOOK - Webhook for backup notifications"
        echo ""
        ;;
    *)
        main
        ;;
esac