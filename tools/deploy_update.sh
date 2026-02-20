#!/bin/bash
# Deploy update: build, upload .pck, update version.txt, sync server source
# Usage: ./tools/deploy_update.sh [version]
# Example: ./tools/deploy_update.sh 0.1.1

set -e

SERVER="root@137.184.76.179"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH="ssh -i $SSH_KEY $SERVER"
RSYNC="rsync -avz -e 'ssh -i $SSH_KEY'"

GODOT_DIR="$(dirname "$0")/../godot"
BUILD_DIR="$(dirname "$0")/../builds/linux"

# Get version from argument or from game_settings.gd
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=$(grep 'GAME_VERSION' "$GODOT_DIR/scripts/autoload/game_settings.gd" | grep -oP '"[^"]+"' | tr -d '"')
    echo "Current version: $VERSION"
    echo "Usage: $0 <new_version> to deploy a new version"
    echo "Or run without args to re-deploy current version"
fi

echo "=== Deploying v$VERSION ==="

# Step 1: Update version in game_settings.gd if provided as arg
if [ -n "$1" ]; then
    echo "[1/6] Updating version to $VERSION..."
    sed -i "s/GAME_VERSION := \"[^\"]*\"/GAME_VERSION := \"$VERSION\"/" "$GODOT_DIR/scripts/autoload/game_settings.gd"
    sed -i "s/config\/version=\"[^\"]*\"/config\/version=\"$VERSION\"/" "$GODOT_DIR/project.godot"
else
    echo "[1/6] Using existing version $VERSION"
fi

# Step 2: Build Linux export
echo "[2/6] Building Linux export..."
mkdir -p "$BUILD_DIR"
cd "$GODOT_DIR"
godot-4 --headless --export-release "Linux" "$BUILD_DIR/ChibiRoyale.x86_64" 2>&1 | tail -3
cd - > /dev/null

# Step 3: Upload .pck to web server for auto-update
echo "[3/6] Uploading .pck to update server..."
rsync -avz --progress -e "ssh -i $SSH_KEY" "$BUILD_DIR/ChibiRoyale.pck" "$SERVER:/var/www/chibiroyale/updates/ChibiRoyale.pck"

# Step 4: Update version.txt
echo "[4/6] Updating version.txt to $VERSION..."
$SSH "echo '$VERSION' > /var/www/chibiroyale/version.txt && chown www-data:www-data /var/www/chibiroyale/version.txt /var/www/chibiroyale/updates/ChibiRoyale.pck"

# Step 5: Sync source to game server
echo "[5/6] Syncing source to game server..."
rsync -avz --delete --exclude=".godot/editor/" --exclude=".godot/shader_cache/" -e "ssh -i $SSH_KEY" "$GODOT_DIR/" "$SERVER:/opt/novojogo/godot/" 2>&1 | tail -5

# Step 6: Restart game server
echo "[6/6] Restarting game server..."
$SSH "systemctl restart novojogo"
sleep 3
$SSH "systemctl is-active novojogo"

echo ""
echo "=== Deploy v$VERSION complete ==="
echo "  - Auto-update .pck: https://chibiroyale.xyz/updates/ChibiRoyale.pck"
echo "  - Version check:    https://chibiroyale.xyz/version.txt"
echo "  - Game server:      game.chibiroyale.xyz:27015"
echo ""
echo "Clients will auto-update on next launch."
