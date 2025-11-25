#!/bin/bash
# Location: utilities/scripts/start_compose.sh
# Start all labs with docker-compose

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting all labs...${NC}"

cd "$(dirname "$0")/../.."

for lab_dir in labs/lab_*; do
    if [ -d "$lab_dir" ] && [ -f "$lab_dir/docker-compose.yml" ]; then
        lab_name=$(basename "$lab_dir")
        echo -e "${YELLOW}Starting $lab_name...${NC}"
        (cd "$lab_dir" && docker-compose up -d) || echo -e "${RED}Failed to start $lab_name${NC}"
    fi
done

echo -e "${GREEN}✓ All labs started${NC}"
