# Quick Start: AU eRequesting FHIR Example

## One Command Setup

Run the complete demo:

```bash
cd /Users/xtfer/working/runbeam/runbeam-workspace/projects/harmony-examples/pipelines/au-erequesting
./demo.sh
```

This starts everything and runs tests automatically.

## What It Does

The demo script will:
1. ✅ Start a Python FHIR server on port 8888
2. ✅ Build Harmony
3. ✅ Start Harmony proxy on port 8080
4. ✅ Run sample HTTP requests
5. ✅ Show the transformed FHIR and responses
6. ✅ Clean up on exit

## Try It Manually

Once the demo is running, you can test with curl in another terminal:

```bash
# Simple request
curl 'http://127.0.0.1:8080/service-requests?providerId=8003621566684455'

# Pretty-printed
curl -s 'http://127.0.0.1:8080/service-requests?providerId=8003621566684455' | jq .data
```

## What Happens

1. **Your HTTP Request**
   ```
   GET /service-requests?providerId=8003621566684455
   ```

2. **Transforms to FHIR Bundle**
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

5. **Transforms Back to HTTP**
   ```json
   {
     "data": {
       "orderId": "PGN-123456",
       "patientName": "Citizen Pat",
       "serviceCode": "169069000",
       "serviceDisplay": "CT of chest",
       "priority": "routine",
       "requesterName": "Nguyen, Alex",
       "organizationName": "Example GP Clinic",
       "status": "active",
       "authoredOn": "2025-12-07T10:00:00+11:00",
       "message": "Service request successfully processed..."
     }
   }
   ```

## File Structure

```
au-erequesting/
├── config.toml                      # Harmony configuration
├── pipelines/
│   └── au-erequesting.toml         # Request/response pipeline
├── transforms/
│   ├── http-request-to-fhir.json   # HTTP → FHIR conversion
│   └── fhir-response-to-http.json  # FHIR → HTTP conversion
├── server.py                        # FHIR server (Python)
├── request.json                     # FHIR response template
├── demo.sh                          # Automation script
└── README.md                        # Full documentation
```

## Ports

- **FHIR Server**: http://127.0.0.1:8888
  - `GET /health` - Health check
  - `POST /` - Accept FHIR bundles

- **Harmony Proxy**: http://127.0.0.1:8080
  - `GET /service-requests?providerId={id}` - API endpoint

## View Logs

After running demo.sh, check logs:

```bash
# Harmony proxy activity
tail tmp/harmony.log

# FHIR server activity
tail tmp/fhir_server.log
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
