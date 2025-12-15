# Webhook Middleware Example

This example shows how to use the `webhook` middleware to emit JSON payloads on request/response. It demonstrates:
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
