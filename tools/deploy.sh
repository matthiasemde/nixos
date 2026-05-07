#!/usr/bin/env bash
set -euo pipefail

# Deployment script: resets the deployment clone to origin/main and runs nixos-rebuild.
# Used both by the automated systemd service and for manual deployments.
#
# Must be run as root.
#
# Usage: deploy.sh [--dry-run] [--deploy-dir <dir>] <flake-target>
#   --dry-run         Print what would happen without making changes
#   --deploy-dir DIR  Override the deployment clone directory
#
# Environment variable overrides (used by the systemd service):
#   DEPLOY_DIR   Deployment clone directory (default: /var/lib/nixos-deploy)
#   REPO_URL     Repository URL            (default: https://github.com/matthiasemde/nixos.git)

DRY_RUN=false
DEPLOY_DIR="${DEPLOY_DIR:-/var/lib/nixos-deploy}"
REPO_URL="${REPO_URL:-https://github.com/matthiasemde/nixos.git}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --deploy-dir)
            DEPLOY_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done


if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root" >&2
    exit 1
fi

log() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] [$(date +'%Y-%m-%d %H:%M:%S')] $*"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/nixos-deploy.log
    fi
}

log "=== Starting deployment ==="
log "Deploy dir   : $DEPLOY_DIR"

# Bail out if a previous rebuild is still running (can happen when daemon-reload
# kills this service mid-flight but the transient switch unit lives on).
if systemctl is-active --quiet nixos-rebuild-switch-to-configuration.service; then
    log "A nixos-rebuild switch is already in progress - skipping this run."
    exit 0
fi

# Clone on first run, otherwise just update
if [ ! -d "$DEPLOY_DIR/.git" ]; then
    log "No clone found - cloning $REPO_URL ..."
    if [ "$DRY_RUN" = false ]; then
        git clone --branch main "$REPO_URL" "$DEPLOY_DIR"
    fi
else
    log "Fetching latest changes from origin..."
    if [ "$DRY_RUN" = true ]; then
        log "Would run: git -C $DEPLOY_DIR fetch origin && git -C $DEPLOY_DIR reset --hard origin/main"
    else
        git -C "$DEPLOY_DIR" fetch origin
        git -C "$DEPLOY_DIR" reset --hard origin/main
    fi
fi

COMMIT=$(git -C "$DEPLOY_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
log "Deploying commit: $COMMIT"

if [ "$DRY_RUN" = true ]; then
    log "Would run: nixos-rebuild switch --flake $DEPLOY_DIR"
    exit 0
fi

if nixos-rebuild switch --flake "$DEPLOY_DIR"; then
    log "=== Deployment succeeded (generation: $(readlink /run/current-system)) ==="
else
    log "Deployment FAILED - rolling back to previous generation"
    nixos-rebuild switch --rollback
    exit 1
fi

