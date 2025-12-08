#!/usr/bin/env python3
"""
Simple HTTP API Backend for Service Requests
Accepts simplified HTTP requests and stores/returns service order information
"""

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from datetime import datetime

# Storage for received orders
orders_store = {}
next_order_id = 1000


class APIBackendHandler(BaseHTTPRequestHandler):
    """HTTP request handler for simple API backend"""

    def do_GET(self):
        """Handle GET requests - retrieve orders"""
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "status": "healthy",
                "service": "Service Request API Backend"
            }
            self.wfile.write(json.dumps(response).encode())
        
        elif parsed_url.path == "/orders":
            # List all orders
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {
                "orders": list(orders_store.values()),
                "count": len(orders_store)
            }
            self.wfile.write(json.dumps(response).encode())
        
        elif parsed_url.path.startswith("/orders/"):
            # Get specific order
            order_id = parsed_url.path.split("/")[-1]
            if order_id in orders_store:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(orders_store[order_id]).encode())
            else:
                self.send_response(404)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                response = {"error": f"Order {order_id} not found"}
                self.wfile.write(json.dumps(response).encode())
        
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": "Not Found"}
            self.wfile.write(json.dumps(response).encode())

    def do_POST(self):
        """Handle POST requests - create service order"""
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
        
        if parsed_url.path == "/orders":
            # Create new order from simplified HTTP request
            global next_order_id
            
            order_id = str(next_order_id)
            next_order_id += 1
            
            # Validate required fields
            required_fields = ["patientId", "patientName", "serviceCode", "serviceDisplay"]
            missing_fields = [f for f in required_fields if f not in request_data]
            
            if missing_fields:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                response = {"error": f"Missing required fields: {', '.join(missing_fields)}"}
                self.wfile.write(json.dumps(response).encode())
                return
            
            # Create order record
            order = {
                "orderId": order_id,
                "createdAt": datetime.utcnow().isoformat() + "Z",
                "status": "received",
                "patientId": request_data.get("patientId"),
                "patientName": request_data.get("patientName"),
                "serviceCode": request_data.get("serviceCode"),
                "serviceDisplay": request_data.get("serviceDisplay"),
                "priority": request_data.get("priority", "routine"),
                "requesterName": request_data.get("requesterName"),
                "organizationName": request_data.get("organizationName"),
                "notes": request_data.get("notes", ""),
                "message": "Service request order received and stored"
            }
            
            orders_store[order_id] = order
            
            print(f"[INFO] Created order {order_id} for {request_data.get('patientName')}")
            
            # Return created order with 201 Created
            self.send_response(201)
            self.send_header("Content-Type", "application/json")
            self.send_header("Location", f"/orders/{order_id}")
            self.end_headers()
            self.wfile.write(json.dumps(order).encode())
        
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            response = {"error": "Not Found"}
            self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        """Override to add custom logging prefix"""
        print(f"[API] {format % args}")


def run_server(host="127.0.0.1", port=8889):
    """Start the API backend server"""
    server_address = (host, port)
    httpd = HTTPServer(server_address, APIBackendHandler)
    print(f"[INFO] Service Request API Backend starting on {host}:{port}")
    print(f"[INFO] Health check: GET http://{host}:{port}/health")
    print(f"[INFO] List orders: GET http://{host}:{port}/orders")
    print(f"[INFO] Get order: GET http://{host}:{port}/orders/{{id}}")
    print(f"[INFO] Create order: POST http://{host}:{port}/orders")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Server shutdown requested")
    finally:
        httpd.server_close()
        print("[INFO] Server stopped")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8889
    run_server(port=port)
