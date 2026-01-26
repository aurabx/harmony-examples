#!/bin/bash
# DICOM to JMIX Demo Script
# Demonstrates receiving DICOM images and packaging them into JMIX envelopes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_DICOM_PORT=11113
HARMONY_HTTP_PORT=8086
MOCK_JMIX_PORT=9998
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== DICOM to JMIX Demo ===${NC}"
echo "This script demonstrates receiving DICOM images via C-STORE"
echo "and packaging them into JMIX envelopes for upstream storage"
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

# Check for DCMTK tools (optional but recommended)
HAS_DCMTK=false
if command -v storescu &> /dev/null && command -v echoscu &> /dev/null; then
    HAS_DCMTK=true
    echo -e "${GREEN}DCMTK tools found (storescu, echoscu)${NC}"
else
    echo -e "${YELLOW}DCMTK tools not found - DICOM tests will be limited${NC}"
    echo "  Install with: brew install dcmtk (macOS) or apt install dcmtk (Linux)"
fi

echo -e "${GREEN}Core prerequisites found${NC}"
echo ""

# Setup directories
echo -e "${YELLOW}Setting up test environment...${NC}"
mkdir -p "$TMP_DIR"
mkdir -p "$TMP_DIR/dicom-incoming"
mkdir -p "$TMP_DIR/jmix-store"
mkdir -p "$TMP_DIR/mock-jmix-store"

# Create a sample DICOM file if dcmconv is available, otherwise create a minimal placeholder
SAMPLE_DICOM="$TMP_DIR/sample.dcm"
if command -v dcmconv &> /dev/null; then
    # Create minimal DICOM using DCMTK
    echo -e "${YELLOW}Creating sample DICOM file...${NC}"
    # We'll rely on actual DICOM files for the test
fi

echo -e "${GREEN}Test environment ready${NC}"
echo ""

# Create mock JMIX server Python script
cat > "$TMP_DIR/mock_jmix_server.py" << 'MOCK_SERVER'
#!/usr/bin/env python3
"""Mock JMIX server for testing DICOM to JMIX pipeline"""
import http.server
import json
import os
import sys
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9998
STORE_DIR = os.environ.get('STORE_DIR', '/tmp/mock-jmix-store')
os.makedirs(STORE_DIR, exist_ok=True)

# In-memory store for envelopes
envelopes = {}
envelope_count = 0

class JmixHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_POST(self):
        """Handle POST /api/jmix - upload envelope"""
        global envelope_count
        if self.path.startswith('/api/jmix'):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            import uuid
            envelope_id = str(uuid.uuid4())
            envelopes[envelope_id] = body
            envelope_count += 1
            
            # Store to disk
            with open(os.path.join(STORE_DIR, f"{envelope_id}.zip"), 'wb') as f:
                f.write(body)
            
            response = json.dumps({"id": envelope_id, "status": "stored"})
            self.send_response(201)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response.encode())
            print(f"  [Mock JMIX] Received envelope #{envelope_count}: {envelope_id} ({len(body)} bytes)")
        else:
            self.send_error(404)

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path_parts = parsed.path.strip('/').split('/')
        
        # Check stats endpoint first (before envelope ID matching)
        if parsed.path == '/api/jmix/stats':
            # Custom endpoint to check received envelopes
            response = json.dumps({"envelope_count": envelope_count, "envelope_ids": list(envelopes.keys())})
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response))
            self.end_headers()
            self.wfile.write(response.encode())
        elif len(path_parts) >= 3 and path_parts[0] == 'api' and path_parts[1] == 'jmix':
            envelope_id = path_parts[2]
            
            if len(path_parts) == 4 and path_parts[3] == 'manifest':
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
                else:
                    self.send_error(404)
            else:
                if envelope_id in envelopes:
                    data = envelopes[envelope_id]
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/zip')
                    self.send_header('Content-Length', len(data))
                    self.end_headers()
                    self.wfile.write(data)
                else:
                    self.send_error(404)
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
    
    # Kill mock JMIX server
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
echo -e "${YELLOW}Starting mock JMIX server on port $MOCK_JMIX_PORT...${NC}"
STORE_DIR="$TMP_DIR/mock-jmix-store" python3 "$TMP_DIR/mock_jmix_server.py" $MOCK_JMIX_PORT > "$TMP_DIR/mock_jmix.log" 2>&1 &
MOCK_PID=$!
sleep 1

if ! kill -0 $MOCK_PID 2>/dev/null; then
    echo -e "${RED}Error: Mock JMIX server did not start${NC}"
    cat "$TMP_DIR/mock_jmix.log"
    exit 1
fi
echo -e "${GREEN}Mock JMIX server started (PID: $MOCK_PID)${NC}"
echo ""

# Create a modified config that points to our mock server
echo -e "${YELLOW}Creating test configuration...${NC}"
cat > "$TMP_DIR/test-config.toml" << EOF
# DICOM to JMIX Test Configuration
[proxy]
name = "harmony-dicom-to-jmix-test"
log_level = "debug"
pipelines_path = "$SCRIPT_DIR/pipelines"
primary_provider = "local"

[provider.runbeam]
api = "https://api.runbeam.cloud"
poll_interval_secs = 30

# DICOM network for receiving images
[network.dicom_net]
enable_wireguard = false
interface = "wg0"

[network.dicom_net.tcp_config]
bind_address = "0.0.0.0"
bind_port = $HARMONY_DICOM_PORT

# HTTP network for JMIX queries
[network.http_net]
enable_wireguard = false
interface = "wg0"

[network.http_net.http]
bind_address = "127.0.0.1"
bind_port = $HARMONY_HTTP_PORT

[logging]
log_to_file = true
log_file_path = "$TMP_DIR/harmony.log"

[storage]
backend = "filesystem"

[storage.options]
path = "$TMP_DIR"

[services.dicom_scp]
module = ""

[services.jmix]
module = ""

[services.jmix_backend]
module = ""

[middleware_types.jmix_builder]
module = ""

[middleware_types.passthru]
module = ""

[peers.dicom_listener]
connection.host = "0.0.0.0"
connection.port = $HARMONY_DICOM_PORT
connection.protocol = "dicom"

# Point to mock JMIX server
[targets.upstream_jmix]
connection.host = "127.0.0.1"
connection.port = $MOCK_JMIX_PORT
connection.protocol = "http"
timeout_secs = 120
EOF

echo -e "${GREEN}Test configuration created${NC}"
echo ""

# Start Harmony
echo -e "${YELLOW}Starting Harmony DICOM-to-JMIX gateway...${NC}"
echo "  DICOM port: $HARMONY_DICOM_PORT (AE: JMIX_RECEIVER)"
echo "  HTTP port:  $HARMONY_HTTP_PORT"
harmony --config "$TMP_DIR/test-config.toml" > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    # Check HTTP endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$HARMONY_HTTP_PORT/" 2>/dev/null | grep -q "404\|200\|403"; then
        echo -e "${GREEN}Harmony HTTP endpoint is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Harmony did not start in time${NC}"
        echo "Check logs: $TMP_DIR/harmony.log"
        tail -50 "$TMP_DIR/harmony.log"
        exit 1
    fi
    sleep 1
done

# Additional wait for DICOM listener
sleep 2

echo ""
echo -e "${BLUE}=== Running Tests ===${NC}"
echo ""

# Test 1: DICOM Echo (if DCMTK available)
if [ "$HAS_DCMTK" = true ]; then
    echo -e "${YELLOW}Test 1: DICOM C-ECHO (connectivity test)${NC}"
    echo "  Command: echoscu -aec JMIX_RECEIVER 127.0.0.1 $HARMONY_DICOM_PORT"
    
    if echoscu -aec JMIX_RECEIVER -aet TEST_SCU 127.0.0.1 $HARMONY_DICOM_PORT 2>/dev/null; then
        echo -e "${GREEN}  C-ECHO successful - DICOM association accepted${NC}"
    else
        echo -e "${YELLOW}  C-ECHO failed - DICOM listener may not be ready${NC}"
        echo "  Check logs: $TMP_DIR/harmony.log"
    fi
    echo ""
fi

# Test 2: Check HTTP JMIX endpoint
echo -e "${YELLOW}Test 2: HTTP JMIX query endpoint${NC}"
echo "  Command: curl http://127.0.0.1:$HARMONY_HTTP_PORT/jmix/api/jmix?studyInstanceUid=test"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    "http://127.0.0.1:$HARMONY_HTTP_PORT/jmix/api/jmix?studyInstanceUid=1.2.3.test" 2>/dev/null)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  HTTP JMIX endpoint responding (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}  HTTP endpoint returned HTTP $HTTP_CODE${NC}"
fi
echo ""

# Test 3: Send DICOM file (if DCMTK available and sample files exist)
if [ "$HAS_DCMTK" = true ]; then
    echo -e "${YELLOW}Test 3: DICOM C-STORE (send images)${NC}"
    
    # Look for sample DICOM files
    SAMPLE_DIR=""
    for dir in "$PROJECT_ROOT/samples" "$PROJECT_ROOT/../samples" "../../samples/dicom"; do
        if [ -d "$dir" ]; then
            SAMPLE_DIR="$dir"
            break
        fi
    done
    
    if [ ! -z "$SAMPLE_DIR" ] && [ -d "$SAMPLE_DIR" ]; then
        echo "  Found sample DICOM directory: $SAMPLE_DIR"
        echo "  Command: storescu -aec JMIX_RECEIVER -aet TEST_SCU 127.0.0.1 $HARMONY_DICOM_PORT <files>"
        
        # Find a DICOM file to send
        DICOM_FILE=$(find "$SAMPLE_DIR" -name "*.dcm" -type f 2>/dev/null | head -1)
        
        if [ ! -z "$DICOM_FILE" ]; then
            echo "  Sending: $DICOM_FILE"
            if storescu -aec JMIX_RECEIVER -aet TEST_SCU 127.0.0.1 $HARMONY_DICOM_PORT "$DICOM_FILE" 2>/dev/null; then
                echo -e "${GREEN}  C-STORE successful - DICOM image sent${NC}"
                
                # Wait for JMIX processing
                sleep 2
                
                # Check if mock server received envelope
                STATS=$(curl -s "http://127.0.0.1:$MOCK_JMIX_PORT/api/jmix/stats" 2>/dev/null || echo "{}")
                if echo "$STATS" | grep -q '"envelope_count"'; then
                    COUNT=$(echo "$STATS" | grep -o '"envelope_count"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
                    if [ "$COUNT" -gt 0 ]; then
                        echo -e "${GREEN}  JMIX envelope created and forwarded to upstream!${NC}"
                        echo "  Mock server received $COUNT envelope(s)"
                    fi
                fi
            else
                echo -e "${YELLOW}  C-STORE failed - check Harmony logs${NC}"
            fi
        else
            echo -e "${YELLOW}  No DICOM files found in $SAMPLE_DIR${NC}"
        fi
    else
        echo -e "${YELLOW}  No sample DICOM directory found${NC}"
        echo "  To test C-STORE, provide DICOM files:"
        echo "    storescu -aec JMIX_RECEIVER -aet YOUR_AET 127.0.0.1 $HARMONY_DICOM_PORT /path/to/file.dcm"
    fi
    echo ""
fi

# Test 4: Check mock JMIX server stats
echo -e "${YELLOW}Test 4: Check upstream JMIX server (mock)${NC}"
STATS=$(curl -s "http://127.0.0.1:$MOCK_JMIX_PORT/api/jmix/stats" 2>/dev/null || echo '{"error": "failed"}')
echo "  Mock server stats: $STATS"
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "DICOM to JMIX Pipeline:"
echo "  DICOM Listener:  127.0.0.1:$HARMONY_DICOM_PORT (AE: JMIX_RECEIVER)"
echo "  HTTP Query:      http://127.0.0.1:$HARMONY_HTTP_PORT/jmix/api/jmix"
echo "  Upstream JMIX:   http://127.0.0.1:$MOCK_JMIX_PORT (mock server)"
echo ""
echo "Data Flow:"
echo "  1. DICOM modality sends images via C-STORE"
echo "  2. Harmony receives and stores DICOM files"
echo "  3. jmix_builder middleware packages into JMIX envelope"
echo "  4. jmix_backend forwards envelope to upstream server"
echo ""
if [ "$HAS_DCMTK" = true ]; then
    echo "To send DICOM images manually:"
    echo "  storescu -aec JMIX_RECEIVER -aet YOUR_AET \\"
    echo "    127.0.0.1 $HARMONY_DICOM_PORT /path/to/dicom/files/"
    echo ""
fi
echo "Logs available at:"
echo "  Harmony:   $TMP_DIR/harmony.log"
echo "  Mock JMIX: $TMP_DIR/mock_jmix.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
