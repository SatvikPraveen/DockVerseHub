#!/bin/bash
# Location: utilities/scripts/stop_all.sh
# Stop all running Docker containers

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Stopping all labs...${NC}"

cd "$(dirname "$0")/../.."

for lab_dir in labs/lab_*; do
    if [ -d "$lab_dir" ] && [ -f "$lab_dir/docker-compose.yml" ]; then
        lab_name=$(basename "$lab_dir")
        echo -e "${YELLOW}Stopping $lab_name...${NC}"
        (cd "$lab_dir" && docker-compose down) || echo -e "${RED}Failed to stop $lab_name${NC}"
    fi
done

echo -e "${GREEN}✓ All labs stopped${NC}"
