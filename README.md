# Harmony Examples

Example pipeline configurations and templates for [Harmony/Runbeam](https://runbeam.cloud), demonstrating healthcare data integration patterns including FHIR, DICOM, DICOMweb, and JMIX.

## Overview

This repository contains example pipelines that showcase Harmony's capabilities for:

- **Healthcare Protocol Integration**: FHIR, DICOM, DICOMweb, JMIX
- **HTTP Proxying & API Gateway**: REST API proxying with authentication and transformation
- **Data Transformation**: JOLT-based JSON transformations
- **Security**: Authentication, authorization, rate limiting, IP filtering
- **Content Type Support**: JSON, XML, CSV, form data, multipart, binary

## Pipeline Examples

### Basic Examples

- **basic-echo** - Simple echo service for testing request/response flow
- **http-external** - HTTP proxy with external backend and access control
- **http-internal** - HTTP proxy restricted to internal networks
- **transform** - JOLT transform middleware demonstrations
- **soap-to-json** - SOAP/XML to JSON conversion with JWT authentication

### Healthcare Integration

- **fhir** - FHIR endpoint with authentication and JSON extraction
- **fhir-dicom** - FHIR ImagingStudy integration with DICOM backend
- **dicom-scp** - DICOM SCP endpoint (C-ECHO, C-FIND, C-GET, C-MOVE)
- **dicom-backend** - HTTP to DICOM protocol translation
- **dicomweb** - DICOMweb QIDO-RS and WADO-RS to DIMSE bridge
- **jmix** - High-performance JMIX packaging and delivery

### Advanced

- **content-types** - Multi-content-type parsing (JSON, XML, CSV, multipart, binary)
- **smoketest** - Comprehensive integration test of all middleware types

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
