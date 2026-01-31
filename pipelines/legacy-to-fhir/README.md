# Legacy HTTP to FHIR Example

## What is this pipeline?

This example demonstrates how to accept HTTP requests from legacy systems and convert them to FHIR requests. It enables older applications to communicate with modern FHIR servers without needing to understand FHIR. This example is ideal for:

- Connecting legacy patient management systems to FHIR servers
- Migrating applications to FHIR incrementally
- Providing a FHIR-compatible facade for existing APIs
- Enabling legacy EMR/EHR systems to participate in FHIR exchanges

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Update the FHIR server target address
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

- Accepting legacy flat JSON via HTTP POST
- JOLT transformation from legacy format to FHIR R4 Patient
- Gender code mapping (M/F to male/female)
- Adding FHIR metadata and coding systems
- Converting FHIR responses back to legacy format

## Prerequisites

- Harmony Proxy installed
- FHIR server backend (or use the built-in echo service for testing)

## Configuration

### Network Settings

- **HTTP Listener**: `127.0.0.1:8080`
- **Endpoint Path**: `/api/patients`
- **Content-Type**: `application/json`

### Pipeline Flow

```
Legacy System                  Harmony Proxy                    FHIR Server
    |                               |                               |
    |  POST /api/patients           |                               |
    |  (Legacy JSON)                |                               |
    |------------------------------>|                               |
    |                               |  Transform: Legacy -> FHIR    |
    |                               |------------------------------>|
    |                               |      POST /Patient            |
    |                               |      (FHIR Patient)           |
    |                               |                               |
    |                               |  FHIR Response                |
    |                               |<------------------------------|
    |                               |  Transform: FHIR -> Legacy    |
    |  Legacy JSON Response         |                               |
    |<------------------------------|                               |
```

## How to Run

1. **Start the proxy**:
   ```bash
   harmony-proxy --config config.toml
   ```

2. **Test with a legacy patient request**:
   ```bash
   curl -X POST http://127.0.0.1:8080/api/patients \
     -H "Content-Type: application/json" \
     -d '{
       "patient_id": "12345",
       "first_name": "John",
       "middle_name": "William",
       "last_name": "Smith",
       "dob": "1990-01-15",
       "gender": "M",
       "mrn": "MRN-001234",
       "ssn": "123-45-6789",
       "phone": "+1-555-123-4567",
       "email": "john.smith@email.com",
       "address_line1": "123 Main Street",
       "address_line2": "Apt 4B",
       "city": "Boston",
       "state": "MA",
       "zip": "02101",
       "country": "USA"
     }'
   ```

3. **Expected transformed output** (sent to FHIR server):
   ```json
   {
     "resourceType": "Patient",
     "id": "12345",
     "meta": {
       "profile": ["http://hl7.org/fhir/StructureDefinition/Patient"]
     },
     "identifier": [
       {
         "system": "http://hospital.org/mrn",
         "value": "MRN-001234",
         "type": {
           "coding": [
             {
               "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
               "code": "MR"
             }
           ]
         }
       },
       {
         "system": "http://hl7.org/fhir/sid/us-ssn",
         "value": "123-45-6789",
         "type": {
           "coding": [
             {
               "system": "http://terminology.hl7.org/CodeSystem/v2-0203",
               "code": "SS"
             }
           ]
         }
       }
     ],
     "name": [
       {
         "use": "official",
         "family": "Smith",
         "given": ["John", "William"]
       }
     ],
     "telecom": [
       {
         "system": "phone",
         "use": "home",
         "value": "+1-555-123-4567"
       },
       {
         "system": "email",
         "use": "home",
         "value": "john.smith@email.com"
       }
     ],
     "gender": "male",
     "birthDate": "1990-01-15",
     "address": [
       {
         "use": "home",
         "type": "physical",
         "line": ["123 Main Street", "Apt 4B"],
         "city": "Boston",
         "state": "MA",
         "postalCode": "02101",
         "country": "USA"
       }
     ]
   }
   ```

## Data Mapping

### Legacy to FHIR Field Mapping

| Legacy Field | FHIR Path |
|--------------|-----------|
| `patient_id` | `id` |
| `first_name` | `name[0].given[0]` |
| `middle_name` | `name[0].given[1]` |
| `last_name` | `name[0].family` |
| `dob` or `date_of_birth` | `birthDate` |
| `gender` or `sex` | `gender` (mapped) |
| `mrn` | `identifier[0].value` |
| `ssn` | `identifier[1].value` |
| `phone` | `telecom[0].value` |
| `email` | `telecom[1].value` |
| `address_line1` | `address[0].line[0]` |
| `city` | `address[0].city` |
| `state` | `address[0].state` |
| `zip` or `zip_code` | `address[0].postalCode` |

### Gender Code Mapping

| Legacy Value | FHIR Value |
|--------------|------------|
| `M` or `m` | `male` |
| `F` or `f` | `female` |
| Other | Passed through |

## Files

- `config.toml` - Main proxy configuration
- `pipelines/legacy-to-fhir.toml` - Pipeline definition
- `transforms/legacy-to-fhir-patient.json` - Legacy to FHIR JOLT spec
- `transforms/fhir-response-to-legacy.json` - FHIR to legacy response spec
- `README.md` - This documentation

## Extending the Example

### Supporting Multiple Field Names

The transform already supports common field name variations:

```json
{
  "dob": "data.birthDate",
  "date_of_birth": "data.birthDate"
}
```

Add more aliases as needed for your legacy system.

### Adding More Identifiers

Extend the identifier mapping for additional ID types:

```json
{
  "drivers_license": "data.identifier[2].value"
}
```

And add the corresponding default structure.

### Production FHIR Server

Update `config.toml` to point to your FHIR server:

```toml
[targets.fhir_server]
connection.host = "fhir.yourcompany.com"
connection.port = 443
connection.protocol = "https"
connection.base_path = "/fhir/R4"
```

Then update the pipeline to use the real backend:

```toml
[backends.fhir_backend]
service = "http"
target_ref = "fhir_server"
```

## Troubleshooting

### Transform Errors

Check Harmony logs for JOLT transformation issues:
```bash
tail -f tmp/harmony_legacy_to_fhir.log
```

### Gender Mapping Issues

If gender values aren't mapping correctly, verify your legacy system's gender codes and update the mapping in the JOLT spec.

### Missing Required FHIR Fields

The transform adds sensible defaults, but some FHIR servers may require additional fields. Check the FHIR server's CapabilityStatement for requirements.

## Next Steps

- See [FHIR to Legacy](../fhir-to-legacy/) for the reverse transformation
- Explore [Transform Example](../transform/) for more JOLT patterns
- Check [FHIR Integration](../fhir/) for direct FHIR proxying

## References

- [FHIR R4 Patient Resource](https://hl7.org/fhir/R4/patient.html)
- [FHIR Identifier Coding](https://www.hl7.org/fhir/v2/0203/index.html)
- [JOLT Transform Specification](https://github.com/bazaarvoice/jolt)
- [Harmony Transform Middleware](https://docs.runbeam.io/harmony/middleware/transform)
