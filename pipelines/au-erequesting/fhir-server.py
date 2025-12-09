#!/usr/bin/env python3
"""
Simple FHIR Server for AU eRequesting Example
Accepts FHIR bundle requests and returns a pre-configured AU eRequesting response
"""

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Get the directory where this script is located
SCRIPT_DIR = Path(__file__).parent.absolute()
RESPONSE_FILE = SCRIPT_DIR / "request.json"


class FHIRServerHandler(BaseHTTPRequestHandler):
    """HTTP request handler for FHIR server"""

    def do_GET(self):
        """Handle GET requests - health check and query endpoints"""
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "status": "healthy",
                "service": "AU eRequesting FHIR Server"
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            # For any other GET request, return the FHIR bundle response
            # (representing a search/query result)
            if not RESPONSE_FILE.exists():
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                response = {"error": f"Response file not found: {RESPONSE_FILE}"}
                self.wfile.write(json.dumps(response).encode())
                return
            
            try:
                with open(RESPONSE_FILE, "r") as f:
                    fhir_response = json.load(f)
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                response = {"error": f"Failed to load response: {str(e)}"}
                self.wfile.write(json.dumps(response).encode())
                return
            
            # Log the GET query
            print(f"[INFO] Received GET {parsed_url.path} query")
            
            # Send successful response
            self.send_response(200)
            self.send_header("Content-Type", "application/fhir+json")
            self.send_header("Content-Length", str(len(json.dumps(fhir_response))))
            self.end_headers()
            self.wfile.write(json.dumps(fhir_response).encode())
            
            print("[INFO] Returned AU eRequesting FHIR bundle response")

    def do_POST(self):
        """Handle POST requests - accept FHIR bundle and return response"""
        parsed_url = urlparse(self.path)
        
        # Read the request body
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        
        try:
            request_data = json.loads(body.decode())
        except json.JSONDecodeError:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": "Invalid JSON"}
            self.wfile.write(json.dumps(response).encode())
            return
        
        # Log received request
        print(f"[INFO] Received {parsed_url.path} request")
        if isinstance(request_data, dict) and request_data.get("resourceType") == "Bundle":
            print(f"[INFO] Bundle type: {request_data.get('type', 'unknown')}")
        
        # Load and return the pre-configured response
        if not RESPONSE_FILE.exists():
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": f"Response file not found: {RESPONSE_FILE}"}
            self.wfile.write(json.dumps(response).encode())
            return
        
        try:
            with open(RESPONSE_FILE, "r") as f:
                fhir_response = json.load(f)
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": f"Failed to load response: {str(e)}"}
            self.wfile.write(json.dumps(response).encode())
            return
        
        # Send successful response
        self.send_response(200)
        self.send_header("Content-Type", "application/fhir+json")
        self.send_header("Content-Length", str(len(json.dumps(fhir_response))))
        self.end_headers()
        self.wfile.write(json.dumps(fhir_response).encode())
        
        print("[INFO] Returned AU eRequesting FHIR bundle response")

    def log_message(self, format, *args):
        """Override to add custom logging prefix"""
        print(f"[SERVER] {format % args}")


def run_server(host="127.0.0.1", port=8888):
    """Start the FHIR server"""
    server_address = (host, port)
    httpd = HTTPServer(server_address, FHIRServerHandler)
    print(f"[INFO] FHIR Server starting on {host}:{port}")
    print(f"[INFO] Health check: GET http://{host}:{port}/health")
    print(f"[INFO] Bundle endpoint: POST http://{host}:{port}/")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Server shutdown requested")
    finally:
        httpd.server_close()
        print("[INFO] Server stopped")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8888
    run_server(port=port)
