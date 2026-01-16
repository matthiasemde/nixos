#!/usr/bin/env bash
set -euo pipefail

# Host-side deployment activation script
# This runs on the actual NixOS host, triggered by webhook
# Must be run as root, but does git operations as repo owner

# Automatically determine repository directory (parent of script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Determine repository owner
REPO_OWNER="$(stat -c '%U' "$REPO_DIR")"

LOG_FILE="/var/log/nixos-deploy.log"
CACHE_URL="http://localhost:5000"  # Local binary cache

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
fi

log "=== Starting NixOS activation from binary cache ==="
log "Repository: $REPO_DIR"
log "Owner: $REPO_OWNER"

# Store current generation for rollback
CURRENT_GEN=$(readlink -f /run/current-system)
log "Current generation: $CURRENT_GEN"

# Pull latest changes from git as the repo owner
log "Pulling latest changes from git..."
cd "$REPO_DIR"

sudo -u "$REPO_OWNER" git fetch || error "Failed to fetch from origin"

# Store current commit for rollback
ORIGINAL_COMMIT=$(sudo -u "$REPO_OWNER" git rev-parse HEAD)
log "Original commit: $ORIGINAL_COMMIT"

# Rebase with autostash - git will handle stashing/unstashing automatically
if ! sudo -u "$REPO_OWNER" git rebase --autostash --no-autosquash origin/main; then
    log "Rebase failed, aborting..."
    sudo -u "$REPO_OWNER" git rebase --abort
    error "Failed to rebase to origin/main"
fi

# Ensure all files remain owned by the repo owner
log "Fixing file ownership..."
chown -R "$REPO_OWNER:users" "$REPO_DIR"

# Configure to use local binary cache
# export NIX_CONFIG="substituters = $CACHE_URL https://cache.nixos.org
# trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=

log "Switching to new configuration..."
nixos-rebuild switch --flake "$REPO_DIR#mahler" || {
    log "Switch failed! Rolling back..."
    nixos-rebuild switch --rollback
    error "Deployment failed, rolled back to previous generation"
}

NEW_GEN=$(readlink -f /run/current-system)
log "New generation: $NEW_GEN"

# Health checks
log "Running health checks..."
sleep 5

CRITICAL_SERVICES=(
    "docker-traefik.service"
    "docker-woodpecker-server.service"
)

FAILED_SERVICES=()
for service in "${CRITICAL_SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service" 2>/dev/null; then
        log "WARNING: Service $service is not active"
        FAILED_SERVICES+=("$service")
    else
        log "✓ Service $service is running"
    fi
done

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    log "WARNING: Some critical services failed: ${FAILED_SERVICES[*]}"
    exit 1
fi

# Check Traefik is responding
if timeout 10 curl -sf http://localhost:8080/api/http/routers > /dev/null; then
    log "✓ Traefik is responding"
else
    log "WARNING: Traefik health check failed"
    exit 1
fi

log "=== Deployment completed successfully ==="
log "Previous generation: $CURRENT_GEN"
log "Current generation: $NEW_GEN"

# Cleanup
log "Performing docker system prune..."
docker system prune --all --volumes --force
log "Cleaning up old generations..."
nix-collect-garbage --delete-older-than 30d || log "Warning: garbage collection failed"

exit 0
