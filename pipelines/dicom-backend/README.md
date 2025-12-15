# DICOM Backend (SCU) Example

## What is this pipeline?

This example demonstrates using HTTP requests to trigger DICOM SCU (Service Class User) operations against a PACS system. This example is ideal for:

- Exposing DICOM operations through HTTP APIs
- Integrating DICOM PACS with modern web applications
- Building query/retrieve workflows
- Bridging legacy DICOM systems with REST interfaces

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure DICOM backend target (host, port, AE titles)
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- HTTP to DICOM protocol translation
- DICOM SCU backend configuration
- DIMSE operations (C-FIND, C-MOVE, C-STORE)
- Triggering PACS queries via REST API

## Prerequisites

- **DICOM Server**: Orthanc PACS or compatible DICOM server
- **Default Configuration**: Expects DICOM server at `localhost:4242` with AE title `ORTHANC`

### Setting up Orthanc (Optional)

```bash
docker run -p 4242:4242 -p 8042:8042 --name orthanc \
  -e ORTHANC_AE_TITLE=ORTHANC \
  orthancteam/orthanc
```

## Configuration

- **Proxy ID**: `harmony-dicom-backend`
- **HTTP Listener**: `127.0.0.1:8085`
- **Endpoint Path**: `/trigger-dicom`
- **DICOM Backend**: `localhost:4242` (AE: `ORTHANC`, Local AE: `HARMONY_SCU`)
- **Log File**: `./tmp/harmony_dicom_backend.log`
- **Storage**: `./tmp`

## How to Run

1. Ensure your DICOM server (e.g., Orthanc) is running

2. From the project root, run:
   ```bash
   cargo run -- --config examples/dicom-backend/config.toml
   ```

3. The service will start and bind to `127.0.0.1:8085`

## Testing

### Trigger DICOM Query

```bash
# Send HTTP request to trigger DICOM operations
curl -X POST http://127.0.0.1:8085/trigger-dicom \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "C-FIND",
    "query": {
      "PatientID": "*",
      "PatientName": "*",
      "StudyInstanceUID": ""
    }
  }'
```

### Example Operations

**C-FIND (Query):**
```bash
curl -X POST http://127.0.0.1:8085/trigger-dicom \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "C-FIND",
    "level": "STUDY",
    "query": {
      "StudyInstanceUID": "1.2.3.4.5.6"
    }
  }'
```

**C-MOVE (Retrieve):**
```bash
curl -X POST http://127.0.0.1:8085/trigger-dicom \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "C-MOVE",
    "destination": "HARMONY_SCU",
    "query": {
      "StudyInstanceUID": "1.2.3.4.5.6"
    }
  }'
```

## Expected Behavior

1. HTTP request is received with DICOM operation parameters
2. Harmony establishes DICOM association with configured PACS
3. Specified DIMSE operation (C-FIND, C-MOVE, etc.) is performed
4. Results are returned in HTTP response
5. Association is released

## Use Cases

- **RESTful DICOM Interface**: Expose DICOM operations via HTTP API
- **Study Retrieval**: Trigger C-MOVE operations from web applications
- **PACS Queries**: Query PACS for studies, series, or images via HTTP
- **Integration Bridge**: Connect modern HTTP clients to legacy DICOM systems

## Files

- `config.toml` - Main configuration with DICOM backend settings
- `pipelines/dicom-backend.toml` - Pipeline definition
- `tmp/` - Created at runtime for logs and temporary storage

## Troubleshooting

- **Connection Refused**: Ensure DICOM server is running on configured host/port
- **Association Rejected**: Verify AE titles match (ORTHANC and HARMONY_SCU)
- **Timeout Errors**: Check network connectivity and firewall settings
- **Invalid Query**: Ensure DICOM query attributes are properly formatted

## DICOM Operations Reference

### Supported DIMSE Operations

- **C-ECHO**: Verify connection
- **C-FIND**: Query for studies, series, images
- **C-MOVE**: Retrieve studies from PACS
- **C-STORE**: Send DICOM objects to PACS

### Query Levels

- **PATIENT**: Patient-level queries
- **STUDY**: Study-level queries
- **SERIES**: Series-level queries
- **IMAGE**: Image-level queries

## Next Steps

- See `examples/fhir-to-dicom/` for FHIR to DICOM translation
- Explore `examples/dicom-scp/` to receive DICOM connections
- Review DICOM standard for query/retrieve specifications
