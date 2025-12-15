# Basic Echo Example

## What is this pipeline?

This example demonstrates a simple HTTP passthrough pipeline with an echo backend. It's the simplest possible Harmony configuration and serves as a quick-start reference. This example is ideal for:

- Learning Harmony basics with minimal configuration
- Testing HTTP endpoint setup
- Understanding request/response flow
- Quick-start reference for new users

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure your network and endpoint settings
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- Basic HTTP endpoint configuration
- Passthrough middleware
- Echo backend (returns the request data as the response)
- Minimal configuration required to run Harmony

## Prerequisites

None - this example has no external dependencies.

## Configuration

- **Proxy ID**: `harmony-basic-echo`
- **HTTP Listener**: `127.0.0.1:8080`
- **Endpoint Path**: `/echo`
- **Log File**: `./tmp/harmony_basic_echo.log`
- **Storage**: `./tmp`

## How to Run

1. From the project root, run:
   ```bash
   cargo run -- --config examples/basic-echo/config.toml
   ```

2. The service will start and bind to `127.0.0.1:8080`

## Testing

Send a simple HTTP request to the echo endpoint:

```bash
# Basic GET request
curl -v http://127.0.0.1:8080/echo

# POST with JSON data
curl -X POST http://127.0.0.1:8080/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, Harmony!"}'
```

### Expected Behavior

The echo backend will return the request data back to you. You should see:
- Request headers
- Request body
- Metadata about the request

The response demonstrates how Harmony processes and transforms requests through its pipeline.

## Files

- `config.toml` - Main configuration file
- `pipelines/basic-echo.toml` - Pipeline definition
- `tmp/` - Created at runtime for logs and temporary storage

## Next Steps

After understanding this basic example, explore:
- `examples/fhir/` - Authentication and JSON extraction
- `examples/transform/` - Data transformation with JOLT
- `examples/dicom-backend/` - DICOM protocol integration
