#!/bin/bash
# AU eRequesting Forward Flow Demo
# Demonstrates HTTP API → FHIR Bundle → HTTP response transformation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8080
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== AU eRequesting FHIR HTTP Integration Demo ===${NC}"
echo "This script demonstrates HTTP-to-FHIR-to-HTTP conversion"
echo "Using SMILE FHIR server backend: https://smile.sparked-fhir.com/ereq/fhir/DEFAULT"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl not found. Please install curl.${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found. Please install Python 3.${NC}"
    exit 1
fi

if ! command -v harmony &> /dev/null; then
    echo -e "${RED}Error: harmony not found. Please install Harmony.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"
echo ""

# Setup directories
echo -e "${YELLOW}Setting up test environment...${NC}"
mkdir -p "$TMP_DIR"
echo -e "${GREEN}✓ Test environment ready${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Kill Harmony
    if [ ! -z "$HARMONY_PID" ] && kill -0 $HARMONY_PID 2>/dev/null; then
        echo "  Stopping Harmony (PID: $HARMONY_PID)..."
        kill $HARMONY_PID
        wait $HARMONY_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

echo -e "${YELLOW}Using remote SMILE FHIR server...${NC}"
echo -e "${GREEN}✓ FHIR backend configured: https://smile.sparked-fhir.com/ereq/fhir/DEFAULT${NC}"
echo ""

# Build Harmony (already installed)
echo -e "${YELLOW}Harmony already available${NC}"
echo ""

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony proxy on port $HARMONY_PORT...${NC}"
cd "$SCRIPT_DIR"
harmony --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$HARMONY_PORT/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Harmony is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Harmony did not start in time${NC}"
        echo "Check logs: $TMP_DIR/harmony.log"
        exit 1
    fi
    sleep 1
done

echo ""
echo -e "${BLUE}=== Running Tests ===${NC}"
echo ""

# Test 1: HTTP request through Harmony proxy
echo -e "${YELLOW}Test 1: HTTP request through Harmony to FHIR conversion${NC}"
echo "  Command: curl -s 'http://127.0.0.1:$HARMONY_PORT/service-requests?type=Task&owner=kioma-pathology'"

RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:$HARMONY_PORT/service-requests?type=Task&owner=kioma-pathology")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Request successful (HTTP $HTTP_CODE)${NC}"
    
    # Check if we got JSON response with expected fields
    if echo "$BODY" | grep -q 'tasks'; then
        echo -e "${GREEN}  ✓ Got expected JSON response structure${NC}"
        echo ""
        echo "  Response (formatted):"
        echo "$BODY" | python3 -m json.tool 2>/dev/null | sed 's/^/    /'
    else
        echo -e "${YELLOW}  ⚠ Response body: $BODY${NC}"
    fi
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 2: Verify transformed data contains expected fields
echo -e "${YELLOW}Test 2: Verify key fields in response${NC}"

echo "  Checking for key fields..."
if echo "$BODY" | grep -q 'totalTasks'; then
    echo -e "  ${GREEN}✓ totalTasks${NC}"
else
    echo -e "  ${RED}✗ totalTasks not found${NC}"
fi

if echo "$BODY" | grep -q 'tasks'; then
    echo -e "  ${GREEN}✓ tasks array${NC}"
else
    echo -e "  ${RED}✗ tasks array not found${NC}"
fi

if echo "$BODY" | grep -q 'taskId'; then
    echo -e "  ${GREEN}✓ taskId${NC}"
else
    echo -e "  ${RED}✗ taskId not found${NC}"
fi

if echo "$BODY" | grep -q 'status'; then
    echo -e "  ${GREEN}✓ status${NC}"
else
    echo -e "  ${RED}✗ status not found${NC}"
fi

if echo "$BODY" | grep -q 'patientRef'; then
    echo -e "  ${GREEN}✓ patientRef${NC}"
else
    echo -e "  ${RED}✗ patientRef not found${NC}"
fi

if echo "$BODY" | grep -q 'organizationRef'; then
    echo -e "  ${GREEN}✓ organizationRef${NC}"
else
    echo -e "  ${RED}✗ organizationRef not found${NC}"
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "AU eRequesting FHIR Integration Capabilities:"
echo "  ✅ HTTP API accepts query requests"
echo "  ✅ Transforms query params to FHIR query path"
echo "  ✅ Queries FHIR server"
echo "  ✅ Receives FHIR Bundle response"
echo "  ✅ Extracts task entries into JSON array"
echo ""
echo "Service Architecture:"
echo "  FHIR Server:  https://smile.sparked-fhir.com/ereq/fhir/DEFAULT"
echo "  Harmony Proxy: http://127.0.0.1:$HARMONY_PORT"
echo "  HTTP Endpoint: GET /service-requests?type={resource}&owner={org}"
echo ""
echo "Example Query:"
echo "  curl 'http://127.0.0.1:$HARMONY_PORT/service-requests?type=Task&owner=kioma-pathology'"
echo ""
echo "Response Structure:"
echo "  • totalTasks: count of tasks"
echo "  • tasks[]: array of task summaries"
echo "    - taskId, status, priority, authoredOn"
echo "    - orderId, patientRef, requesterRef, organizationRef"
echo ""
echo "Logs available at:"
echo "  Harmony:     $TMP_DIR/harmony.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
