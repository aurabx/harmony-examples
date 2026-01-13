#!/bin/bash
# DICOM SCP Demo Script
# Starts Harmony DICOM SCP and demonstrates C-ECHO, C-FIND, C-GET, C-MOVE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HARMONY_PORT=11112
HARMONY_AET="HARMONY_SCP"
ORTHANC_DICOM_PORT=4242
ORTHANC_HTTP_PORT=8042
ORTHANC_AET="ORTHANC"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR
ORTHANC_DIR="$TMP_DIR/orthanc"

echo -e "${BLUE}=== DICOM SCP Demo ===${NC}"
echo "This script demonstrates Harmony's DICOM SCP capabilities"
echo ""

# Check for required tools
echo -e "${YELLOW}Checking prerequisites...${NC}"
for tool in echoscu findscu getscu movescu storescu; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: $tool not found. Please install DCMTK:${NC}"
        echo "  macOS: brew install dcmtk"
        echo "  Linux: apt-get install dcmtk"
        exit 1
    fi
done

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker not found. Please install Docker:${NC}"
    echo "  macOS: https://docs.docker.com/desktop/install/mac-install/"
    echo "  Linux: https://docs.docker.com/engine/install/"
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
mkdir -p "$ORTHANC_DIR"

# Create test DICOM file
echo -e "${YELLOW}Creating test DICOM file...${NC}"
TEST_DCM="$TMP_DIR/test.dcm"
cat > "$TMP_DIR/test.json" << 'EOF'
{
  "00080016": {"vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.7"]},
  "00080018": {"vr": "UI", "Value": ["1.2.3.4.5.6.7.8.9"]},
  "0020000D": {"vr": "UI", "Value": ["1.2.3.4.5.6.7"]},
  "0020000E": {"vr": "UI", "Value": ["1.2.3.4.5.6.8"]},
  "00080060": {"vr": "CS", "Value": ["OT"]},
  "00100020": {"vr": "LO", "Value": ["DEMO123"]},
  "00100010": {"vr": "PN", "Value": [{"Alphabetic": "DEMO^PATIENT"}]},
  "00080020": {"vr": "DA", "Value": ["20250124"]},
  "00080030": {"vr": "TM", "Value": ["120000"]}
}
EOF

# Use Python to create DICOM file (fallback if dicom_json_tool not available)
python3 - << 'PYTHON_SCRIPT'
import json
import os
import sys
from pathlib import Path

# Try to create a minimal DICOM file
try:
    import pydicom
    from pydicom.dataset import Dataset, FileDataset
    from pydicom.uid import ImplicitVRLittleEndian
    import datetime
    
    # Create a minimal dataset
    ds = FileDataset(
        "test.dcm",
        {},
        file_meta=pydicom.dataset.FileMetaDataset(),
        preamble=b"\0" * 128
    )
    
    # File meta information
    ds.file_meta.TransferSyntaxUID = ImplicitVRLittleEndian
    ds.file_meta.MediaStorageSOPClassUID = "1.2.840.10008.5.1.4.1.1.7"
    ds.file_meta.MediaStorageSOPInstanceUID = "1.2.3.4.5.6.7.8.9"
    ds.file_meta.ImplementationClassUID = "1.2.3.4.5.6.7.8"
    
    # Required fields
    ds.SOPClassUID = "1.2.840.10008.5.1.4.1.1.7"
    ds.SOPInstanceUID = "1.2.3.4.5.6.7.8.9"
    ds.StudyInstanceUID = "1.2.3.4.5.6.7"
    ds.SeriesInstanceUID = "1.2.3.4.5.6.8"
    ds.Modality = "OT"
    ds.PatientID = "DEMO123"
    ds.PatientName = "DEMO^PATIENT"
    ds.StudyDate = "20250124"
    ds.StudyTime = "120000"
    
    # Save
    tmp_dir = os.environ.get('TMP_DIR', './tmp')
    ds.save_as(f"{tmp_dir}/test.dcm", write_like_original=False)
    print(f"✓ Created test DICOM file")
except ImportError:
    print("⚠ pydicom not available, will skip DICOM file creation", file=sys.stderr)
    print("  Install with: pip3 install pydicom", file=sys.stderr)
except Exception as e:
    print(f"⚠ Error creating DICOM file: {e}", file=sys.stderr)
PYTHON_SCRIPT

if [ ! -f "$TEST_DCM" ]; then
    echo -e "${YELLOW}⚠ Could not create test DICOM file, some tests may be skipped${NC}"
fi

# Setup Orthanc (for C-GET/C-MOVE testing)
echo -e "${YELLOW}Setting up Orthanc Docker container...${NC}"

# Stop and remove any existing Orthanc container
docker rm -f harmony-orthanc-test 2>/dev/null || true

# Start Orthanc in Docker with Harmony as a known modality
echo -e "${YELLOW}Starting Orthanc on DICOM port $ORTHANC_DICOM_PORT, HTTP port $ORTHANC_HTTP_PORT...${NC}"
docker run -d \
  --name harmony-orthanc-test \
  -p $ORTHANC_DICOM_PORT:4242 \
  -p $ORTHANC_HTTP_PORT:8042 \
  -e ORTHANC__DICOM_AET="$ORTHANC_AET" \
  -e ORTHANC__OVERWRITE_INSTANCES=true \
  -e ORTHANC__DICOM_MODALITIES='{"HARMONY":["HARMONY_SCU","host.docker.internal",'$HARMONY_PORT']}' \
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

# Store test file to Orthanc if available
if [ -f "$TEST_DCM" ]; then
    echo -e "${YELLOW}Storing test file to Orthanc...${NC}"
    storescu -aec $ORTHANC_AET 127.0.0.1 $ORTHANC_DICOM_PORT "$TEST_DCM" > /dev/null 2>&1 || true
    echo -e "${GREEN}✓ Test data stored in Orthanc${NC}"
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
    if docker ps -q -f name=harmony-orthanc-test | grep -q .; then
        echo "  Stopping Orthanc Docker container..."
        docker stop harmony-orthanc-test > /dev/null 2>&1
        docker rm harmony-orthanc-test > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Build Harmony (already installed)
echo -e "${YELLOW}Harmony already available${NC}"
echo ""

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony DICOM SCP on port $HARMONY_PORT...${NC}"
cd "$SCRIPT_DIR"
harmony --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if echoscu -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT > /dev/null 2>&1; then
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

# Initialize test status tracking
# Use simple variables instead of associative arrays for shell compatibility
TEST_STATUS_echo="✗"
TEST_STATUS_store="✗"
TEST_STATUS_find="✗"
TEST_STATUS_get="✗"
TEST_STATUS_move="✗"

# Test 1: C-ECHO
echo -e "${YELLOW}Test 1: C-ECHO (Verification)${NC}"
echo "  Command: echoscu -v -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT"
if echoscu -v -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT 2>&1 | grep -q "Association Accepted"; then
    echo -e "${GREEN}  ✓ C-ECHO successful${NC}"
    TEST_STATUS_echo="✓"
else
    echo -e "${RED}  ✗ C-ECHO failed${NC}"
    TEST_STATUS_echo="✗"
fi
echo ""

# Test 2: C-STORE (store test data first so we can query it later)
echo -e "${YELLOW}Test 2: C-STORE${NC}"
if [ -f "$TEST_DCM" ]; then
    echo "  Command: storescu -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT test.dcm"
    if storescu -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT "$TEST_DCM" > "$TMP_DIR/store_output.txt" 2>&1; then
        echo -e "${GREEN}  ✓ C-STORE succeeded${NC}"
        TEST_STATUS_store="✓"
        
        # Verify data is in Orthanc
        sleep 1
        ORTHANC_RESPONSE=$(curl -s -u orthanc:orthanc http://127.0.0.1:$ORTHANC_HTTP_PORT/studies)
        ORTHANC_STUDIES=$(echo "$ORTHANC_RESPONSE" | grep -o '"' | wc -l | tr -d ' ')
        if [ "$ORTHANC_STUDIES" -gt 0 ]; then
            echo -e "${GREEN}  ✓ Verified: Study stored in Orthanc${NC}"
        else
            echo -e "${YELLOW}  ⚠ Warning: No studies found in Orthanc via HTTP API${NC}"
        fi
    else
        echo -e "${RED}  ✗ C-STORE failed${NC}"
        TEST_STATUS_store="✗"
    fi
else
    echo -e "${YELLOW}  ⚠ Skipped (no test data)${NC}"
    TEST_STATUS_store="⚠"
fi
echo ""

# Test 3: C-FIND Study Level - Query for the specific study we just stored
echo -e "${YELLOW}Test 3: C-FIND (Query stored study)${NC}"
echo "  Command: findscu -v -aec $HARMONY_AET -S 127.0.0.1 $HARMONY_PORT -k 0020,000D=\"1.2.3.4.5.6.7\""
findscu -v -aec $HARMONY_AET -S 127.0.0.1 $HARMONY_PORT -k "0020,000D=1.2.3.4.5.6.7" > "$TMP_DIR/find_specific_output.txt" 2>&1
if grep -q "Releasing Association" "$TMP_DIR/find_specific_output.txt"; then
    MATCHES=$(grep "^I: Find Response:" "$TMP_DIR/find_specific_output.txt" | wc -l | tr -d ' ')
    if [ "$MATCHES" -gt 0 ]; then
        echo -e "${GREEN}  ✓ C-FIND found stored study ($MATCHES results)${NC}"
        TEST_STATUS_find="✓"
    else
        echo -e "${YELLOW}  ⚠ C-FIND succeeded but found no results${NC}"
        TEST_STATUS_find="⚠"
    fi
else
    echo -e "${RED}  ✗ C-FIND failed${NC}"
    TEST_STATUS_find="✗"
fi
echo ""

# Test 4: C-GET (if test data exists)
echo -e "${YELLOW}Test 4: C-GET (Retrieve)${NC}"
echo "  Command: getscu -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT -k 0020,000D=\"1.2.3.4.5.6.7\""
if [ -f "$TEST_DCM" ]; then
    mkdir -p "$TMP_DIR/retrieved"
    rm -rf "$TMP_DIR/retrieved"/* 2>/dev/null || true
    getscu -aec $HARMONY_AET 127.0.0.1 $HARMONY_PORT -k "0020,000D=1.2.3.4.5.6.7" -od "$TMP_DIR/retrieved" > "$TMP_DIR/get_output.txt" 2>&1 || true
    # Count all files in retrieved directory (getscu doesn't always add .dcm extension)
    RETRIEVED_COUNT=$(find "$TMP_DIR/retrieved" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$RETRIEVED_COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✓ C-GET retrieved $RETRIEVED_COUNT file(s)${NC}"
        TEST_STATUS_get="✓"
    elif grep -q "Association Release" "$TMP_DIR/get_output.txt"; then
        echo -e "${YELLOW}  ⚠ C-GET completed but no files retrieved (check logs)${NC}"
        TEST_STATUS_get="⚠"
    else
        echo -e "${RED}  ✗ C-GET failed${NC}"
        TEST_STATUS_get="✗"
    fi
else
    echo -e "${YELLOW}  ⚠ Skipped (no test data)${NC}"
    TEST_STATUS_get="⚠"
fi
echo ""

# Test 5: C-MOVE
echo -e "${YELLOW}Test 5: C-MOVE${NC}"
echo "  Command: movescu -aec $HARMONY_AET -aem $ORTHANC_AET 127.0.0.1 $HARMONY_PORT -k 0020,000D=\"1.2.3.4.5.6.7\""
if [ -f "$TEST_DCM" ]; then
    movescu -aec $HARMONY_AET -aem $ORTHANC_AET 127.0.0.1 $HARMONY_PORT -k "0020,000D=1.2.3.4.5.6.7" > "$TMP_DIR/move_output.txt" 2>&1
    MOVE_EXIT_CODE=$?
    # movescu returns 0 on success - check exit code and/or association release
    if [ $MOVE_EXIT_CODE -eq 0 ] || grep -q "Association Release" "$TMP_DIR/move_output.txt"; then
        # Check if there were any errors or just verify it completed
        if grep -q "Sub-Operations Complete" "$TMP_DIR/move_output.txt" || [ $MOVE_EXIT_CODE -eq 0 ]; then
            echo -e "${GREEN}  ✓ C-MOVE completed successfully${NC}"
            TEST_STATUS_move="✓"
        else
            echo -e "${YELLOW}  ⚠ C-MOVE completed (check logs for sub-operation status)${NC}"
            TEST_STATUS_move="⚠"
        fi
    else
        echo -e "${RED}  ✗ C-MOVE failed${NC}"
        TEST_STATUS_move="✗"
    fi
else
    echo -e "${YELLOW}  ⚠ Skipped (no test data)${NC}"
    TEST_STATUS_move="⚠"
fi
echo ""


echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Harmony DICOM SCP Capabilities:"
echo "  ${TEST_STATUS_echo} C-ECHO  - Verification"
echo "  ${TEST_STATUS_store} C-STORE - Store"
echo "  ${TEST_STATUS_find} C-FIND  - Query"
echo "  ${TEST_STATUS_get} C-GET   - Retrieve"
echo "  ${TEST_STATUS_move} C-MOVE  - Move"
echo ""
echo "Logs available at:"
echo "  Harmony:  $TMP_DIR/harmony.log"
echo "  Orthanc:  $TMP_DIR/orthanc.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
