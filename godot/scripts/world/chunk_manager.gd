extends Node
## Manages chunk lifecycle: loading, unloading, LOD transitions.
## Autoload — integrates with WorldGenerator and ChunkStreamer.

signal chunk_loaded(chunk_x: int, chunk_z: int)
signal chunk_unloaded(chunk_x: int, chunk_z: int)

const CHUNK_SIZE := 256
const MAP_SIZE := 4096
const GRID_SIZE := 16
const LOD_DISTANCES := [256.0, 512.0, 1024.0]  # LOD 0, 1, 2 max distances
const UPDATE_INTERVAL := 0.5  # Seconds between chunk update checks

const GRASS_STEP := 8.0  # Sample every 8m for grass placement
const GRASS_SCENES: Array[String] = [
	"res://assets/kaykit/forest/Grass_1_A_Color1.gltf",
	"res://assets/kaykit/forest/Grass_2_A_Color1.gltf",
]

var _loaded_chunks: Dictionary = {}  # "cx_cz" -> {data: ChunkData, node: Node3D, lod: int}
var _update_timer: float = 0.0
var _terrain_material: ShaderMaterial
var _water_scene: PackedScene
var _grass_mesh: Mesh


func _ready() -> void:
	# Pre-load shader material and water scene
	if ResourceLoader.exists("res://shaders/terrain.gdshader"):
		var shader := load("res://shaders/terrain.gdshader") as Shader
		if shader:
			_terrain_material = ShaderMaterial.new()
			_terrain_material.shader = shader
	if ResourceLoader.exists("res://scenes/world/water_plane.tscn"):
		_water_scene = load("res://scenes/world/water_plane.tscn")
	_load_grass_mesh()


func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL

	# Find the local player position
	var players := get_tree().get_nodes_in_group("players") if is_inside_tree() else []
	if players.is_empty():
		return

	# In singleplayer or on server, update for all players
	for player in players:
		if player is CharacterBody3D:
			update_chunks(player.global_position)
			break  # For now, single-viewpoint updates


func update_chunks(player_position: Vector3) -> void:
	## Load/unload chunks based on distance from player.
	var player_chunk := _get_chunk_coord(player_position)

	# Determine which chunks should be loaded at which LOD
	var desired: Dictionary = {}  # "cx_cz" -> lod
	for cz in GRID_SIZE:
		for cx in GRID_SIZE:
			var center := Vector3((cx + 0.5) * CHUNK_SIZE, 0.0, (cz + 0.5) * CHUNK_SIZE)
			var dist := Vector2(player_position.x, player_position.z).distance_to(
				Vector2(center.x, center.z)
			)
			var lod := _get_lod_for_distance(dist)
			if lod >= 0:
				desired[_chunk_key(cx, cz)] = lod

	# Unload chunks no longer needed
	var to_unload: Array[String] = []
	for key in _loaded_chunks:
		if not desired.has(key):
			to_unload.append(key)
	for key in to_unload:
		var parts = key.split("_")
		_unload_chunk(int(parts[0]), int(parts[1]))

	# Load new chunks or update LOD
	for key in desired:
		var lod: int = desired[key]
		if not _loaded_chunks.has(key):
			var parts = key.split("_")
			_load_chunk(int(parts[0]), int(parts[1]), lod)
		elif _loaded_chunks[key]["lod"] != lod:
			# LOD changed — reload
			var parts = key.split("_")
			_unload_chunk(int(parts[0]), int(parts[1]))
			_load_chunk(int(parts[0]), int(parts[1]), lod)


func _get_chunk_coord(world_pos: Vector3) -> Vector2i:
	## Convert world position to chunk grid coordinate (0-15).
	var cx := clampi(int(world_pos.x / CHUNK_SIZE), 0, GRID_SIZE - 1)
	var cz := clampi(int(world_pos.z / CHUNK_SIZE), 0, GRID_SIZE - 1)
	return Vector2i(cx, cz)


func _get_lod_for_distance(distance: float) -> int:
	## Returns LOD level (0-2) or -1 if too far (unload).
	for i in LOD_DISTANCES.size():
		if distance <= LOD_DISTANCES[i]:
			return i
	return -1


func _load_chunk(cx: int, cz: int, lod: int) -> void:
	var wg = get_node_or_null("/root/WorldGenerator")
	if not wg or not wg.is_initialized:
		return

	var data: ChunkData = wg.generate_chunk_data(cx, cz)
	data.lod_level = lod

	# Build terrain mesh
	var biome_colors := _generate_biome_colors(data)
	var mesh := TerrainGenerator.build_terrain_mesh(
		data.heightmap, data.get_world_origin(), lod, biome_colors
	)

	# Create chunk node
	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [cx, cz]
	chunk_node.position = data.get_world_origin()

	# Terrain mesh
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Terrain"
	mesh_inst.mesh = mesh
	if _terrain_material:
		mesh_inst.material_override = _terrain_material
	chunk_node.add_child(mesh_inst)

	# Collision (only LOD 0 and 1) — build from heightmap faces directly
	if lod <= 1:
		var col_body := StaticBody3D.new()
		col_body.name = "TerrainCollider"
		var step_val := 1 << lod
		var verts_side := (TerrainGenerator.VERTICES_PER_SIDE - 1) / step_val + 1
		var faces := PackedVector3Array()
		for fz in verts_side - 1:
			for fx in verts_side - 1:
				var hx0 := fx * step_val
				var hz0 := fz * step_val
				var hx1 := (fx + 1) * step_val
				var hz1 := (fz + 1) * step_val
				var sp := TerrainGenerator.VERTEX_SPACING
				var tl := Vector3(hx0 * sp, data.heightmap[hz0 * TerrainGenerator.VERTICES_PER_SIDE + hx0], hz0 * sp)
				var tr := Vector3(hx1 * sp, data.heightmap[hz0 * TerrainGenerator.VERTICES_PER_SIDE + hx1], hz0 * sp)
				var bl := Vector3(hx0 * sp, data.heightmap[hz1 * TerrainGenerator.VERTICES_PER_SIDE + hx0], hz1 * sp)
				var br := Vector3(hx1 * sp, data.heightmap[hz1 * TerrainGenerator.VERTICES_PER_SIDE + hx1], hz1 * sp)
				# Two triangles per quad (CCW winding, matching visual mesh)
				faces.append(tl)
				faces.append(tr)
				faces.append(bl)
				faces.append(bl)
				faces.append(tr)
				faces.append(br)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		col_body.add_child(col_shape)
		chunk_node.add_child(col_body)

	# Water plane — offset to center over terrain (PlaneMesh is origin-centered)
	if _water_scene and data.water_level > 0.0:
		var water := _water_scene.instantiate()
		water.position = Vector3(CHUNK_SIZE / 2.0, data.water_level, CHUNK_SIZE / 2.0)
		chunk_node.add_child(water)

	# Resource nodes (only LOD 0)
	if lod == 0:
		_spawn_resources(data, chunk_node)
		_spawn_grass(data, chunk_node)

	add_child(chunk_node)

	_loaded_chunks[_chunk_key(cx, cz)] = {
		"data": data,
		"node": chunk_node,
		"lod": lod,
	}
	chunk_loaded.emit(cx, cz)


func _unload_chunk(cx: int, cz: int) -> void:
	var key := _chunk_key(cx, cz)
	if not _loaded_chunks.has(key):
		return
	var entry: Dictionary = _loaded_chunks[key]
	var node: Node3D = entry["node"]
	if node and is_instance_valid(node):
		node.queue_free()
	_loaded_chunks.erase(key)
	chunk_unloaded.emit(cx, cz)


func _spawn_resources(data: ChunkData, parent: Node3D) -> void:
	## Instantiate resource node scenes at spawn points.
	for spawn in data.resource_positions:
		var scene_path := ResourceSpawner.get_scene_path(spawn["type"])
		if not ResourceLoader.exists(scene_path):
			continue
		var scene := load(scene_path) as PackedScene
		if not scene:
			continue
		var node := scene.instantiate()
		node.position = spawn["position"] - parent.position  # local to chunk
		node.rotation.y = spawn["rotation_y"]
		parent.add_child(node)


func _load_grass_mesh() -> void:
	## Extract mesh from a KayKit grass GLTF for use in MultiMesh.
	for path in GRASS_SCENES:
		if not ResourceLoader.exists(path):
			continue
		var scene := load(path) as PackedScene
		if not scene:
			continue
		var inst := scene.instantiate()
		var mesh_inst := _find_mesh_instance(inst)
		if mesh_inst:
			_grass_mesh = mesh_inst.mesh
		inst.free()
		if _grass_mesh:
			break


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := _find_mesh_instance(child)
		if result:
			return result
	return null


func _spawn_grass(data: ChunkData, parent: Node3D) -> void:
	## Create MultiMeshInstance3D with grass scattered across the chunk terrain.
	if not _grass_mesh:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = data.chunk_x * 1000 + data.chunk_z + 99999

	var transforms: Array[Transform3D] = []
	var cells := int(CHUNK_SIZE / GRASS_STEP)  # 32

	for gz in cells:
		for gx in cells:
			var local_x := gx * GRASS_STEP + rng.randf_range(0.0, GRASS_STEP)
			var local_z := gz * GRASS_STEP + rng.randf_range(0.0, GRASS_STEP)
			local_x = clampf(local_x, 0.0, CHUNK_SIZE - 0.1)
			local_z = clampf(local_z, 0.0, CHUNK_SIZE - 0.1)

			var height := TerrainGenerator.get_height_from_map(
				data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
			)

			# Skip underwater
			if height < WaterSystem.BASE_WATER_LEVEL:
				continue

			# Biome density filter
			var bx := mini(int(local_x / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
			var bz := mini(int(local_z / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
			var biome := data.get_biome_at_local(bx, bz)
			if rng.randf() > _get_grass_density(biome):
				continue

			var t := Transform3D.IDENTITY
			var scale_f := rng.randf_range(0.6, 1.4)
			t = t.scaled(Vector3(scale_f, scale_f, scale_f))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(local_x, height, local_z)
			transforms.append(t)

	if transforms.is_empty():
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var multi := MultiMeshInstance3D.new()
	multi.name = "Grass"
	multi.multimesh = mm
	parent.add_child(multi)


func _get_grass_density(biome: int) -> float:
	match biome:
		BiomeData.BiomeType.FOREST:
			return 0.8
		BiomeData.BiomeType.GRASSLAND:
			return 0.6
		BiomeData.BiomeType.DESERT:
			return 0.1
		BiomeData.BiomeType.ARCTIC:
			return 0.15
		_:
			return 0.4


func _generate_biome_colors(data: ChunkData) -> PackedColorArray:
	## Create per-vertex biome colors for the terrain mesh.
	var colors := PackedColorArray()
	var side := TerrainGenerator.VERTICES_PER_SIDE
	colors.resize(side * side)
	var biome_colors := {
		BiomeData.BiomeType.GRASSLAND: Color(0.35, 0.45, 0.25),
		BiomeData.BiomeType.FOREST: Color(0.2, 0.35, 0.15),
		BiomeData.BiomeType.DESERT: Color(0.76, 0.65, 0.4),
		BiomeData.BiomeType.ARCTIC: Color(0.85, 0.88, 0.92),
	}
	for z in side:
		for x in side:
			# Map vertex to biome grid (17 vertices -> 16 cells)
			var bx := mini(x, ChunkData.BIOME_GRID_SIDE - 1)
			var bz := mini(z, ChunkData.BIOME_GRID_SIDE - 1)
			var biome := data.get_biome_at_local(bx, bz)
			colors[z * side + x] = biome_colors.get(biome, Color(0.35, 0.45, 0.25))
	return colors


func _chunk_key(cx: int, cz: int) -> String:
	return "%d_%d" % [cx, cz]


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func is_chunk_loaded(cx: int, cz: int) -> bool:
	return _loaded_chunks.has(_chunk_key(cx, cz))
