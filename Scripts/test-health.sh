#!/bin/bash
# Health Check Testing Script for Pipster Identity Server

set -e

echo "🏥 Pipster Identity Server - Health Check Tests"
echo "================================================"
echo ""

# Configuration
BASE_URL="http://localhost:5000"
CONTAINER_NAME="pipster-identity"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local name=$2
    
    echo -n "Testing ${name}... "
    
    response=$(curl -s -w "\n%{http_code}" "${BASE_URL}${endpoint}")
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ PASSED${NC} (HTTP ${http_code})"
        if [ -n "$body" ] && [ "$body" != "Healthy" ]; then
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
        fi
        return 0
    else
        echo -e "${RED}✗ FAILED${NC} (HTTP ${http_code})"
        echo "$body"
        return 1
    fi
    
    echo ""
}

# Check if containers are running
echo "📦 Checking Docker containers..."
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${GREEN}✓${NC} Container is running"
else
    echo -e "${RED}✗${NC} Container is not running"
    echo "Run: docker-compose up -d"
    exit 1
fi

echo ""

# Wait for application to be ready
echo "⏳ Waiting for application to start (30s grace period)..."
sleep 5

echo ""

# Test endpoints
echo "🧪 Testing Health Endpoints"
echo "----------------------------"
test_endpoint "/health" "Full Health Check"
echo ""

test_endpoint "/health/ready" "Readiness Probe"
echo ""

test_endpoint "/health/live" "Liveness Probe"
echo ""

# Check container health status
echo "🐳 Docker Container Health Status"
echo "----------------------------------"
health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no healthcheck")

if [ "$health_status" = "healthy" ]; then
    echo -e "${GREEN}✓${NC} Container health: ${health_status}"
elif [ "$health_status" = "no healthcheck" ]; then
    echo -e "${YELLOW}⚠${NC} No healthcheck configured"
else
    echo -e "${RED}✗${NC} Container health: ${health_status}"
fi

echo ""

# Show recent health check logs
echo "📋 Recent Health Check Logs (Docker)"
echo "------------------------------------"
docker inspect "$CONTAINER_NAME" | jq '.[0].State.Health.Log[-3:]' 2>/dev/null || echo "No health logs available"

echo ""
echo "✅ Health check tests completed!"
echo ""
echo "💡 Tip: Watch health checks in real-time:"
echo "   docker logs -f $CONTAINER_NAME | grep -i health"