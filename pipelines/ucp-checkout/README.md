# UCP Checkout Example

## What is this pipeline?

This example demonstrates implementing the Universal Commerce Protocol (UCP) checkout capability using Harmony as a UCP-compliant commerce gateway. This example is ideal for:

- Building agentic commerce integrations
- Understanding UCP checkout session flows
- Implementing standardized commerce APIs
- Enabling AI agents to complete purchases on behalf of users

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Customize UCP profile and payment handlers for your business
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## About Universal Commerce Protocol (UCP)

<cite index="4-3">UCP defines building blocks for agentic commerce—from discovering and buying to post purchase experiences—allowing the ecosystem to interoperate through one standard, without custom builds.</cite>

<cite index="5-1,5-2">UCP is designed to enable agentic commerce where AI agents act on behalf of users to discover products, fill carts, and complete purchases securely, with support for advanced security patterns like AP2 mandates and verifiable credentials.</cite>

<cite index="7-2,7-3">The primary transport for UCP is HTTP/1.1 (or higher) using RESTful patterns, with requests and responses using application/json.</cite>

**Resources:**
- Official Site: [https://ucp.dev](https://ucp.dev)
- GitHub: [https://github.com/Universal-Commerce-Protocol/ucp](https://github.com/Universal-Commerce-Protocol/ucp)
- Specification: [https://ucp.dev/specification/overview/](https://ucp.dev/specification/overview/)

## What This Example Demonstrates

### UCP Capabilities
- **Profile Discovery** - `.well-known/ucp/profile` endpoint for capability advertisement
- **Checkout Sessions** - Create, update, and complete checkout flows
- **Payment Handler Negotiation** - Dynamic payment method selection
- **Cart Calculations** - Line items, totals, tax, shipping
- **Extensibility** - Discount extension support

### Harmony Features
- HTTP service with RESTful endpoints
- JOLT transform middleware for UCP schema mapping
- JSON extraction and parsing
- Session-like data flow through middleware chains
- Echo backend for demonstration

## Prerequisites

- **Harmony Proxy** (Rust-based runtime)
- No external dependencies - this example is fully self-contained

## Configuration

- **Proxy ID**: `harmony-ucp-checkout`
- **HTTP Listener**: `0.0.0.0:8085`
- **Management API**: `127.0.0.1:9095`
- **Log File**: `./tmp/ucp_checkout.log`
- **Storage**: `./tmp`

## UCP Endpoints

### Profile Discovery
```
GET /.well-known/ucp/profile
```
Returns business profile with supported capabilities, services, and payment instruments.

### Checkout Session Create
```
POST /v1/checkout/sessions
```
Creates a new checkout session with line items and buyer information.

### Checkout Session Update
```
PATCH /v1/checkout/sessions/{id}
```
Updates an existing checkout session (add/remove items, update quantities).

### Checkout Session Complete
```
POST /v1/checkout/sessions/{id}/complete
```
Completes the checkout and creates an order.

## How to Run

1. From the `pipelines/ucp-checkout` directory, run:
   ```bash
   harmony-proxy --config config.toml
   ```

2. The service will start and bind to `0.0.0.0:8085`

## Testing

### 1. Discover UCP Profile

```bash
curl http://localhost:8085/.well-known/ucp/profile | jq
```

**Expected Response:**
```json
{
  "ucp": {
    "version": "2026-01-11",
    "services": {
      "dev.ucp.shopping": {
        "version": "2026-01-11",
        "spec": "https://ucp.dev/specification/overview",
        "rest": {
          "schema": "https://ucp.dev/services/shopping/rest.openapi.json",
          "endpoint": "http://localhost:8085/v1"
        }
      }
    },
    "capabilities": [
      {
        "name": "dev.ucp.shopping.checkout",
        "version": "2026-01-11",
        "spec": "https://ucp.dev/specification/checkout",
        "schema": "https://ucp.dev/schemas/shopping/checkout.json"
      },
      {
        "name": "dev.ucp.shopping.discounts",
        "version": "2026-01-11",
        "spec": "https://ucp.dev/specification/discounts",
        "schema": "https://ucp.dev/schemas/shopping/discounts.json",
        "extends": "dev.ucp.shopping.checkout"
      }
    ]
  },
  "business": {
    "id": "harmony-demo-merchant",
    "name": "Harmony Demo Store",
    "website": "https://example.com"
  }
}
```

### 2. Create Checkout Session

```bash
curl -X POST http://localhost:8085/v1/checkout/sessions \
  -H "Content-Type: application/json" \
  -H 'UCP-Agent: profile="https://agent.example/profiles/shopping-agent.json"' \
  -d '{
    "line_items": [
      {
        "id": "li_1",
        "item": {
          "id": "item_monos_carryon",
          "title": "Monos Carry-On Pro suitcase",
          "price": 26550,
          "description": "Premium lightweight carry-on luggage",
          "image_url": "https://example.com/images/monos-carryon.jpg"
        },
        "quantity": 1
      }
    ],
    "buyer": {
      "email": "e.beckett@example.com",
      "first_name": "Elisa",
      "last_name": "Beckett"
    }
  }' | jq
```

**Expected Response:**
```json
{
  "ucp": {
    "version": "1.0.0"
  },
  "id": "chk_123456789",
  "status": "ready_for_complete",
  "currency": "USD",
  "buyer": {
    "email": "e.beckett@example.com",
    "first_name": "Elisa",
    "last_name": "Beckett"
  },
  "line_items": [
    {
      "id": "li_1",
      "item": {
        "id": "item_monos_carryon",
        "title": "Monos Carry-On Pro suitcase",
        "price": 26550,
        "description": "Premium lightweight carry-on luggage",
        "image_url": "https://example.com/images/monos-carryon.jpg"
      },
      "quantity": 1
    }
  ],
  "totals": [
    {
      "type": "subtotal",
      "label": "Subtotal",
      "amount": 26550
    },
    {
      "type": "tax",
      "label": "Tax (10%)",
      "amount": 2655
    },
    {
      "type": "shipping",
      "label": "Shipping",
      "amount": 995
    },
    {
      "type": "total",
      "label": "Total",
      "amount": 30200
    }
  ],
  "payment": {
    "handlers": [
      {
        "id": "google-pay-handler",
        "name": "com.google.pay",
        "version": "2026-01-11",
        "spec": "https://pay.google.com/gp/p/ucp/2026-01-11/",
        "config_schema": "https://pay.google.com/gp/p/ucp/2026-01-11/schemas/config.json",
        "instrument_schemas": [
          "https://pay.google.com/gp/p/ucp/2026-01-11/schemas/card_payment_instrument.json"
        ],
        "config": {
          "merchant_info": {
            "merchant_id": "demo-merchant-123",
            "merchant_name": "Harmony Demo Store"
          },
          "allowed_payment_methods": [
            {
              "type": "CARD",
              "parameters": {
                "allowed_card_networks": ["VISA", "MASTERCARD", "AMEX"]
              }
            }
          ]
        }
      },
      {
        "id": "shop-pay-handler",
        "name": "dev.shopify.shop_pay",
        "version": "2026-01-11",
        "spec": "https://shopify.dev/ucp/shop_pay",
        "config_schema": "https://shopify.dev/ucp/schemas/shop_pay_config.json",
        "instrument_schemas": [
          "https://shopify.dev/ucp/schemas/shop_pay_instrument.json"
        ],
        "config": {
          "merchant_id": "demo-merchant-123"
        }
      }
    ],
    "required_fields": [
      {
        "field": "billing_address",
        "type": "address",
        "required": true
      }
    ]
  },
  "links": [
    {
      "rel": "self",
      "href": "/v1/checkout/sessions/{id}"
    },
    {
      "rel": "complete",
      "href": "/v1/checkout/sessions/{id}/complete"
    }
  ]
}
```

### 3. Complete Checkout Session

```bash
curl -X POST http://localhost:8085/v1/checkout/sessions/chk_123456789/complete \
  -H "Content-Type: application/json" \
  -d '{
    "payment_token": "tok_visa_4242",
    "payment_method": "google_pay"
  }' | jq
```

**Expected Response:**
```json
{
  "ucp": {
    "version": "1.0.0"
  },
  "id": "order_987654321",
  "status": "confirmed",
  "checkout_session_id": "chk_123456789",
  "payment": {
    "token": "tok_visa_4242",
    "method": "google_pay"
  },
  "confirmation": {
    "number": "ORD-987654321",
    "timestamp": "2024-01-01T00:00:00Z",
    "status": "processing"
  },
  "next_steps": [
    {
      "action": "track_shipment",
      "url": "/v1/orders/{id}/tracking"
    },
    {
      "action": "view_receipt",
      "url": "/v1/orders/{id}/receipt"
    }
  ]
}
```

## Architecture

### Request Flow

```
AI Agent/Platform
       ↓
[Profile Discovery] → Discover capabilities
       ↓
[Create Session] → Initialize cart with line items
       ↓
[Transform: session_init] → Build UCP session structure
       ↓
[Transform: calculate_totals] → Calculate subtotal, tax, shipping, total
       ↓
[Transform: payment_handlers] → Negotiate available payment methods
       ↓
[Complete Session] → Submit payment token
       ↓
[Transform: session_complete] → Generate order confirmation
       ↓
Commerce Backend (Echo)
```

### Middleware Chains

**Profile Discovery:**
- `profile_response` (transform) - Builds UCP profile JSON

**Checkout Create:**
- `json_extract` - Parse incoming JSON
- `session_init` (transform) - Initialize session structure
- `calculate_totals` (transform) - Calculate cart totals
- `payment_handlers` (transform) - Add payment handler options

**Checkout Complete:**
- `json_extract` - Parse payment data
- `session_complete` (transform) - Generate order confirmation

## JOLT Transforms

### `profile_response.json`
Generates UCP profile with business info, capabilities, services, and payment instruments.

### `session_init.json`
Transforms incoming line items and buyer data into UCP checkout session format with session ID and status.

### `calculate_totals.json`
Calculates subtotal, tax (10%), shipping ($9.95), and total amounts. In production, this would integrate with tax/shipping calculation services.

### `payment_handlers.json`
Adds payment handler negotiation data including Google Pay, Shop Pay, and tokenized card options with their configurations.

### `session_complete.json`
Transforms payment submission into order confirmation with order ID, confirmation number, and next steps.

## UCP Concepts Demonstrated

### 1. Capability Discovery
<cite index="5-12">Businesses declare their supported capabilities in a standardized profile, allowing platforms to autonomously discover and configure themselves.</cite>

### 2. Payment Handler Negotiation
<cite index="7-4,7-5">UCP adopts a decoupled architecture for payments to solve the "N-to-N" complexity problem between platforms, businesses, and payment credential providers, separating Payment Instruments (what is accepted) from Payment Handlers (the specifications for how instruments are processed).</cite>

### 3. Transport Agnostic
<cite index="5-6,5-7">The protocol is designed to work across various transports. Businesses can offer capabilities via REST APIs, MCP (Model Context Protocol), or A2A, depending on their infrastructure.</cite>

### 4. Extensibility
<cite index="5-3,5-4">UCP defines capabilities such as "Checkout" or "Identity Linking" that businesses implement to enable easy integration, with specific extensions that can be added to enhance the consumer experience without bloating the capability definitions.</cite>

## Files

```
pipelines/ucp-checkout/
├── config.toml                          # Main configuration
├── README.md                            # This file
├── pipelines/
│   ├── profile.toml                     # Profile discovery endpoint
│   ├── checkout-create.toml             # Session creation endpoint
│   └── checkout-update.toml             # Session update/complete endpoints
└── transforms/
    ├── profile_response.json            # UCP profile structure
    ├── session_init.json                # Session initialization
    ├── calculate_totals.json            # Cart totals calculation
    ├── payment_handlers.json            # Payment handler negotiation
    └── session_complete.json            # Order confirmation
```

## Customization

### Adding Your Business Profile
Edit `transforms/profile_response.json` to set:
- Business ID, name, website
- Supported capabilities and extensions
- Service endpoints
- Payment instruments

### Implementing Real Tax/Shipping
Replace `calculate_totals.json` with integration to tax calculation services (Avalara, TaxJar) and shipping rate APIs.

### Adding Payment Providers
Modify `payment_handlers.json` to include your actual payment provider configurations, API keys, and tokenization endpoints.

### Extending with UCP Extensions
Add support for additional UCP extensions:
- `dev.ucp.shopping.fulfillment` - Delivery options
- `dev.ucp.shopping.buyer_consent` - User consent tracking
- `dev.ucp.shopping.ap2_mandate` - Cryptographic payment proofs

## Production Considerations

This example uses mock/echo backends for demonstration. For production:

1. **State Management** - Implement persistent session storage (Redis, database)
2. **Authentication** - Add OAuth 2.0 for identity linking capability
3. **Payment Processing** - Integrate real payment gateways (Stripe, Adyen)
4. **Tax Calculation** - Connect to tax services
5. **Inventory Management** - Validate product availability
6. **Order Management** - Implement order creation and tracking
7. **Security** - Add rate limiting, input validation, encryption
8. **Monitoring** - Track checkout conversion, abandonment rates

## UCP Ecosystem

This example demonstrates how Harmony can serve as:
- **UCP Business Backend** - Merchant's commerce system exposing UCP endpoints
- **UCP Gateway** - Translation layer between existing systems and UCP
- **UCP Aggregator** - Route requests across multiple merchant backends

## Next Steps

- Explore the [UCP Specification](https://ucp.dev/specification/overview/)
- Review [UCP GitHub samples](https://github.com/Universal-Commerce-Protocol/ucp)
- Implement Identity Linking capability for account association
- Add Order Management capability for post-purchase tracking
- Integrate with Model Context Protocol (MCP) for AI assistant support

## Support

- **UCP Documentation**: [https://ucp.dev](https://ucp.dev)
- **Harmony Documentation**: [https://docs.runbeam.cloud](https://docs.runbeam.cloud)
- **Issues**: [GitHub Issues](https://github.com/runbeam/harmony-examples/issues)

<citations>
<document>
<document_type>WEB_PAGE</document_type>
<document_id>https://ucp.dev/</document_id>
</document>
<document>
<document_type>WEB_PAGE</document_type>
<document_id>https://github.com/Universal-Commerce-Protocol/ucp</document_id>
</document>
<document>
<document_type>WEB_PAGE</document_type>
<document_id>https://ucp.dev/specification/overview/</document_id>
</document>
</citations>
