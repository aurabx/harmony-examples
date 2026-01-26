#!/bin/bash
# JMIX Backend Demo Script
# Demonstrates JMIX POST and GET forwarding to upstream servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8085
MOCK_SERVER_PORT=9999
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== JMIX Backend Demo ===${NC}"
echo "This script demonstrates Harmony's JMIX backend forwarding capabilities"
echo "including POST (upload) and GET (retrieve) operations"
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

echo -e "${GREEN}All prerequisites found${NC}"
echo ""

# Setup directories
echo -e "${YELLOW}Setting up test environment...${NC}"
mkdir -p "$TMP_DIR"
mkdir -p "$TMP_DIR/jmix-store"

# Create a test JMIX envelope ZIP file
TEST_ENVELOPE_ID="test-$(date +%s)"
TEST_ENVELOPE_DIR="$TMP_DIR/test-envelope"
mkdir -p "$TEST_ENVELOPE_DIR/payload"

# Create manifest.json
cat > "$TEST_ENVELOPE_DIR/manifest.json" << EOF
{
  "id": "$TEST_ENVELOPE_ID",
  "type": "envelope",
  "version": 1,
  "content": {
    "type": "directory",
    "path": "payload"
  }
}
EOF

# Create metadata.json
cat > "$TEST_ENVELOPE_DIR/payload/metadata.json" << EOF
{
  "id": "$TEST_ENVELOPE_ID",
  "studies": {
    "1.2.3.4.5.test": {
      "study_uid": "1.2.3.4.5.test",
      "patient_name": "TEST^PATIENT",
      "study_date": "20240115",
      "modality": "CT"
    }
  }
}
EOF

# Create the ZIP envelope
TEST_ZIP="$TMP_DIR/test-envelope.zip"
cd "$TEST_ENVELOPE_DIR"
zip -r "$TEST_ZIP" manifest.json payload/ > /dev/null 2>&1
cd "$SCRIPT_DIR"

echo -e "${GREEN}Test environment ready${NC}"
echo "  Test envelope ID: $TEST_ENVELOPE_ID"
echo "  Test ZIP file: $TEST_ZIP"
echo ""

# Create mock JMIX server Python script
cat > "$TMP_DIR/mock_jmix_server.py" << 'MOCK_SERVER'
#!/usr/bin/env python3
"""Mock JMIX server for testing JMIX backend forwarding"""
import http.server
import json
import os
import sys
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9999
STORE_DIR = os.environ.get('STORE_DIR', '/tmp/mock-jmix-store')
os.makedirs(STORE_DIR, exist_ok=True)

# In-memory store: {envelope_id: bytes}
envelopes = {}
# Track last uploaded ID for study UID queries
last_envelope_id = None

class JmixHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        """Handle POST /api/jmix - upload envelope"""
        global last_envelope_id
        if self.path.startswith('/api/jmix'):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            # Generate envelope ID
            import uuid
            envelope_id = str(uuid.uuid4())
            envelopes[envelope_id] = body
            last_envelope_id = envelope_id
            
            response = json.dumps({"id": envelope_id, "status": "stored"})
            self.send_response(201)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response.encode())
            print(f"  [Mock Server] POST /api/jmix -> stored {envelope_id} ({len(body)} bytes)")
        else:
            self.send_error(404)

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path_parts = parsed.path.strip('/').split('/')
        
        # Query by studyInstanceUid - return last uploaded envelope
        if parsed.path == '/api/jmix' and parsed.query:
            params = parse_qs(parsed.query)
            study_uid = params.get('studyInstanceUid', [None])[0]
            
            if last_envelope_id and last_envelope_id in envelopes:
                data = envelopes[last_envelope_id]
                self.send_response(200)
                self.send_header('Content-Type', 'application/zip')
                self.send_header('Content-Length', len(data))
                self.end_headers()
                self.wfile.write(data)
                print(f"  [Mock Server] GET /api/jmix?studyInstanceUid={study_uid} -> 200 ({len(data)} bytes)")
            else:
                response = json.dumps({"envelopes": []})
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', len(response))
                self.end_headers()
                self.wfile.write(response.encode())
                print(f"  [Mock Server] GET /api/jmix?studyInstanceUid={study_uid} -> 200 (empty)")
            return
        
        if len(path_parts) >= 3 and path_parts[0] == 'api' and path_parts[1] == 'jmix':
            envelope_id = path_parts[2]
            
            if len(path_parts) == 4 and path_parts[3] == 'manifest':
                # GET manifest
                if envelope_id in envelopes:
                    manifest = json.dumps({
                        "id": envelope_id,
                        "type": "envelope",
                        "version": 1
                    })
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', len(manifest))
                    self.end_headers()
                    self.wfile.write(manifest.encode())
                    print(f"  [Mock Server] GET /api/jmix/{envelope_id}/manifest -> 200")
                else:
                    self.send_error(404, "Envelope not found")
                    print(f"  [Mock Server] GET /api/jmix/{envelope_id}/manifest -> 404")
            else:
                # GET envelope by ID
                if envelope_id in envelopes:
                    data = envelopes[envelope_id]
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/zip')
                    self.send_header('Content-Length', len(data))
                    self.end_headers()
                    self.wfile.write(data)
                    print(f"  [Mock Server] GET /api/jmix/{envelope_id} -> 200 ({len(data)} bytes)")
                else:
                    self.send_error(404, "Envelope not found")
                    print(f"  [Mock Server] GET /api/jmix/{envelope_id} -> 404")
        else:
            self.send_error(404)

if __name__ == '__main__':
    server = http.server.HTTPServer(('127.0.0.1', PORT), JmixHandler)
    print(f"Mock JMIX server listening on port {PORT}")
    server.serve_forever()
MOCK_SERVER

echo -e "${GREEN}Mock JMIX server script created${NC}"
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
    
    # Kill mock server
    if [ ! -z "$MOCK_PID" ] && kill -0 $MOCK_PID 2>/dev/null; then
        echo "  Stopping mock JMIX server (PID: $MOCK_PID)..."
        kill $MOCK_PID
        wait $MOCK_PID 2>/dev/null || true
    fi
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start mock JMIX server
echo -e "${YELLOW}Starting mock JMIX server on port $MOCK_SERVER_PORT...${NC}"
STORE_DIR="$TMP_DIR/mock-jmix-store" python3 "$TMP_DIR/mock_jmix_server.py" $MOCK_SERVER_PORT > "$TMP_DIR/mock_server.log" 2>&1 &
MOCK_PID=$!
sleep 1

if ! kill -0 $MOCK_PID 2>/dev/null; then
    echo -e "${RED}Error: Mock server did not start${NC}"
    cat "$TMP_DIR/mock_server.log"
    exit 1
fi
echo -e "${GREEN}Mock JMIX server started (PID: $MOCK_PID)${NC}"
echo ""

# Create a modified config that points to our mock server
echo -e "${YELLOW}Creating test configuration...${NC}"
cat > "$TMP_DIR/test-config.toml" << EOF
# JMIX Backend Test Configuration
[proxy]
name = "harmony-jmix-backend-test"
log_level = "debug"
pipelines_path = "$SCRIPT_DIR/pipelines"
primary_provider = "local"

[provider.runbeam]
api = "https://api.runbeam.cloud"
poll_interval_secs = 30

[network.http_net]
enable_wireguard = false
interface = "wg0"

[network.http_net.http]
bind_address = "127.0.0.1"
bind_port = $HARMONY_PORT

[logging]
log_to_file = true
log_file_path = "$TMP_DIR/harmony.log"

[storage]
backend = "filesystem"

[storage.options]
path = "$TMP_DIR"

[services.http]
module = ""

[services.jmix]
module = ""

[services.jmix_backend]
module = ""

[middleware_types.passthru]
module = ""

[middleware_types.policies]
module = ""

# Point to mock server instead of example.com
[targets.upstream_jmix]
connection.host = "127.0.0.1"
connection.port = $MOCK_SERVER_PORT
connection.protocol = "http"
timeout_secs = 60
EOF

echo -e "${GREEN}Test configuration created${NC}"
echo ""

# Start Harmony
echo -e "${YELLOW}Starting Harmony JMIX backend proxy on port $HARMONY_PORT...${NC}"
harmony --config "$TMP_DIR/test-config.toml" > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$HARMONY_PORT/" 2>/dev/null | grep -q "404\|200\|403"; then
        echo -e "${GREEN}Harmony is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Harmony did not start in time${NC}"
        echo "Check logs: $TMP_DIR/harmony.log"
        cat "$TMP_DIR/harmony.log"
        exit 1
    fi
    sleep 1
done

echo ""
echo -e "${BLUE}=== Running Tests ===${NC}"
echo ""

# Test 1: POST - Upload JMIX envelope
echo -e "${YELLOW}Test 1: POST - Upload JMIX envelope${NC}"
echo "  Command: curl -X POST -H 'Content-Type: application/zip' --data-binary @envelope.zip"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/zip" \
    --data-binary "@$TEST_ZIP" \
    "http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  POST successful (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
    
    # Extract envelope ID for subsequent tests
    if command -v jq &> /dev/null; then
        UPLOADED_ID=$(echo "$BODY" | jq -r '.id // empty' 2>/dev/null)
    else
        UPLOADED_ID=$(echo "$BODY" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    if [ ! -z "$UPLOADED_ID" ]; then
        echo -e "${GREEN}  Uploaded envelope ID: $UPLOADED_ID${NC}"
    fi
else
    echo -e "${RED}  POST failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 2: GET - Retrieve envelope manifest
echo -e "${YELLOW}Test 2: GET - Retrieve envelope manifest${NC}"
if [ ! -z "$UPLOADED_ID" ]; then
    echo "  Command: curl http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix/$UPLOADED_ID/manifest"
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix/$UPLOADED_ID/manifest")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}  GET manifest successful (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
    else
        echo -e "${RED}  GET manifest failed (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
    fi
else
    echo -e "${YELLOW}  Skipped: No envelope ID from previous test${NC}"
fi
echo ""

# Test 3: GET - Retrieve full envelope
echo -e "${YELLOW}Test 3: GET - Retrieve full envelope (ZIP)${NC}"
if [ ! -z "$UPLOADED_ID" ]; then
    DOWNLOAD_FILE="$TMP_DIR/downloaded-envelope.zip"
    echo "  Command: curl -o envelope.zip http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix/$UPLOADED_ID"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$DOWNLOAD_FILE" \
        -H "Accept: application/zip" \
        "http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix/$UPLOADED_ID")
    
    if [ "$HTTP_CODE" = "200" ]; then
        if [ -f "$DOWNLOAD_FILE" ]; then
            FILE_SIZE=$(stat -f%z "$DOWNLOAD_FILE" 2>/dev/null || stat -c%s "$DOWNLOAD_FILE" 2>/dev/null)
            if [ "$FILE_SIZE" -gt 0 ]; then
                echo -e "${GREEN}  GET envelope successful (HTTP $HTTP_CODE)${NC}"
                echo "  Downloaded: $FILE_SIZE bytes"
                if file "$DOWNLOAD_FILE" | grep -q "Zip archive"; then
                    echo -e "${GREEN}  Valid ZIP file received${NC}"
                fi
            else
                echo -e "${YELLOW}  GET envelope returned HTTP $HTTP_CODE but 0 bytes${NC}"
            fi
        fi
    else
        echo -e "${RED}  GET envelope failed (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${YELLOW}  Skipped: No envelope ID from previous test${NC}"
fi
echo ""

# Test 4: GET - Query by Study Instance UID
echo -e "${YELLOW}Test 4: GET - Query by Study Instance UID${NC}"
STUDY_UID="1.2.3.4.5.test"
QUERY_FILE="$TMP_DIR/query-result.zip"
echo "  Command: curl 'http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix?studyInstanceUid=$STUDY_UID'"
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$QUERY_FILE" \
    "http://127.0.0.1:$HARMONY_PORT/jmix/api/jmix?studyInstanceUid=$STUDY_UID")

if [ "$HTTP_CODE" = "200" ]; then
    FILE_SIZE=$(stat -f%z "$QUERY_FILE" 2>/dev/null || stat -c%s "$QUERY_FILE" 2>/dev/null)
    if [ "$FILE_SIZE" -gt 0 ]; then
        echo -e "${GREEN}  Query successful (HTTP $HTTP_CODE)${NC}"
        echo "  Downloaded: $FILE_SIZE bytes"
        if file "$QUERY_FILE" | grep -q "Zip archive"; then
            echo -e "${GREEN}  Valid ZIP file received${NC}"
        fi
    else
        echo -e "${YELLOW}  Query returned HTTP $HTTP_CODE but 0 bytes${NC}"
    fi
else
    echo -e "${RED}  Query failed (HTTP $HTTP_CODE)${NC}"
    cat "$QUERY_FILE" 2>/dev/null
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "JMIX Backend Capabilities Demonstrated:"
echo "  POST /jmix/api/jmix              - Upload JMIX envelope to upstream"
echo "  GET /jmix/api/jmix/{id}          - Retrieve envelope from upstream"
echo "  GET /jmix/api/jmix/{id}/manifest - Retrieve manifest from upstream"
echo "  GET /jmix/api/jmix?studyInstanceUid=... - Query by study UID"
echo ""
echo "Configuration:"
echo "  Harmony Proxy: http://127.0.0.1:$HARMONY_PORT"
echo "  Upstream JMIX: http://127.0.0.1:$MOCK_SERVER_PORT (mock server)"
echo ""
echo "Logs available at:"
echo "  Harmony:     $TMP_DIR/harmony.log"
echo "  Mock Server: $TMP_DIR/mock_server.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
