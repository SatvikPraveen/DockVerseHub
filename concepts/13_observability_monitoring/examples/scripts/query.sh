#!/bin/bash
# Query script - Common Prometheus queries

BASE_URL="${1:-http://localhost:9090}"

echo "🔍 Prometheus Query Examples"
echo "============================"
echo ""

echo "1️⃣  Request Rate (requests/sec)"
curl -s "$BASE_URL/api/query?query=rate(app_requests_total\[5m\])" | jq '.data.result[] | {metric: .metric, value: .value[1]}'

echo ""
echo "2️⃣  Error Rate"
curl -s "$BASE_URL/api/query?query=rate(app_errors_total\[5m\])" | jq '.data.result[] | {metric: .metric, value: .value[1]}'

echo ""
echo "3️⃣  P95 Latency"
curl -s "$BASE_URL/api/query?query=histogram_quantile(0.95,rate(app_request_duration_ms_bucket\[5m\]))" | jq '.data.result[] | {metric: .metric, value: .value[1]}'

echo ""
echo "4️⃣  Active Requests"
curl -s "$BASE_URL/api/query?query=app_active_requests" | jq '.data.result[] | {metric: .metric, value: .value[1]}'

echo ""
echo "5️⃣  Memory Usage"
curl -s "$BASE_URL/api/query?query=process_resident_memory_bytes" | jq '.data.result[] | {metric: .metric, bytes: .value[1]}'
