#!/bin/bash
# DICOM Backend Demo Script
# Demonstrates HTTP to DICOM operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=8085
ORTHANC_DICOM_PORT=4242
ORTHANC_HTTP_PORT=8042
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== DICOM Backend Demo ===${NC}"
echo "This script demonstrates triggering DICOM operations via HTTP"
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

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found. Please install jq.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker not found. Please install Docker:${NC}"
    echo "  macOS: https://docs.docker.com/desktop/install/mac-install/"
    echo "  Linux: https://docs.docker.com/engine/install/"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"
echo ""

# Setup directories
echo -e "${YELLOW}Setting up test environment...${NC}"
mkdir -p "$TMP_DIR"
echo -e "${GREEN}✓ Test environment ready${NC}"
echo ""

# Setup Orthanc Docker container
echo -e "${YELLOW}Setting up Orthanc Docker container...${NC}"

# Stop and remove any existing Orthanc container
docker rm -f harmony-dicom-backend-orthanc 2>/dev/null || true

# Start Orthanc in Docker
echo -e "${YELLOW}Starting Orthanc on DICOM port $ORTHANC_DICOM_PORT, HTTP port $ORTHANC_HTTP_PORT...${NC}"
docker run -d \
  --name harmony-dicom-backend-orthanc \
  -p $ORTHANC_DICOM_PORT:4242 \
  -p $ORTHANC_HTTP_PORT:8042 \
  -e ORTHANC__DICOM_AET="ORTHANC" \
  -e ORTHANC__OVERWRITE_INSTANCES=true \
  orthancteam/orthanc:latest > "$TMP_DIR/orthanc_container.log" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Orthanc Docker container started${NC}"
else
    echo -e "${RED}Error: Failed to start Orthanc container${NC}"
    exit 1
fi

# Wait for Orthanc to be ready
echo -e "${YELLOW}Waiting for Orthanc to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$ORTHANC_HTTP_PORT/system > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Orthanc is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Orthanc did not start in time${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# Initialize test status tracking
# Use simple variables instead of associative arrays for shell compatibility
TEST_STATUS_echo=""
TEST_STATUS_find=""
TEST_STATUS_get=""
TEST_STATUS_store=""

# Fetch study data from Orthanc for realistic demo
echo -e "${YELLOW}Fetching study data from Orthanc...${NC}"
ORTHANC_STUDIES=$(curl -s -u orthanc:orthanc http://localhost:8042/studies 2>/dev/null)
if [ -n "$ORTHANC_STUDIES" ] && [ "$ORTHANC_STUDIES" != "[]" ]; then
    FIRST_STUDY_ID=$(echo "$ORTHANC_STUDIES" | jq -r '.[0]' 2>/dev/null)
    if [ -n "$FIRST_STUDY_ID" ] && [ "$FIRST_STUDY_ID" != "null" ]; then
        STUDY_INFO=$(curl -s -u orthanc:orthanc "http://localhost:8042/studies/$FIRST_STUDY_ID" 2>/dev/null)
        STUDY_UID=$(echo "$STUDY_INFO" | jq -r '.MainDicomTags.StudyInstanceUID' 2>/dev/null)
        PATIENT_ID=$(echo "$STUDY_INFO" | jq -r '.PatientMainDicomTags.PatientID' 2>/dev/null)
        PATIENT_NAME=$(echo "$STUDY_INFO" | jq -r '.PatientMainDicomTags.PatientName' 2>/dev/null)
        echo -e "${GREEN}✓ Found study data from Orthanc${NC}"
        echo "  PatientID: $PATIENT_ID"
        echo "  PatientName: $PATIENT_NAME"
        echo "  StudyInstanceUID: $STUDY_UID"
    else
        echo -e "${YELLOW}⚠ Could not parse Orthanc response, using defaults${NC}"
        STUDY_UID="1.2.3.4.5.6"
        PATIENT_ID="*"
    fi
else
    echo -e "${YELLOW}⚠ Orthanc not available or empty, using defaults${NC}"
    STUDY_UID="1.2.3.4.5.6"
    PATIENT_ID="*"
fi
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
    
    # Stop Orthanc Docker container
    if docker ps -q -f name=harmony-dicom-backend-orthanc | grep -q .; then
        echo "  Stopping Orthanc Docker container..."
        docker stop harmony-dicom-backend-orthanc > /dev/null 2>&1
        docker rm harmony-dicom-backend-orthanc > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Build Harmony (already installed)
echo -e "${YELLOW}Harmony already available${NC}"
echo ""

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony DICOM backend service on port $HARMONY_PORT...${NC}"
cd "$SCRIPT_DIR"
harmony --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$HARMONY_PORT/echo > /dev/null 2>&1; then
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

# Test 1: C-FIND operation
echo -e "${YELLOW}Test 1: Trigger C-FIND operation${NC}"
# Query identifier in DICOM JSON format
CFIND_REQUEST='{
  "00100020": {"vr": "LO", "Value": ["*"]},
  "0020000D": {"vr": "UI", "Value": []}
}'
echo "  Command: curl -X POST http://127.0.0.1:$HARMONY_PORT/find"
echo "  Payload: C-FIND request for all studies"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/find \
    -H "Content-Type: application/json" \
    -d "$CFIND_REQUEST")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ C-FIND operation successful (HTTP $HTTP_CODE)${NC}"
    echo "  Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    TEST_STATUS_find="✓"
else
    echo -e "${YELLOW}  ⚠ C-FIND operation returned HTTP $HTTP_CODE${NC}"
    echo "  Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    TEST_STATUS_find="✗"
fi
echo ""

# Test 2: C-FIND with specific patient
echo -e "${YELLOW}Test 2: C-FIND for specific patient${NC}"
# Query identifier in DICOM JSON format
CFIND_PATIENT="{
  \"00100020\": {\"vr\": \"LO\", \"Value\": [\"$PATIENT_ID\"]},
  \"00100010\": {\"vr\": \"PN\", \"Value\": []}
}"
echo "  Command: curl -X POST http://127.0.0.1:$HARMONY_PORT/find (PatientID=$PATIENT_ID)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/find \
    -H "Content-Type: application/json" \
    -d "$CFIND_PATIENT")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Patient-level C-FIND successful (HTTP $HTTP_CODE)${NC}"
    echo "  Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
else
    echo -e "${YELLOW}  ⚠ Patient-level C-FIND returned HTTP $HTTP_CODE${NC}"
    echo "  Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
fi
echo ""

# Test 3: C-GET operation (retrieves images over the same association)
echo -e "${YELLOW}Test 3: Trigger C-GET operation${NC}"
# Query identifier in DICOM JSON format
CGET_REQUEST="{
  \"0020000D\": {\"vr\": \"UI\", \"Value\": [\"$STUDY_UID\"]}
}"
echo "  Command: curl -X POST http://127.0.0.1:$HARMONY_PORT/get (StudyInstanceUID=$STUDY_UID)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/get \
    -H "Content-Type: application/json" \
    -d "$CGET_REQUEST")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
    echo -e "${GREEN}  ✓ C-GET operation successful (HTTP $HTTP_CODE)${NC}"
    # Show summary without pixel data
    INSTANCE_COUNT=$(echo "$BODY" | jq '.file_count // .instances | length' 2>/dev/null || echo "?")
    FOLDER_PATH=$(echo "$BODY" | jq -r '.folder_path // "N/A"' 2>/dev/null || echo "N/A")
    echo "  Retrieved $INSTANCE_COUNT instance(s)"
    echo "  Stored to: $FOLDER_PATH"
    CGET_FOLDER_PATH="$FOLDER_PATH"
    TEST_STATUS_get="✓"
else
    echo -e "${YELLOW}  ⚠ C-GET operation returned HTTP $HTTP_CODE${NC}"
    # Show error summary
    echo "$BODY" | jq '{operation, success, error}' 2>/dev/null || echo "$BODY"
    CGET_FOLDER_PATH=""
    TEST_STATUS_get="✗"
fi
echo ""

# Test 4: C-STORE operation (send a DICOM file to PACS)
echo -e "${YELLOW}Test 4: Trigger C-STORE operation${NC}"
if [ -n "$CGET_FOLDER_PATH" ] && [ -d "$CGET_FOLDER_PATH" ]; then
    # Find a .dcm file from the C-GET results
    DICOM_FILE=$(find "$CGET_FOLDER_PATH" -name "*.dcm" -type f 2>/dev/null | head -1)
    if [ -n "$DICOM_FILE" ]; then
        echo "  Command: curl -X POST http://127.0.0.1:$HARMONY_PORT/store (file: $(basename "$DICOM_FILE"))"
        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/store \
            -H "Content-Type: application/dicom" \
            --data-binary @"$DICOM_FILE")
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | sed '$d')

        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}  ✓ C-STORE operation successful (HTTP $HTTP_CODE)${NC}"
            echo "  Response:"
            echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
            TEST_STATUS_store="✓"
        else
            echo -e "${YELLOW}  ⚠ C-STORE operation returned HTTP $HTTP_CODE${NC}"
            echo "  Response:"
            echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
            TEST_STATUS_store="✗"
        fi
    else
        echo -e "${YELLOW}  ⚠ No DICOM files found from C-GET to use for C-STORE test${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Skipping C-STORE test (no files from C-GET)${NC}"
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Harmony DICOM SCU Capabilities:"
echo "  ${TEST_STATUS_find:-⚪} C-FIND  - Query working"
echo "  ${TEST_STATUS_get:-⚪} C-GET   - Retrieve working"
echo "  ${TEST_STATUS_store:-⚪} C-STORE - Store working"
echo ""
echo "Configuration:"
echo "  DICOM Backend: Orthanc (localhost:4242)"
echo "  Local AE:      HARMONY_SCU"
echo "  Remote AE:     ORTHANC"
echo ""
echo "To test with real DICOM PACS:"
echo "  1. Start Orthanc: docker run -p 4242:4242 -p 8042:8042 orthancteam/orthanc"
echo "  2. Upload DICOM studies to Orthanc"
echo "  3. Trigger operations via HTTP POST to /trigger-dicom"
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
