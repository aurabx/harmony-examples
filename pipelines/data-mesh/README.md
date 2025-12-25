# Data Mesh Example

## What is this pipeline?

This example demonstrates Harmony's Data Mesh feature for secure inter-proxy communication. A Data Mesh enables multiple Harmony instances to communicate with each other as a distributed network, with secure authentication and routing between mesh members.

This example is ideal for:

- Understanding mesh networking concepts
- Setting up multi-organization healthcare data exchange
- Configuring ingress/egress for inter-service communication
- Learning about mesh providers (local vs Runbeam Cloud)

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Create a `mesh/` directory alongside your `pipelines/` directory
3. Copy the configuration files from this example
4. Configure your network, endpoint, and mesh settings
5. Harmony automatically discovers and loads all configurations

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Data Mesh Documentation](https://docs.runbeam.io/harmony/configuration/mesh)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- **Mesh Configuration**: Grouping ingress and egress points
- **Ingress Definitions**: Exposing endpoints for other mesh members
- **Egress Definitions**: Routing to other mesh members' backends
- **URL Mapping**: Binding external URLs to internal endpoints
- **Multi-Network Setup**: Internal and mesh-external networks

## Data Mesh Concepts

### Mesh

A mesh groups related ingress and egress definitions together. It specifies:
- **Protocol Type**: `http` or `http3`
- **Provider**: `local` (self-managed) or `runbeam` (cloud-managed)

### Ingress

An ingress allows other mesh members to send requests to this proxy:
- Maps external URLs to internal endpoints
- Other proxies use these URLs to route requests here

### Egress

An egress allows this proxy to send requests to other mesh members:
- References a backend for outgoing requests
- Enables secure communication to partner systems

## Prerequisites

None - this example runs standalone for demonstration.

For production mesh networking:
- TLS certificates for HTTPS/HTTP3
- Runbeam Cloud account (for cloud-managed meshes)
- Partner organization mesh configurations

## Configuration

- **Proxy ID**: `harmony-mesh-node`
- **Internal Network**: `127.0.0.1:8080` (local services)
- **Mesh Network**: `0.0.0.0:8443` (mesh traffic)
- **Log File**: `./tmp/harmony_mesh.log`
- **Storage**: `./tmp`

### Mesh Configuration

| Component | Name | Description |
|-----------|------|-------------|
| Mesh | `healthcare` | Healthcare data mesh (HTTP/3, local provider) |
| Ingress | `fhir_ingress` | FHIR R4 API ingress |
| Ingress | `dicomweb_ingress` | DICOMweb ingress |
| Egress | `partner_egress` | Egress to partner FHIR server |
| Egress | `imaging_egress` | Egress to imaging center |

## How to Run

1. From the project root, run:
   ```bash
   cargo run -- --config examples/data-mesh/config.toml
   ```

2. The service will start and bind to:
   - Internal: `127.0.0.1:8080`
   - Mesh: `0.0.0.0:8443`

## Testing

### Internal API Access

```bash
# Access the internal FHIR endpoint
curl -v http://127.0.0.1:8080/fhir/r4/Patient

# Access the mesh-exposed FHIR endpoint
curl -v http://127.0.0.1:8443/mesh/fhir/r4/Patient
```

### Expected Behavior

The echo backend returns request metadata, demonstrating how requests flow through the pipeline. In production:

1. **Ingress Flow**: Requests from mesh members arrive at the mesh network, are validated via mesh authentication, and routed to the appropriate endpoint.

2. **Egress Flow**: Outgoing requests to partner systems are authenticated with mesh JWT tokens and routed through the configured backend.

## Files

- `config.toml` - Main configuration file with mesh_path setting
- `pipelines/api.toml` - Pipeline, endpoint, and backend definitions
- `mesh/healthcare.toml` - Mesh, ingress, and egress definitions
- `tmp/` - Created at runtime for logs and temporary storage

## Production Considerations

### TLS/HTTPS

For production, configure TLS certificates:

```toml
[network.mesh_external.http]
bind_address = "0.0.0.0"
bind_port = 443
cert_path = "/etc/harmony/certs/fullchain.pem"
key_path = "/etc/harmony/certs/privkey.pem"
```

### HTTP/3

For HTTP/3 support, add an http3 block:

```toml
[network.mesh_external.http3]
bind_address = "0.0.0.0"
bind_port = 443
cert_path = "/etc/harmony/certs/fullchain.pem"
key_path = "/etc/harmony/certs/privkey.pem"
```

### Mesh Authentication (Future)

Mesh authentication middleware will validate JWT tokens from mesh members:

```toml
[middleware.mesh_auth]
type = "mesh_auth"

[middleware.mesh_auth.options]
mesh = "healthcare"
```

### Runbeam Cloud Provider

For cloud-managed mesh authentication:

```toml
[mesh.healthcare]
type = "http3"
provider = "runbeam"  # JWT tokens fetched from Runbeam Cloud
# ...
```

## Next Steps

After understanding this example, explore:
- `examples/fhir/` - FHIR protocol handling
- `examples/http3-listener/` - HTTP/3 configuration
- `examples/transform/` - Data transformation with JOLT
