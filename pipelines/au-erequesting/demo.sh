#!/bin/bash
# AU eRequesting FHIR HTTP Integration Demo
# Demonstrates HTTP-to-FHIR-to-HTTP conversion for service requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8080
FHIR_SERVER_PORT=8888
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== AU eRequesting FHIR HTTP Integration Demo ===${NC}"
echo "This script demonstrates HTTP-to-FHIR-to-HTTP conversion"
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
    
    # Kill FHIR server
    if [ ! -z "$FHIR_SERVER_PID" ] && kill -0 $FHIR_SERVER_PID 2>/dev/null; then
        echo "  Stopping FHIR Server (PID: $FHIR_SERVER_PID)..."
        kill $FHIR_SERVER_PID
        wait $FHIR_SERVER_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start FHIR Server
echo -e "${YELLOW}Starting FHIR Server on port $FHIR_SERVER_PORT...${NC}"
cd "$SCRIPT_DIR"
python3 server.py $FHIR_SERVER_PORT > "$TMP_DIR/fhir_server.log" 2>&1 &
FHIR_SERVER_PID=$!
echo -e "${GREEN}✓ FHIR Server started (PID: $FHIR_SERVER_PID)${NC}"

# Wait for FHIR server to be ready
echo -e "${YELLOW}Waiting for FHIR Server to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$FHIR_SERVER_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ FHIR Server is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: FHIR Server did not start in time${NC}"
        echo "Check logs: $TMP_DIR/fhir_server.log"
        exit 1
    fi
    sleep 1
done
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

# Test 1: FHIR Server health check
echo -e "${YELLOW}Test 1: FHIR Server health check${NC}"
echo "  Command: curl -s http://127.0.0.1:$FHIR_SERVER_PORT/health | jq"
RESPONSE=$(curl -s -w "\n%{http_code}" http://127.0.0.1:$FHIR_SERVER_PORT/health)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ FHIR Server health check passed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
else
    echo -e "${RED}  ✗ Health check failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 2: HTTP request through Harmony proxy
echo -e "${YELLOW}Test 2: HTTP request through Harmony to FHIR conversion${NC}"
echo "  Command: curl -s 'http://127.0.0.1:$HARMONY_PORT/service-requests?providerId=8003621566684455'"

RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:$HARMONY_PORT/service-requests?providerId=8003621566684455")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Request successful (HTTP $HTTP_CODE)${NC}"
    
    # Check if we got JSON response with expected fields
    if echo "$BODY" | grep -q 'orderId'; then
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

# Test 3: Verify transformed data contains expected fields
echo -e "${YELLOW}Test 3: Verify key fields in response${NC}"

echo "  Checking for key fields..."
if echo "$BODY" | grep -q 'patientName'; then
    echo -e "  ${GREEN}✓ patientName${NC}"
else
    echo -e "  ${RED}✗ patientName not found${NC}"
fi

if echo "$BODY" | grep -q 'orderId'; then
    echo -e "  ${GREEN}✓ orderId${NC}"
else
    echo -e "  ${RED}✗ orderId not found${NC}"
fi

if echo "$BODY" | grep -q 'serviceCode'; then
    echo -e "  ${GREEN}✓ serviceCode${NC}"
else
    echo -e "  ${RED}✗ serviceCode not found${NC}"
fi

if echo "$BODY" | grep -q 'serviceDisplay'; then
    echo -e "  ${GREEN}✓ serviceDisplay${NC}"
else
    echo -e "  ${RED}✗ serviceDisplay not found${NC}"
fi

if echo "$BODY" | grep -q 'requesterName'; then
    echo -e "  ${GREEN}✓ requesterName${NC}"
else
    echo -e "  ${RED}✗ requesterName not found${NC}"
fi

if echo "$BODY" | grep -q 'organizationName'; then
    echo -e "  ${GREEN}✓ organizationName${NC}"
else
    echo -e "  ${RED}✗ organizationName not found${NC}"
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "AU eRequesting FHIR Integration Capabilities:"
echo "  ✅ HTTP API accepts requests"
echo "  ✅ Converts to AU eRequesting FHIR bundle"
echo "  ✅ Posts to FHIR server"
echo "  ✅ Receives FHIR response"
echo "  ✅ Extracts key fields back to HTTP JSON"
echo ""
echo "Service Architecture:"
echo "  FHIR Server:  http://127.0.0.1:$FHIR_SERVER_PORT"
echo "  Harmony Proxy: http://127.0.0.1:$HARMONY_PORT"
echo "  HTTP Endpoint: GET /service-requests?providerId={id}"
echo ""
echo "Key Resources Demonstrated:"
echo "  • Task (group coordination)"
echo "  • Task (diagnostic request)"
echo "  • ServiceRequest (CT imaging)"
echo "  • Patient"
echo "  • Practitioner"
echo "  • PractitionerRole"
echo "  • Organization"
echo "  • Encounter"
echo ""
echo "Logs available at:"
echo "  Harmony:     $TMP_DIR/harmony.log"
echo "  FHIR Server: $TMP_DIR/fhir_server.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
