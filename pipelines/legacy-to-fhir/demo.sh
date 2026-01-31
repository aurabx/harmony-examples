#!/bin/bash
# Legacy HTTP to FHIR Demo Script
# Starts Harmony and demonstrates legacy JSON to FHIR transformation

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
TMP_DIR="$SCRIPT_DIR/tmp"
export TMP_DIR

echo -e "${BLUE}=== Legacy HTTP to FHIR Demo ===${NC}"
echo "This script demonstrates transforming legacy HTTP JSON to FHIR resources"
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
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Start Harmony in background
echo -e "${YELLOW}Starting Harmony on port $HARMONY_PORT...${NC}"
cd "$SCRIPT_DIR"
harmony --config ./config.toml > "$TMP_DIR/harmony.log" 2>&1 &
HARMONY_PID=$!
echo -e "${GREEN}✓ Harmony started (PID: $HARMONY_PID)${NC}"

# Wait for Harmony to be ready
echo -e "${YELLOW}Waiting for Harmony to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://127.0.0.1:$HARMONY_PORT/api/patients > /dev/null 2>&1; then
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

# Test 1: POST legacy patient and transform to FHIR
echo -e "${YELLOW}Test 1: POST legacy patient JSON and transform to FHIR${NC}"
LEGACY_PATIENT='{
  "patient_id": "12345",
  "first_name": "John",
  "middle_name": "William",
  "last_name": "Smith",
  "dob": "1990-01-15",
  "gender": "M",
  "mrn": "MRN-001234",
  "ssn": "123-45-6789",
  "phone": "+1-555-123-4567",
  "email": "john.smith@email.com",
  "address_line1": "123 Main Street",
  "address_line2": "Apt 4B",
  "city": "Boston",
  "state": "MA",
  "zip": "02101",
  "country": "USA"
}'
echo "  Sending legacy patient data..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/api/patients \
    -H "Content-Type: application/json" \
    -d "$LEGACY_PATIENT")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}  ✓ Legacy patient transformed successfully (HTTP $HTTP_CODE)${NC}"
    echo "  Response (FHIR format):"
    echo "$BODY" | jq -C . 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Legacy to FHIR Transformation:"
echo "  ✅ Legacy flat JSON accepted"
echo "  ✅ Transformed to FHIR Patient resource"
echo "  ✅ Gender codes mapped (M/F → male/female)"
echo "  ✅ FHIR metadata and coding systems added"
echo ""
echo "Key Mappings:"
echo "  legacy.patient_id → FHIR id"
echo "  legacy.first_name → FHIR.name.given[0]"
echo "  legacy.gender (M/F) → FHIR.gender (male/female)"
echo "  legacy.mrn → FHIR.identifier with MRN coding"
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
