#!/bin/sh
set -euo pipefail

CONTAINER_NAME="kopia"
REPO_PATH="/repository"

# Check if the repository exists inside the container
if docker exec "$CONTAINER_NAME" test -f "$REPO_PATH/kopia.repository.f"; then
  echo "✅ Repository already exists at $REPO_PATH."

  echo "📦 Repository info:"
  docker exec "$CONTAINER_NAME" kopia repository status || echo "ℹ️ Not connected (possibly already connected by server)."

else
  echo "🚀 Creating new Kopia repository at $REPO_PATH..."
  docker exec "$CONTAINER_NAME" \
    kopia repository create filesystem --path="$REPO_PATH" --description=main

  echo "✅ Repository created."
fi
