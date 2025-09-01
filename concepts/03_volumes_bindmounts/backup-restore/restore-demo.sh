#!/bin/bash
# File Location: concepts/03_volumes_bindmounts/backup-restore/restore-demo.sh

set -e

show_usage() {
    echo "Usage: $0 <backup_file> <volume_name>"
    echo ""
    echo "Examples:"
    echo "  $0 backup.tar.gz my-restored-volume"
    echo "  $0 /tmp/postgres-data.tar postgres-data"
}

restore_volume() {
    local backup_file="$1"
    local volume_name="$2"
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file '$backup_file' not found"
        exit 1
    fi
    
    # Create volume if it doesn't exist
    if ! docker volume inspect "$volume_name" &>/dev/null; then
        echo "Creating volume: $volume_name"
        docker volume create "$volume_name"
    else
        echo "Warning: Volume '$volume_name' already exists"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo "Restoring from: $backup_file"
    echo "To volume: $volume_name"
    
    # Detect compression
    if [[ "$backup_file" == *.gz ]]; then
        echo "Detected gzipped backup"
        docker run --rm \
            -v "$volume_name":/volume-data \
            -v "$(dirname "$backup_file")":/backup \
            alpine:latest \
            tar xzf "/backup/$(basename "$backup_file")" -C /volume-data
    else
        echo "Detected uncompressed backup"
        docker run --rm \
            -v "$volume_name":/volume-data \
            -v "$(dirname "$backup_file")":/backup \
            alpine:latest \
            tar xf "/backup/$(basename "$backup_file")" -C /volume-data
    fi
    
    echo "Restore completed successfully!"
    
    # Show restored content
    echo "Restored content:"
    docker run --rm -v "$volume_name":/data alpine:latest find /data -type f | head -20
}

if [ $# -ne 2 ]; then
    show_usage
    exit 1
fi

if ! docker info &>/dev/null; then
    echo "Error: Docker is not running"
    exit 1
fi

restore_volume "$1" "$2"