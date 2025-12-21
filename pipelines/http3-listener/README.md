# HTTP/3 Listener Example

## What is this pipeline?

This example demonstrates receiving HTTP/3 (QUIC) requests on Harmony's frontend and forwarding them to a standard HTTP backend. This is useful when you want to:

- **Serve modern clients**: Accept HTTP/3 connections from browsers and clients that support it
- **Terminate QUIC**: Handle QUIC/TLS 1.3 at the edge, forward plain HTTP internally
- **Gradual migration**: Add HTTP/3 support without changing your backend infrastructure
- **Performance at the edge**: Benefit from HTTP/3's reduced latency for client connections

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure your TLS certificates for HTTP/3
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- HTTP/3 (QUIC) listener receiving incoming connections
- TLS 1.3 termination at the Harmony edge
- Protocol translation from HTTP/3 to HTTP/1.x
- Dual-protocol support (HTTP/1.x and HTTP/3 on same network)

## Prerequisites

- TLS certificate and private key in PEM format
- Backend HTTP service to forward requests to
- HTTP/3-capable client for testing (e.g., curl with `--http3` flag, modern browsers)

## Configuration

- **Proxy ID**: `harmony-http3-listener`
- **HTTP/3 Listener**: `0.0.0.0:443` (UDP/QUIC)
- **HTTP Listener**: `127.0.0.1:8080` (TCP, optional fallback)
- **Endpoint Path**: `/api`
- **Backend**: HTTP connection to `localhost:9000`
- **Log File**: `./tmp/harmony_http3_listener.log`

### HTTP/3 Network Configuration

```toml
[network.http3_net.http3]
bind_address = "0.0.0.0"    # UDP bind address
bind_port = 443              # Standard HTTPS port
cert_path = "./certs/server.crt"   # TLS certificate (PEM)
key_path = "./certs/server.key"    # TLS private key (PEM)
```

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `bind_address` | string | Yes | UDP address to bind (e.g., "0.0.0.0") |
| `bind_port` | integer | Yes | UDP port for QUIC (typically 443) |
| `cert_path` | string | Yes | Path to TLS certificate chain (PEM) |
| `key_path` | string | Yes | Path to TLS private key (PEM) |

## How to Run

1. Generate TLS certificates (for testing):
   ```bash
   mkdir -p certs
   openssl req -x509 -newkey rsa:4096 -keyout certs/server.key \
     -out certs/server.crt -days 365 -nodes \
     -subj "/CN=localhost"
   ```

2. Start a backend HTTP server (for testing):
   ```bash
   # Simple Python server
   python3 -m http.server 9000
   ```

3. From the project root, run Harmony:
   ```bash
   harmony --config examples/http3-listener/config.toml
   ```

4. The service will start with:
   - HTTP/3 on UDP port 443
   - HTTP/1.x on TCP port 8080 (fallback)

## Testing

### With HTTP/3 (requires curl with HTTP/3 support)

```bash
# Test HTTP/3 connection (use --insecure for self-signed certs)
curl --http3 -k https://localhost:443/api

# POST with JSON data over HTTP/3
curl --http3 -k -X POST https://localhost:443/api/resource \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello via HTTP/3!"}'
```

### With HTTP/1.x (fallback)

```bash
# Standard HTTP request
curl http://127.0.0.1:8080/api
```

### Expected Behavior

1. HTTP/3 client connects to Harmony via QUIC on port 443
2. TLS 1.3 handshake completes (built into QUIC)
3. Request is processed through the pipeline
4. Harmony forwards to backend via standard HTTP
5. Response returns to client over HTTP/3

## Dual Protocol Support

This example shows that a single network can serve both HTTP/1.x and HTTP/3:

```toml
# TCP-based HTTP/1.x and HTTP/2
[network.http3_net.http]
bind_address = "127.0.0.1"
bind_port = 8080

# UDP-based HTTP/3 (QUIC)
[network.http3_net.http3]
bind_address = "0.0.0.0"
bind_port = 443
```

Both adapters serve the same pipelines and endpoints.

## Files

- `config.toml` - Main configuration file with HTTP/3 listener
- `pipelines/http3-listener.toml` - Pipeline definition
- `certs/` - TLS certificates (you must create these)
- `tmp/` - Created at runtime for logs and temporary storage

## Troubleshooting

**"Certificate not found" error?**
- Ensure `cert_path` and `key_path` point to valid PEM files
- Generate test certificates using the OpenSSL command above

**Client can't connect via HTTP/3?**
- Verify UDP port 443 is open (not just TCP)
- Check firewall rules allow UDP traffic
- Ensure client supports HTTP/3 (curl needs `--http3` flag)

**Connection works on HTTP but not HTTP/3?**
- HTTP/3 uses UDP, HTTP/1.x uses TCP - check both are accessible
- Some networks/firewalls block UDP on port 443

## Next Steps

After understanding HTTP/3 listeners, explore:
- `examples/http3-backend/` - HTTP/3 backend connectivity
- `examples/http-http/` - Standard HTTP proxy
- `examples/fhir/` - Healthcare FHIR integration
