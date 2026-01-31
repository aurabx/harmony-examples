# FHIR to Legacy HTTP Example

## What is this pipeline?

This example demonstrates how to accept FHIR R4 resources and transform them for legacy systems that don't speak FHIR. It bridges modern FHIR-compliant applications with older HTTP APIs using JOLT transformations. This example is ideal for:

- Integrating FHIR-enabled EHRs with legacy patient management systems
- Converting FHIR resources to flat JSON structures
- Enabling gradual FHIR adoption without replacing legacy backends
- Healthcare data interoperability with older systems

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Update the legacy API target address
4. Customize JOLT transforms for your legacy API format
5. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- Accepting FHIR R4 Patient resources via HTTP POST
- JOLT transformation from FHIR structure to flat JSON
- Converting FHIR identifiers, names, and addresses to legacy format
- Transforming legacy responses back to FHIR OperationOutcome
- Bidirectional data flow with separate request/response transforms

## Prerequisites

- Harmony Proxy installed
- Legacy API backend (or use the built-in echo service for testing)

## Configuration

### Network Settings

- **HTTP Listener**: `127.0.0.1:8080`
- **Endpoint Path**: `/Patient`
- **Content-Type**: `application/fhir+json`

### Pipeline Flow

```
FHIR Client                    Harmony Proxy                    Legacy API
    |                               |                               |
    |  POST /Patient                |                               |
    |  (FHIR Patient resource)      |                               |
    |------------------------------>|                               |
    |                               |  Transform: FHIR -> Legacy    |
    |                               |------------------------------>|
    |                               |                               |
    |                               |  Legacy JSON response         |
    |                               |<------------------------------|
    |                               |  Transform: Legacy -> FHIR    |
    |  FHIR OperationOutcome        |                               |
    |<------------------------------|                               |
```

## How to Run

1. **Start the proxy**:
   ```bash
   harmony-proxy --config config.toml
   ```

2. **Test with a FHIR Patient resource**:
   ```bash
   curl -X POST http://127.0.0.1:8080/Patient \
     -H "Content-Type: application/fhir+json" \
     -d '{
       "resourceType": "Patient",
       "id": "12345",
       "name": [
         {
           "family": "Smith",
           "given": ["John", "William"]
         }
       ],
       "birthDate": "1990-01-15",
       "gender": "male",
       "identifier": [
         {
           "system": "http://hospital.org/mrn",
           "value": "MRN-001234"
         }
       ],
       "telecom": [
         {
           "system": "phone",
           "value": "+1-555-123-4567",
           "use": "home"
         }
       ],
       "address": [
         {
           "line": ["123 Main Street", "Apt 4B"],
           "city": "Boston",
           "state": "MA",
           "postalCode": "02101",
           "country": "USA"
         }
       ]
     }'
   ```

3. **Expected transformed output** (sent to legacy backend):
   ```json
   {
     "patient_id": "12345",
     "first_name": "John",
     "middle_name": "William",
     "last_name": "Smith",
     "date_of_birth": "1990-01-15",
     "sex": "male",
     "identifiers": [
       {
         "type": "http://hospital.org/mrn",
         "value": "MRN-001234"
       }
     ],
     "contacts": [
       {
         "type": "phone",
         "value": "+1-555-123-4567",
         "use": "home"
       }
     ],
     "address_line1": "123 Main Street",
     "address_line2": "Apt 4B",
     "city": "Boston",
     "state": "MA",
     "zip_code": "02101",
     "country": "USA",
     "api_version": "1.0",
     "record_type": "patient"
   }
   ```

## Data Mapping

### FHIR to Legacy Field Mapping

| FHIR Path | Legacy Field |
|-----------|--------------|
| `id` | `patient_id` |
| `name[0].family` | `last_name` |
| `name[0].given[0]` | `first_name` |
| `name[0].given[1]` | `middle_name` |
| `birthDate` | `date_of_birth` |
| `gender` | `sex` |
| `identifier[*].system` | `identifiers[*].type` |
| `identifier[*].value` | `identifiers[*].value` |
| `telecom[*].system` | `contacts[*].type` |
| `telecom[*].value` | `contacts[*].value` |
| `address[0].line[0]` | `address_line1` |
| `address[0].city` | `city` |
| `address[0].state` | `state` |
| `address[0].postalCode` | `zip_code` |

## Files

- `config.toml` - Main proxy configuration
- `pipelines/fhir-to-legacy.toml` - Pipeline definition
- `transforms/fhir-patient-to-legacy.json` - FHIR to legacy JOLT spec
- `transforms/legacy-response-to-fhir.json` - Legacy to FHIR response spec
- `README.md` - This documentation

## Extending the Example

### Adding More Resource Types

Create additional pipelines for other FHIR resources:

```toml
[pipelines.fhir_observation_to_legacy]
description = "Transform FHIR Observation to legacy lab results"
endpoints = ["fhir_observation_endpoint"]
# ... rest of configuration
```

### Customizing Field Mappings

Modify the JOLT spec to match your legacy API:

```json
{
  "operation": "shift",
  "spec": {
    "data": {
      "name": {
        "0": {
          "family": "data.surname",
          "given": {
            "0": "data.forename"
          }
        }
      }
    }
  }
}
```

### Production Backend

Update `config.toml` to point to your legacy API:

```toml
[targets.legacy_api]
connection.host = "legacy-api.yourcompany.com"
connection.port = 443
connection.protocol = "https"
```

Then update the pipeline to use the real backend:

```toml
[backends.legacy_backend]
service = "http"
target_ref = "legacy_api"
```

## Troubleshooting

### Transform Errors

Check Harmony logs for JOLT transformation issues:
```bash
tail -f tmp/harmony_fhir_to_legacy.log
```

### Invalid FHIR Resources

Ensure your input conforms to FHIR R4 Patient structure. The transform expects standard FHIR paths.

### Missing Fields

If required fields are missing in the legacy output, verify the JOLT spec paths match your FHIR input structure.

## Next Steps

- See [Legacy to FHIR](../legacy-to-fhir/) for the reverse transformation
- Explore [Transform Example](../transform/) for more JOLT patterns
- Check [AU eRequesting](../au-erequesting/) for a complete bidirectional example

## References

- [FHIR R4 Patient Resource](https://hl7.org/fhir/R4/patient.html)
- [JOLT Transform Specification](https://github.com/bazaarvoice/jolt)
- [Harmony Transform Middleware](https://docs.runbeam.io/harmony/middleware/transform)
