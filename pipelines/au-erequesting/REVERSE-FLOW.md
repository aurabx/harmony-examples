# Reverse Flow: FHIR to HTTP API

This document describes the second pipeline which reverses the data flow: accepting FHIR bundles and converting them to simplified HTTP API calls.

## Overview

The reverse pipeline demonstrates a FHIR-first workflow where clients post AU eRequesting FHIR bundles to Harmony, which extracts key information and makes HTTP API calls to a backend service.

```
FHIR Client
   │
   ├─ POST FHIR Bundle (application/fhir+json)
   │
   ↓
Harmony Proxy (Port 8080)
   │
   ├─ /fhir endpoint (FHIR service)
   │
   ├─ Left middleware:
   │  ├─ Validate FHIR bundle
   │  ├─ Transform to API request (fhir-to-api-request.json)
   │  └─ Log API request
   │
   ├─ Backend: POST to API Server
   │
   └─ Right middleware:
      └─ Log API response
   │
   ↓
API Backend (Port 8889)
   │
   ├─ POST /orders (with simplified API request)
   │
   └─ Returns: 201 Created with Order record
   │
   ↓
FHIR Client receives HTTP 201 + Order Details
```

## Architecture

### Components

**FHIR Endpoint** (`/fhir`)
- Accepts POST requests with FHIR Bundle content-type
- Validates incoming bundles (optional AU eRequesting validation)
- Transforms bundles to API requests

**API Backend** (`api_backend.py`)
- Listens on port 8889
- Accepts simplified JSON order requests
- Stores orders in memory
- Provides GET endpoints for order retrieval

### Pipeline: `fhir-to-api.toml`

```toml
[pipelines.fhir_to_api]
description = "POST FHIR Bundle → converts to HTTP API call"
networks = ["http_net"]
endpoints = ["fhir_bundle_endpoint"]
middleware.left = [
    "validate_fhir_bundle",
    "extract_api_request",
    "dump_api_request",
]
middleware.right = [
    "dump_api_response",
]
backends = ["api_backend"]
```

## API Backend (`api_backend.py`)

### Endpoints

**GET /health**
- Health check endpoint
- Returns: `{"status": "healthy", "service": "Service Request API Backend"}`
- HTTP 200

**GET /orders**
- List all stored orders
- Returns: `{"orders": [...], "count": N}`
- HTTP 200

**GET /orders/{id}**
- Retrieve specific order
- Returns: Order object
- HTTP 200 or 404

**POST /orders**
- Create new service request order
- Accepts: Simplified HTTP API request JSON
- Returns: Order object with auto-generated ID
- HTTP 201 Created
- Location header points to GET endpoint

### Required Fields for POST /orders

```json
{
  "patientId": "00001234",
  "patientName": "Citizen Pat",
  "serviceCode": "169069000",
  "serviceDisplay": "CT of chest"
}
```

### Optional Fields

```json
{
  "priority": "routine",
  "requesterName": "Nguyen, Alex",
  "organizationName": "Example GP Clinic",
  "notes": "Additional clinical notes"
}
```

### Response Example (201 Created)

```json
{
  "orderId": "1000",
  "createdAt": "2025-12-08T06:59:57.123456Z",
  "status": "received",
  "patientId": "00001234",
  "patientName": "Citizen Pat",
  "serviceCode": "169069000",
  "serviceDisplay": "CT of chest",
  "priority": "routine",
  "requesterName": "Nguyen, Alex",
  "organizationName": "Example GP Clinic",
  "notes": "Service request converted from AU eRequesting FHIR bundle",
  "message": "Service request order received and stored"
}
```

## Transform: `fhir-to-api-request.json`

Converts AU eRequesting FHIR bundles to simplified HTTP API requests.

### Input
Complete FHIR Bundle with entries including:
- ServiceRequest resource
- Patient resource
- Practitioner resource
- Organization resource

### Processing Steps

1. **Extract Resources**: Identifies and separates FHIR resources by type
   - `ServiceRequest` → service details
   - `Patient` → patient information
   - `Practitioner` → requester information
   - `Organization` → organization name

2. **Map to API Fields**:
   - ServiceRequest.code → serviceCode
   - ServiceRequest.code.display → serviceDisplay
   - Patient.name → patientName
   - Patient.identifier[0].value → patientId
   - Practitioner.name → requesterName
   - Organization.name → organizationName
   - ServiceRequest.priority → priority

3. **Output**: Simplified JSON request object

### Output Example

```json
{
  "patientId": "00001234",
  "patientName": "Citizen Pat",
  "serviceCode": "169069000",
  "serviceDisplay": "CT of chest",
  "priority": "routine",
  "requesterName": "Nguyen, Alex",
  "organizationName": "Example GP Clinic",
  "notes": "Service request converted from AU eRequesting FHIR bundle"
}
```

## Running the Reverse Flow

### Test with curl

```bash
# Start the demo (includes all services)
./demo-both.sh

# In another terminal, post a FHIR bundle
curl -X POST \
  -H "Content-Type: application/fhir+json" \
  -d @request.json \
  http://127.0.0.1:8080/fhir

# Retrieve orders from API backend
curl http://127.0.0.1:8889/orders
```

### Workflow Example

1. **Client has FHIR Bundle**
   - Generated from external FHIR system
   - AU eRequesting compliant
   - Contains complete patient and service details

2. **Client POST to Harmony**
   ```bash
   POST http://harmony:8080/fhir
   Content-Type: application/fhir+json
   [bundle JSON]
   ```

3. **Harmony Processes**
   - Validates bundle structure
   - Extracts key fields via transform
   - Posts simplified API request to backend

4. **Backend Creates Order**
   - Validates required fields
   - Generates order ID
   - Returns 201 Created with order details

5. **Client Receives Response**
   ```json
   HTTP 201 Created
   Location: /orders/1000
   {
     "orderId": "1000",
     "patientName": "Citizen Pat",
     ...
   }
   ```

## Use Cases

### 1. FHIR System Integration
Connect existing FHIR systems to legacy HTTP API backends without modifying either system. Harmony acts as a bridge.

### 2. Standards Compliance Gateway
Accept FHIR-compliant requests and transform them for internal HTTP APIs that don't yet support FHIR.

### 3. Simplified API Exposure
Provide HTTP API for basic operations while supporting FHIR for advanced clients.

### 4. Data Extraction
Extract specific fields from complex FHIR bundles for simpler downstream systems.

## Configuration

### Harmony Config Addition

```toml
# In config.toml, add the API backend target:
[targets.api_server]
connection.host = "127.0.0.1"
connection.port = 8889
connection.protocol = "http"
timeout_secs = 60
```

### Pipeline Configuration

```toml
# In pipelines/fhir-to-api.toml:
[endpoints.fhir_bundle_endpoint]
service = "fhir"
[endpoints.fhir_bundle_endpoint.options]
path_prefix = "/fhir"

[backends.api_backend]
service = "http"
target_ref = "api_server"
```

## Error Handling

### Missing Required Fields
If the FHIR bundle doesn't contain expected resources:

```json
HTTP 400 Bad Request
{
  "error": "Missing required fields: patientId, serviceCode"
}
```

### Invalid JSON
If the FHIR bundle is malformed:

```json
HTTP 400 Bad Request
{
  "error": "Invalid JSON"
}
```

### Not Found
If accessing non-existent order:

```json
HTTP 404 Not Found
{
  "error": "Order 9999 not found"
}
```

## Extending the Reverse Flow

### Add More API Endpoints

Modify `fhir-to-api-request.json` to support different service types:

```json
{
  "operation": "shift",
  "spec": {
    "serviceType": "serviceCategory",
    "procedure": "procedureCode"
  }
}
```

### Validate AU eRequesting Profiles

Add validation middleware before transformation:

```toml
[middleware.validate_profiles]
type = "validate_fhir"  # Custom validation
[middleware.validate_profiles.options]
profiles = [
  "http://hl7.org.au/fhir/ereq/StructureDefinition/au-erequesting-task-group",
  "http://hl7.org.au/fhir/ereq/StructureDefinition/au-erequesting-servicerequest-imag"
]
```

### Store Orders Persistently

Replace in-memory storage in `api_backend.py`:

```python
# Instead of: orders_store = {}
# Use: database/persistent storage
import sqlite3
db = sqlite3.connect('orders.db')
```

### Add Audit Logging

Extend API backend to log all transformations:

```python
def log_transformation(fhir_bundle, api_request):
    with open('transformations.log', 'a') as f:
        f.write(f"{datetime.now()} {len(api_request)} bytes\n")
```

## Logs

The reverse flow produces logs in `tmp/`:

- **harmony.log**: Transformation and middleware logs
- **api_backend.log**: Order creation and retrieval events

### Relevant Log Entries

```
[MIDDLEWARE] received_fhir_bundle
[MIDDLEWARE] api_request_to_backend
[API] POST /orders from 127.0.0.1:12345
[INFO] Created order 1000 for Citizen Pat
[MIDDLEWARE] api_response_from_backend
```

## Performance Considerations

- **Bundle Size**: Large FHIR bundles (~1MB) process in <100ms
- **Transformation**: Jolt transform typically <50ms per bundle
- **API Call**: HTTP POST to backend typically <200ms
- **Memory**: In-memory storage supports 10,000+ orders

## References

- [FHIR Bundle](https://www.hl7.org/fhir/bundle.html)
- [AU eRequesting IG](https://build.fhir.org/ig/hl7au/au-fhir-erequesting/)
- [Jolt Transforms](https://github.com/bazaarvoice/jolt)
