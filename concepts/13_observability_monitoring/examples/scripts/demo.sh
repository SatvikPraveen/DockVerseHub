#!/bin/bash
# Demo script - Generate load and errors for testing observability stack

set -e

BASE_URL="${1:-http://localhost:5000}"
DURATION="${2:-60}"  # seconds

echo "🚀 Starting observability demo"
echo "Target: $BASE_URL"
echo "Duration: ${DURATION}s"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

start_time=$(date +%s)
end_time=$((start_time + DURATION))

request_count=0
error_count=0
success_count=0

while [ $(date +%s) -lt $end_time ]; do
  # Random endpoint selection
  endpoint=$((RANDOM % 5))
  
  case $endpoint in
    0)
      echo -ne "${GREEN}→${NC} GET /api/data ... "
      if curl -s "$BASE_URL/api/data" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗${NC}"
        ((error_count++))
      fi
      ;;
    1)
      echo -ne "${YELLOW}→${NC} GET /api/slow ... "
      if curl -s "$BASE_URL/api/slow" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗${NC}"
        ((error_count++))
      fi
      ;;
    2)
      echo -ne "${RED}→${NC} GET /api/error ... "
      if curl -s "$BASE_URL/api/error" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗${NC}"
      fi
      ((error_count++))
      ;;
    3)
      echo -ne "${GREEN}→${NC} POST /api/compute ... "
      if curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"value\": $RANDOM}" "$BASE_URL/api/compute" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗${NC}"
        ((error_count++))
      fi
      ;;
    *)
      echo -ne "${GREEN}→${NC} GET / ... "
      if curl -s "$BASE_URL/" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((success_count++))
      else
        echo -e "${RED}✗${NC}"
        ((error_count++))
      fi
      ;;
  esac
  
  ((request_count++))
  
  # Random delay
  sleep $((RANDOM % 2 + 1))
done

echo ""
echo "📊 Demo Summary"
echo "================"
echo "Total Requests: $request_count"
echo -e "Success: ${GREEN}$success_count${NC}"
echo -e "Errors: ${RED}$error_count${NC}"
echo "Error Rate: $(echo "scale=2; $error_count * 100 / $request_count" | bc)%"
echo ""
echo "📈 View observability data:"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana: http://localhost:3000"
echo "   - Jaeger: http://localhost:16686"
