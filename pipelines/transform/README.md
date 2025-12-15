# Transform Middleware Example

## What is this pipeline?

This example demonstrates the transform middleware using JOLT (JSON-to-JSON transformation) to reshape and restructure JSON data in transit. This example is ideal for:

- Transforming data between formats (e.g., DICOM to FHIR)
- Restructuring JSON responses
- Field renaming and data normalization
- Building data transformation pipelines

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize JOLT transform specifications for your data
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- JOLT transformation middleware
- JSON data restructuring
- Patient data to FHIR format transformation
- Simple field renaming transforms
- Pre-transform snapshot preservation

## Prerequisites

None - this example is self-contained.

## Configuration

- **Proxy ID**: `harmony-transform`
- **HTTP Listener**: `127.0.0.1:8083`
- **Endpoint Path**: `/transform`
- **Log File**: `./tmp/harmony_transform.log`
- **Storage**: `./tmp`

## Transform Specifications

### 1. Patient to FHIR (`transforms/patient_to_fhir.json`)

Transforms patient data into FHIR Patient resource format:

**Input:**
```json
{
  "PatientID": "12345",
  "PatientName": "John Doe",
  "StudyInstanceUID": "1.2.3.4.5.6",
  "StudyDate": "2024-01-15"
}
```

**Output:**
```json
{
  "resourceType": "Patient",
  "resource": {
    "identifier": [{
      "system": "http://example.com/patient-id",
      "value": "12345"
    }],
    "name": [{
      "use": "usual",
      "family": "John Doe"
    }],
    "extension": [
      {
        "url": "http://example.com/study-uid",
        "valueString": "1.2.3.4.5.6"
      },
      {
        "url": "http://example.com/study-date",
        "valueDate": "2024-01-15"
      }
    ]
  }
}
```

### 2. Simple Rename (`transforms/simple_rename.json`)

Basic field renaming transformation.

## How to Run

1. From the project root, run:
   ```bash
   cargo run -- --config examples/transform/config.toml
   ```

2. The service will start and bind to `127.0.0.1:8083`

## Testing

```bash
# Test patient to FHIR transformation
curl -X POST http://127.0.0.1:8083/transform \
  -H "Content-Type: application/json" \
  -d '{
    "PatientID": "12345",
    "PatientName": "John Doe",
    "StudyInstanceUID": "1.2.3.4.5.6",
    "StudyDate": "2024-01-15"
  }'
```

## Expected Behavior

1. HTTP request with JSON payload is received
2. JSON extractor middleware normalizes the data
3. Transform middleware applies the JOLT specification
4. Original data is preserved in `normalized_snapshot` field
5. Transformed data is available in `normalized_data` field
6. Response shows the transformed structure

## JOLT Operations

The transform middleware uses [Jolt-RS](https://github.com/aurabx/jolt-rs) and supports:

- **shift**: Move/copy data with path transformations
- **default**: Apply default values for missing fields
- **remove**: Remove fields from output
- **wildcards**: Use `*` and `&` for dynamic field matching

## Files

- `config.toml` - Main configuration file
- `pipelines/transform-example.toml` - Pipeline with transform middleware
- `transforms/patient_to_fhir.json` - JOLT spec for patient data
- `transforms/simple_rename.json` - JOLT spec for field renaming
- `tmp/` - Created at runtime for logs and temporary storage

## Configuration Options

In the pipeline, transforms can be configured with:

```toml
[middleware.my_transform]
type = "transform"
[middleware.my_transform.options]
spec_path = "transforms/my_spec.json"
apply = "both"  # "left", "right", or "both"
fail_on_error = true  # true or false
```

- **apply**: When to apply the transform
  - `left`: Request (to backend)
  - `right`: Response (from backend)
  - `both`: Both directions (default)
- **fail_on_error**: Whether to fail the request on transformation errors

## Next Steps

- See [Jolt-RS documentation](https://github.com/aurabx/jolt-rs) for complete JOLT specification
- Explore `examples/fhir-to-dicom/` for real-world transformation use cases
- Create your own JOLT specifications for custom transformations
