# Manual Setup: AU eRequesting FHIR Example

This guide walks you through running everything manually in separate terminal windows, giving you full control and visibility into each component.

## Quick Start with Scripts

If you want everything automated, just run:

```bash
./demo-forward.sh          # Forward flow only (HTTP→FHIR→HTTP)
./demo-bidirectional.sh    # Full integration with both flows
```

But keep reading for the full manual setup!

## Manual Setup (Recommended for Development)

Open 3-4 terminal windows and follow the steps below.

### Terminal 1: Start FHIR Server

Start the FHIR backend service on port 8888:

```bash
cd /Users/xtfer/working/runbeam/runbeam-workspace/projects/harmony-examples/pipelines/au-erequesting
python3 fhir-server.py 8888
```

You should see:
```
[INFO] FHIR Server starting on 127.0.0.1:8888
[INFO] Health check: GET http://127.0.0.1:8888/health
[INFO] Bundle endpoint: POST http://127.0.0.1:8888/
```

Test it's working:
```bash
curl http://127.0.0.1:8888/health | jq
```

Should return:
```json
{
  "status": "healthy",
  "service": "AU eRequesting FHIR Server"
}
```

### Terminal 2 (Optional): Start HTTP Server

For bidirectional integration, start the HTTP API backend on port 8889:

```bash
python3 http-server.py 8889
```

You should see:
```
[INFO] Service Request API Backend starting on 127.0.0.1:8889
[INFO] Health check: GET http://127.0.0.1:8889/health
[INFO] List orders: GET http://127.0.0.1:8889/orders
[INFO] Create order: POST http://127.0.0.1:8889/orders
```

Test it's working:
```bash
curl http://127.0.0.1:8889/health | jq
```

### Terminal 3: Start Harmony Proxy

Start Harmony to run the transformation pipelines on port 8080:

```bash
harmony --config ./config.toml
```

You should see:
```
[INFO] Starting Harmony proxy on port 8080...
[INFO] Harmony is ready
```

It will run two active pipelines:
1. **http-to-fhir**: HTTP→FHIR→HTTP flow
2. **fhir-to-fhir**: FHIR→FHIR pass-through

### Terminal 4: Test the Endpoints

Once all services are running, test them:

#### Direct Backend Requests (No Transformation)

These show the raw untransformed responses from the backend servers:

**FHIR Server - Health Check**:
```bash
curl -s http://127.0.0.1:8888/health | jq
```
Response:
```json
{
  "status": "healthy",
  "service": "AU eRequesting FHIR Server"
}
```

**FHIR Server - Get FHIR Bundle (raw)**:

Note: The FHIR server always returns the same bundle (`request.json`) regardless of what you POST. This simulates a real FHIR server that would process transactions. You can POST anything:

```bash
curl -s -X POST \
  -H "Content-Type: application/fhir+json" \
  -d '{"resourceType":"Bundle"}' \
  http://127.0.0.1:8888/ | jq . | head -30
```

Or with a full bundle:
```bash
curl -s -X POST \
  -H "Content-Type: application/fhir+json" \
  -d @request.json \
  http://127.0.0.1:8888/ | jq . | head -30
```

Response: Raw FHIR Bundle (Task, ServiceRequest, Patient, etc.) - first 30 lines (same either way)

**HTTP Server - Health Check** (if running):
```bash
curl -s http://127.0.0.1:8889/health | jq
```
Response:
```json
{
  "status": "healthy",
  "service": "Service Request API Backend"
}
```

**HTTP Server - List Orders** (if running):
```bash
curl -s http://127.0.0.1:8889/orders | jq
```
Response:
```json
{
  "orders": [],
  "count": 0
}
```

#### Test Forward Flow Through Harmony (HTTP→FHIR→HTTP)

This request goes through Harmony's transformation pipeline:

```bash
curl -s 'http://127.0.0.1:8080/service-requests' | jq
```

Response (transformed from FHIR to simplified HTTP JSON):
```json
{
  "orderId": "PGN-123456",
  "patientName": "Citizen, Pat",
  "serviceCode": "169069000",
  "serviceDisplay": "CT of chest",
  "priority": "routine",
  "requesterName": "Nguyen, Alex",
  "organizationName": "Example GP Clinic",
  "status": "active",
  "authoredOn": "2025-12-07T10:00:00+11:00",
  "message": "Service request successfully processed through AU eRequesting FHIR server"
}
```

#### Test Reverse Flow Through Harmony (FHIR→FHIR)

This request sends FHIR to Harmony which passes it through to the FHIR server (no transformation):

```bash
curl -s -X POST \
  -H "Content-Type: application/fhir+json" \
  -d @request.json \
  'http://127.0.0.1:8080/fhir-bundle' | jq . | head -30
```

Response: FHIR Bundle (identical to what the FHIR server returns directly)

## Shutdown

When you're done testing, shut down the services (in reverse order):

```bash
# Terminal 4: Ctrl+C (or just close the terminal)

# Terminal 3: Ctrl+C to stop Harmony

# Terminal 2 (if running): Ctrl+C to stop HTTP server

# Terminal 1: Ctrl+C to stop FHIR server
```

## Understanding the Flows

### Forward Flow: HTTP → FHIR → HTTP

1. **Your HTTP Request**
   ```
   GET /service-requests?providerId=8003621566684455
   ```

2. **Harmony transforms to FHIR Bundle**
   - Task (group coordination)
   - Task (diagnostic request)
   - ServiceRequest (CT imaging)
   - Patient, Practitioner, Organization, Encounter

3. **Sent to FHIR Server**
   ```
   POST http://127.0.0.1:8888/
   Content-Type: application/fhir+json
   [bundle]
   ```

4. **Server Returns Response**
   - Same FHIR bundle structure

5. **Harmony transforms back to HTTP**
   ```json
   {
     "orderId": "PGN-123456",
     "patientName": "Citizen, Pat",
     "serviceCode": "169069000",
     "serviceDisplay": "CT of chest",
     "priority": "routine",
     "requesterName": "Nguyen, Alex",
     "organizationName": "Example GP Clinic",
     "status": "active",
     "authoredOn": "2025-12-07T10:00:00+11:00",
     "message": "Service request successfully processed..."
   }
   ```

### Reverse Flow: FHIR → FHIR

1. **Your FHIR Bundle Request**
   ```
   POST /fhir-bundle
   Content-Type: application/fhir+json
   [bundle from request.json]
   ```

2. **Harmony passes through to FHIR Server**
   ```
   POST http://127.0.0.1:8888/
   [same bundle]
   ```

3. **Server Returns FHIR Response**
   ```
   [FHIR Bundle response]
   ```

## File Structure

```
au-erequesting/
├── config.toml                      # Harmony configuration
├── fhir-server.py                   # FHIR backend (Python)
├── http-server.py                   # HTTP API backend (Python)
├── request.json                     # FHIR bundle (test data)
├── demo-forward.sh                  # Forward flow demo script
├── demo-bidirectional.sh            # Full integration demo
├── pipelines/
│   ├── http-to-fhir.toml            # Forward flow pipeline
│   └── fhir-to-fhir.toml            # FHIR pass-through pipeline
├── transforms/
│   ├── http-request-to-fhir.json    # HTTP → FHIR spec
│   └── fhir-response-to-http.json   # FHIR → HTTP spec
├── README.md                        # Full documentation
├── MANUAL.md                        # This file
├── BIDIRECTIONAL.md                 # Bidirectional flow details
└── REVERSE-FLOW.md                  # Reverse flow details
```

## Services Overview

### FHIR Server (fhir-server.py)
- Port: 8888
- Endpoints:
  - `GET /health` - Health check
  - `GET /*` - Respond with FHIR bundle (for queries)
  - `POST /` - Accept and respond to FHIR bundles
- Response: Returns `request.json` as FHIR response

### HTTP Server (http-server.py)
- Port: 8889 (optional, only needed for bidirectional demo)
- Endpoints:
  - `GET /health` - Health check
  - `GET /orders` - List all orders
  - `GET /orders/{id}` - Get specific order
  - `POST /orders` - Create new order

### Harmony Proxy
- Port: 8080
- Forward Flow Endpoint: `GET /service-requests?providerId={id}`
- Reverse Flow Endpoint: `POST /fhir-bundle`
- Configuration: `config.toml`
- Pipelines:
  - `pipelines/http-to-fhir.toml` (forward)
  - `pipelines/fhir-to-fhir.toml` (reverse)

## Viewing Logs

While services are running, check logs in separate terminals:

```bash
# Harmony logs (realtime)
tail -f tmp/harmony.log

# FHIR server logs (in its terminal window)
# HTTP server logs (in its terminal window)
```

## Key Features Demonstrated

✅ HTTP API for service requests  
✅ Transform to AU eRequesting FHIR bundles  
✅ Conformant profiles and coding systems  
✅ Multi-resource workflow (Task, ServiceRequest, etc.)  
✅ Transform response back to HTTP JSON  
✅ Extract key fields for client consumption  

## Next Steps

Read `README.md` for:
- Detailed architecture explanation
- Extending the example
- Troubleshooting
- References to FHIR specs
