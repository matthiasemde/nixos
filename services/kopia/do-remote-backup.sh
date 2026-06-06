#!/bin/bash

# Redirect output to the container's main process stdout/stderr so it appears in service logs
exec >/proc/1/fd/1 2>/proc/1/fd/2

BUCKET=kopia-remote-backup
ENDPOINT=minio.remote.emdecloud.de

echo "Starting remote backup..."
if ! kopia repository sync-to s3 \
  --endpoint $ENDPOINT \
  --bucket $BUCKET \
  --access-key $MINIO_ACCESS_KEY \
  --secret-access-key $MINIO_SECRET_ACCESS_KEY \
  --no-progress; then
  echo "ERROR: Remote backup sync failed!" >&2
  exit 1
fi

echo "Remote backup completed."
echo "Kopia backup + sync completed successfully."
