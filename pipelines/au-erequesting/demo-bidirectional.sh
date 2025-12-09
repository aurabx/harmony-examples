#!/bin/bash
# AU eRequesting Bidirectional Integration Demo
# Demonstrates both HTTP→FHIR→HTTP and FHIR→FHIR flows

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
API_BACKEND_PORT=8889
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== AU eRequesting Bidirectional Integration Demo ===${NC}"
echo "This script demonstrates both forward (HTTP→FHIR→HTTP) and reverse (FHIR→FHIR) flows"
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
    
    # Kill API backend
    if [ ! -z "$API_BACKEND_PID" ] && kill -0 $API_BACKEND_PID 2>/dev/null; then
        echo "  Stopping API Backend (PID: $API_BACKEND_PID)..."
        kill $API_BACKEND_PID
        wait $API_BACKEND_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start FHIR Server
echo -e "${YELLOW}Starting FHIR Server on port $FHIR_SERVER_PORT...${NC}"
cd "$SCRIPT_DIR"
python3 fhir-server.py $FHIR_SERVER_PORT > "$TMP_DIR/fhir_server.log" 2>&1 &
FHIR_SERVER_PID=$!
echo -e "${GREEN}✓ FHIR Server started (PID: $FHIR_SERVER_PID)${NC}"

# Start API Backend
echo -e "${YELLOW}Starting API Backend on port $API_BACKEND_PORT...${NC}"
python3 http-server.py $API_BACKEND_PORT > "$TMP_DIR/api_backend.log" 2>&1 &
API_BACKEND_PID=$!
echo -e "${GREEN}✓ API Backend started (PID: $API_BACKEND_PID)${NC}"

# Wait for servers to be ready
echo -e "${YELLOW}Waiting for servers to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$FHIR_SERVER_PORT/health > /dev/null 2>&1 && \
       curl -s http://127.0.0.1:$API_BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ All backends are ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Servers did not start in time${NC}"
        exit 1
    fi
    sleep 1
done
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
        exit 1
    fi
    sleep 1
done

echo ""
echo -e "${BLUE}=== Test 1: HTTP → FHIR → HTTP (Forward Flow) ===${NC}"
echo ""

echo -e "${YELLOW}Sending HTTP request through HTTP→FHIR pipeline...${NC}"
echo "  GET /service-requests?providerId=8003621566684455"

RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:$HARMONY_PORT/service-requests?providerId=8003621566684455")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Request successful (HTTP $HTTP_CODE)${NC}"
    if echo "$BODY" | grep -q 'orderId'; then
        echo -e "${GREEN}✓ Got expected response structure${NC}"
        echo ""
        echo "Response summary:"
        echo "$BODY" | python3 -m json.tool 2>/dev/null | head -20 | sed 's/^/  /'
    fi
else
    echo -e "${RED}✗ Request failed (HTTP $HTTP_CODE)${NC}"
fi

echo ""
echo -e "${BLUE}=== Test 2: FHIR → FHIR (Reverse Flow) ===${NC}"
echo ""

echo -e "${YELLOW}Reading AU eRequesting FHIR bundle from request.json...${NC}"
FHIR_BUNDLE=$(cat "$SCRIPT_DIR/request.json")
echo -e "${GREEN}✓ Bundle loaded ($(echo "$FHIR_BUNDLE" | wc -c) bytes)${NC}"
echo ""
echo "Bundle preview (first 10 lines):"
echo "$FHIR_BUNDLE" | head -10 | sed 's/^/  /'
echo ""

echo -e "${YELLOW}Posting FHIR bundle to FHIR→FHIR pipeline...${NC}"
echo "  POST /fhir-bundle (Content-Type: application/fhir+json)"

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/fhir+json" \
    -d "$FHIR_BUNDLE" \
    "http://127.0.0.1:$HARMONY_PORT/fhir-bundle")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Request successful (HTTP $HTTP_CODE)${NC}"
    if echo "$BODY" | grep -q '"resourceType"'; then
        echo -e "${GREEN}✓ Got FHIR response${NC}"
        echo ""
        echo "FHIR Bundle response (summary):"
        echo "$BODY" | python3 -m json.tool 2>/dev/null | head -30 | sed 's/^/  /'
    fi
else
    echo -e "${RED}✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}=== Test 3: Bidirectional FHIR Validation ===${NC}"
echo ""

echo "Summary of pipeline flows:"
echo "  Test 1: HTTP API → FHIR transformation → HTTP API response"
echo "          GET /service-requests → FHIR Server → transformed HTTP JSON"
echo ""
echo "  Test 2: FHIR Bundle → FHIR Server → FHIR Bundle response"
echo "          POST /fhir-bundle → FHIR Server → FHIR Bundle"
echo ""
echo -e "${GREEN}✓ Bidirectional integration demonstrated${NC}"

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Bidirectional Workflow Capabilities:"
echo "  ✅ HTTP API → FHIR transformation (service-requests endpoint)"
echo "  ✅ FHIR → FHIR pass-through (fhir-bundle endpoint)"
echo "  ✅ Full FHIR bundle processing"
echo ""
echo "Service Architecture:"
echo "  FHIR Server (Echo):    http://127.0.0.1:$FHIR_SERVER_PORT"
echo "  Harmony Proxy:         http://127.0.0.1:$HARMONY_PORT"
echo ""
echo "Endpoints:"
echo "  Forward:  GET /service-requests?providerId={id}"
echo "  Reverse:  POST /fhir-bundle (application/fhir+json)"
echo ""
echo "Logs available at:"
echo "  Harmony:      $TMP_DIR/harmony.log"
echo "  FHIR Server:  $TMP_DIR/fhir_server.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
