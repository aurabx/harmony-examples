#!/bin/bash
# HTTP/3 Listener Demo Script
# Demonstrates HTTP/3 (QUIC) connections through Harmony's HTTP/3 listener

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_HTTP_PORT=8080
HARMONY_HTTP3_PORT=443
BACKEND_PORT=9002
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
BACKEND_DIR="$TMP_DIR/backend"
export TMP_DIR

echo -e "${BLUE}=== HTTP/3 Listener Demo ===${NC}"
echo "This script demonstrates Harmony's HTTP/3 (QUIC) listener with HTTP backend"
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

# Check if curl supports HTTP/3
CURL_SUPPORTS_HTTP3=false
if curl --version 2>&1 | grep -qi "http3"; then
    CURL_SUPPORTS_HTTP3=true
    echo -e "${GREEN}✓ curl supports HTTP/3${NC}"
else
    echo -e "${YELLOW}⚠ curl does not support HTTP/3 (HTTP/1.x tests will run, HTTP/3 tests will be skipped)${NC}"
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"
echo ""

# Setup directories
echo -e "${YELLOW}Setting up test environment...${NC}"
mkdir -p "$TMP_DIR"
mkdir -p "$BACKEND_DIR"

# Create test HTML file for backend
cat > "$BACKEND_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head><title>HTTP/3 Backend</title></head>
<body>
<h1>Hello from HTTP/3 Backend!</h1>
<p>This content was served through Harmony's HTTP/3 listener and proxied to the HTTP backend.</p>
</body>
</html>
EOF

# Create JSON test file
cat > "$BACKEND_DIR/data.json" << 'EOF'
{
  "message": "Hello from HTTP/3 proxied backend",
  "protocol": "HTTP/3",
  "status": "success",
  "timestamp": "2024-01-01T12:00:00Z"
}
EOF

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
    
    # Kill Python backend
    if [ ! -z "$BACKEND_PID" ] && kill -0 $BACKEND_PID 2>/dev/null; then
        echo "  Stopping Python backend (PID: $BACKEND_PID)..."
        kill $BACKEND_PID
        wait $BACKEND_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start Python HTTP server as backend
echo -e "${YELLOW}Starting Python HTTP backend on port $BACKEND_PORT...${NC}"
cd "$BACKEND_DIR"
python3 -m http.server $BACKEND_PORT > "$TMP_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"

# Wait for backend to be ready
sleep 2
if ! curl -s http://127.0.0.1:$BACKEND_PORT/ > /dev/null; then
    echo -e "${RED}Error: Backend did not start${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Backend is ready${NC}"
echo ""

# Determine harmony binary location
HARMONY_BIN=""
if command -v harmony &> /dev/null; then
    HARMONY_BIN="harmony"
elif [ -f "$PROJECT_ROOT/target/debug/harmony" ]; then
    HARMONY_BIN="$PROJECT_ROOT/target/debug/harmony"
elif [ -f "$PROJECT_ROOT/harmony-proxy/target/debug/harmony" ]; then
    HARMONY_BIN="$PROJECT_ROOT/harmony-proxy/target/debug/harmony"
else
    echo -e "${RED}Error: harmony binary not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Using harmony binary: $HARMONY_BIN${NC}"
echo ""

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony HTTP/3 listener...${NC}"
cd "$SCRIPT_DIR"
$HARMONY_BIN --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$HARMONY_HTTP_PORT/ > /dev/null 2>&1; then
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

# Test 1: HTTP/1.x request
echo -e "${YELLOW}Test 1: HTTP/1.x request to Harmony${NC}"
echo "  Command: curl http://127.0.0.1:$HARMONY_HTTP_PORT/"
RESPONSE=$(curl -s -w "\n%{http_code}" http://127.0.0.1:$HARMONY_HTTP_PORT/)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ HTTP/1.x request successful (HTTP $HTTP_CODE)${NC}"
    if echo "$BODY" | grep -q "HTTP/3"; then
        echo -e "${GREEN}  ✓ Content from proxied backend received${NC}"
    fi
else
    echo -e "${RED}  ✗ HTTP/1.x request failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 2: HTTP/3 request (if curl supports it)
echo -e "${YELLOW}Test 2: HTTP/3 (QUIC) request to Harmony${NC}"
if [ "$CURL_SUPPORTS_HTTP3" = true ]; then
    echo "  Command: curl --http3 -k https://127.0.0.1:$HARMONY_HTTP3_PORT/"
    RESPONSE=$(curl -s -w "\n%{http_code}" --http3 -k https://127.0.0.1:$HARMONY_HTTP3_PORT/)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}  ✓ HTTP/3 request successful (HTTP $HTTP_CODE)${NC}"
        if echo "$BODY" | grep -q "HTTP/3"; then
            echo -e "${GREEN}  ✓ Content from proxied backend received over HTTP/3${NC}"
        fi
    else
        echo -e "${RED}  ✗ HTTP/3 request failed (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ curl does not support HTTP/3 (requires QUIC support)${NC}"
    echo "    HTTP/3 listener is running but cannot test with this curl version"
fi
echo ""

# Test 3: JSON endpoint via HTTP/1.x
echo -e "${YELLOW}Test 3: JSON endpoint via HTTP/1.x${NC}"
echo "  Command: curl http://127.0.0.1:$HARMONY_HTTP_PORT/data.json"
RESPONSE=$(curl -s -w "\n%{http_code}" http://127.0.0.1:$HARMONY_HTTP_PORT/data.json)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ JSON request successful (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
    if echo "$BODY" | grep -q '"message"'; then
        echo -e "${GREEN}  ✓ JSON data proxied correctly${NC}"
    fi
else
    echo -e "${RED}  ✗ JSON request failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 4: JSON endpoint via HTTP/3 (if supported)
echo -e "${YELLOW}Test 4: JSON endpoint via HTTP/3${NC}"
if [ "$CURL_SUPPORTS_HTTP3" = true ]; then
    echo "  Command: curl --http3 -k https://127.0.0.1:$HARMONY_HTTP3_PORT/data.json"
    RESPONSE=$(curl -s -w "\n%{http_code}" --http3 -k https://127.0.0.1:$HARMONY_HTTP3_PORT/data.json)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}  ✓ JSON over HTTP/3 successful (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        if echo "$BODY" | grep -q '"protocol"'; then
            echo -e "${GREEN}  ✓ JSON correctly proxied over HTTP/3${NC}"
        fi
    else
        echo -e "${RED}  ✗ JSON over HTTP/3 failed (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${YELLOW}  ⊘ curl does not support HTTP/3${NC}"
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "HTTP/3 Listener Capabilities:"
echo "  ✅ HTTP/1.x listener on TCP port $HARMONY_HTTP_PORT"
echo "  ✅ HTTP/3 (QUIC) listener on UDP port $HARMONY_HTTP3_PORT"
echo "  ✅ Protocol translation (HTTP/3 → HTTP/1.x)"
echo "  ✅ TLS 1.3 termination at edge"
echo "  ✅ Proxying to HTTP backend"
echo ""
echo "Configuration:"
echo "  Harmony HTTP/1.x:  http://127.0.0.1:$HARMONY_HTTP_PORT"
echo "  Harmony HTTP/3:    https://127.0.0.1:$HARMONY_HTTP3_PORT (QUIC/UDP)"
echo "  Backend:           http://127.0.0.1:$BACKEND_PORT"
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo "  Backend: $TMP_DIR/backend.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
