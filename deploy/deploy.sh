#!/bin/bash
set -euo pipefail

# Deploy NovoJogo to a remote server via rsync.
# Usage: ./deploy/deploy.sh usuario@ip-do-droplet
#        ./deploy/deploy.sh --dry-run usuario@ip-do-droplet

DRY_RUN=""
HOST=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN="--dry-run" ;;
        *) HOST="$arg" ;;
    esac
done

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 [--dry-run] usuario@ip-do-droplet"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REMOTE_PATH="/opt/novojogo/godot/"

echo "=== NovoJogo Deploy ==="
echo "Source: ${PROJECT_DIR}/godot/"
echo "Target: ${HOST}:${REMOTE_PATH}"
[[ -n "$DRY_RUN" ]] && echo "MODE: dry-run (no changes)"

# Sync project files, excluding dev-only stuff
rsync -avz --delete $DRY_RUN \
    --exclude='.godot/' \
    --exclude='tests/' \
    --exclude='addons/gut/' \
    --exclude='*.uid' \
    --exclude='.gdignore' \
    "${PROJECT_DIR}/godot/" "${HOST}:${REMOTE_PATH}"

if [[ -n "$DRY_RUN" ]]; then
    echo "Dry-run complete. No changes made."
    exit 0
fi

echo "Restarting server..."
ssh "$HOST" "sudo systemctl restart novojogo"

echo "Checking status..."
STATUS=$(ssh "$HOST" "systemctl is-active novojogo" || true)
if [[ "$STATUS" == "active" ]]; then
    echo "Server is running."
else
    echo "WARNING: Server status is '${STATUS}'. Check logs:"
    echo "  ssh ${HOST} 'journalctl -u novojogo -n 50 --no-pager'"
fi

echo "=== Deploy complete ==="
