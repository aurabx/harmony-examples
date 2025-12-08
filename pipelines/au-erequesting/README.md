# AU eRequesting FHIR HTTP Integration Example

This example demonstrates how to use Harmony to convert HTTP API requests into FHIR bundles compliant with the AU eRequesting Implementation Guide, send them to a FHIR server, and convert the responses back to simplified HTTP JSON responses.

## Overview

The example illustrates a complete HTTP-to-FHIR-to-HTTP workflow:

```
HTTP Request
   ↓ (HTTP→FHIR transform)
FHIR Bundle (AU eRequesting)
   ↓ (POST to backend)
FHIR Server
   ↓ (receive FHIR response)
FHIR Bundle
   ↓ (FHIR→HTTP transform)
HTTP JSON Response
```

## Architecture

### Components

1. **FHIR Server** (`server.py`)
   - Simple Python HTTP server listening on port 8888
   - Accepts POST requests with FHIR bundles
   - Returns the pre-configured AU eRequesting response

2. **Harmony Proxy** (Rust application)
   - Listens on port 8080
   - Transforms HTTP requests to FHIR bundles
   - Forwards bundles to the FHIR server
   - Transforms responses back to HTTP JSON

3. **HTTP API**
   - `GET /service-requests?providerId={id}`
   - Query parameters: `providerId`, `patientId`, `serviceCode`
   - Returns simplified JSON with key service request details

### Files

```
au-erequesting/
├── config.toml                 # Harmony proxy configuration
├── pipelines/
│   └── au-erequesting.toml    # Pipeline definition
├── transforms/
│   ├── http-request-to-fhir.json      # Request transformation
│   └── fhir-response-to-http.json     # Response transformation
├── server.py                   # FHIR server implementation
├── request.json               # AU eRequesting FHIR bundle template
├── demo.sh                    # Orchestration script
└── README.md                  # This file
```

## Getting Started

### Prerequisites

- Python 3.6+
- Rust and Cargo
- curl
- zsh or bash shell

### Running the Demo

```bash
cd /Users/xtfer/working/runbeam/runbeam-workspace/projects/harmony-examples/pipelines/au-erequesting
./demo.sh
```

The demo script will:

1. Check for required tools
2. Start the FHIR server on port 8888
3. Build Harmony
4. Start the Harmony proxy on port 8080
5. Run test requests
6. Display results
7. Clean up on exit

### Manual Execution

#### 1. Start FHIR Server

```bash
python3 server.py 8888
```

#### 2. Start Harmony Proxy

```bash
cd /path/to/au-erequesting
harmony --config ./config.toml
```

#### 3. Make HTTP Requests

```bash
# Simple GET request for service requests
curl 'http://127.0.0.1:8080/service-requests?providerId=8003621566684455'

# Pretty-print the response
curl -s 'http://127.0.0.1:8080/service-requests?providerId=8003621566684455' | jq
```

## Configuration Details

### Harmony Configuration (`config.toml`)

- **Proxy ID**: `harmony-au-erequesting`
- **HTTP Port**: 8080
- **Log Level**: debug
- **Transforms Path**: `./transforms`
- **Pipelines Path**: `./pipelines`
- **FHIR Backend**: localhost:8888

### Pipeline Configuration (`au-erequesting.toml`)

The pipeline defines a single flow:

1. **HTTP Request Endpoint**: `/` (all paths)
2. **Request Middleware**:
   - `http_to_fhir_transform`: Converts HTTP request to FHIR bundle
   - `dump_fhir_request`: Logs the FHIR request for debugging
3. **Backend**: HTTP POST to FHIR server
4. **Response Middleware**:
   - `fhir_to_http_transform`: Extracts key fields from FHIR response
   - `dump_final_response`: Logs the final HTTP response

## Transform Specifications

### HTTP to FHIR Transform (`http-request-to-fhir.json`)

Converts HTTP request into a AU eRequesting FHIR bundle containing:

- **Task (Group)**: Top-level task for coordinating the request
- **Task (Diagnostic Request)**: Task focused on the diagnostic request
- **ServiceRequest**: The actual service being requested (CT imaging)
- **Patient**: The patient receiving the service
- **Practitioner**: The requesting clinician
- **PractitionerRole**: Role of the practitioner
- **Organization**: The organization initiating the request
- **Encounter**: The clinical encounter context

**Notes**:
- Uses fixed UUIDs for relationships
- Creates conformant AU eRequesting bundle with proper profiles
- Status set to "requested" and intent to "order"

### FHIR to HTTP Transform (`fhir-response-to-http.json`)

Extracts key information from the FHIR bundle response:

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
    "bundleType": "Bundle",
    "message": "Service request successfully processed through AU eRequesting FHIR server"
  }
}
```

## FHIR Server (`server.py`)

### Endpoints

- **GET `/health`**: Health check
  - Returns: `{"status": "healthy", "service": "AU eRequesting FHIR Server"}`
  - HTTP 200

- **POST `/`**: Bundle submission
  - Accepts: FHIR Bundle with `resourceType: "Bundle"`
  - Returns: AU eRequesting FHIR bundle (from `request.json`)
  - HTTP 200 with `Content-Type: application/fhir+json`

### Implementation Details

- Uses Python's built-in `http.server` for simplicity
- No external dependencies required
- Reads response from `request.json` in the same directory
- Logs all requests to stdout
- Returns 404 for unrecognized paths
- Returns 400 for invalid JSON

## Demonstrating Conformance

The example demonstrates conformance to the AU eRequesting Implementation Guide v1.0.0 by:

1. Using correct profile URLs for all resources
2. Including required metadata profiles
3. Using proper coding systems (SNOMED-CT, HL7, Australian-specific systems)
4. Following the task-based workflow pattern
5. Including proper resource relationships and references

## Extending the Example

To extend this example:

1. **Modify Request Parameters**: Edit `http-request-to-fhir.json` to extract additional query parameters
2. **Custom FHIR Response**: Replace `request.json` with different FHIR bundles
3. **Additional Transforms**: Add more middleware to modify the request/response flow
4. **Multiple Endpoints**: Add more pipelines for different service types
5. **Real FHIR Server**: Point the backend target to a real FHIR server endpoint

### Example: Adding Patient ID to ServiceRequest

```json
{
  "operation": "shift",
  "spec": {
    "subject": {
      "reference": "@(patientId)"
    }
  }
}
```

## Logs

The demo script generates two log files in the `tmp/` directory:

- **harmony.log**: Harmony proxy debug output and middleware logs
- **fhir_server.log**: FHIR server request/response logs

## Troubleshooting

### FHIR Server won't start
- Check that port 8888 is available: `lsof -i :8888`
- Verify `request.json` exists in the same directory as `server.py`
- Check Python version: `python3 --version`

### Harmony won't start
- Check that port 8080 is available: `lsof -i :8080`
- Verify Harmony built successfully: Check `harmony.log`
- Ensure config.toml paths are correct

### Transform errors
- Check Harmony logs for details: `tail -f tmp/harmony.log`
- Verify transform JSON syntax: `python3 -m json.tool transforms/http-request-to-fhir.json`

### Request returns empty or incorrect response
- Verify FHIR server is running: `curl http://127.0.0.1:8888/health`
- Check that the bundle was sent to the backend: Look in `harmony.log` for "fhir_request_to_backend"
- Verify response transformation: Look for "final_http_response" in logs

## References

- [AU eRequesting Implementation Guide](https://build.fhir.org/ig/hl7au/au-fhir-erequesting/)
- [FHIR Bundle](https://www.hl7.org/fhir/bundle.html)
- [FHIR ServiceRequest](https://www.hl7.org/fhir/servicerequest.html)
- [FHIR Task](https://www.hl7.org/fhir/task.html)
- [Jolt Transform Specification](https://github.com/bazaarvoice/jolt)

## License

This example is provided as part of the Harmony project.
