#!/bin/bash
# Add a new Meshy skin to the game
# Usage: ./tools/add_skin.sh /path/to/model.glb SkinName "Descricao" "0.7,0.5,0.3"
#
# Example:
#   ./tools/add_skin.sh ~/Downloads/elonzin.glb Elonzin "O magnata espacial" "0.7,0.7,0.8"

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <model.glb> <SkinName> [description] [r,g,b]"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Downloads/pepe.glb Pepe"
    echo "  $0 ~/Downloads/ninja.glb Ninja 'Guerreiro das sombras' '0.3,0.3,0.5'"
    exit 1
fi

MODEL_PATH="$(realpath "$1")"
SKIN_NAME="$2"
DESCRIPTION="${3:-Skin customizada}"
COLOR="${4:-0.5,0.5,0.5}"
SKIN_ID=$(echo "$SKIN_NAME" | tr '[:upper:]' '[:lower:]')

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="$PROJ_DIR/godot/assets/kaykit/adventurers/${SKIN_NAME}.glb"
BLENDER="/home/lumen/blender-4.2.0-linux-x64/blender"

echo "=== Adding skin: $SKIN_NAME ==="
echo "  Model: $MODEL_PATH"
echo "  Output: $OUTPUT_PATH"
echo "  ID: $SKIN_ID"

# Step 1: Rig with Blender (keep Meshy weights)
echo ""
echo "--- Step 1: Processing in Blender ---"
$BLENDER --background --python-expr "
import bpy, os

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='$MODEL_PATH')

armature = None
meshes = []
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        meshes.append(obj)

# Find main mesh (most verts + has vertex groups)
main = max(meshes, key=lambda m: len(m.data.vertices))
print(f'[SKIN] Main mesh: {main.name} ({len(main.data.vertices)} verts)')

# Remove other meshes
for m in meshes:
    if m != main:
        print(f'[SKIN] Removing: {m.name}')
        bpy.data.objects.remove(m, do_unlink=True)

main.name = '$SKIN_NAME'

# Decimate if needed
n = len(main.data.vertices)
if n > 50000:
    ratio = 50000 / n
    print(f'[SKIN] Decimating {n} -> ~50000 (ratio={ratio:.4f})')
    bpy.ops.object.select_all(action='DESELECT')
    main.select_set(True)
    bpy.context.view_layer.objects.active = main
    mod = main.modifiers.new(name='Decimate', type='DECIMATE')
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier='Decimate')
    # Fill holes
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.mesh.select_non_manifold(extend=False)
    try:
        bpy.ops.mesh.fill_holes(sides=8)
    except:
        pass
    bpy.ops.object.mode_set(mode='OBJECT')
    print(f'[SKIN] After decimate: {len(main.data.vertices)} verts')
else:
    print(f'[SKIN] No decimation needed ({n} verts)')

# Export
bpy.ops.object.select_all(action='DESELECT')
if armature:
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
main.select_set(True)

bpy.ops.export_scene.gltf(
    filepath='$OUTPUT_PATH',
    use_selection=True,
    export_format='GLB',
    export_apply=True,
    export_animations=False,
    export_skins=True,
)
size = os.path.getsize('$OUTPUT_PATH') / 1024
print(f'[SKIN] Exported: {size:.1f} KB')
print('[SKIN] DONE')
" 2>&1 | grep "\[SKIN\]"

# Step 2: Register in player_controller.gd
echo ""
echo "--- Step 2: Registering in game ---"
CONTROLLER="$PROJ_DIR/godot/scripts/player/player_controller.gd"
SELECT="$PROJ_DIR/godot/scripts/ui/character_select.gd"

if grep -q "\"$SKIN_ID\"" "$CONTROLLER"; then
    echo "  Already in player_controller.gd"
else
    sed -i "/^}$/i\\\\t\"$SKIN_ID\": \"res://assets/kaykit/adventurers/${SKIN_NAME}.glb\"," "$CONTROLLER"
    echo "  Added to player_controller.gd"
fi

if grep -q "\"$SKIN_ID\"" "$SELECT"; then
    echo "  Already in character_select.gd"
else
    IFS=',' read -r R G B <<< "$COLOR"
    sed -i "/^]$/i\\\\t{\"id\": \"$SKIN_ID\", \"name\": \"$SKIN_NAME\", \"glb\": \"res://assets/kaykit/adventurers/${SKIN_NAME}.glb\", \"desc\": \"$DESCRIPTION\", \"color\": Color($R, $G, $B)}," "$SELECT"
    echo "  Added to character_select.gd"
fi

echo ""
echo "=== Done! Run the game to test $SKIN_NAME ==="
