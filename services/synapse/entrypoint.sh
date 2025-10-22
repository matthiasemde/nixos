#!/bin/sh
set -eu

TEMPLATE_PATH=${TEMPLATE_PATH:-/data/homeserver.yaml.j2}
OUTPUT_PATH=${OUTPUT_PATH:-/data/homeserver.yaml}
RENDER_SCRIPT=${RENDER_SCRIPT:-/render-config.py}

echo "[entrypoint] Rendering Synapse configuration..."
python3 "$RENDER_SCRIPT" "$TEMPLATE_PATH" "$OUTPUT_PATH"

# ensure ownership & permissions
chown 991:991 "$OUTPUT_PATH"
chmod 600 "$OUTPUT_PATH"

echo "[entrypoint] Starting Synapse..."
exec /start.py "$@"
