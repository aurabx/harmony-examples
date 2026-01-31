#!/bin/bash
# Webhook to FHIR Demo Script
# Starts Harmony and demonstrates webhook to FHIR transformation

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

echo -e "${BLUE}=== Webhook to FHIR Demo ===${NC}"
echo "This script demonstrates transforming webhooks to FHIR resources"
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
    if curl -s http://127.0.0.1:$HARMONY_PORT/webhooks/patient > /dev/null 2>&1; then
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

# Test 1: Patient registration webhook
echo -e "${YELLOW}Test 1: Patient registration webhook → FHIR Patient${NC}"
WEBHOOK_PATIENT='{
  "event": "patient.created",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "id": "ext-12345",
    "first_name": "John",
    "last_name": "Smith",
    "email": "john.smith@example.com",
    "phone": "+1-555-123-4567",
    "dob": "1990-01-15",
    "gender": "male"
  }
}'
echo "  Sending patient registration webhook..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/webhooks/patient \
    -H "Content-Type: application/json" \
    -H "X-Webhook-Event: patient.created" \
    -d "$WEBHOOK_PATIENT")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}  ✓ Patient webhook transformed (HTTP $HTTP_CODE)${NC}"
    echo "  Response:"
    echo "$BODY" | jq -C . 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 2: Appointment webhook
echo -e "${YELLOW}Test 2: Appointment webhook → FHIR Appointment${NC}"
WEBHOOK_APPOINTMENT='{
  "event": "appointment.booked",
  "data": {
    "id": "apt-67890",
    "patient_id": "12345",
    "practitioner_id": "dr-001",
    "start_time": "2024-01-20T09:00:00Z",
    "end_time": "2024-01-20T09:30:00Z",
    "duration": 30,
    "type": "General Consultation",
    "status": "booked"
  }
}'
echo "  Sending appointment webhook..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/webhooks/appointment \
    -H "Content-Type: application/json" \
    -d "$WEBHOOK_APPOINTMENT")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}  ✓ Appointment webhook transformed (HTTP $HTTP_CODE)${NC}"
    echo "  Response:"
    echo "$BODY" | jq -C . 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

# Test 3: Lab result webhook
echo -e "${YELLOW}Test 3: Lab result webhook → FHIR Observation${NC}"
WEBHOOK_LAB='{
  "event": "lab.result.ready",
  "data": {
    "id": "lab-99999",
    "patient_id": "12345",
    "test_code": "2339-0",
    "test_name": "Glucose [Mass/volume] in Blood",
    "value": 95,
    "unit": "mg/dL",
    "reference_range_low": 70,
    "reference_range_high": 100,
    "status": "final",
    "interpretation": "N",
    "collected_at": "2024-01-15T08:00:00Z",
    "issued": "2024-01-15T14:30:00Z",
    "lab_id": "lab-acme"
  }
}'
echo "  Sending lab result webhook..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:$HARMONY_PORT/webhooks/lab \
    -H "Content-Type: application/json" \
    -d "$WEBHOOK_LAB")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}  ✓ Lab webhook transformed (HTTP $HTTP_CODE)${NC}"
    echo "  Response:"
    echo "$BODY" | jq -C . 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}  ✗ Request failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
fi
echo ""

echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Webhook to FHIR Transformation:"
echo "  ✅ Patient webhooks → FHIR Patient"
echo "  ✅ Appointment webhooks → FHIR Appointment"
echo "  ✅ Lab result webhooks → FHIR Observation"
echo "  ✅ Flexible field mapping for various webhook formats"
echo ""
echo "Supported Endpoints:"
echo "  /webhooks/patient     → FHIR Patient"
echo "  /webhooks/appointment → FHIR Appointment"
echo "  /webhooks/lab         → FHIR Observation"
echo ""
echo "Logs available at:"
echo "  Harmony: $TMP_DIR/harmony.log"
echo ""
echo -e "${GREEN}Demo complete!${NC}"
echo ""
echo "Press Enter to stop services and exit..."
read
