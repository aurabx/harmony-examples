#!/usr/bin/env python3
"""
Simple HTTP server for testing mesh networking.
Returns JSON responses with request details for verification.
"""

import json
import http.server
import socketserver
from datetime import datetime
from urllib.parse import urlparse, parse_qs

PORT = 5000


class MeshTestHandler(http.server.BaseHTTPRequestHandler):
    """Handle HTTP requests and return JSON with request details."""

    def _send_json_response(self, status: int, data: dict):
        """Send a JSON response."""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def _build_response(self) -> dict:
        """Build response with request details."""
        parsed = urlparse(self.path)
        return {
            "status": "ok",
            "server": "python-backend",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "request": {
                "method": self.command,
                "path": parsed.path,
                "query": parse_qs(parsed.query),
                "headers": dict(self.headers),
            },
            "message": "Request successfully routed through mesh!",
        }

    def do_GET(self):
        """Handle GET requests."""
        if self.path == "/health":
            self._send_json_response(200, {"status": "healthy"})
            return

        response = self._build_response()
        self._send_json_response(200, response)

    def do_POST(self):
        """Handle POST requests."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else ""

        response = self._build_response()
        
        # Try to parse body as JSON
        try:
            response["request"]["body"] = json.loads(body) if body else None
        except json.JSONDecodeError:
            response["request"]["body"] = body if body else None

        self._send_json_response(200, response)

    def do_PUT(self):
        """Handle PUT requests."""
        self.do_POST()

    def do_DELETE(self):
        """Handle DELETE requests."""
        response = self._build_response()
        self._send_json_response(200, response)

    def log_message(self, format, *args):
        """Override to add timestamp to logs."""
        print(f"[{datetime.utcnow().isoformat()}] {args[0]}")


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), MeshTestHandler) as httpd:
        print(f"Python backend server running on port {PORT}")
        print("Endpoints:")
        print("  GET  /health     - Health check")
        print("  GET  /api/*      - Echo request details")
        print("  POST /api/*      - Echo request details with body")
        httpd.serve_forever()
