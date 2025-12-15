# HTTP-to-HTTP Proxy Pipeline

## What is this pipeline?

This pipeline demonstrates a comprehensive HTTP-to-HTTP proxy with advanced access control policies. It combines network-level IP restrictions, path filtering, rate limiting, and HTTP method validation for production-grade security. This example is ideal for:

- Proxying HTTP requests with comprehensive security policies
- Restricting access to internal networks while blocking sensitive paths
- Rate limiting and traffic control for HTTP services
- Demonstrating combined security rule evaluation

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize the allowed IP ranges, blocked paths, and backend target
4. Harmony automatically discovers and loads the pipeline

Quick example:
```toml
# pipelines/my-http-proxy.toml
[pipelines.http_proxy]
description = "Comprehensive HTTP proxy pipeline"
networks = ["http_net"]
endpoints = ["proxy_endpoint"]
middleware = ["access_control", "passthru"]
backends = ["backend_service"]

[backends.backend_service]
service = "http"
target_ref = "my_backend"

[targets.my_backend]
connection.host = "backend.internal"
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
- **Bind Address**: 127.0.0.1 (localhost)
- **Port**: 8080
- **Endpoint**: `/` (all paths)

### Middleware Chain

1. **Access Control Policies**: Comprehensive security policies combining multiple rule types
   - IP allowlisting for internal networks only
   - Block admin and internal paths (`/admin/*`, `/internal/*`)
   - Rate limit: 100 requests per minute
   - Allow GET, POST, PUT, DELETE methods

2. **Passthru**: Forward all remaining requests to the backend

### Backend

The pipeline proxies to an HTTP service at `127.0.0.1:8888`. Update the `[targets.local_server]` section to point to your actual backend.

## Example Request

```bash
# Make a test request (from internal network)
curl http://127.0.0.1:8080/api/v1/data
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

## Rule Evaluation Order

Policies are evaluated based on rule weight and configuration:
1. IP allowlisting (weight 90) - Highest priority network restriction
2. Path filtering (weight 95) - Block sensitive paths
3. Method filtering (weight 80) - Restrict HTTP methods
4. Rate limiting (weight 50) - Traffic control

This weighted evaluation ensures network security is enforced first, followed by path-level restrictions.

## Files Structure

```
http-http/
├── config.toml                    # Main proxy configuration
├── pipelines/
│   └── http-http.toml             # Pipeline definition with comprehensive policies
└── README.md                      # This file
```

## Customization

### Modify Allowed Networks

Edit the IP allowlisting rule in your pipeline configuration:
```toml
[rules.internal_networks.options]
ip_addresses = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "127.0.0.1/32",
    "203.0.113.0/24"  # Add custom range
]
```

### Adjust Rate Limiting

Change the rate limit parameters:
```toml
[rules.rate_limit.options]
max_requests = 1000
window_seconds = 60
```

### Allow Additional Methods

Update the allowed HTTP methods:
```toml
[rules.method_filter.options]
methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
```
