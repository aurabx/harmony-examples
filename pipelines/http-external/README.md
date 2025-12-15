# HTTP External Proxy Pipeline

## What is this pipeline?

This pipeline demonstrates an HTTP-to-HTTP proxy that forwards requests to an external backend service. It includes production-grade security features such as path filtering, rate limiting, and HTTP method validation. This example is ideal for:

- Proxying requests to external APIs
- Adding security policies without modifying backend code
- Rate limiting and access control for HTTP services
- Path-based routing and request filtering

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize the backend target to point to your external service
4. Harmony automatically discovers and loads the pipeline

Quick example:
```toml
# pipelines/my-http-proxy.toml
[pipelines.http_proxy]
description = "My HTTP proxy pipeline"
networks = ["http_net"]
endpoints = ["proxy_endpoint"]
middleware = ["access_control", "passthru"]
backends = ["external_api"]

[backends.external_api]
service = "http"
target_ref = "my_service"

[targets.my_service]
connection.host = "api.example.com"
connection.port = 443
connection.protocol = "https"
```

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## Configuration Overview

### Network
- **Bind Address**: 0.0.0.0 (all interfaces)
- **Port**: 8080
- **Endpoint**: `/` (all paths)

### Middleware Chain

1. **Access Control Policies**: Production-grade security policies
   - Block admin and internal paths (`/admin/*`, `/internal/*`)
   - Rate limit: 100 requests per minute
   - Allow only GET and POST methods

2. **Passthru**: Forward all remaining requests to the backend

### Backend

The pipeline proxies to an external HTTP service at `127.0.0.1:8888`. Update the `[targets.local_server]` section to point to your actual backend.

## Example Request

```bash
# Make a test request
curl http://127.0.0.1:8080/api/data
```

## Security Features

### Path Filtering
Blocks requests to sensitive paths:
- `/admin/*` - Administrative endpoints
- `/internal/*` - Internal service endpoints

### Rate Limiting
- **Limit**: 100 requests per minute per client
- **Window**: 60 seconds

### HTTP Method Filtering
- **Allowed Methods**: GET, POST
- **Denied Methods**: PUT, DELETE, PATCH, etc.

## Files Structure

```
http-external/
├── config.toml                    # Main proxy configuration
├── pipelines/
│   └── http-external.toml         # Pipeline definition with policies
└── README.md                      # This file
```
