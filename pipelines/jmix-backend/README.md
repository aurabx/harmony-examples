# JMIX Backend Forwarding Example

## What is this pipeline?

This example demonstrates the JMIX backend service (`jmix_backend`) for forwarding JMIX requests to an upstream JMIX server. This pipeline acts as a proxy layer that can:

- Forward JMIX envelope uploads (POST) to upstream servers
- Proxy JMIX envelope retrieval (GET) requests
- Forward manifest requests to upstream JMIX repositories
- Query upstream servers by Study Instance UID

This pattern is ideal for:

- Building JMIX distribution networks across organizations
- Adding security and access control layers to existing JMIX infrastructure
- Creating edge proxies for JMIX repositories
- Implementing multi-tier JMIX architectures

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure the upstream JMIX server target connection
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- **JMIX Backend Service**: Forward requests to upstream JMIX servers
- **POST Forwarding**: Upload JMIX envelopes (ZIP files) to upstream servers
- **GET Forwarding**: Retrieve envelopes by ID or query by Study Instance UID
- **Manifest Retrieval**: Fetch envelope manifests from upstream
- **Security Policies**: IP-based access control and rate limiting
- **Path Prefix Configuration**: Map local paths to upstream server paths

## Prerequisites

- **Upstream JMIX Server**: A JMIX-compatible server to forward requests to
  - This can be another Harmony instance with a `jmix` endpoint
  - Or any server implementing the JMIX API specification

## Configuration

- **Proxy ID**: `harmony-jmix-backend`
- **HTTP Listener**: `127.0.0.1:8085`
- **Endpoint Path**: `/jmix`
- **Upstream Target**: `https://jmix.example.com` (configurable)
- **Log File**: `./tmp/harmony_jmix_backend.log`
- **Storage**: `./tmp`

### Configuring the Upstream Target

Edit `config.toml` to set your upstream JMIX server:

```toml
[targets.upstream_jmix]
connection.host = "your-jmix-server.example.com"
connection.port = 443
connection.protocol = "https"
timeout_secs = 120
```

Or use `base_url` in the backend options:

```toml
[backends.upstream_jmix]
service = "jmix_backend"
[backends.upstream_jmix.options]
base_url = "https://your-jmix-server.example.com"
```

## How to Run

1. Configure the upstream JMIX server target in `config.toml`

2. From the project root, run:
   ```bash
   cargo run -- --config examples/jmix-backend/config.toml
   ```

3. The service will start and bind to `127.0.0.1:8085`

## API Endpoints

The JMIX backend forwards requests to the upstream server. All standard JMIX operations are supported:

### 1. Upload JMIX Envelope (POST)

Upload a JMIX envelope ZIP file to the upstream server:

```bash
# Upload a JMIX envelope
curl -X POST "http://127.0.0.1:8085/jmix/api/jmix" \
  -H "Content-Type: application/zip" \
  --data-binary @envelope.zip
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "stored"
}
```

### 2. Retrieve JMIX Envelope by ID (GET)

Download a stored envelope from the upstream server:

```bash
# Download as ZIP
curl "http://127.0.0.1:8085/jmix/api/jmix/{envelope_id}" \
  -H "Accept: application/zip" \
  -o envelope.zip
```

**Response:** Binary ZIP file containing the JMIX envelope

### 3. Get Envelope Manifest (GET)

Retrieve the manifest for a specific envelope:

```bash
# Get manifest.json
curl "http://127.0.0.1:8085/jmix/api/jmix/{envelope_id}/manifest" \
  -H "Accept: application/json"
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "version": 1,
  "content": {
    "type": "directory",
    "path": "payload"
  }
}
```

### 4. Query by Study Instance UID (GET)

Query for envelopes by DICOM Study Instance UID:

```bash
# Query by StudyInstanceUID
curl "http://127.0.0.1:8085/jmix/api/jmix?studyInstanceUid=1.2.3.4.5.6" \
  -H "Accept: application/zip" \
  -o study_envelope.zip
```

## Request Flow

```
Client                    Harmony (JMIX Backend)           Upstream JMIX Server
  |                              |                                |
  |-- POST /jmix/api/jmix ------>|                                |
  |   (ZIP envelope)             |-- POST /api/jmix ------------->|
  |                              |   (forwarded ZIP)              |
  |                              |<-- 201 {"id": "...", ...} -----|
  |<-- 201 {"id": "..."} --------|                                |
  |                              |                                |
  |-- GET /jmix/api/jmix/{id} -->|                                |
  |                              |-- GET /api/jmix/{id} --------->|
  |                              |<-- 200 (ZIP data) -------------|
  |<-- 200 (ZIP data) -----------|                                |
```

## Advanced Configuration

### Authentication to Upstream Server

Add authentication for the upstream JMIX server:

```toml
# In config.toml
[authentications.upstream_auth]
id = "upstream_auth"
method = "bearer"

[authentications.upstream_auth.options]
token = "your-api-token"

# In the pipeline TOML
[backends.upstream_jmix.options]
authentication_ref = "upstream_auth"
```

### Custom Path Mapping

Map local paths to different upstream paths:

```toml
[backends.upstream_jmix.options]
path_prefix = "/v2/jmix"  # Upstream uses /v2/jmix instead of /api/jmix
```

### Timeout Configuration

Adjust timeouts for large envelope transfers:

```toml
[targets.upstream_jmix]
timeout_secs = 300  # 5 minutes for large envelopes
```

## JMIX Envelope Structure

A JMIX envelope is a ZIP archive with the following structure:

```
envelope.zip
  manifest.json       # Package metadata with unique ID
  payload/
    metadata.json     # DICOM/study metadata
    [files...]        # DICOM or other medical imaging files
```

### manifest.json Format

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "envelope",
  "version": 1,
  "content": {
    "type": "directory",
    "path": "payload"
  }
}
```

## Error Handling

| Status Code | Description |
|-------------|-------------|
| 200 | Success - envelope retrieved or operation completed |
| 201 | Created - envelope successfully uploaded |
| 400 | Bad Request - invalid envelope format or missing manifest |
| 404 | Not Found - envelope ID does not exist |
| 409 | Conflict - envelope ID already exists (duplicate upload) |
| 415 | Unsupported Media Type - POST must use `application/zip` |
| 502 | Bad Gateway - upstream server error |
| 504 | Gateway Timeout - upstream server timeout |

## Files

- `config.toml` - Main configuration with target and service definitions
- `pipelines/jmix-backend.toml` - Pipeline with JMIX endpoint and backend
- `tmp/` - Created at runtime for logs and temporary storage

## Troubleshooting

- **502 Bad Gateway**: Check that the upstream JMIX server is reachable and the target configuration is correct
- **Connection Refused**: Verify the upstream host, port, and protocol settings
- **401/403 Errors**: Check authentication configuration if the upstream requires credentials
- **Timeout Errors**: Increase `timeout_secs` for large envelope transfers

## Next Steps

- Explore `examples/jmix/` for JMIX endpoint with DICOM backend integration
- See `examples/http-http/` for basic HTTP proxy patterns
- Review JMIX schema specifications for envelope format details
