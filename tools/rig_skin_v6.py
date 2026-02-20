"""
Rig any Meshy model onto KayKit skeleton - V6.
Generic version: works with GLB or FBX input.
Usage: blender --background --python rig_skin_v6.py
"""
import bpy
import math
import sys
import os

# ===================== CONFIG =====================
MODEL_PATH = "/home/lumen/Downloads/Meshy_AI_Camouflage_Frog_Soldi_0216214951_texture.glb"
KNIGHT_PATH = "/home/lumen/novojogo/godot/assets/kaykit/adventurers/Knight.glb"
OUTPUT_PATH = "/home/lumen/novojogo/godot/assets/kaykit/adventurers/CamoFrog.glb"
OUTPUT_NAME = "CamoFrog"
TARGET_HEIGHT = 2.3
# ==================================================

def log(msg):
    print(f"[RIG6] {msg}")

def import_model(path):
    """Import GLB, FBX, or OBJ based on extension."""
    ext = os.path.splitext(path)[1].lower()
    if ext in ('.glb', '.gltf'):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=path)
    else:
        log(f"ERROR: Unsupported format: {ext}")
        sys.exit(1)

# =============================================================
# 1. Import Knight — extract armature + bone info
# =============================================================
log("STEP 1: Import Knight armature")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=KNIGHT_PATH)

armature_obj = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature_obj = obj
        break

if not armature_obj:
    log("ERROR: No armature found in Knight.glb")
    sys.exit(1)

armature_obj.name = "Rig_Medium"
armature_obj.data.name = "Rig_Medium"

bone_info = {}
am = armature_obj.matrix_world
for bone in armature_obj.data.bones:
    h = am @ bone.head_local
    t = am @ bone.tail_local
    bone_info[bone.name] = {'head': h.copy(), 'tail': t.copy()}

bone_names = [b.name for b in armature_obj.data.bones]
log(f"  Armature: {len(bone_names)} bones: {bone_names[:10]}...")

# Armature height for reference
arm_zs = []
for bi in bone_info.values():
    arm_zs.extend([bi['head'].z, bi['tail'].z])
arm_height = max(arm_zs) - min(arm_zs)
log(f"  Armature height: {arm_height:.3f}")

# Remove custom bone shapes
bpy.context.view_layer.objects.active = armature_obj
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.object.mode_set(mode='POSE')
for pbone in armature_obj.pose.bones:
    if pbone.custom_shape:
        pbone.custom_shape = None
bpy.ops.object.mode_set(mode='OBJECT')

# Remove everything except armature
for obj in list(bpy.data.objects):
    if obj != armature_obj:
        bpy.data.objects.remove(obj, do_unlink=True)

for _ in range(3):
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)

for mesh in list(bpy.data.meshes):
    bpy.data.meshes.remove(mesh)

# =============================================================
# 2. Import model mesh
# =============================================================
log(f"STEP 2: Import model from {os.path.basename(MODEL_PATH)}")
pre_import = set(obj.name for obj in bpy.data.objects)
import_model(MODEL_PATH)

model_meshes = []
for obj in bpy.data.objects:
    if obj.name not in pre_import:
        if obj.type == 'MESH':
            model_meshes.append(obj)
        elif obj.type == 'ARMATURE':
            log(f"  Removing model's own armature: {obj.name}")
            # First unparent any children
            for child in list(obj.children):
                child.parent = None
                child.matrix_world = child.matrix_world
                if child.type == 'MESH' and child not in model_meshes:
                    model_meshes.append(child)
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == 'EMPTY':
            # FBX often has Empty nodes — check for mesh children
            for child in list(obj.children):
                child.parent = None
                child.matrix_world = child.matrix_world
                if child.type == 'MESH' and child not in model_meshes:
                    model_meshes.append(child)
            bpy.data.objects.remove(obj, do_unlink=True)

# Also find meshes that were children of removed armatures/empties
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj != armature_obj and obj not in model_meshes:
        if obj.name not in pre_import or obj.name == 'Rig_Medium':
            continue
        model_meshes.append(obj)

log(f"  Model meshes: {[m.name for m in model_meshes]}")
if not model_meshes:
    log("ERROR: No meshes found in model")
    sys.exit(1)

# Remove any armature modifiers from imported meshes (from their old rig)
for m in model_meshes:
    for mod in list(m.modifiers):
        if mod.type == 'ARMATURE':
            m.modifiers.remove(mod)
    # Clear vertex groups from old rig
    m.vertex_groups.clear()

# =============================================================
# 3. Apply transforms, scale, center
# =============================================================
log("STEP 3: Apply transforms, scale, center")

# Apply transforms first
for m in model_meshes:
    bpy.ops.object.select_all(action='DESELECT')
    m.select_set(True)
    bpy.context.view_layer.objects.active = m
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Compute bounds
all_wv = []
for m in model_meshes:
    mm = m.matrix_world
    for v in m.data.vertices:
        all_wv.append(mm @ v.co)

min_x = min(v.x for v in all_wv); max_x = max(v.x for v in all_wv)
min_y = min(v.y for v in all_wv); max_y = max(v.y for v in all_wv)
min_z = min(v.z for v in all_wv); max_z = max(v.z for v in all_wv)
cx = (min_x + max_x) / 2; cy = (min_y + max_y) / 2
cur_height = max_z - min_z
sf = TARGET_HEIGHT / cur_height if cur_height > 0.001 else 1.0
log(f"  Bounds: X=[{min_x:.3f},{max_x:.3f}] Y=[{min_y:.3f},{max_y:.3f}] Z=[{min_z:.3f},{max_z:.3f}]")
log(f"  Current height: {cur_height:.3f}, target: {TARGET_HEIGHT}, scale: {sf:.4f}")

for m in model_meshes:
    m.location.x -= cx; m.location.y -= cy; m.location.z -= min_z
    bpy.ops.object.select_all(action='DESELECT')
    m.select_set(True)
    bpy.context.view_layer.objects.active = m
    bpy.ops.object.transform_apply(location=True)
    m.scale = (sf, sf, sf)
    bpy.ops.object.transform_apply(scale=True)

# =============================================================
# 4. Join meshes
# =============================================================
log("STEP 4: Join meshes")
if len(model_meshes) > 1:
    bpy.ops.object.select_all(action='DESELECT')
    for m in model_meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = model_meshes[0]
    bpy.ops.object.join()
    skin_mesh = bpy.context.active_object
else:
    skin_mesh = model_meshes[0]
skin_mesh.name = OUTPUT_NAME

n_verts = len(skin_mesh.data.vertices)
mm = skin_mesh.matrix_world
scaled_verts = [mm @ v.co for v in skin_mesh.data.vertices]
height = max(v.z for v in scaled_verts) - min(v.z for v in scaled_verts)
log(f"  {n_verts} vertices, height={height:.3f}")

# =============================================================
# 5. Arm detection
# =============================================================
log("STEP 5: Arm detection")

SHOULDER_Z = bone_info['upperarm.l']['head'].z

neck_verts = [sv for sv in scaled_verts if 1.12 <= sv.z <= 1.22]
if neck_verts:
    neck_abs_x = sorted([abs(sv.x) for sv in neck_verts])
    neck_half = neck_abs_x[len(neck_abs_x) // 2]
else:
    neck_half = 0.19
log(f"  Neck half-width: {neck_half:.4f}")

def body_hw(z):
    if z >= SHOULDER_Z:
        return neck_half * 0.75
    elif z >= 0.7:
        t = (SHOULDER_Z - z) / (SHOULDER_Z - 0.7)
        return neck_half * 0.75 + t * 0.10
    elif z >= 0.40:
        return neck_half * 0.85 + 0.05
    else:
        return 0.20

adj = {i: set() for i in range(n_verts)}
for edge in skin_mesh.data.edges:
    a, b = edge.vertices
    adj[a].add(b); adj[b].add(a)

left_arm = set()
right_arm = set()

for vi, sv in enumerate(scaled_verts):
    if sv.z < 0.35 or sv.z > 1.22:
        continue
    bw = body_hw(sv.z)
    if sv.x > bw:
        left_arm.add(vi)
    elif sv.x < -bw:
        right_arm.add(vi)

def flood_extend(seed_set, adj, scaled_verts, side_sign, body_hw_fn):
    result = set(seed_set)
    queue = list(seed_set)
    visited = set(seed_set)
    while queue:
        cur = queue.pop(0)
        for nb in adj[cur]:
            if nb in visited:
                continue
            visited.add(nb)
            nv = scaled_verts[nb]
            if nv.z > 1.25 or nv.z < 0.30:
                continue
            if nv.x * side_sign < 0.02:
                continue
            bw = body_hw_fn(nv.z) * 0.80
            if abs(nv.x) < bw:
                continue
            result.add(nb)
            queue.append(nb)
    return result

left_arm = flood_extend(left_arm, adj, scaled_verts, 1, body_hw)
right_arm = flood_extend(right_arm, adj, scaled_verts, -1, body_hw)
log(f"  Left arm: {len(left_arm)} verts, Right arm: {len(right_arm)} verts")

# =============================================================
# 6. Reshape arms to T-pose
# =============================================================
log("STEP 6: Reshape to T-pose")

from mathutils import Matrix
KAYKIT_ARM_LENGTH = 0.69
mm_inv = skin_mesh.matrix_world.inverted()

for side_sign, arm_set, side_name in [(1, left_arm, "Left"), (-1, right_arm, "Right")]:
    if not arm_set:
        continue
    side = 'l' if side_sign > 0 else 'r'
    pivot = bone_info[f'upperarm.{side}']['head'].copy()
    avs = [scaled_verts[vi] for vi in arm_set]
    arm_bottom = min(v.z for v in avs)
    cur_len = pivot.z - arm_bottom
    arm_scale = KAYKIT_ARM_LENGTH / max(cur_len, 0.1)
    arm_scale = min(arm_scale, 3.0)
    angle = -math.pi / 2 * side_sign
    rot = Matrix.Rotation(angle, 3, 'Y')
    log(f"  {side_name}: pivot=({pivot.x:.3f},{pivot.z:.3f}), len={cur_len:.3f}, scale={arm_scale:.3f}")
    for vi in arm_set:
        rel = scaled_verts[vi] - pivot
        new_rel = rot @ (rel * arm_scale)
        new_world = pivot + new_rel
        skin_mesh.data.vertices[vi].co = mm_inv @ new_world
        scaled_verts[vi] = new_world

skin_mesh.data.update()

# =============================================================
# 7. Create vertex groups + weight assignment
# =============================================================
log("STEP 7: Weight assignment")

skin_mesh.vertex_groups.clear()
vg = {}
for bn in bone_names:
    vg[bn] = skin_mesh.vertex_groups.new(name=bn)

mm = skin_mesh.matrix_world
verts = [mm @ v.co for v in skin_mesh.data.vertices]

def seg_dist(p, a, b):
    ab = b - a; sq = ab.dot(ab)
    if sq < 1e-10: return (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / sq))
    return (p - (a + ab * t)).length

HEAD_BOTTOM = bone_info['head']['head'].z
CHEST_TOP = bone_info['chest']['tail'].z
CHEST_BOTTOM = bone_info['chest']['head'].z
SPINE_BOTTOM = bone_info['spine']['head'].z
HIPS_BOTTOM = bone_info['hips']['head'].z

all_arm = left_arm | right_arm

for vi in range(n_verts):
    v = verts[vi]
    x, y, z = v.x, v.y, v.z
    weights = {}

    if vi in all_arm:
        side = 'l' if vi in left_arm else 'r'
        arm_bones = [f'upperarm.{side}', f'lowerarm.{side}', f'wrist.{side}', f'hand.{side}', f'handslot.{side}']
        sigmas = {
            f'upperarm.{side}': 0.15, f'lowerarm.{side}': 0.13,
            f'wrist.{side}': 0.08, f'hand.{side}': 0.07, f'handslot.{side}': 0.06,
        }
        for bn in arm_bones:
            d = seg_dist(v, bone_info[bn]['head'], bone_info[bn]['tail'])
            s = sigmas[bn]
            w = math.exp(-d**2 / (2 * s**2))
            if w > 0.001:
                weights[bn] = w
        d_chest = seg_dist(v, bone_info['chest']['head'], bone_info['chest']['tail'])
        w_chest = math.exp(-d_chest**2 / (2 * 0.15**2)) * 0.2
        if w_chest > 0.001:
            weights['chest'] = w_chest

    elif z > HEAD_BOTTOM - 0.08:
        t = min(1, max(0, (z - (HEAD_BOTTOM - 0.08)) / 0.13))
        weights['head'] = t
        weights['chest'] = (1 - t) * 0.7
        weights['spine'] = (1 - t) * 0.3

    elif z > CHEST_BOTTOM:
        t = min(1, max(0, (z - CHEST_BOTTOM) / (CHEST_TOP - CHEST_BOTTOM)))
        weights['chest'] = 0.5 + 0.5 * t
        weights['spine'] = 0.5 - 0.5 * t

    elif z > SPINE_BOTTOM:
        t = min(1, max(0, (z - SPINE_BOTTOM) / (CHEST_BOTTOM - SPINE_BOTTOM)))
        weights['spine'] = 0.5 + 0.5 * t
        weights['hips'] = 0.3 * (1 - t)
        weights['chest'] = 0.2 * t

    elif z > HIPS_BOTTOM:
        t = min(1, max(0, (z - HIPS_BOTTOM) / (SPINE_BOTTOM - HIPS_BOTTOM)))
        weights['hips'] = 0.6 + 0.2 * t
        weights['spine'] = 0.2 * t
        weights['root'] = 0.2 * (1 - t)
        if abs(x) > 0.10:
            side = 'l' if x > 0 else 'r'
            d = seg_dist(v, bone_info[f'upperleg.{side}']['head'], bone_info[f'upperleg.{side}']['tail'])
            weights[f'upperleg.{side}'] = math.exp(-d**2 / (2*0.12**2)) * 0.4

    else:  # Legs
        if abs(x) < 0.03:
            for s in ['l', 'r']:
                blend = 0.5 + (x / 0.06 if s == 'l' else -x / 0.06)
                blend = max(0.2, min(0.8, blend))
                for bp in ['upperleg', 'lowerleg', 'foot', 'toes']:
                    bn = f'{bp}.{s}'
                    d = seg_dist(v, bone_info[bn]['head'], bone_info[bn]['tail'])
                    sig = 0.10 if bp == 'toes' else 0.12
                    w = math.exp(-d**2 / (2*sig**2)) * blend
                    if w > 0.001: weights[bn] = w
            if z > HIPS_BOTTOM - 0.08:
                weights['hips'] = max(0, (z - (HIPS_BOTTOM - 0.08)) / 0.08) * 0.3
        else:
            side = 'l' if x > 0 else 'r'
            for bp in ['upperleg', 'lowerleg', 'foot', 'toes']:
                bn = f'{bp}.{side}'
                d = seg_dist(v, bone_info[bn]['head'], bone_info[bn]['tail'])
                sig = 0.10 if bp == 'toes' else 0.12
                w = math.exp(-d**2 / (2*sig**2))
                if w > 0.001: weights[bn] = w
            if z > HIPS_BOTTOM - 0.08:
                weights['hips'] = max(0, (z - (HIPS_BOTTOM - 0.08)) / 0.08) * 0.3

    total = sum(weights.values())
    if total > 0:
        for bn, w in weights.items():
            nw = w / total
            if nw > 0.003:
                vg[bn].add([vi], nw, 'REPLACE')
    else:
        vg['root'].add([vi], 1.0, 'REPLACE')

# Boost handslot weights
log("STEP 7b: Boost handslot weights")
for side in ['l', 'r']:
    hs = f'handslot.{side}'
    hs_pos = bone_info[hs]['head']
    arm_set = left_arm if side == 'l' else right_arm
    candidates = []
    for vi in arm_set:
        d = (verts[vi] - hs_pos).length
        candidates.append((vi, d))
    candidates.sort(key=lambda t: t[1])
    n_assign = min(40, len(candidates))
    for vi, d in candidates[:n_assign]:
        w = max(0.05, math.exp(-d**2 / (2 * 0.05**2)))
        vg[hs].add([vi], w, 'ADD')
    log(f"  {hs}: assigned {n_assign} vertices")

# Normalize
bpy.ops.object.select_all(action='DESELECT')
skin_mesh.select_set(True)
bpy.context.view_layer.objects.active = skin_mesh
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')

# =============================================================
# 8. Smooth weights
# =============================================================
log("STEP 8: Smooth weights")
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
vg_hs_l = skin_mesh.vertex_groups.get('handslot.l')
vg_hs_r = skin_mesh.vertex_groups.get('handslot.r')
if vg_hs_l: vg_hs_l.lock_weight = True
if vg_hs_r: vg_hs_r.lock_weight = True
for bn in bone_names:
    if 'handslot' in bn:
        continue
    idx = skin_mesh.vertex_groups[bn].index
    skin_mesh.vertex_groups.active_index = idx
    bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.25, repeat=1)
if vg_hs_l: vg_hs_l.lock_weight = False
if vg_hs_r: vg_hs_r.lock_weight = False
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.ops.object.mode_set(mode='OBJECT')

# =============================================================
# 9. Parent mesh to armature
# =============================================================
log("STEP 9: Parent to armature (ARMATURE_NAME)")

skin_mesh.parent = None
skin_mesh.matrix_world = skin_mesh.matrix_world

for mod in list(skin_mesh.modifiers):
    if mod.type == 'ARMATURE':
        skin_mesh.modifiers.remove(mod)

bpy.ops.object.select_all(action='DESELECT')
skin_mesh.select_set(True)
armature_obj.select_set(True)
bpy.context.view_layer.objects.active = armature_obj
bpy.ops.object.parent_set(type='ARMATURE_NAME')

has_arm_mod = False
for mod in skin_mesh.modifiers:
    if mod.type == 'ARMATURE':
        has_arm_mod = True
        mod.object = armature_obj
        log(f"  Armature modifier: {mod.name} -> {mod.object.name}")
        break

if not has_arm_mod:
    mod = skin_mesh.modifiers.new(name='Armature', type='ARMATURE')
    mod.object = armature_obj
    log("  Added armature modifier manually")

log(f"  Parent: {skin_mesh.parent.name if skin_mesh.parent else 'NONE'}")

# =============================================================
# 10. Pre-export verification
# =============================================================
log("STEP 10: Pre-export verification")
vg_names = set(g.name for g in skin_mesh.vertex_groups)
bone_name_set = set(bone_names)
matching = vg_names & bone_name_set
log(f"  Vertex groups matching bones: {len(matching)}/{len(bone_name_set)}")

for bn in ['hips', 'chest', 'head', 'hand.r', 'handslot.r']:
    vg_obj = skin_mesh.vertex_groups.get(bn)
    if vg_obj:
        count = sum(1 for v in skin_mesh.data.vertices for g in v.groups if g.group == vg_obj.index and g.weight > 0.005)
        log(f"  {bn:20s}: {count} weighted verts")

# =============================================================
# 11. Cleanup + Export
# =============================================================
log("STEP 11: Export")

for obj in list(bpy.data.objects):
    if obj != armature_obj and obj != skin_mesh:
        log(f"  Removing stray: {obj.name}")
        bpy.data.objects.remove(obj, do_unlink=True)

for _ in range(3):
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)

skin_mesh_data = skin_mesh.data
for mesh in list(bpy.data.meshes):
    if mesh != skin_mesh_data:
        bpy.data.meshes.remove(mesh)

log(f"  Final objects: {[(o.name, o.type) for o in bpy.data.objects]}")

bpy.ops.object.select_all(action='DESELECT')
armature_obj.select_set(True)
skin_mesh.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=OUTPUT_PATH,
    export_format='GLB',
    use_selection=True,
    export_apply=False,
    export_animations=False,
    export_skins=True,
    export_all_influences=False,
    export_materials='EXPORT',
    export_texcoords=True,
    export_normals=True,
    export_yup=True,
)

sz = os.path.getsize(OUTPUT_PATH)
log(f"  Exported: {sz/1024:.1f} KB")

# =============================================================
# 12. Verify
# =============================================================
log("STEP 12: Verify exported GLB")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=OUTPUT_PATH)

for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        log(f"  ARMATURE: {obj.name}, {len(obj.data.bones)} bones")
    elif obj.type == 'MESH':
        log(f"  MESH: {obj.name}, {len(obj.data.vertices)} verts, {len(obj.vertex_groups)} vgroups")
        if obj.parent and obj.parent.type == 'ARMATURE':
            log(f"    SKIN BINDING OK — parent: {obj.parent.name}")
        else:
            log(f"    NO SKIN BINDING — parent: {obj.parent}")
        weighted = {}
        for v in obj.data.vertices:
            for g in v.groups:
                if g.weight > 0.005:
                    gn = obj.vertex_groups[g.group].name
                    weighted[gn] = weighted.get(gn, 0) + 1
        log(f"    Bones with weights: {len(weighted)}/23")

log("DONE!")
