# DICOM to JMIX Pipeline Example

## What is this pipeline?

This example demonstrates receiving DICOM images via the DICOM protocol (C-STORE) and automatically packaging them into JMIX envelopes for storage on an upstream JMIX server. This pipeline bridges traditional DICOM infrastructure with modern JMIX-based distribution systems.

This pattern is ideal for:

- Converting DICOM workflows to JMIX distribution
- Receiving images from modalities (CT, MRI, Ultrasound) and packaging for cloud storage
- Building DICOM-to-JMIX gateway services
- Integrating legacy PACS systems with JMIX repositories

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure the DICOM endpoint AE title and upstream JMIX server
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- **DICOM SCP Endpoint**: Receives DICOM images via C-STORE operations
- **JMIX Builder Middleware**: Automatically packages received DICOM files into JMIX envelopes
- **JMIX Backend Service**: Forwards built envelopes to an upstream JMIX server
- **Dual Network Configuration**: DICOM listener for receiving images, HTTP for querying envelopes
- **Performance Optimization**: Configurable hashing and file listing options

## Prerequisites

- **DICOM Source**: Modality, PACS, or workstation capable of sending DICOM via C-STORE
- **Upstream JMIX Server**: A JMIX-compatible server to receive packaged envelopes
- **DCMTK Tools** (optional): For testing with `storescu`

### Installing DCMTK (for testing)

```bash
# macOS
brew install dcmtk

# Ubuntu/Debian
apt-get install dcmtk

# Windows
# Download from https://dicom.offis.de/dcmtk.php.en
```

## Configuration

- **Proxy ID**: `harmony-dicom-to-jmix`
- **DICOM Listener**: `0.0.0.0:11113` (AE Title: `JMIX_RECEIVER`)
- **HTTP Listener**: `127.0.0.1:8086` (for querying local envelopes)
- **Upstream JMIX Target**: `https://jmix.example.com` (configurable)
- **Log File**: `./tmp/harmony_dicom_to_jmix.log`
- **Storage**: `./tmp`

### Configuring the DICOM Endpoint

Edit the pipeline TOML to customize the DICOM endpoint:

```toml
[endpoints.dicom_receiver.options]
local_aet = "YOUR_AE_TITLE"    # AE Title for this receiver
max_pdu = 32768                 # Maximum PDU size
enable_store = true             # Accept C-STORE operations
enable_echo = true              # Accept C-ECHO for testing
```

### Configuring the Upstream JMIX Server

Edit `config.toml` to set your upstream JMIX server:

```toml
[targets.upstream_jmix]
connection.host = "your-jmix-server.example.com"
connection.port = 443
connection.protocol = "https"
timeout_secs = 300
```

## How to Run

1. Configure the DICOM endpoint and upstream JMIX server

2. From the project root, run:
   ```bash
   cargo run -- --config examples/dicom-to-jmix/config.toml
   ```

3. The service will start with:
   - DICOM listener on `0.0.0.0:11113`
   - HTTP listener on `127.0.0.1:8086`

## Data Flow

```
DICOM Modality              Harmony                      Upstream JMIX Server
     |                         |                                |
     |-- C-STORE (images) ---->|                                |
     |                         |                                |
     |                    [DICOM SCP Receives]                  |
     |                         |                                |
     |                    [jmix_builder packages]               |
     |                    [DICOM into JMIX envelope]            |
     |                         |                                |
     |                         |-- POST /api/jmix ------------->|
     |                         |   (ZIP envelope)               |
     |                         |                                |
     |                         |<-- 201 {"id": "..."} ----------|
     |                         |                                |
     |<-- C-STORE-RSP ---------|                                |
     |    (Success)            |                                |
```

## Testing with DCMTK

### 1. Verify Connectivity (C-ECHO)

```bash
# Test DICOM connectivity
echoscu -aec JMIX_RECEIVER 127.0.0.1 11113

# Expected output: Association accepted
```

### 2. Send DICOM Images (C-STORE)

```bash
# Send a single DICOM file
storescu -aec JMIX_RECEIVER -aet MY_MODALITY \
  127.0.0.1 11113 /path/to/image.dcm

# Send an entire directory recursively
storescu -aec JMIX_RECEIVER -aet MY_MODALITY \
  --scan-directories --recurse \
  127.0.0.1 11113 /path/to/dicom/directory/
```

### 3. Query Local Envelopes (HTTP)

```bash
# Query by Study Instance UID
curl "http://127.0.0.1:8086/jmix/api/jmix?studyInstanceUid=1.2.3.4.5.6"

# Get manifest for a specific envelope
curl "http://127.0.0.1:8086/jmix/api/jmix/{envelope_id}/manifest"

# Download envelope as ZIP
curl "http://127.0.0.1:8086/jmix/api/jmix/{envelope_id}" \
  -H "Accept: application/zip" \
  -o envelope.zip
```

## JMIX Envelope Structure

When DICOM images are received, the `jmix_builder` middleware creates envelopes with this structure:

```
envelope.zip
  manifest.json           # Package metadata with unique ID
  payload/
    metadata.json         # DICOM study/series/instance metadata
    series_1/
      image_001.dcm       # Original DICOM files
      image_002.dcm
      ...
```

### manifest.json

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

### metadata.json

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "studies": {
    "1.2.3.4.5.6": {
      "study_uid": "1.2.3.4.5.6",
      "patient_name": "DOE^JOHN",
      "study_date": "20240115",
      "modality": "CT",
      "series": [...]
    }
  }
}
```

## Performance Tuning

### JMIX Builder Options

```toml
[middleware.jmix_builder.options]
# Skip SHA256 hash computation (faster, no integrity verification)
skip_hashing = true

# Skip file listing in manifest (faster for large studies)
skip_listing = true
```

### When to Use Performance Flags

| Scenario | skip_hashing | skip_listing |
|----------|--------------|--------------|
| High-throughput ingestion | `true` | `true` |
| Data integrity critical | `false` | `false` |
| Need file inventory | any | `false` |
| Maximum speed | `true` | `true` |

### DICOM PDU Size

Adjust PDU size for optimal transfer speed:

```toml
[endpoints.dicom_receiver.options]
max_pdu = 65536  # Larger PDU for faster transfers
```

## Advanced Configuration

### Authentication to Upstream JMIX Server

```toml
# In config.toml
[authentications.jmix_auth]
id = "jmix_auth"
method = "bearer"

[authentications.jmix_auth.options]
token = "your-api-token"

# In pipeline TOML
[backends.jmix_upstream.options]
authentication_ref = "jmix_auth"
```

### Multiple AE Title Support

Configure different behaviors per calling AE:

```toml
[endpoints.dicom_receiver.options.aet_table]
MODALITY_CT = { ae_title = "MODALITY_CT", host = "ct.local", port = 104 }
MODALITY_MR = { ae_title = "MODALITY_MR", host = "mr.local", port = 104 }
```

## Error Handling

| DICOM Status | Description |
|--------------|-------------|
| `0x0000` | Success - image stored and packaged |
| `0xA700` | Out of resources - storage full |
| `0xA900` | Dataset does not match SOP Class |
| `0xC000` | Cannot understand - processing error |

| HTTP Status | Description |
|-------------|-------------|
| 201 | Envelope successfully uploaded to upstream |
| 400 | Invalid envelope format |
| 502 | Upstream JMIX server error |
| 504 | Upstream timeout |

## Files

- `config.toml` - Main configuration with network and service definitions
- `pipelines/dicom-to-jmix.toml` - Pipeline with DICOM endpoint and JMIX backend
- `tmp/` - Created at runtime for logs, DICOM staging, and JMIX envelopes

## Troubleshooting

- **Association Rejected**: Check that the calling AE title is allowed and the port is correct
- **C-STORE Failure**: Verify storage directory has write permissions
- **Upstream 502**: Check upstream JMIX server connectivity and credentials
- **Missing Envelopes**: Ensure `jmix_builder` middleware is in the pipeline chain

## Next Steps

- Explore `examples/jmix-backend/` for JMIX-to-JMIX forwarding
- See `examples/jmix/` for JMIX endpoint with DICOM query/retrieve
- Review `examples/dicom-scp/` for standalone DICOM receiver patterns
