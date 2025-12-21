# HTTP/3 Backend Example

## What is this pipeline?

This example demonstrates using HTTP/3 (QUIC) to connect to upstream backend servers. It shows how to configure Harmony to proxy HTTP requests to backends using HTTP/3 transport, which provides benefits like:

- **No head-of-line blocking**: Unlike HTTP/2 over TCP, packet loss on one stream doesn't block others
- **Faster connections**: 0-RTT connection resumption and reduced handshake latency
- **Connection migration**: Connections survive network changes (useful for mobile clients)
- **Built-in encryption**: HTTP/3 always uses TLS 1.3

This example is ideal for:

- Connecting to modern APIs that support HTTP/3
- High-latency or lossy network conditions
- Mobile applications where network changes are common
- Services requiring low-latency connections

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure your HTTP/3 backend host and options
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- HTTP/3 backend connectivity using QUIC transport
- Proxying HTTP/1.x requests to HTTP/3 backends
- TLS 1.3 encryption (always enabled with HTTP/3)
- Custom CA certificate configuration for self-signed servers

## Prerequisites

- Backend server that supports HTTP/3 (e.g., Cloudflare, Google, or any QUIC-enabled server)
- For self-signed backends: CA certificate in PEM format

## Configuration

- **Proxy ID**: `harmony-http3-backend`
- **HTTP Listener**: `127.0.0.1:8080`
- **Endpoint Path**: `/api`
- **Backend**: HTTP/3 connection to `cloudflare-quic.com:443`
- **Log File**: `./tmp/harmony_http3_backend.log`

### HTTP/3 Backend Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `host` | string | Yes | - | Target server hostname |
| `port` | integer | No | 443 | Target server port |
| `base_path` | string | No | - | Base URL path prefix |
| `ca_cert_path` | string | No | - | Custom CA certificate (PEM) |
| `timeout_secs` | integer | No | 30 | Request timeout in seconds |

## How to Run

1. From the project root, run:
   ```bash
   harmony --config examples/http3-backend/config.toml
   ```

2. The service will start and bind to `127.0.0.1:8080`

## Testing

Send HTTP requests to the proxy endpoint:

```bash
# Basic GET request - proxied via HTTP/3 to backend
curl -v http://127.0.0.1:8080/api

# POST with JSON data
curl -X POST http://127.0.0.1:8080/api/resource \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello via HTTP/3!"}'
```

### Expected Behavior

1. Your HTTP/1.x request arrives at Harmony on port 8080
2. Harmony connects to the backend using HTTP/3 over QUIC
3. The request is forwarded and the response returned
4. You receive the response over HTTP/1.x

Note: The client doesn't need to support HTTP/3 - Harmony handles the protocol translation.

## Using a Custom CA Certificate

For backends with self-signed or custom CA certificates:

```toml
[backends.my_h3_backend]
service = "http3"
[backends.my_h3_backend.options]
host = "internal.example.com"
port = 8443
ca_cert_path = "./certs/my-ca.pem"
```

The CA certificate must be in PEM format.

## Files

- `config.toml` - Main configuration file
- `pipelines/http3-backend.toml` - Pipeline definition
- `tmp/` - Created at runtime for logs and temporary storage

## Troubleshooting

**Connection refused or timeout?**
- Verify the backend server supports HTTP/3
- Check if UDP port 443 is open (HTTP/3 uses QUIC over UDP)
- Try a known HTTP/3 server like `cloudflare-quic.com`

**TLS certificate errors?**
- For self-signed certs, provide the CA certificate via `ca_cert_path`
- Ensure the certificate is in PEM format
- Verify the hostname matches the certificate

**Slow connections?**
- First connection may be slower (QUIC handshake)
- Subsequent connections benefit from 0-RTT resumption

## Next Steps

After understanding HTTP/3 backends, explore:
- `examples/http-http/` - Standard HTTP backend proxy
- `examples/transform/` - Data transformation with JOLT
- `examples/fhir/` - Healthcare FHIR integration
