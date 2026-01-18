#!/usr/bin/env python3
"""
Simple webhook listener for NixOS deployments.
Listens for POST requests and triggers the activation script.

Usage: webhook-listener.py <deploy-script-path> <repo-directory>
"""

import hmac
import hashlib
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

# Parse command line arguments
if len(sys.argv) != 3:
    print("Usage: webhook-listener.py <deploy-script-path> <repo-directory>", file=sys.stderr)
    sys.exit(1)

DEPLOY_SCRIPT = sys.argv[1]
REPO_DIR = sys.argv[2]

# Read webhook secret from agenix-managed file
SECRET_FILE = '/run/agenix/mahler-WEBHOOK_SECRET.env'
try:
    with open(SECRET_FILE, 'r') as f:
        WEBHOOK_SECRET = f.read().strip().encode()
except FileNotFoundError:
    print(f"Warning: Secret file {SECRET_FILE} not found. Webhook authentication disabled.")
    WEBHOOK_SECRET = b''

PORT = 9999

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/deploy':
            self.send_response(404)
            self.end_headers()
            return

        # only accept connections from the docker network
        client_ip = self.client_address[0]

        if not client_ip.startswith("172.17."):
            self.send_response(403)
            self.end_headers()
            return

        # Read request body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b''

        # Verify signature if secret is set
        if WEBHOOK_SECRET:
            signature = self.headers.get('X-Webhook-Signature', '')
            expected = hmac.new(WEBHOOK_SECRET, body, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(signature, expected):
                print(f"Invalid signature: {signature} != {expected}")
                self.send_response(403)
                self.end_headers()
                self.wfile.write(b'Invalid signature')
                return

        # Trigger deployment
        try:
            print("Triggering deployment...")
            result = subprocess.run(
                [DEPLOY_SCRIPT, REPO_DIR],
                capture_output=True,
                text=True,
                timeout=600  # 10 minutes max
            )

            response = {
                'status': 'success' if result.returncode == 0 else 'failed',
                'returncode': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr
            }

            self.send_response(200 if result.returncode == 0 else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        except subprocess.TimeoutExpired:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b'Deployment timeout')
        except Exception as e:
            print(f"Error: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")

if __name__ == '__main__':
    print(f"Starting webhook listener on port {PORT}...")
    print(f"Deploy script: {DEPLOY_SCRIPT}")
    print(f"Repository directory: {REPO_DIR}")
    print(f"Webhook secret configured: {bool(WEBHOOK_SECRET)}")

    server = HTTPServer(('0.0.0.0', PORT), WebhookHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()
