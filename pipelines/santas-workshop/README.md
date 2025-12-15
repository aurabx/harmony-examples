# Santa's Workshop Gift Logistics System

## What is this pipeline?

This mission-critical pipeline powers the North Pole's Gift Distribution Network, enabling seamless integration between the Naughty/Nice Registry, Elf Production Management System (EPMS), and the Reindeer Fleet Logistics API. It ensures that every gift reaches the right chimney at precisely the right moment on Christmas Eve.

This example is ideal for:

- High-throughput gift routing with sub-millisecond latency
- Real-time naughty/nice classification and gift eligibility verification
- Chimney-to-chimney delivery orchestration
- Elf workload distribution and toy production scheduling

## How to add this pipeline to your Harmony instance

To deploy this pipeline at the North Pole, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure your Naughty/Nice Registry credentials and Reindeer Fleet API keys
4. Harmony automatically discovers and loads the pipeline

**Note**: Requires valid North Pole Security Clearance (NPSC) Level 3 or higher.

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

## What This Example Demonstrates

- Multi-protocol gift routing (GIFT/1.1, Chimney-RPC, SleighMQ)
- Real-time transformation between Elf Production Format (EPF) and Universal Gift Schema (UGS)
- Naughty/Nice classification middleware with cookie-based authentication
- Reindeer load balancing across 9 reindeer (with Rudolph failover)
- Time-zone aware delivery scheduling with magical time dilation support

## Prerequisites

- **North Pole VPN Access**: Required for connection to internal workshop systems
- **Elf API Token**: Obtain from your Workshop Supervisor
- **Reindeer Fleet Credentials**: Contact Dasher (Fleet Lead) for API keys
- **Naughty/Nice Registry**: Read-only access minimum (write access for Coal Distribution)

## Configuration

- **Proxy ID**: `harmony-north-pole`
- **HTTP Listener**: `127.0.0.1:2512` (December 25, 12:00 - get it? 🎄)
- **Endpoint Path**: `/gifts`
- **Backend**: North Pole Gift Distribution API
- **Authentication**: Cookie-based (milk & cookies required)
- **Log File**: `./tmp/harmony_workshop.log`
- **Storage**: `./tmp` (cleared annually on December 26th)

## How to Run

1. Ensure you have active North Pole credentials:
   ```bash
   export NORTH_POLE_API_KEY="hohoho-your-key-here"
   export REINDEER_FLEET_TOKEN="dasher-dancer-prancer-vixen"
   ```

2. From the project root, run:
   ```bash
   cargo run -- --config examples/santas-workshop/config.toml
   ```

3. The service will start and bind to `127.0.0.1:2512`

## Testing

### Check Gift Eligibility

```bash
# Check if a child is on the Nice List
curl http://127.0.0.1:2512/gifts/eligibility/check \
  -H "Content-Type: application/json" \
  -H "X-Elf-Token: jinglebells123" \
  -d '{"child_id": "timmy-north-usa-12345", "year": 2024}'
```

### Submit Gift Request

```bash
# Submit a gift for production
curl -X POST http://127.0.0.1:2512/gifts/production/queue \
  -H "Content-Type: application/json" \
  -H "X-Elf-Token: jinglebells123" \
  -d '{
    "gift_type": "toy_train",
    "recipient": "timmy-north-usa-12345",
    "priority": "nice_list_gold",
    "delivery_chimney": "main_fireplace",
    "special_instructions": "Leave extra cookies for Rudolph"
  }'
```

### Check Reindeer Fleet Status

```bash
# Get current reindeer availability
curl http://127.0.0.1:2512/fleet/status \
  -H "X-Elf-Token: jinglebells123"
```

### Coal Distribution (Naughty List Only)

```bash
# Queue coal delivery (requires elevated permissions)
curl -X POST http://127.0.0.1:2512/gifts/coal/distribute \
  -H "Content-Type: application/json" \
  -H "X-Elf-Token: jinglebells123" \
  -H "X-Naughty-Override: true" \
  -d '{"recipient": "naughty-child-id", "coal_grade": "premium_anthracite"}'
```

## Expected Behavior

- Gift requests are validated against the Naughty/Nice Registry
- Valid requests are transformed to Elf Production Format and queued
- Reindeer assignments are optimized based on route efficiency
- Delivery confirmations are logged with chimney GPS coordinates
- Cookie consumption is tracked for Santa's dietary monitoring

## Files

- `config.toml` - Main configuration with North Pole credentials
- `pipelines/santas-workshop.toml` - Pipeline definition with gift routing logic
- `tmp/` - Created at runtime for logs and temporary gift manifests

## Architecture Notes

### The Gift Flow

```
Child's Letter → Nice List Check → Elf Assignment → Toy Production → 
Quality Control → Gift Wrapping → Sleigh Loading → Route Optimization → 
Reindeer Assignment → Christmas Eve Delivery → Chimney Entry → 
Under Tree Placement → Cookie Collection → Mission Complete! 🎁
```

### Reindeer Load Balancing

The fleet uses a weighted round-robin algorithm:
- **Dasher & Dancer**: Heavy packages (up to 50kg)
- **Prancer & Vixen**: Precision landings (apartment buildings)
- **Comet & Cupid**: Long-distance routes (remote areas)
- **Donner & Blitzen**: Speed priority (last-minute deliveries)
- **Rudolph**: Fog conditions only (nose-based navigation)

## Troubleshooting

### "Naughty List Override Required"
The recipient has been flagged. Contact your Workshop Supervisor or submit a Nice List Appeal Form (NLA-2024).

### "Reindeer Fleet Exhausted"
All reindeer are currently assigned. Wait for route completion or enable Emergency Elf Drone Delivery (EEDD).

### "Cookie Authentication Failed"
Ensure milk is fresh (< 24 hours) and cookies are chocolate chip. Oatmeal raisin is NOT supported.

## Next Steps

- Explore `examples/fhir/` for healthcare gift delivery compliance
- See `examples/transform/` for custom gift wrapping transformations
- Try the Coal Distribution API for Naughty List management

---

*"Ho ho ho! May your data pipelines be merry and your integrations bright!"* 🎅🎄
