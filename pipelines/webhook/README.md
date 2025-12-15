# Webhook Middleware Example

## What is this pipeline?

This example shows how to use the `webhook` middleware to emit JSON payloads on request/response. This example is ideal for:

- Logging and audit trails
- Event-driven integrations
- Sending requests to external webhooks
- Building observable pipelines

## How to add this pipeline to your Harmony instance

To use this pipeline in your Harmony deployment, follow the [Adding Pipelines guide](https://docs.runbeam.io/harmony/guides/adding-pipelines):

1. Create a new TOML file in your `pipelines/` directory
2. Copy the pipeline configuration from this example
3. Configure webhook endpoints and authentication
4. Harmony automatically discovers and loads the pipeline

## About Harmony and Runbeam

**Harmony** is a high-performance API gateway and proxy runtime built in Rust, designed for healthcare data integration, protocol translation, and advanced middleware processing.

**Runbeam** provides the cloud platform and ecosystem for deploying and managing Harmony instances.

- [Harmony Documentation](https://docs.runbeam.io/harmony)
- [Runbeam Cloud](https://runbeam.io)
- [GitHub Repository](https://github.com/runbeam/harmony)

---

This example demonstrates the following webhook features:
- Per-instance authentication (Basic)
- Redacting sensitive headers/metadata in the webhook payload
- Supplying extra JSON via request metadata (`webhook.<instance_name>`)

## Run

1. Start a simple receiver in another terminal (any HTTP server that accepts POST at `/hook`). For example using Node:

```js
// save as hook.js and run: node hook.js
const http = require('http');
http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/hook') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      console.log('Headers:', req.headers);
      console.log('Body:', body);
      res.writeHead(200); res.end('ok');
    });
  } else { res.writeHead(404); res.end(); }
}).listen(9000, () => console.log('Listening on :9000'));
```

2. In this directory, run the proxy with this example config:

```
cargo run -p harmony -- --config ./config.toml
```

3. Send a test request:

```
curl -s http://127.0.0.1:8080/echo -H 'Authorization: Bearer inbound' -H 'Content-Type: application/json' -d '{"hello":"world"}' | jq
```

You should see two webhook POSTs at your receiver (apply = both). The Authorization header and secret metadata are redacted in the payload, and `extra` contains the parsed JSON from `transforms/set_webhook_metadata.json`.
