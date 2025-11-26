#!/bin/bash
# Cleanup script - Remove observability stack

set -e

echo "🧹 Cleaning up observability stack..."

# Stop containers
echo "⏹️  Stopping containers..."
docker-compose down

# Clean volumes (optional)
read -p "Remove volumes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing volumes..."
    docker-compose down -v
fi

echo "✅ Cleanup complete"
