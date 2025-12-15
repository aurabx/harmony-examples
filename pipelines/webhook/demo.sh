#!/bin/bash
# Webhook Middleware Demo Script
# Starts a webhook receiver, runs Harmony, and sends a test request

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8080
HOOK_PORT=9001
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== Webhook Middleware Demo ===${NC}"
echo "This script demonstrates Harmony's webhook middleware posting payloads to a receiver"
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

    # Kill webhook receiver
    if [ ! -z "$RECEIVER_PID" ] && kill -0 $RECEIVER_PID 2>/dev/null; then
        echo "  Stopping webhook receiver (PID: $RECEIVER_PID)..."
        kill $RECEIVER_PID
        wait $RECEIVER_PID 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start a simple webhook receiver using Python (common on macOS)
echo -e "${YELLOW}Starting webhook receiver on port $HOOK_PORT...${NC}"
python3 - <<'PYRECEIVER' &
import http.server
import json
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # silence default logging
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode('utf-8')
        try:
            data = json.loads(body)
            side = data.get('side', '?')
            name = data.get('name', '?')
            extra = data.get('extra')
            auth = self.headers.get('Authorization', '(none)')
            print(f"[HOOK] side={side} name={name} extra={extra} auth_header={auth[:30]}...")
        except:
            print(f"[HOOK] raw body: {body[:100]}...")
        self.send_response(200)
        self.end_headers()
http.server.HTTPServer(('127.0.0.1', 9001), Handler).serve_forever()
PYRECEIVER
RECEIVER_PID=$!
sleep 0.5
echo -e "${GREEN}✓ Webhook receiver started (PID: $RECEIVER_PID)${NC}"
echo ""

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony on port $HARMONY_PORT...${NC}"
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

# Test 1: POST request that triggers webhooks on both sides
echo -e "${YELLOW}Test 1: POST request triggering webhook (apply=both)${NC}"
echo "  Command: curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer inbound' -d '{\"hello\":\"world\"}' http://127.0.0.1:$HARMONY_PORT/echo"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/echo \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer inbound-token" \
    -d '{"hello":"world"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Request successful (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Give time for async webhook posts
sleep 1

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "You should have seen two HOOK lines printed by the receiver (side=left, side=right)."
echo "The Authorization header in the webhook POST is the per-instance Basic auth (demo:demo123), not the inbound Bearer."
echo "Headers like 'authorization' and 'cookie' plus metadata key 'secret' are redacted in the payload."
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
