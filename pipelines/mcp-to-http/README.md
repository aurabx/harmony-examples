# MCP to HTTP Bridge

## What is this pipeline?

This example demonstrates how to bridge MCP (Model Context Protocol) requests to standard HTTP APIs. MCP is a protocol used by AI agents to discover and interact with external services. This pipeline allows AI agents using MCP to communicate with existing HTTP-based APIs without requiring native MCP support on the backend.

## Overview

MCP (Model Context Protocol) is a standardized protocol for AI agents to:
- Discover available tools and capabilities
- Execute function calls
- Exchange context between agents and services

This pipeline acts as a translation layer, converting MCP JSON-RPC formatted requests to standard HTTP API calls that existing services can understand.

## What This Example Demonstrates

- **Protocol Translation**: Convert MCP JSON-RPC requests to HTTP format
- **AI Agent Integration**: Enable AI agents to use MCP to call standard HTTP APIs
- **JOLT Transformation**: Use JOLT transforms to reshape MCP payloads for HTTP backends
- **Security Controls**: Apply IP restrictions, rate limiting, and content type validation

## Architecture

```
AI Agent (MCP Client)
       |
       | MCP/JSON-RPC Request
       v
Harmony Proxy
       | 1. Extract JSON payload
       | 2. Transform MCP to HTTP format
       | 3. Apply security policies
       v
HTTP Backend API
       |
       | Standard HTTP Response
       v
Harmony Proxy
       |
       | JSON-RPC Response
       v
AI Agent (MCP Client)
```

## Prerequisites

- HTTP Service
- Transform Middleware

## Configuration

- **Proxy ID**: `harmony-mcp-to-http`
- **HTTP Listener**: `127.0.0.1:8090`
- **Endpoint Path**: `/mcp`
- **Backend**: HTTP API at `127.0.0.1:8081`
- **Log File**: `./tmp/harmony_mcp_to_http.log`

## How to Run

### Quick Demo (Recommended)

Run the interactive demo script which starts both Harmony and a mock backend:

```bash
cd pipelines/mcp-to-http
./demo.sh
```

The demo will:
- Start a mock HTTP backend on port 8081
- Start Harmony MCP bridge on port 8090
- Run test requests showing MCP to HTTP transformation
- Display results and logs

### Manual Start

1. From the project root, run:
   ```bash
   cd pipelines/mcp-to-http
   harmony-proxy --config config.toml
   ```

2. The service will start and bind to `127.0.0.1:8090`

3. Ensure your backend HTTP API is running on port 8081

## MCP Request Format

MCP requests are JSON-RPC 2.0 formatted:

```json
{
  "jsonrpc": "2.0",
  "id": "request-001",
  "method": "tools/call",
  "params": {
    "name": "get_user",
    "arguments": {
      "user_id": "12345"
    }
  }
}
```

## Testing

Send an MCP request to the bridge endpoint:

```bash
curl -X POST http://127.0.0.1:8090/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "req-001",
    "method": "tools/call",
    "params": {
      "name": "api_call",
      "arguments": {
        "endpoint": "/users",
        "method": "GET"
      }
    }
  }'
```

### Expected Behavior

1. Harmony receives the MCP formatted request
2. The transform middleware converts MCP structure to HTTP format
3. Request is forwarded to the HTTP backend at `127.0.0.1:8081/api`
4. Backend response is wrapped back into MCP JSON-RPC response format
5. Response returned to the AI agent

## Middleware Chain

1. **mcp_security** - Validates source IP, enforces POST/JSON only
2. **json_extractor** - Extracts and validates JSON payload
3. **mcp_transform** - Applies JOLT transformation to convert MCP to HTTP format

## Transform

The JOLT transform (`transforms/mcp-to-http/mcp_to_http.json`) maps MCP fields to HTTP API format:
- Extracts `method`, `params`, and `id` from MCP request
- Transforms nested `params.arguments` into HTTP request parameters
- Preserves `jsonrpc` version for response formatting

## Security Considerations

- **IP Allowlisting**: Restricts access to internal networks only (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, localhost)
- **Method Restriction**: Only POST requests allowed (MCP standard)
- **Content Type**: Only application/json accepted
- **Rate Limiting**: Can be added via policies

## Files

- `config.toml` - Main proxy configuration
- `pipelines/mcp-to-http.toml` - Pipeline definition
- `transforms/mcp_to_http.json` - JOLT transform specification
- `demo.sh` - Interactive demo script with mock backend


## Use Cases

- **AI Agent Integration**: Allow Claude, GPT, or other AI agents to use MCP to call your existing REST APIs
- **Legacy API Modernization**: Expose existing HTTP services through MCP without code changes
- **Multi-Agent Systems**: Enable different AI agents to communicate with shared backend services
- **API Gateway**: Centralize and secure AI-to-API communication

## References

- [Model Context Protocol Specification](https://modelcontextprotocol.io)
- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [JOLT Transformation Documentation](https://docs.runbeam.io/harmony/transforms)
