#!/usr/bin/env bash
set -euo pipefail

# Host-side deployment activation script
# This runs on the actual NixOS host, triggered by webhook
# Must be run as root, but does git operations as repo owner
#
# Usage: deploy.sh [--dry-run] <repo-directory>

DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            REPO_DIR="$1"
            shift
            ;;
    esac
done

# Verify repo directory was provided
if [ -z "${REPO_DIR:-}" ]; then
    echo "Usage: $0 [--dry-run] <repo-directory>" >&2
    exit 1
fi

# Verify repo directory exists
if [ ! -d "$REPO_DIR" ]; then
    echo "ERROR: Repository directory does not exist: $REPO_DIR" >&2
    exit 1
fi

# Determine repository owner
REPO_OWNER="$(stat -c '%U' "$REPO_DIR")"

LOG_FILE="/var/log/nixos-deploy.log"
CACHE_URL="http://localhost:5000"  # Local binary cache

log() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] [$(date +'%Y-%m-%d %H:%M:%S')] $*"
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    fi
}

error() {
    log "ERROR: $*"
    exit 1
}

# Git wrapper to run commands as repo owner
git_as_owner() {
    sudo -u "$REPO_OWNER" git "$@"
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

git_as_owner fetch || error "Failed to fetch from origin"

# Update main branch to match origin/main
log "Updating main branch to origin/main..."
CURRENT_BRANCH=$(git_as_owner branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    # If not on main, update main ref without checking it out
    if [ "$DRY_RUN" = true ]; then
        log "Would update main to origin/main"
    else
        git_as_owner update-ref refs/heads/main refs/remotes/origin/main || log "Warning: failed to update main"
    fi
else
    # If on main, do a fast-forward merge
    if [ "$DRY_RUN" = true ]; then
        log "Would fast-forward main to origin/main"
    else
        git_as_owner merge --ff-only origin/main || log "Warning: failed to fast-forward main"
    fi
fi

# Store current commit for rollback
ORIGINAL_COMMIT=$(git_as_owner rev-parse HEAD)
log "Original commit: $ORIGINAL_COMMIT"

# Rebase current branch with autostash - git will handle stashing/unstashing automatically
if [ "$CURRENT_BRANCH" != "main" ]; then
    log "Rebasing $CURRENT_BRANCH onto origin/main..."
    if ! git_as_owner rebase --autostash --no-autosquash --no-gpg-sign origin/main; then
        log "Rebase failed, aborting..."
        git_as_owner rebase --abort
        error "Failed to rebase to origin/main"
    fi
fi

# Ensure all files remain owned by the repo owner
log "Fixing file ownership..."
chown -R "$REPO_OWNER:users" "$REPO_DIR"

# Configure to use local binary cache
# export NIX_CONFIG="substituters = $CACHE_URL https://cache.nixos.org
# trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=

log "Switching to new configuration..."
if [ "$DRY_RUN" = true ]; then
    log "Would run: nixos-rebuild switch --flake $REPO_DIR#mahler"
else
    nixos-rebuild switch --flake "$REPO_DIR#mahler" || {
        log "Switch failed! Rolling back..."
        nixos-rebuild switch --rollback
        error "Deployment failed, rolled back to previous generation"
    }
fi

NEW_GEN=$(readlink -f /run/current-system)
log "New generation: $NEW_GEN"

# Health checks
log "Running health checks..."
sleep 5

CRITICAL_SERVICES=(
    "docker-authentik-server.service"
    "docker-frp.service"
    "docker-immich-app.service"
    "docker-kopia.service"
    "docker-nextcloud-app.service"
    "docker-synapse-app.service"
    "docker-traefik.service"
    "docker-uptime-kuma.service"
    "docker-vaultwarden.service"
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
log "Performing git cleanup..."

# Fetch and prune remote branches
log "Fetching and pruning remote branches..."
git_as_owner fetch --prune || log "Warning: fetch --prune failed"

# For squash merges, check if branch no longer exists on remote
log "Cleaning up branches deleted from remote..."
DELETED_BRANCHES=""
for branch in $(git_as_owner branch | grep -v "^\*" | grep -v "main" | sed 's/^[[:space:]]*//'); do
    # Check if remote tracking branch exists
    if ! git_as_owner rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        log "Branch $branch no longer exists on remote, deleting..."
        if [ "$DRY_RUN" = true ]; then
            log "Would delete branch: $branch"
            DELETED_BRANCHES="$DELETED_BRANCHES $branch"
        elif git_as_owner branch -D "$branch" 2>/dev/null; then
            DELETED_BRANCHES="$DELETED_BRANCHES $branch"
        else
            log "Warning: could not delete branch $branch"
        fi
    fi
done

if [ -n "$DELETED_BRANCHES" ]; then
    log "Deleted branches:$DELETED_BRANCHES"
else
    log "No branches to clean up"
fi

# Find leaf branches (branches with no other branches stacked on top)
log "Finding leaf branches to rebase..."
ALL_BRANCHES=$(git_as_owner branch | grep -v "^\*" | grep -v "main" | sed 's/^[[:space:]]*//')

# Find commits that are parents of other branch tips (non-leaf branches)
# The snippet shows commits that have children branches pointing beyond them
NON_LEAF_COMMITS=$(git_as_owner for-each-ref --format='%(objectname)^{commit}' refs/heads \
  | git_as_owner cat-file --batch-check='%(objectname)^!' \
  | grep -v missing \
  | git_as_owner log --oneline --stdin --no-walk \
  | cut -d' ' -f1)

LEAF_BRANCHES=""
for branch in $ALL_BRANCHES; do
    BRANCH_COMMIT=$(git_as_owner rev-parse --short "$branch" 2>/dev/null)

    # If branch commit is NOT in the non-leaf list, it's a leaf
    if echo "$NON_LEAF_COMMITS" | grep -q "^$BRANCH_COMMIT"; then
        LEAF_BRANCHES="$LEAF_BRANCHES $branch"
    fi
done

# Rebase leaf branches on top of main
if [ -n "$LEAF_BRANCHES" ]; then
    log "Rebasing leaf branches: $LEAF_BRANCHES"
    CURRENT_BRANCH=$(git_as_owner branch --show-current)

    # Stash any changes before switching branches
    STASHED=false
    if ! git_as_owner diff-index --quiet HEAD --; then
        log "Stashing changes before branch operations..."
        if [ "$DRY_RUN" = false ]; then
            git_as_owner stash push -m "Pre-rebase stash" || log "Warning: stash failed"
        fi
        STASHED=true
    fi

    for branch in $LEAF_BRANCHES; do
        log "Rebasing leaf branch: $branch"
        if [ "$DRY_RUN" = true ]; then
            log "Would rebase $branch onto main"
        elif git_as_owner checkout "$branch" 2>/dev/null; then
            if git_as_owner rebase --update-refs --no-autosquash --no-gpg-sign origin/main; then
                log "✓ Successfully rebased $branch"
            else
                log "Warning: Failed to rebase $branch, aborting rebase"
                git_as_owner rebase --abort
            fi
        else
            log "Warning: Could not checkout branch $branch"
        fi
    done

    # Return to original branch
    if [ -n "$CURRENT_BRANCH" ] && [ "$DRY_RUN" = false ]; then
        git_as_owner checkout "$CURRENT_BRANCH" 2>/dev/null || log "Warning: could not return to branch $CURRENT_BRANCH"
    fi

    # Restore stashed changes
    if [ "$STASHED" = true ] && [ "$DRY_RUN" = false ]; then
        log "Restoring stashed changes..."
        git_as_owner stash pop || log "Warning: could not restore stash"
    fi
else
    log "No leaf branches to rebase"
fi

# Ensure file ownership is correct
log "Fixing file ownership..."
if [ "$DRY_RUN" = false ]; then
    chown -R "$REPO_OWNER:users" "$REPO_DIR"
fi

if [ "$DRY_RUN" = true ]; then
    log "Would run: docker system prune --all --volumes --force"
    log "Would run: nix-collect-garbage --delete-older-than 30d"
else
    log "Performing docker system prune..."
    docker system prune --all --volumes --force
    log "Cleaning up old generations..."
    nix-collect-garbage --delete-older-than 30d || log "Warning: garbage collection failed"
fi

exit 0
