# SOAP to JSON Pipeline Example

## What is this pipeline?

This example demonstrates a complete HTTP-to-HTTP pipeline that converts SOAP/XML requests to JSON. This example is ideal for:

- Modernizing legacy SOAP APIs with JSON
- Adding authentication to unsecured SOAP services
- Converting and restructuring SOAP messages
- Building bridges between SOAP and REST systems

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure JWT authentication and backend target
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

This example demonstrates a complete HTTP-to-HTTP pipeline that:

1. **Receives SOAP/XML requests** via HTTP POST to `/soap`
2. **Automatically converts XML to JSON** based on Content-Type header detection
3. **Authenticates requests** using JWT Bearer token authentication  
4. **Transforms data structure** using JOLT for field reorganization
5. **Forwards to HTTP backend** at `http://127.0.0.1:9000`

## Use Case

This pipeline is ideal for modernizing legacy SOAP APIs by:
- Converting SOAP/XML messages to REST/JSON
- Adding authentication layers to unsecured services
- Restructuring data from legacy formats to modern JSON schemas
- Proxying to microservices that expect JSON

## Pipeline Flow

```
Client (SOAP/XML) 
  → Endpoint (/soap)
  → Auto XML→JSON (Content-Type: application/xml)
  → JWT Auth (RS256/HS256)
  → JOLT Transform
  → HTTP Backend (JSON)
```

## Configuration

### Network
- **Bind Address**: 127.0.0.1
- **Port**: 8086
- **Endpoint**: `/soap`
- **Methods**: POST

### Middleware Chain

**Note:** XML to JSON conversion happens automatically when the HTTP service detects `Content-Type: application/xml`, `text/xml`, or `application/soap+xml`. No explicit middleware needed!

1. **jwt_auth**: Validates JWT Bearer tokens (RS256 or HS256)
   - Header: `Authorization: Bearer <jwt-token>`
   - RS256 (recommended): Uses RSA public key for verification
   - HS256 (dev/test): Uses shared secret
   - Validates signature, expiration, issuer, and audience claims

2. **jolt_transform**: Reorganizes JSON structure
   - Flattens nested SOAP structures
   - Renames fields to RESTful conventions
   - Adds default values

### Backend
- **URL**: http://127.0.0.1:9000

## Example Request

### Input (SOAP/XML)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <customerId>CUST-12345</customerId>
    <customerName>John Doe</customerName>
    <orderDetails>
      <orderId>ORD-98765</orderId>
      <orderDate>2025-11-18</orderDate>
      <items>
        <item>
          <productId>PROD-001</productId>
          <productName>Widget</productName>
          <quantity>5</quantity>
          <price>29.99</price>
        </item>
      </items>
      <totalAmount>149.95</totalAmount>
    </orderDetails>
    <shippingAddress>
      <street>123 Main St</street>
      <city>Springfield</city>
      <state>IL</state>
      <zipCode>62701</zipCode>
      <country>USA</country>
    </shippingAddress>
  </soap:Body>
</soap:Envelope>
```

### Output (JSON to Backend)
```json
{
  "customer": {
    "id": "CUST-12345",
    "name": "John Doe",
    "type": "customer"
  },
  "order": {
    "id": "ORD-98765",
    "date": "2025-11-18",
    "items": [
      {
        "product_id": "PROD-001",
        "product_name": "Widget",
        "quantity": 5,
        "price": 29.99
      }
    ],
    "total_amount": 149.95,
    "status": "pending",
    "currency": "USD"
  },
  "shipping": {
    "street": "123 Main St",
    "city": "Springfield",
    "state": "IL",
    "zip_code": "62701",
    "country": "USA",
    "method": "standard"
  }
}
```

## Testing

```bash
# Start the pipeline
harmony-proxy --config config.toml

# Send a test request with SOAP/XML
curl -X POST http://127.0.0.1:8086/soap \
  -H "Authorization: Bearer your-token-here" \
  -H "Content-Type: application/xml" \
  -d @test-request.xml

# Or with SOAP-specific Content-Type
curl -X POST http://127.0.0.1:8086/soap \
  -H "Authorization: Bearer your-token-here" \
  -H "Content-Type: application/soap+xml" \
  -d @test-request.xml
```

**Important:** The `Content-Type` header must be set to `application/xml`, `text/xml`, or `application/soap+xml` for automatic XML-to-JSON conversion. The HTTP service detects this header and converts the XML body to JSON before passing it to the middleware chain.

## Customization

### Modify the Transform
Edit `transforms/soap-to-json-transform.json` to change field mappings:
- Add new field mappings in the "shift" operation
- Add default values in the "default" operation
- Chain multiple operations for complex transformations

### Change Authentication
Modify `[middleware.jwt_auth]` section (options are on the middleware itself, not in a sub-table):
- **For Production**: Use RS256 with `public_key_path` pointing to your RSA public key (PEM format)
- **For Development**: Use HS256 with `use_hs256 = true` and `hs256_secret`
- Configure `issuer` and `audience` to match your auth provider
- Adjust `leeway_secs` for clock skew tolerance

### Adjust Backend
Update `[backends.http_backend.options]` section:
- Change `base_url` to your service endpoint
- Note: HTTP service handles timeouts and header forwarding automatically

## Files

- `config.toml` - Main proxy configuration
- `pipelines/soap-to-json.toml` - Pipeline definition and middleware chain
- `transforms/soap-to-json-transform.json` - JOLT transformation specification

## Production Notes

- Update Bearer token validation with real auth service
- Configure proper logging and monitoring
- Adjust timeouts based on backend performance
- Add rate limiting and circuit breakers as needed
- Enable HTTPS/TLS for production traffic
