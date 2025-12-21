# Harmony Examples

Example pipeline configurations and templates for [Harmony/Runbeam](https://runbeam.cloud), demonstrating healthcare data integration patterns including FHIR, DICOM, DICOMweb, and JMIX.

## What are these pipelines?

Harmony Examples contains 17 ready-to-use pipeline configurations that demonstrate Harmony's core capabilities. Each example includes a complete pipeline definition with middleware configuration, backend setup, and comprehensive documentation. Examples are organized by use case:

- **Basic Patterns**: HTTP proxying, echo endpoints, content-type handling
- **Healthcare Integration**: FHIR, DICOM, DICOMweb, JMIX
- **Data Transformation**: JOLT-based transformations, format conversion
- **Security**: Authentication, authorization, rate limiting, access control

## How to add these pipelines to your Harmony instance

Each pipeline example can be used as a starting point for your own deployments. To use any example:

1. Copy the pipeline directory to your Harmony configuration directory
2. Review the example's README.md for specific setup instructions
3. Customize configuration files for your environment
4. Deploy using your preferred method

For detailed instructions on adding and managing pipelines, see the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines).

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## Overview

This repository contains example pipelines that showcase Harmony's capabilities for:

- **Healthcare Protocol Integration**: FHIR, DICOM, DICOMweb, JMIX
- **HTTP Proxying & API Gateway**: REST API proxying with authentication and transformation
- **Data Transformation**: JOLT-based JSON transformations
- **Security**: Authentication, authorization, rate limiting, IP filtering
- **Content Type Support**: JSON, XML, CSV, form data, multipart, binary

## Pipeline Examples

### HTTP API Gateway Patterns

- **basic-echo** - Simple echo service for testing request/response flow
- **http-external** - HTTP proxy with external backend and access control
- **http-internal** - HTTP proxy restricted to internal networks
- **http-http** - Comprehensive HTTP proxy with combined security policies
- **http3-backend** - HTTP to HTTP/3 backend proxy (QUIC outbound)
- **http3-listener** - HTTP/3 to HTTP backend proxy (QUIC inbound)
- **http-file-upload** - HTTP file upload handling with storage backend
- **http-with-middleware** - Complete middleware chain demonstration

### Data Transformation

- **transform** - JOLT transform middleware demonstrations
- **soap-to-json** - SOAP/XML to JSON conversion with JWT authentication
- **content-types** - Multi-content-type parsing (JSON, XML, CSV, multipart, binary)
- **webhook** - Webhook middleware for audit trails and event integration

### Healthcare Integration

- **fhir** - FHIR endpoint with authentication and JSON extraction
- **fhir_dicom** - FHIR ImagingStudy integration with DICOM backend
- **dicom-scp** - DICOM SCP endpoint (C-ECHO, C-FIND, C-GET, C-MOVE)
- **dicom-backend** - HTTP to DICOM protocol translation (SCU)
- **dicomweb** - DICOMweb QIDO-RS and WADO-RS to DIMSE bridge
- **jmix** - High-performance JMIX packaging and delivery

### Specialized Healthcare Systems

- **au-erequesting** - Australian eRequesting FHIR integration
- **cstore-filesystem** - DICOM C-STORE to filesystem storage

## Project Structure

```
├── pipelines/           # Pipeline configurations organized by example
│   ├── basic-echo/
│   ├── fhir/
│   ├── dicom-scp/
│   └── ...
├── transforms/          # Shared JOLT transform specifications
├── src/                 # PHP utilities for template loading
├── tests/               # PHPUnit test suite
├── pipelines.json       # Pipeline catalog metadata
└── transforms.json      # Transform catalog metadata
```

## Getting Started

### Prerequisites

- **Harmony Proxy** (Rust-based runtime)
- **PHP 8.3+** (for template utilities)
- **Composer** (for PHP dependencies)
- **Node.js 18+** (if consuming as an npm package)

### Installation

#### PHP (Composer)

```bash
# Install PHP dependencies
composer install

# Run tests
composer test
```

#### Node.js (npm)

```bash
npm install @aurabx/harmony-examples
```

### Running an Example

Each pipeline example includes its own configuration and documentation:

```bash
# Example: Run the basic echo pipeline
cd pipelines/basic-echo
harmony-proxy --config config.toml

# Test it
curl http://127.0.0.1:8080/echo
```

Refer to individual `README.md` files in each pipeline directory for specific instructions.

## Template Loading

### Node.js

```js
const examples = require('@aurabx/harmony-examples');

// Catalog objects
console.log(Object.keys(examples.pipelines));

// Resolve a file path inside the installed package
console.log(examples.resolvePipelinePath('basic-echo'));
```

### PHP

The `TemplateLoader` class provides utilities for loading pipeline and transform metadata:

```php
use Runbeam\HarmonyExamples\TemplateLoader;

$loader = new TemplateLoader();

// Load pipeline catalog
$pipelines = $loader->loadPipelines();

// Load transform catalog
$transforms = $loader->loadTransforms();
```

## Testing

```bash
# Run all tests
composer test

# Run specific test
vendor/bin/phpunit tests/TemplateLoaderTest.php
```

Test coverage includes:
- Pipeline metadata validation
- JSON loading and error handling
- Category label formatting
- Required field validation

## Configuration Patterns

### Networks

Define network listeners for HTTP, DICOM, or management APIs:

```toml
[network.default]
enable_wireguard = false

[network.default.http]
bind_address = "0.0.0.0"
bind_port = 8080
```

### Middleware

Chain middleware for request/response processing:

```toml
[pipelines.my_pipeline]
middleware = [
    "auth",
    "transform",
    "passthru"
]
```

### Backends

Configure target services:

```toml
[backends.my_backend]
service = "http"
target_ref = "my_target"

[targets.my_target]
connection.host = "api.example.com"
connection.port = 443
connection.protocol = "https"
```

## Contributing

Contributions welcome! Please:

1. Follow existing configuration patterns
2. Include comprehensive README documentation
3. Add tests for new utilities
4. Update `pipelines.json` metadata

## License

MIT License - see LICENSE file for details

## Support

- **Documentation**: [Harmony Docs](https://docs.runbeam.cloud)
- **Issues**: [GitHub Issues](https://github.com/runbeam/harmony-examples/issues)
- **Email**: hello@aurabox.cloud
