# Mesh Networking Test Setup

This Docker Compose setup creates a two-node mesh for testing Harmony's mesh networking capabilities.

## Architecture

```
┌─────────────────┐      Mesh (JWT Auth)      ┌─────────────────┐
│     Node B      │ ────────────────────────► │     Node A      │
│  (Entry Point)  │                           │ (Backend Node)  │
│   Port: 8081    │                           │   Port: 8080    │
└─────────────────┘                           └────────┬────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │  Python Server  │
                                              │   Port: 5000    │
                                              └─────────────────┘
```

### Node Roles

- **Node B (Entry Point)**: Receives external HTTP requests on port 8081 and forwards them via mesh egress to Node A. This simulates a gateway that routes traffic into a mesh.

- **Node A (Backend Node)**: Receives mesh traffic via ingress, validates JWT auth, and forwards requests to the Python backend. This simulates a service inside the mesh.

- **Python Server**: Simple HTTP server that echoes request details in JSON format. Verifies that requests successfully traverse the mesh.

## Quick Start

### 1. Build and Start

```bash
cd docker/mesh-test

# Build and start all containers (builds Harmony from source)
docker compose up --build

# Or run in detached mode
docker compose up --build -d
```

### 2. Test the Mesh

```bash
# Test mesh routing: Node B → Node A → Python Backend
curl -i http://localhost:8081/api/test

# Expected response: JSON from Python backend showing the request traversed the mesh
```

### 3. View Logs

```bash
# All containers
docker compose logs -f

# Individual containers
docker compose logs -f node-a
docker compose logs -f node-b
docker compose logs -f python-server
```

### 4. Stop

```bash
docker compose down
```

## Endpoints

| Port  | Service       | Description                          |
|-------|---------------|--------------------------------------|
| 5050  | Python Server | Backend HTTP server (direct access)  |
| 8080  | Node A        | Mesh backend (receives mesh traffic) |
| 8081  | Node B        | Entry point (external requests)      |
| 9080  | Node A Admin  | Management API for Node A            |
| 9081  | Node B Admin  | Management API for Node B            |

## Test Scenarios

### Basic Mesh Routing
```bash
# Request flows: Client → Node B → Mesh → Node A → Python
curl http://localhost:8081/api/test
```

### POST with JSON Body
```bash
curl -X POST http://localhost:8081/api/data \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello mesh!"}'
```

### Direct Backend Access (bypass mesh)
```bash
# Direct to Python (no mesh)
curl http://localhost:5050/api/test

# Direct to Node A (requires mesh auth - will fail without JWT)
curl http://localhost:8080/test
```

### Health Checks
```bash
# Python server health
curl http://localhost:5050/health

# Node A management
curl http://localhost:9080/admin/health

# Node B management  
curl http://localhost:9081/admin/health
```

## Configuration

### Mesh Authentication

Both nodes share a JWT secret for mesh authentication:
```toml
jwt_secret = "mesh-test-secret-key-change-in-production"
```

**⚠️ Warning**: Change this secret for any non-development use.

### Node A Configuration (`configs/node-a/`)
- Defines mesh **ingress** (receives mesh traffic)
- Routes to Python backend
- Validates incoming JWT tokens

### Node B Configuration (`configs/node-b/`)
- Defines mesh **egress** (sends mesh traffic)
- Signs outgoing requests with JWT
- Entry point for external traffic

## Debugging

### Check Container Status
```bash
docker compose ps
```

### View Harmony Logs Inside Container
```bash
docker compose exec node-a cat /tmp/harmony/harmony.log
docker compose exec node-b cat /tmp/harmony/harmony.log
```

### Interactive Shell
```bash
docker compose exec node-a /bin/bash
docker compose exec node-b /bin/bash
```

### Network Inspection
```bash
# Check container IPs
docker network inspect mesh-test_mesh-network
```

## Customization

### Using Local Binary (faster iteration)

Instead of building from source each time, you can mount a locally-built binary:

1. Build Harmony locally:
   ```bash
   cargo build --release
   ```

2. Modify `docker-compose.yml` to mount the binary:
   ```yaml
   volumes:
     - ../../target/release/harmony:/usr/local/bin/harmony
   ```

### Adding More Nodes

To add additional mesh nodes:

1. Create `configs/node-c/` with appropriate config
2. Add new service to `docker-compose.yml`
3. Update mesh definitions to include new ingress/egress points
