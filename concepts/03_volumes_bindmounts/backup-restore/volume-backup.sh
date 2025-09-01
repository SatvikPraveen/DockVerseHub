#!/bin/bash
# File Location: concepts/03_volumes_bindmounts/backup-restore/volume-backup.sh

set -e

BACKUP_DIR="/tmp/docker-backups"
DATE=$(date +%Y%m%d_%H%M%S)

show_usage() {
    echo "Usage: $0 <volume_name> [backup_name]"
    echo ""
    echo "Examples:"
    echo "  $0 my-data-volume"
    echo "  $0 postgres-data backup-before-upgrade"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help"
    echo "  -d, --dir     Backup directory (default: $BACKUP_DIR)"
    echo "  -c, --compress Use compression (gzip)"
}

backup_volume() {
    local volume_name="$1"
    local backup_name="${2:-${volume_name}_${DATE}}"
    local backup_file="${BACKUP_DIR}/${backup_name}.tar"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Check if volume exists
    if ! docker volume inspect "$volume_name" &>/dev/null; then
        echo "Error: Volume '$volume_name' does not exist"
        exit 1
    fi
    
    echo "Starting backup of volume: $volume_name"
    echo "Backup location: $backup_file"
    
    # Run backup container
    if [ "$USE_COMPRESSION" = true ]; then
        backup_file="${backup_file}.gz"
        docker run --rm \
            -v "$volume_name":/volume-data:ro \
            -v "$BACKUP_DIR":/backup \
            alpine:latest \
            tar czf "/backup/${backup_name}.tar.gz" -C /volume-data .
    else
        docker run --rm \
            -v "$volume_name":/volume-data:ro \
            -v "$BACKUP_DIR":/backup \
            alpine:latest \
            tar cf "/backup/${backup_name}.tar" -C /volume-data .
    fi
    
    echo "Backup completed successfully!"
    echo "File: $backup_file"
    echo "Size: $(ls -lh "$backup_file" | awk '{print $5}')"
}

# Parse arguments
USE_COMPRESSION=false
VOLUME_NAME=""
BACKUP_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--compress)
            USE_COMPRESSION=true
            shift
            ;;
        *)
            if [ -z "$VOLUME_NAME" ]; then
                VOLUME_NAME="$1"
            elif [ -z "$BACKUP_NAME" ]; then
                BACKUP_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$VOLUME_NAME" ]; then
    echo "Error: Volume name is required"
    show_usage
    exit 1
fi

# Check Docker is running
if ! docker info &>/dev/null; then
    echo "Error: Docker is not running"
    exit 1
fi

backup_volume "$VOLUME_NAME" "$BACKUP_NAME"