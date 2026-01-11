#!/usr/bin/env bash
set -euo pipefail

# Woodpecker CI Deployment Script for NixOS
# This script is triggered by Woodpecker CI to rebuild the system

REPO_DIR="/home/matthias/infra"
LOG_FILE="/var/log/nixos-deploy.log"
HEALTH_CHECK_TIMEOUT=60

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "=== Starting NixOS deployment ==="

exit 0
