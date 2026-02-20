extends Node
## Manages chunk lifecycle: loading, unloading, LOD transitions.
## Autoload — integrates with WorldGenerator and ChunkStreamer.

signal chunk_loaded(chunk_x: int, chunk_z: int)
signal chunk_unloaded(chunk_x: int, chunk_z: int)

const CHUNK_SIZE := 256
const MAP_SIZE := 1024
const GRID_SIZE := 4
const LOD_DISTANCES := [256.0, 512.0, 1024.0]  # LOD 0, 1, 2 max distances
const UPDATE_INTERVAL := 0.5  # Seconds between chunk update checks

const GRASS_STEP := 4.0  # Sample every 4m for dense grass
const GRASS_SCENES: Array[String] = [
	"res://assets/kaykit/forest/Grass_1_A_Color1.gltf",
	"res://assets/kaykit/forest/Grass_1_B_Color1.gltf",
	"res://assets/kaykit/forest/Grass_1_C_Color1.gltf",
	"res://assets/kaykit/forest/Grass_1_D_Color1.gltf",
	"res://assets/kaykit/forest/Grass_2_A_Color1.gltf",
	"res://assets/kaykit/forest/Grass_2_B_Color1.gltf",
	"res://assets/kaykit/forest/Grass_2_C_Color1.gltf",
	"res://assets/kaykit/forest/Grass_2_D_Color1.gltf",
]

const BUSH_STEP := 12.0  # Bushes every ~12m
const BUSH_SCENES: Array[String] = [
	"res://assets/kaykit/forest/Bush_1_A_Color1.gltf",
	"res://assets/kaykit/forest/Bush_1_B_Color1.gltf",
	"res://assets/kaykit/forest/Bush_1_C_Color1.gltf",
	"res://assets/kaykit/forest/Bush_1_D_Color1.gltf",
	"res://assets/kaykit/forest/Bush_1_E_Color1.gltf",
	"res://assets/kaykit/forest/Bush_2_A_Color1.gltf",
	"res://assets/kaykit/forest/Bush_2_B_Color1.gltf",
	"res://assets/kaykit/forest/Bush_2_C_Color1.gltf",
	"res://assets/kaykit/forest/Bush_3_A_Color1.gltf",
	"res://assets/kaykit/forest/Bush_3_B_Color1.gltf",
	"res://assets/kaykit/forest/Bush_4_A_Color1.gltf",
	"res://assets/kaykit/forest/Bush_4_B_Color1.gltf",
	"res://assets/kaykit/forest/Bush_4_C_Color1.gltf",
]

const HILL_SCENES: Array[String] = [
	"res://assets/kaykit/forest/Hill_2x2x2_Color1.gltf",
	"res://assets/kaykit/forest/Hill_2x2x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_4x2x2_Color1.gltf",
	"res://assets/kaykit/forest/Hill_4x2x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_4x4x2_Color1.gltf",
	"res://assets/kaykit/forest/Hill_4x4x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_8x4x2_Color1.gltf",
	"res://assets/kaykit/forest/Hill_8x4x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_8x8x2_Color1.gltf",
	"res://assets/kaykit/forest/Hill_8x8x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_8x8x8_Color1.gltf",
	"res://assets/kaykit/forest/Hill_12x6x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_12x12x4_Color1.gltf",
	"res://assets/kaykit/forest/Hill_12x12x8_Color1.gltf",
]
const HILLS_PER_CHUNK := 3  # Max hills per chunk

const ASPHALT_COLOR := Color(0.35, 0.35, 0.38)  # Dark grey asphalt

var _loaded_chunks: Dictionary = {}  # "cx_cz" -> {data: ChunkData, node: Node3D, lod: int}
var _update_timer: float = 0.0
var _terrain_material: ShaderMaterial
var _water_scene: PackedScene
var _grass_meshes: Array[Mesh] = []
var _bush_meshes: Array[Mesh] = []
var _hill_scenes: Array[PackedScene] = []
var _city_scene_cache: Dictionary = {}  # scene_name -> PackedScene
var _loot_tables: Dictionary = {}  # "common"/"uncommon"/"rare" -> LootTable
var _ground_item_scene: PackedScene


func _ready() -> void:
	# Pre-load shader material and water scene
	if ResourceLoader.exists("res://shaders/terrain.gdshader"):
		var shader := load("res://shaders/terrain.gdshader") as Shader
		if shader:
			_terrain_material = ShaderMaterial.new()
			_terrain_material.shader = shader
	if ResourceLoader.exists("res://scenes/world/water_plane.tscn"):
		_water_scene = load("res://scenes/world/water_plane.tscn")
	_load_vegetation_meshes()
	_load_hill_scenes()
	_load_loot_tables()


func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL

	# Find player positions to load chunks around
	var players := get_tree().get_nodes_in_group("players") if is_inside_tree() else []
	if players.is_empty():
		return

	if multiplayer.is_server():
		# Server: load chunks around ALL players for collision/raycasts
		for player in players:
			if player is CharacterBody3D:
				update_chunks(player.global_position)
	else:
		# Client or singleplayer: load chunks around local authority player only
		for player in players:
			if player is CharacterBody3D:
				if not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority():
					update_chunks(player.global_position)
					break


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

	var is_city: bool = wg.world_type == WorldGenerator.WorldType.CITY

	# Water plane — offset to center over terrain (PlaneMesh is origin-centered)
	if not is_city and _water_scene and data.water_level > 0.0:
		var water := _water_scene.instantiate()
		water.position = Vector3(CHUNK_SIZE / 2.0, data.water_level, CHUNK_SIZE / 2.0)
		chunk_node.add_child(water)

	# Resource nodes and vegetation (only LOD 0)
	if lod == 0:
		if is_city:
			_spawn_city_elements(cx, cz, chunk_node, wg)
		else:
			_spawn_resources(data, chunk_node)
			_spawn_grass(data, chunk_node)
			_spawn_bushes(data, chunk_node)
			_spawn_hills(data, chunk_node)
		_spawn_loot_items(cx, cz, chunk_node, data, wg, is_city)

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


func _load_vegetation_meshes() -> void:
	## Extract meshes from KayKit GLTF files for MultiMesh usage.
	for path in GRASS_SCENES:
		var mesh := _extract_mesh_from_scene(path)
		if mesh:
			_grass_meshes.append(mesh)
	for path in BUSH_SCENES:
		var mesh := _extract_mesh_from_scene(path)
		if mesh:
			_bush_meshes.append(mesh)


func _extract_mesh_from_scene(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if not scene:
		return null
	var inst := scene.instantiate()
	var mesh_inst := _find_mesh_instance(inst)
	var mesh: Mesh = mesh_inst.mesh if mesh_inst else null
	inst.free()
	return mesh


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
	## Uses multiple mesh types for visual variety.
	if _grass_meshes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = data.chunk_x * 1000 + data.chunk_z + 99999

	# Collect transforms per mesh type
	var mesh_transforms: Array[Array] = []
	for i in _grass_meshes.size():
		mesh_transforms.append([])

	var cells := int(CHUNK_SIZE / GRASS_STEP)

	for gz in cells:
		for gx in cells:
			var local_x := gx * GRASS_STEP + rng.randf_range(0.0, GRASS_STEP)
			var local_z := gz * GRASS_STEP + rng.randf_range(0.0, GRASS_STEP)
			local_x = clampf(local_x, 0.0, CHUNK_SIZE - 0.1)
			local_z = clampf(local_z, 0.0, CHUNK_SIZE - 0.1)

			var height := TerrainGenerator.get_height_from_map(
				data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
			)

			if height < WaterSystem.BASE_WATER_LEVEL:
				continue

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

			var mesh_idx := rng.randi() % _grass_meshes.size()
			mesh_transforms[mesh_idx].append(t)

	# Create one MultiMeshInstance3D per mesh type
	for i in _grass_meshes.size():
		var tforms: Array = mesh_transforms[i]
		if tforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _grass_meshes[i]
		mm.instance_count = tforms.size()
		for j in tforms.size():
			mm.set_instance_transform(j, tforms[j])
		var multi := MultiMeshInstance3D.new()
		multi.name = "Grass_%d" % i
		multi.multimesh = mm
		parent.add_child(multi)


func _spawn_bushes(data: ChunkData, parent: Node3D) -> void:
	## Scatter decorative bushes across the chunk using MultiMeshInstance3D.
	if _bush_meshes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = data.chunk_x * 2000 + data.chunk_z + 77777

	var mesh_transforms: Array[Array] = []
	for i in _bush_meshes.size():
		mesh_transforms.append([])

	var cells := int(CHUNK_SIZE / BUSH_STEP)

	for gz in cells:
		for gx in cells:
			var local_x := gx * BUSH_STEP + rng.randf_range(0.0, BUSH_STEP)
			var local_z := gz * BUSH_STEP + rng.randf_range(0.0, BUSH_STEP)
			local_x = clampf(local_x, 0.0, CHUNK_SIZE - 0.1)
			local_z = clampf(local_z, 0.0, CHUNK_SIZE - 0.1)

			var height := TerrainGenerator.get_height_from_map(
				data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
			)

			if height < WaterSystem.BASE_WATER_LEVEL:
				continue

			var bx := mini(int(local_x / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
			var bz := mini(int(local_z / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
			var biome := data.get_biome_at_local(bx, bz)
			if rng.randf() > _get_bush_density(biome):
				continue

			var t := Transform3D.IDENTITY
			var scale_f := rng.randf_range(0.7, 1.3)
			t = t.scaled(Vector3(scale_f, scale_f, scale_f))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(local_x, height, local_z)

			var mesh_idx := rng.randi() % _bush_meshes.size()
			mesh_transforms[mesh_idx].append(t)

	for i in _bush_meshes.size():
		var tforms: Array = mesh_transforms[i]
		if tforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _bush_meshes[i]
		mm.instance_count = tforms.size()
		for j in tforms.size():
			mm.set_instance_transform(j, tforms[j])
		var multi := MultiMeshInstance3D.new()
		multi.name = "Bush_%d" % i
		multi.multimesh = mm
		parent.add_child(multi)


func _get_grass_density(biome: int) -> float:
	match biome:
		BiomeData.BiomeType.FOREST:
			return 0.85
		BiomeData.BiomeType.GRASSLAND:
			return 0.7
		BiomeData.BiomeType.DESERT:
			return 0.08
		BiomeData.BiomeType.ARCTIC:
			return 0.12
		_:
			return 0.4


func _get_bush_density(biome: int) -> float:
	match biome:
		BiomeData.BiomeType.FOREST:
			return 0.7
		BiomeData.BiomeType.GRASSLAND:
			return 0.4
		BiomeData.BiomeType.DESERT:
			return 0.05
		BiomeData.BiomeType.ARCTIC:
			return 0.08
		_:
			return 0.3


func _generate_biome_colors(data: ChunkData) -> PackedColorArray:
	## Create per-vertex biome colors for the terrain mesh.
	var colors := PackedColorArray()
	var side := TerrainGenerator.VERTICES_PER_SIDE
	colors.resize(side * side)

	# City mode: all asphalt grey
	var wg = get_node_or_null("/root/WorldGenerator")
	if wg and wg.world_type == WorldGenerator.WorldType.CITY:
		colors.fill(ASPHALT_COLOR)
		return colors

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


func _load_hill_scenes() -> void:
	for path in HILL_SCENES:
		if ResourceLoader.exists(path):
			var scene := load(path) as PackedScene
			if scene:
				_hill_scenes.append(scene)


func _spawn_hills(data: ChunkData, parent: Node3D) -> void:
	## Place 3D hill/mountain models on the chunk for terrain variety.
	if _hill_scenes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = data.chunk_x * 3000 + data.chunk_z + 55555

	for i in HILLS_PER_CHUNK:
		# Random position within the chunk
		var local_x := rng.randf_range(30.0, CHUNK_SIZE - 30.0)
		var local_z := rng.randf_range(30.0, CHUNK_SIZE - 30.0)

		var height := TerrainGenerator.get_height_from_map(
			data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
		)

		# Skip underwater
		if height < WaterSystem.BASE_WATER_LEVEL + 1.0:
			continue

		# Biome filter: more hills in rocky/mountain areas, fewer in flat
		var bx := mini(int(local_x / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
		var bz := mini(int(local_z / 16.0), ChunkData.BIOME_GRID_SIDE - 1)
		var biome := data.get_biome_at_local(bx, bz)
		var hill_chance := _get_hill_chance(biome)
		if rng.randf() > hill_chance:
			continue

		# Pick a random hill model
		var scene := _hill_scenes[rng.randi() % _hill_scenes.size()]
		var hill := scene.instantiate()
		hill.position = Vector3(local_x, height - 0.5, local_z)
		hill.rotation.y = rng.randf_range(0.0, TAU)

		# Scale variation
		var scale_f := rng.randf_range(0.8, 1.5)
		hill.scale = Vector3(scale_f, scale_f, scale_f)

		parent.add_child(hill)


func _get_hill_chance(biome: int) -> float:
	match biome:
		BiomeData.BiomeType.FOREST:
			return 0.5
		BiomeData.BiomeType.GRASSLAND:
			return 0.35
		BiomeData.BiomeType.DESERT:
			return 0.6
		BiomeData.BiomeType.ARCTIC:
			return 0.55
		_:
			return 0.4


func _spawn_city_elements(cx: int, cz: int, parent: Node3D, wg: Node) -> void:
	## Instantiate city buildings, roads, cars, and props for this chunk.
	var elements := CityGenerator.get_elements_in_chunk(wg._city_layout, cx, cz)
	var chunk_origin := parent.position

	# Road surface height: road model is 0.1 units thick * CITY_SCALE
	var road_surface := 0.1 * CityGenerator.CITY_SCALE  # 0.5m

	# Roads (with collision so player walks on road surface)
	for elem in elements["roads"]:
		_place_city_element(elem, chunk_origin, parent, true)

	# Buildings (with collision)
	for elem in elements["buildings"]:
		_place_city_element(elem, chunk_origin, parent, true)

	# Cars (with collision, raised to road surface)
	for elem in elements["cars"]:
		_place_city_element(elem, chunk_origin, parent, true, road_surface)

	# Props (no collision, raised to road surface)
	for elem in elements["props"]:
		_place_city_element(elem, chunk_origin, parent, false, road_surface)


func _place_city_element(elem: Dictionary, chunk_origin: Vector3, parent: Node3D, add_collision: bool, y_offset: float = 0.0) -> void:
	var scene := _load_city_scene(elem["scene"])
	if not scene:
		return
	var node := scene.instantiate()
	var world_pos: Vector3 = elem["position"]
	node.position = world_pos - chunk_origin
	node.position.y = y_offset
	node.rotation.y = elem["rotation_y"]
	var s := CityGenerator.CITY_SCALE
	node.scale = Vector3(s, s, s)
	parent.add_child(node)

	if add_collision:
		_add_trimesh_collision(node)


func _load_city_scene(scene_name: String) -> PackedScene:
	if _city_scene_cache.has(scene_name):
		return _city_scene_cache[scene_name]
	var path := CityGenerator.get_scene_path(scene_name)
	if not ResourceLoader.exists(path):
		_city_scene_cache[scene_name] = null
		return null
	var scene := load(path) as PackedScene
	_city_scene_cache[scene_name] = scene
	return scene


func _add_trimesh_collision(node: Node) -> void:
	## Add trimesh collision to all MeshInstance3D children.
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var body := StaticBody3D.new()
			body.name = "Collider"
			var shape: ConcavePolygonShape3D = child.mesh.create_trimesh_shape()
			if shape:
				var col := CollisionShape3D.new()
				col.shape = shape
				body.add_child(col)
				# Match the mesh transform
				body.transform = child.transform
				node.add_child(body)
		elif child.get_child_count() > 0:
			_add_trimesh_collision(child)


func _load_loot_tables() -> void:
	var paths := {
		"common": "res://resources/loot_tables/br_common.tres",
		"uncommon": "res://resources/loot_tables/br_uncommon.tres",
		"rare": "res://resources/loot_tables/br_rare.tres",
	}
	for tier in paths:
		var path: String = paths[tier]
		if ResourceLoader.exists(path):
			var table := load(path) as LootTable
			if table:
				_loot_tables[tier] = table
	if ResourceLoader.exists("res://scenes/items/ground_item.tscn"):
		_ground_item_scene = load("res://scenes/items/ground_item.tscn")


func _spawn_loot_items(cx: int, cz: int, chunk_node: Node3D, data: ChunkData, wg: Node, is_city: bool) -> void:
	## Spawn ground loot items in this chunk using LootSpawner positions.
	if _loot_tables.is_empty() or not _ground_item_scene:
		return

	var seed_val: int = wg.world_seed if wg else 0
	var positions := LootSpawner.generate_loot_positions(cx, cz, seed_val, is_city)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + cx * 48271 + cz * 16807

	var chunk_origin := chunk_node.position

	for spawn in positions:
		var tier: String = spawn["table_tier"]
		var table: LootTable = _loot_tables.get(tier) as LootTable
		if not table:
			continue

		var loot := LootTable.roll(table, rng)
		if loot.is_empty():
			continue

		var item_data: ItemData = loot[0]["item"]
		var count: int = loot[0]["count"]
		if not item_data:
			continue

		var world_pos: Vector3 = spawn["position"]

		# Get ground height
		var ground_y: float
		if is_city:
			ground_y = 0.5  # Road surface
		else:
			var local_x := world_pos.x - chunk_origin.x
			var local_z := world_pos.z - chunk_origin.z
			local_x = clampf(local_x, 0.0, CHUNK_SIZE - 0.1)
			local_z = clampf(local_z, 0.0, CHUNK_SIZE - 0.1)
			ground_y = TerrainGenerator.get_height_from_map(
				data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
			)

		var gi: GroundItem = _ground_item_scene.instantiate()
		gi.item_data = item_data
		gi.item_count = count
		gi.position = Vector3(world_pos.x - chunk_origin.x, ground_y + 0.3, world_pos.z - chunk_origin.z)
		gi.freeze = true
		chunk_node.add_child(gi)
		gi._settled = true
