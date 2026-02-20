#!/bin/bash
# Deploy ChibiRoyale builds to itch.io
# Usage: ./tools/deploy_itchio.sh [username/game]
# Example: ./tools/deploy_itchio.sh chibiroyale/foforoyal

set -e

BUTLER="$HOME/.local/bin/butler"
GAME="${1:-chibiroyale/foforoyal}"
BUILD_DIR="godot/builds"

echo "=== ChibiRoyale itch.io Deploy ==="
echo "Target: $GAME"

# Check butler
if [ ! -f "$BUTLER" ]; then
    echo "ERROR: butler not found at $BUTLER"
    exit 1
fi

# Check builds exist
if [ ! -f "$BUILD_DIR/windows/ChibiRoyale.exe" ]; then
    echo "ERROR: Windows build not found. Run export first."
    exit 1
fi

if [ ! -f "$BUILD_DIR/linux/ChibiRoyale.x86_64" ]; then
    echo "ERROR: Linux build not found. Run export first."
    exit 1
fi

echo ""
echo "Pushing Windows build..."
$BUTLER push "$BUILD_DIR/windows" "$GAME:windows" --userversion-file godot/project.godot

echo ""
echo "Pushing Linux build..."
$BUTLER push "$BUILD_DIR/linux" "$GAME:linux" --userversion-file godot/project.godot

echo ""
echo "=== Deploy complete! ==="
echo "Check: https://${GAME%%/*}.itch.io/${GAME##*/}"
