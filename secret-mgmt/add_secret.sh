#!/usr/bin/env bash
# add_secret.sh – add or edit a secret in the appropriate per-host SOPS YAML.
#
# Usage:
#   ./secret-mgmt/add_secret.sh -n <secret-name> (-s <service> | -h <hostname>)
#
# The script opens the target host's secrets.yaml with 'sops edit'.
# The YAML key for the new secret follows the naming convention:
#   <service|host>-<secret-name>  (with dots replaced by underscores)
set -euo pipefail

usage() {
  echo "Usage: $0 -n <secret-name> (-s <service> | -h <hostname>)"
  echo
  echo "  -n <secret-name>   Name of the secret (e.g. DB_PASSWORD.env)"
  echo "  -s <service>       Target service name (secret belongs to this service)"
  echo "  -h <hostname>      Target hostname    (host-level secret)"
  exit 1
}

SERVICE=""
HOST=""
SECRET_NAME=""

while getopts "s:h:n:" opt; do
  case "$opt" in
  s) SERVICE="$OPTARG" ;;
  h) HOST="$OPTARG" ;;
  n) SECRET_NAME="$OPTARG" ;;
  *) usage ;;
  esac
done

if [[ "$(git rev-parse --show-toplevel)" != "$(pwd)" ]]; then
  echo "❌ Please run this script from the root of the Git repository."
  exit 1
fi

if [[ -z "$SECRET_NAME" || (-z "$SERVICE" && -z "$HOST") || (-n "$SERVICE" && -n "$HOST") ]]; then
  echo "❌ You must provide -n and either -s or -h (but not both)."
  usage
fi

# Determine which host owns this secret.
# Service secrets live in the mahler secrets set by default; override with HOST_OVERRIDE.
if [[ -n "$SERVICE" ]]; then
  OWNER_PREFIX="$SERVICE"
  TARGET_HOST="${HOST_OVERRIDE:-mahler}"
else
  OWNER_PREFIX="$HOST"
  TARGET_HOST="$HOST"
fi

SOPS_FILE="./hosts/${TARGET_HOST}/secrets.yaml"

if [[ ! -f "$SOPS_FILE" ]]; then
  echo "❌ SOPS file not found: $SOPS_FILE"
  echo "   Run secret-mgmt/migrate.sh first to create it."
  exit 1
fi

# Derive the YAML key (dots → underscores, prefix with owner)
raw_key="${OWNER_PREFIX}-${SECRET_NAME}"
yaml_key="${raw_key//./_}"

echo "🔑 Secret key in SOPS YAML : $yaml_key"
echo "📁 Runtime path            : /run/secrets/${raw_key}"
echo "📄 SOPS file               : $SOPS_FILE"
echo ""
echo "Opening $SOPS_FILE for editing. Add or update the key: $yaml_key"
echo ""

sops edit "$SOPS_FILE"

