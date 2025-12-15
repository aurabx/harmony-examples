# HTTP Internal Proxy Pipeline

## What is this pipeline?

This pipeline demonstrates an HTTP-to-HTTP proxy restricted to internal networks only. It includes production-grade security features including IP allowlisting, path filtering, rate limiting, and HTTP method validation. This example is ideal for:

- Proxying requests from internal networks only
- Adding network-level access control without modifying backend code
- Rate limiting and access control for internal HTTP services
- Protecting sensitive internal APIs with network restrictions

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize the allowed IP ranges and backend target as needed
4. Harmony automatically discovers and loads the pipeline

Quick example:
```toml
# pipelines/my-internal-proxy.toml
[pipelines.internal_http_proxy]
description = "Internal HTTP proxy pipeline"
networks = ["http_net"]
endpoints = ["proxy_endpoint"]
middleware = ["access_control", "passthru"]
backends = ["internal_api"]

[backends.internal_api]
service = "http"
target_ref = "my_internal_service"

[targets.my_internal_service]
connection.host = "10.0.1.50"
connection.port = 8080
connection.protocol = "http"
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
- **Bind Address**: 127.0.0.1 (localhost only)
- **Port**: 8080
- **Endpoint**: `/` (all paths)

### Middleware Chain

1. **Access Control Policies**: Production-grade security policies
   - Restrict to internal networks only (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.1)
   - Block admin and internal paths (`/admin/*`, `/internal/*`)
   - Rate limit: 100 requests per minute
   - Allow GET, POST, PUT, DELETE methods

2. **Passthru**: Forward all remaining requests to the backend

### Backend

The pipeline proxies to an internal HTTP service at `127.0.0.1:8888`. Update the `[targets.local_server]` section to point to your actual internal backend.

## Example Request

```bash
# Make a test request (from internal network)
curl http://127.0.0.1:8080/api/data
```

## Security Features

### IP Allowlisting
Restricts access to internal network ranges:
- `10.0.0.0/8` - Private network (Class A)
- `172.16.0.0/12` - Private network (Class B)
- `192.168.0.0/16` - Private network (Class C)
- `127.0.0.1/32` - Localhost

### Path Filtering
Blocks requests to sensitive paths:
- `/admin/*` - Administrative endpoints
- `/internal/*` - Internal service endpoints

### Rate Limiting
- **Limit**: 100 requests per minute per client
- **Window**: 60 seconds

### HTTP Method Filtering
- **Allowed Methods**: GET, POST, PUT, DELETE
- **Denied Methods**: PATCH, OPTIONS, HEAD, etc.

## Files Structure

```
http-internal/
├── config.toml                    # Main proxy configuration
├── pipelines/
│   └── http-internal.toml         # Pipeline definition with policies
└── README.md                      # This file
```
