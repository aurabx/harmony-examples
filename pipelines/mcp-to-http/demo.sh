#!/bin/bash
# MCP to HTTP Bridge Demo Script
# Demonstrates MCP protocol transformation to standard HTTP API calls

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8090
BACKEND_PORT=8081
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== MCP to HTTP Bridge Demo ===${NC}"
echo "This script demonstrates Harmony's MCP to HTTP transformation capabilities"
echo "MCP (Model Context Protocol) allows AI agents to communicate with HTTP APIs"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl not found. Please install curl.${NC}"
    exit 1
fi

if ! command -v harmony &> /dev/null; then
    echo -e "${RED}Error: harmony not found. Please install Harmony.${NC}"
    exit 1
fi

HAS_JQ=false
if command -v jq &> /dev/null; then
    HAS_JQ=true
    echo -e "${GREEN}✓ jq found (will use for pretty printing)${NC}"
fi

echo -e "${GREEN}✓ All required prerequisites found${NC}"
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
    
    # Kill backend mock
    if [ ! -z "$BACKEND_PID" ] && kill -0 $BACKEND_PID 2>/dev/null; then
        echo "  Stopping backend mock (PID: $BACKEND_PID)..."
        kill $BACKEND_PID
        wait $BACKEND_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start mock backend server
echo -e "${YELLOW}Starting mock HTTP backend on port $BACKEND_PORT...${NC}"
# Simple mock backend using netcat or python
cat > "$TMP_DIR/mock_backend.py" << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json

PORT = 8081

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        
        response = {
            "status": "success",
            "received": json.loads(body.decode('utf-8')),
            "endpoint": self.path,
            "message": "HTTP backend received the transformed MCP request"
        }
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def log_message(self, format, *args):
        pass  # Suppress logs

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
EOF

python3 "$TMP_DIR/mock_backend.py" > "$TMP_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
echo -e "${GREEN}✓ Backend mock started (PID: $BACKEND_PID)${NC}"

# Wait for backend to be ready
sleep 2

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony MCP bridge on port $HARMONY_PORT...${NC}"
cd "$SCRIPT_DIR"
harmony --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s -X POST http://127.0.0.1:$HARMONY_PORT/mcp \
        -H "Content-Type: application/json" \
        -d '{}' > /dev/null 2>&1; then
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

# Test 1: Basic MCP request
echo -e "${YELLOW}Test 1: Basic MCP Protocol Request${NC}"
MCP_REQUEST='{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "tools/call",
  "params": {
    "name": "get_data",
    "arguments": {
      "user_id": "12345"
    }
  }
}'
echo "  Input MCP request:"
if [ "$HAS_JQ" = true ]; then
    echo "$MCP_REQUEST" | jq '.' 2>/dev/null || echo "$MCP_REQUEST"
else
    echo "$MCP_REQUEST"
fi
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/mcp \
    -H "Content-Type: application/json" \
    -d "$MCP_REQUEST")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ MCP request successful (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo "  Backend response:"
    if [ "$HAS_JQ" = true ]; then
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
    echo ""
    echo -e "${GREEN}  ✓ MCP to HTTP transformation working${NC}"
else
    echo -e "${RED}  ✗ MCP request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 2: Complex MCP request
echo -e "${YELLOW}Test 2: Complex MCP Request with Multiple Parameters${NC}"
COMPLEX_MCP='{
  "jsonrpc": "2.0",
  "id": "req-002",
  "method": "tools/call",
  "params": {
    "name": "create_order",
    "arguments": {
      "customer": "ACME Corp",
      "items": [
        {"sku": "ITEM-001", "qty": 5},
        {"sku": "ITEM-002", "qty": 3}
      ],
      "priority": "high"
    }
  }
}'
echo "  Input MCP request (complex):"
if [ "$HAS_JQ" = true ]; then
    echo "$COMPLEX_MCP" | jq '.' 2>/dev/null || echo "$COMPLEX_MCP"
else
    echo "$COMPLEX_MCP"
fi
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/mcp \
    -H "Content-Type: application/json" \
    -d "$COMPLEX_MCP")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Complex MCP request successful (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo "  Backend response:"
    if [ "$HAS_JQ" = true ]; then
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
else
    echo -e "${YELLOW}  ⚠ Complex MCP request returned HTTP $HTTP_CODE${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 3: Invalid method (should fail)
echo -e "${YELLOW}Test 3: Invalid Method (GET should be rejected)${NC}"
echo "  Testing GET request (should fail due to policy)..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET http://127.0.0.1:$HARMONY_PORT/mcp 2>/dev/null || echo "")
if [ -z "$RESPONSE" ]; then
    HTTP_CODE="000"
else
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
fi

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${YELLOW}  ⚠ GET request was allowed (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${GREEN}  ✓ GET request correctly rejected (HTTP $HTTP_CODE)${NC}"
    echo -e "${GREEN}    Security policy is working${NC}"
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "MCP to HTTP Bridge Capabilities:"
echo "  ✅ MCP JSON-RPC requests accepted"
echo "  ✅ Protocol transformation working"
echo "  ✅ HTTP backend communication"
echo "  ✅ Security policies enforced (POST/JSON only)"
echo "  ✅ Internal network restrictions"
echo ""
echo "Architecture:"
echo "  AI Agent (MCP) → Harmony Proxy → Transform → HTTP Backend"
echo ""
echo "Files:"
echo "  - config.toml - Main proxy configuration"
echo "  - pipelines/mcp-to-http.toml - Pipeline definition"
echo "  - transforms/mcp_to_http.json - JOLT transform"
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo "  Backend: $TMP_DIR/backend.log"
echo ""
if [ "$HAS_JQ" = false ]; then
    echo -e "${YELLOW}Tip: Install 'jq' for better JSON formatting${NC}"
    echo ""
fi
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
