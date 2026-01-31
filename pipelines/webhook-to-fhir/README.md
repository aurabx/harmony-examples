# Webhook to FHIR Example

## What is this pipeline?

This example demonstrates how to receive webhooks from any system and transform payloads into FHIR resources. It supports multiple webhook types and routes them to the appropriate FHIR resource transformations. This example is ideal for:

- Integrating SaaS applications with FHIR systems
- Receiving patient registration events from booking platforms
- Processing appointment notifications from scheduling systems
- Ingesting lab results from external laboratory systems
- Building event-driven FHIR data pipelines

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Update the FHIR server target address
4. Customize JOLT transforms for your webhook formats
5. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- Receiving webhooks from external systems
- Multiple webhook endpoint types (patient, appointment, lab)
- Flexible field mapping for various webhook formats
- FHIR Patient, Appointment, and Observation resource creation
- Webhook acknowledgment responses

## Prerequisites

- Harmony Proxy installed
- FHIR server backend (or use the built-in echo service for testing)

## Configuration

### Network Settings

- **HTTP Listener**: `127.0.0.1:8080`
- **Webhook Endpoints**:
  - `/webhooks/patient` - Patient registration events
  - `/webhooks/appointment` - Appointment booking events
  - `/webhooks/lab` - Lab result notifications

### Pipeline Flow

```
External System                Harmony Proxy                    FHIR Server
    |                               |                               |
    |  POST /webhooks/patient       |                               |
    |  (Webhook payload)            |                               |
    |------------------------------>|                               |
    |                               |  Transform: Webhook -> FHIR   |
    |                               |------------------------------>|
    |                               |      POST /Patient            |
    |                               |                               |
    |                               |  FHIR Response                |
    |                               |<------------------------------|
    |                               |  Transform: FHIR -> Ack       |
    |  Webhook Acknowledgment       |                               |
    |<------------------------------|                               |
```

## How to Run

1. **Start the proxy**:
   ```bash
   harmony-proxy --config config.toml
   ```

2. **Test patient registration webhook**:
   ```bash
   curl -X POST http://127.0.0.1:8080/webhooks/patient \
     -H "Content-Type: application/json" \
     -H "X-Webhook-Event: patient.created" \
     -d '{
       "event": "patient.created",
       "timestamp": "2024-01-15T10:30:00Z",
       "data": {
         "id": "ext-12345",
         "first_name": "John",
         "last_name": "Smith",
         "email": "john.smith@example.com",
         "phone": "+1-555-123-4567",
         "dob": "1990-01-15",
         "gender": "male"
       }
     }'
   ```

3. **Test appointment webhook**:
   ```bash
   curl -X POST http://127.0.0.1:8080/webhooks/appointment \
     -H "Content-Type: application/json" \
     -d '{
       "event": "appointment.booked",
       "data": {
         "id": "apt-67890",
         "patient_id": "12345",
         "practitioner_id": "dr-001",
         "start_time": "2024-01-20T09:00:00Z",
         "end_time": "2024-01-20T09:30:00Z",
         "duration": 30,
         "type": "General Consultation",
         "status": "booked"
       }
     }'
   ```

4. **Test lab result webhook**:
   ```bash
   curl -X POST http://127.0.0.1:8080/webhooks/lab \
     -H "Content-Type: application/json" \
     -d '{
       "event": "lab.result.ready",
       "data": {
         "id": "lab-99999",
         "patient_id": "12345",
         "test_code": "2339-0",
         "test_name": "Glucose [Mass/volume] in Blood",
         "value": 95,
         "unit": "mg/dL",
         "reference_range_low": 70,
         "reference_range_high": 100,
         "status": "final",
         "interpretation": "N",
         "collected_at": "2024-01-15T08:00:00Z",
         "issued": "2024-01-15T14:30:00Z",
         "lab_id": "lab-acme"
       }
     }'
   ```

## Supported Webhook Formats

### Patient Registration

The patient webhook transform accepts various field naming conventions:

| Webhook Field | Alternative Names |
|--------------|-------------------|
| `id` | `external_id`, `patient_id` |
| `first_name` | `given_name` |
| `last_name` | `family_name` |
| `name` | `full_name` |
| `dob` | `date_of_birth`, `birth_date` |
| `gender` | `sex` |
| `email` | - |
| `phone` | `mobile` |

**Output**: FHIR Patient resource

### Appointment Booking

| Webhook Field | Alternative Names |
|--------------|-------------------|
| `id` | `appointment_id` |
| `patient_id` | `patient_ref` |
| `practitioner_id` | `practitioner_ref`, `provider_id` |
| `start_time` | `start`, `scheduled_at` |
| `end_time` | `end` |
| `duration` | `duration_minutes` |
| `status` | `appointment_status` |
| `type` | `service_type`, `appointment_type` |

**Output**: FHIR Appointment resource

### Lab Results

| Webhook Field | Alternative Names |
|--------------|-------------------|
| `id` | `result_id`, `observation_id` |
| `patient_id` | `patient_ref` |
| `test_code` | `code`, `loinc_code` |
| `test_name` | `code_display` |
| `value` | `result_value`, `numeric_value` |
| `unit` | `units` |
| `status` | `result_status` |
| `interpretation` | `abnormal_flag` |
| `collected_at` | `collection_date`, `effective_date` |

**Output**: FHIR Observation resource

## Files

- `config.toml` - Main proxy configuration
- `pipelines/webhook-to-fhir.toml` - Pipeline definitions
- `transforms/webhook-patient-to-fhir.json` - Patient webhook transform
- `transforms/webhook-appointment-to-fhir.json` - Appointment webhook transform
- `transforms/webhook-lab-to-fhir.json` - Lab result webhook transform
- `transforms/fhir-to-webhook-ack.json` - Acknowledgment response transform
- `README.md` - This documentation

## Extending the Example

### Adding New Webhook Types

1. Create a new pipeline section in `webhook-to-fhir.toml`:

```toml
[pipelines.webhook_document]
description = "Transform document webhooks to FHIR DocumentReference"
networks = ["http_net"]
endpoints = ["webhook_document_endpoint"]
middleware.left = [
    "log_incoming",
    "document_webhook_transform",
]
backends = ["fhir_backend"]

[endpoints.webhook_document_endpoint]
service = "http"
[endpoints.webhook_document_endpoint.options]
path_prefix = "/webhooks/document"
```

2. Create the corresponding JOLT transform.

### Webhook Authentication

Add authentication middleware for secure webhook endpoints:

```toml
middleware.left = [
    "webhook_auth",
    "log_incoming",
    "patient_webhook_transform",
]

[middleware.webhook_auth]
type = "basic_auth"
[middleware.webhook_auth.options]
username = "webhook_user"
password = "webhook_secret"
```

### Webhook Signature Verification

For HMAC signature verification, configure policies:

```toml
[middleware.verify_signature]
type = "policies"
[middleware.verify_signature.options]
policies = ["webhook_signature"]
```

### Production FHIR Server

Update `config.toml` to point to your FHIR server:

```toml
[targets.fhir_server]
connection.host = "fhir.yourcompany.com"
connection.port = 443
connection.protocol = "https"
connection.base_path = "/fhir/R4"
```

## Troubleshooting

### Transform Errors

Check Harmony logs for JOLT transformation issues:
```bash
tail -f tmp/harmony_webhook_to_fhir.log
```

### Missing Required Fields

If FHIR validation fails, ensure your webhook includes the minimum required fields for each resource type.

### Field Mapping Issues

The transforms support multiple field naming conventions. If your webhook uses different names, add them to the shift spec.

## Next Steps

- See [Legacy to FHIR](../legacy-to-fhir/) for HTTP API to FHIR conversion
- Explore [FHIR Integration](../fhir/) for direct FHIR proxying
- Check [Webhook Middleware](../webhook/) for outbound webhook emissions

## References

- [FHIR R4 Patient Resource](https://hl7.org/fhir/R4/patient.html)
- [FHIR R4 Appointment Resource](https://hl7.org/fhir/R4/appointment.html)
- [FHIR R4 Observation Resource](https://hl7.org/fhir/R4/observation.html)
- [LOINC Codes](https://loinc.org/)
- [JOLT Transform Specification](https://github.com/bazaarvoice/jolt)
- [Harmony Transform Middleware](https://docs.runbeam.io/harmony/middleware/transform)
