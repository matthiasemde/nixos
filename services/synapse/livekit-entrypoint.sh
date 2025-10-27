#!/bin/sh
set -e

FINALCONF=/etc/livekit.yaml

cat /etc/livekit-pre.yaml > "$FINALCONF"
[ -n "$LIVEKIT_SECRET" ] && {
  echo "keys:" >> "$FINALCONF"
  echo "  $LIVEKIT_KEY: $LIVEKIT_SECRET" >> "$FINALCONF"
}

# exec tail -f /dev/null
exec /livekit-server --config "$FINALCONF"
