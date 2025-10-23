#!/bin/sh
set -eu

TEMPLATE_PATH=${TEMPLATE_PATH:-/data/config.yaml.j2}
OUTPUT_PATH=${OUTPUT_PATH:-/data/config.yaml}
SECRETS_PATH=${SECRETS_PATH:-/data/secrets.yaml}
RENDER_SCRIPT=${RENDER_SCRIPT:-/render-config.py}

echo "[mas-entrypoint] Rendering Matrix Authentication Service configuration..."
python3 "$RENDER_SCRIPT" "$TEMPLATE_PATH" "$OUTPUT_PATH"
# python3 "$RENDER_SCRIPT" /data/homeserver.yaml.j2 /data/homeserver.yaml

# ensure ownership & permissions
chown 999:999 "$OUTPUT_PATH"
chmod 600 "$OUTPUT_PATH"

echo "[mas-entrypoint] Validating Matrix Authentication Service configuration..."
mas-cli config check --config="$OUTPUT_PATH" --config="$SECRETS_PATH"

if [ $? -eq 0 ]; then
    echo "[mas-entrypoint] Configuration validation successful"
else
    echo "[mas-entrypoint] Configuration validation failed!"
    exit 1
fi

echo "[mas-entrypoint] Running database migrations..."
mas-cli config sync --config="$OUTPUT_PATH" --config="$SECRETS_PATH"

echo "[mas-entrypoint] Starting Matrix Authentication Service..."
exec mas-cli server --config="$OUTPUT_PATH" --config="$SECRETS_PATH"
# exec tail -f > /dev/null
