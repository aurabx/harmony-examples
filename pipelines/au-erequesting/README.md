# AU eRequesting FHIR Integration Example

## What is this pipeline?

This example demonstrates bidirectional integration between HTTP APIs and FHIR using Harmony proxies with the SMILE FHIR server backend. It includes two main data flow patterns for converting between HTTP APIs and FHIR resources. This example is ideal for:

- Integrating legacy HTTP APIs with FHIR systems
- Transforming HTTP requests to FHIR queries and back
- Building bidirectional FHIR bridges
- Healthcare data interoperability

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Update the FHIR backend target and HTTP server addresses
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

This example demonstrates bidirectional integration between HTTP APIs and FHIR using Harmony proxies with the SMILE FHIR server backend. It includes two main data flow patterns:

## Overview

### Forward Flow: HTTP → FHIR → HTTP
Convert HTTP API requests to FHIR queries and back:
```
GET /service-requests?type=Task&owner=kioma-pathology
   ↓ (HTTP→FHIR transform)
GET /Task?owner=kioma-pathology (FHIR query)
   ↓ (Query FHIR Server)
FHIR Bundle Response
   ↓ (FHIR→HTTP transform)
HTTP JSON Response with tasks array
```

### Reverse Flow: FHIR → FHIR
Process FHIR bundles directly:
```
POST /fhir-bundle (FHIR Bundle)
   ↓ (pass-through to FHIR Server)
FHIR Response Bundle
```

## Architecture

### Components

1. **SMILE FHIR Server** (https://smile.sparked-fhir.com)
   - Remote FHIR backend service
   - Accepts GET (query) and POST (transaction) requests with FHIR bundles
   - Endpoint: `https://smile.sparked-fhir.com/ereq/fhir/DEFAULT`

2. **http-server.py** (Port 8889)
   - HTTP API backend service
   - Manages orders from HTTP requests
   - Used in bidirectional integration test

3. **Harmony Proxy** (Port 8080)
   - Runs two transformation pipelines
   - Pipeline 1: HTTP → FHIR → HTTP (forward flow)
   - Pipeline 2: FHIR → FHIR (reverse flow)

### File Structure

```
au-erequesting/
├── README.md                       # This file
├── config.toml                     # Harmony proxy configuration
├── fhir-server.py                  # FHIR backend service
├── http-server.py                  # HTTP API backend service
├── request.json                    # AU eRequesting FHIR bundle (test data)
├── demo-forward.sh                 # Forward flow demo script
├── demo-bidirectional.sh           # Bidirectional demo script
├── pipelines/
│   ├── http-to-fhir.toml          # Forward flow pipeline (HTTP→FHIR→HTTP)
│   └── fhir-to-fhir.toml          # Reverse flow pipeline (FHIR→FHIR)
└── transforms/
    ├── http-request-to-fhir.json   # HTTP → FHIR transformation
    ├── fhir-response-to-http.json  # FHIR → HTTP transformation
    └── fhir-to-api-request.json    # (deprecated, not used)
```

## Getting Started

### Prerequisites

- Python 3.6+
- Rust and Cargo
- curl
- zsh or bash shell

### Running the Demos

**Forward Flow Only** (HTTP → FHIR → HTTP):
```bash
./demo-forward.sh
```

**Bidirectional Integration** (both forward and reverse flows):
```bash
./demo-bidirectional.sh
```

Both scripts will:
1. Check for required tools
2. Start all necessary services
3. Run test requests
4. Display results
5. Clean up on exit

### Manual Execution

#### 1. No FHIR Server Setup Required
The example uses the remote SMILE FHIR server (https://smile.sparked-fhir.com/ereq/fhir/DEFAULT).

#### 2. Start HTTP Server (optional, only needed for bidirectional)
```bash
python3 http-server.py 8889
```

#### 3. Start Harmony Proxy
```bash
harmony --config ./config.toml
```

#### 4. Test Forward Flow
```bash
# HTTP → FHIR → HTTP
# Query Tasks owned by a specific organization
curl -s 'http://127.0.0.1:8080/service-requests?type=Task&owner=kioma-pathology' | jq
```

#### 5. Test Reverse Flow
```bash
# FHIR → FHIR
curl -s -X POST \
  -H "Content-Type: application/fhir+json" \
  -d @request.json \
  'http://127.0.0.1:8080/fhir-bundle' | jq
```

## Configuration Details

### Harmony Configuration (`config.toml`)

- **Proxy ID**: `harmony-au-erequesting`
- **HTTP Port**: 8080
- **Log Level**: debug
- **Transforms Path**: `./transforms`
- **Pipelines Path**: `./pipelines`
- **FHIR Backend**: https://smile.sparked-fhir.com/ereq/fhir/DEFAULT

### Pipelines

#### Forward Flow (`http-to-fhir.toml`)
1. **Endpoint**: `GET /service-requests`
2. **Request Processing**:
   - `http_to_fhir_transform`: Converts HTTP query params (`type`, `owner`) to FHIR query path
3. **Backend**: GET query to FHIR server (e.g., `/Task?owner=kioma-pathology`)
4. **Response Processing**:
   - `fhir_to_http_transform`: Extracts task entries from FHIR Bundle into JSON array

#### Reverse Flow (`fhir-to-fhir.toml`)
1. **Endpoint**: `POST /fhir-bundle`
2. **Request Processing**:
   - `dump_incoming_fhir`: Logs incoming FHIR bundle
3. **Backend**: POST to FHIR server
4. **Response Processing**:
   - `dump_outgoing_fhir`: Logs FHIR response

## Transform Specifications

### HTTP to FHIR Transform (`http-request-to-fhir.json`)

Converts HTTP query parameters into a FHIR query path:

- Extracts `type` and `owner` from query params
- Builds target URI: `/{type}?owner={owner}`
- Example: `?type=Task&owner=kioma-pathology` → `/Task?owner=kioma-pathology`

**Query Parameters**:
- `type`: FHIR resource type to query (e.g., `Task`, `ServiceRequest`)
- `owner`: Organization identifier to filter by

### FHIR to HTTP Transform (`fhir-response-to-http.json`)

Extracts task entries from a FHIR Bundle into a simplified JSON structure:

```json
{
  "totalTasks": 5,
  "tasks": [
    {
      "taskId": "task-123",
      "status": "requested",
      "priority": "routine",
      "authoredOn": "2025-12-07T10:00:00+11:00",
      "orderId": "PGN-123456",
      "patientRef": "Patient/pat-001",
      "requesterRef": "PractitionerRole/pr-001",
      "organizationRef": "Organization/org-001"
    },
    ...
  ]
}
```

**Output Fields**:
- `totalTasks`: Total count from Bundle
- `tasks[]`: Array of extracted task information
  - `taskId`, `status`, `priority`, `authoredOn`
  - `orderId` (from groupIdentifier)
  - `patientRef`, `requesterRef`, `organizationRef` (FHIR references)

## Services

### FHIR Server (`fhir-server.py`)

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
- Handles both GET (query) and POST (transaction) requests
- Logs all requests to stdout
- Returns 404 for unrecognized paths
- Returns 400 for invalid JSON

### HTTP Server (`http-server.py`)

Simple HTTP API backend for managing orders.

#### Endpoints

- **GET `/health`**: Health check
- **GET `/orders`**: List all orders
- **GET `/orders/{id}`**: Get specific order
- **POST `/orders`**: Create new order

#### Implementation Details

- Stores orders in-memory
- Validates required fields: patientId, patientName, serviceCode, serviceDisplay
- Returns 201 Created for successful POST requests
- Used in bidirectional demo for full integration testing

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

The demo script generates log files in the `tmp/` directory:

- **harmony.log**: Harmony proxy debug output and middleware logs

## Troubleshooting

### FHIR Server connectivity
- Verify you can reach the SMILE FHIR server: `curl https://smile.sparked-fhir.com/ereq/fhir/DEFAULT`
- Check network connectivity and firewall rules
- Ensure HTTPS/port 443 is accessible

### HTTP Server won't start
- Check that port 8889 is available: `lsof -i :8889`
- Verify http-server.py is executable: `chmod +x http-server.py`

### Harmony won't start
- Check that port 8080 is available: `lsof -i :8080`
- Verify Harmony is installed: `which harmony`
- Ensure config.toml paths are correct

### Transform errors
- Check Harmony logs for details: `tail -f tmp/harmony.log`
- Verify transform JSON syntax: `python3 -m json.tool transforms/http-request-to-fhir.json`

### Request returns empty or incorrect response
- Verify FHIR server is reachable: `curl https://smile.sparked-fhir.com/ereq/fhir/DEFAULT`
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
