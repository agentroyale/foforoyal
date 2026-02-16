#!/bin/bash
set -euo pipefail

# Deploy NovoJogo to a remote server via rsync.
# Usage: ./deploy/deploy.sh usuario@ip-do-droplet
#        ./deploy/deploy.sh --dry-run usuario@ip-do-droplet
#        ./deploy/deploy.sh --website usuario@ip-do-droplet
#        ./deploy/deploy.sh --all usuario@ip-do-droplet

DRY_RUN=""
HOST=""
DEPLOY_GAME=false
DEPLOY_WEBSITE=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN="--dry-run" ;;
        --website) DEPLOY_WEBSITE=true ;;
        --all) DEPLOY_GAME=true; DEPLOY_WEBSITE=true ;;
        *) HOST="$arg" ;;
    esac
done

# Default to game deploy if no flag specified
if [[ "$DEPLOY_GAME" == false && "$DEPLOY_WEBSITE" == false ]]; then
    DEPLOY_GAME=true
fi

if [[ -z "$HOST" ]]; then
    echo "Usage: $0 [--dry-run] [--website|--all] usuario@ip-do-droplet"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== NovoJogo Deploy ==="
[[ -n "$DRY_RUN" ]] && echo "MODE: dry-run (no changes)"

# --- Game Server Deploy ---
if [[ "$DEPLOY_GAME" == true ]]; then
    REMOTE_GAME="/opt/novojogo/godot/"
    echo ""
    echo "--- Game Server ---"
    echo "Source: ${PROJECT_DIR}/godot/"
    echo "Target: ${HOST}:${REMOTE_GAME}"

    rsync -avz --delete $DRY_RUN \
        --exclude='.godot/' \
        --exclude='tests/' \
        --exclude='addons/gut/' \
        --exclude='*.uid' \
        --exclude='.gdignore' \
        "${PROJECT_DIR}/godot/" "${HOST}:${REMOTE_GAME}"

    if [[ -z "$DRY_RUN" ]]; then
        echo "Restarting game server..."
        ssh "$HOST" "sudo systemctl restart novojogo"

        STATUS=$(ssh "$HOST" "systemctl is-active novojogo" || true)
        if [[ "$STATUS" == "active" ]]; then
            echo "Game server is running."
        else
            echo "WARNING: Game server status is '${STATUS}'. Check logs:"
            echo "  ssh ${HOST} 'journalctl -u novojogo -n 50 --no-pager'"
        fi
    fi
fi

# --- Website Deploy ---
if [[ "$DEPLOY_WEBSITE" == true ]]; then
    REMOTE_WEB="/var/www/chibiroyale/"
    echo ""
    echo "--- Website ---"
    echo "Source: ${PROJECT_DIR}/website/"
    echo "Target: ${HOST}:${REMOTE_WEB}"

    rsync -avz --delete $DRY_RUN \
        --exclude='generate_images.py' \
        --exclude='__pycache__/' \
        --exclude='.DS_Store' \
        "${PROJECT_DIR}/website/" "${HOST}:${REMOTE_WEB}"

    if [[ -z "$DRY_RUN" ]]; then
        echo "Website deployed."
    fi
fi

if [[ -n "$DRY_RUN" ]]; then
    echo ""
    echo "Dry-run complete. No changes made."
fi

echo ""
echo "=== Deploy complete ==="
