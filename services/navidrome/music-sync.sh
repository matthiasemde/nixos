#!/bin/bash

SHARED="/data/nas/navidrome/shared-library"
LOCAL="/data/nas/files/Musik"

echo "[sync] Starting music symlink synchronization service"
echo "[sync] Source: $SHARED"
echo "[sync] Target: $LOCAL"

# Create local directory if it doesn't exist
mkdir -p "$LOCAL"

# Function to sync symlinks
sync_links() {
  echo "[sync] Synchronizing symlinks..."

  # Remove broken symlinks in LOCAL
  find "$LOCAL" -maxdepth 1 -type l ! -exec test -e {} \; -delete 2>/dev/null || true

  # Create symlinks for all albums in SHARED
  if [ -d "$SHARED" ]; then
    for album in "$SHARED"/*; do
      [ -d "$album" ] || continue

      name="$(basename "$album")"
      link="$LOCAL/$name"

      if [ ! -e "$link" ]; then
        ln -s "$album" "$link"
        echo "[sync] Created symlink: $link -> $album"
      fi
    done
  fi

  echo "[sync] Synchronization complete"
}

# Initial sync
sync_links

# Watch for changes and re-sync (poll every 60 seconds)
echo "[sync] Watching $SHARED for changes (60s interval)..."
while true; do
  sleep 60
  sync_links
done
