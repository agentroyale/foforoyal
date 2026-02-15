extends GutTest
## Phase 9: World generation unit tests.
## Tests noise determinism, biome classification, chunk coordinates,
## resource density, LOD thresholds, monument spacing, and water detection.

const WorldGeneratorScript = preload("res://scripts/world/world_generator.gd")
const ChunkManagerScript = preload("res://scripts/world/chunk_manager.gd")


# ─── Test 1: Seed Determinism ───

func test_seed_determinism() -> void:
	var noise_a := FastNoiseLite.new()
	noise_a.seed = 12345
	noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_a.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_a.fractal_octaves = 5
	noise_a.frequency = 0.001

	var noise_b := FastNoiseLite.new()
	noise_b.seed = 12345
	noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_b.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_b.fractal_octaves = 5
	noise_b.frequency = 0.001

	var map_a := TerrainGenerator.generate_heightmap(noise_a, 0, 0, 256)
	var map_b := TerrainGenerator.generate_heightmap(noise_b, 0, 0, 256)

	assert_eq(map_a.size(), map_b.size(), "Heightmaps should have same size")
	assert_eq(map_a.size(), 289, "Heightmap should be 17x17 = 289")
	for i in map_a.size():
		assert_almost_eq(map_a[i], map_b[i], 0.001,
			"Height at index %d should match for same seed" % i)

	# Different seed should produce different result
	var noise_c := FastNoiseLite.new()
	noise_c.seed = 99999
	noise_c.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_c.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_c.fractal_octaves = 5
	noise_c.frequency = 0.001

	var map_c := TerrainGenerator.generate_heightmap(noise_c, 0, 0, 256)
	var different := false
	for i in map_a.size():
		if absf(map_a[i] - map_c[i]) > 0.01:
			different = true
			break
	assert_true(different, "Different seed should produce different heightmap")


# ─── Test 2: Biome Classification ───

func test_biome_classification() -> void:
	# Arctic: cold
	assert_eq(
		BiomeData.get_biome_from_climate(0.1, 0.5),
		BiomeData.BiomeType.ARCTIC,
		"Low temperature should be Arctic"
	)
	# Desert: hot + dry
	assert_eq(
		BiomeData.get_biome_from_climate(0.8, 0.2),
		BiomeData.BiomeType.DESERT,
		"High temp + low moisture should be Desert"
	)
	# Forest: wet
	assert_eq(
		BiomeData.get_biome_from_climate(0.4, 0.7),
		BiomeData.BiomeType.FOREST,
		"Moderate temp + high moisture should be Forest"
	)
	# Grassland: moderate everything
	assert_eq(
		BiomeData.get_biome_from_climate(0.45, 0.4),
		BiomeData.BiomeType.GRASSLAND,
		"Moderate temp + moderate moisture should be Grassland"
	)
	# Boundary: exactly at arctic threshold
	assert_eq(
		BiomeData.get_biome_from_climate(0.24, 0.5),
		BiomeData.BiomeType.ARCTIC,
		"Just below 0.25 temp should be Arctic"
	)


# ─── Test 3: Chunk Coordinate Mapping ───

func test_chunk_coordinate_mapping() -> void:
	var cm := ChunkManagerScript.new()
	add_child_autofree(cm)

	# Origin -> chunk (0, 0)
	assert_eq(cm._get_chunk_coord(Vector3(0, 0, 0)), Vector2i(0, 0),
		"Origin should be chunk (0,0)")

	# Middle of chunk 0 -> still (0, 0)
	assert_eq(cm._get_chunk_coord(Vector3(128, 5, 128)), Vector2i(0, 0),
		"Center of first chunk should be (0,0)")

	# Exactly at chunk boundary -> next chunk
	assert_eq(cm._get_chunk_coord(Vector3(256, 0, 0)), Vector2i(1, 0),
		"Position 256 should be chunk (1,0)")

	# Far corner
	assert_eq(cm._get_chunk_coord(Vector3(900, 0, 900)), Vector2i(3, 3),
		"Far corner should be chunk (3,3)")

	# Clamp to valid range
	assert_eq(cm._get_chunk_coord(Vector3(5000, 0, 5000)), Vector2i(3, 3),
		"Beyond map should clamp to (3,3)")

	# Negative coordinates clamp to 0
	assert_eq(cm._get_chunk_coord(Vector3(-100, 0, -100)), Vector2i(0, 0),
		"Negative position should clamp to (0,0)")


# ─── Test 4: Resource Spawn Density Per Biome ───

func test_resource_spawn_density_per_biome() -> void:
	# Forest chunk
	var chunk_forest := ChunkData.new()
	chunk_forest.chunk_x = 0
	chunk_forest.chunk_z = 0
	chunk_forest.biome_grid = PackedByteArray()
	chunk_forest.biome_grid.resize(256)  # 16x16
	chunk_forest.biome_grid.fill(BiomeData.BiomeType.FOREST)
	chunk_forest.heightmap = PackedFloat32Array()
	chunk_forest.heightmap.resize(289)  # 17x17
	chunk_forest.heightmap.fill(20.0)  # above water

	var forest_spawns := ResourceSpawner.generate_spawn_points(chunk_forest, {}, 42)

	# Desert chunk
	var chunk_desert := ChunkData.new()
	chunk_desert.chunk_x = 0
	chunk_desert.chunk_z = 0
	chunk_desert.biome_grid = PackedByteArray()
	chunk_desert.biome_grid.resize(256)
	chunk_desert.biome_grid.fill(BiomeData.BiomeType.DESERT)
	chunk_desert.heightmap = PackedFloat32Array()
	chunk_desert.heightmap.resize(289)
	chunk_desert.heightmap.fill(20.0)

	var desert_spawns := ResourceSpawner.generate_spawn_points(chunk_desert, {}, 42)

	# Count trees
	var forest_trees := forest_spawns.filter(
		func(s): return s["type"] == 0  # TREE
	).size()
	var desert_trees := desert_spawns.filter(
		func(s): return s["type"] == 0
	).size()

	assert_gt(forest_trees, desert_trees,
		"Forest should have more trees than desert")

	# Count rocks
	var forest_rocks := forest_spawns.filter(
		func(s): return s["type"] == 1  # ROCK
	).size()
	var desert_rocks := desert_spawns.filter(
		func(s): return s["type"] == 1
	).size()

	assert_gt(desert_rocks, forest_rocks,
		"Desert should have more rocks than forest")


# ─── Test 5: LOD Distance Thresholds ───

func test_lod_distance_thresholds() -> void:
	var cm := ChunkManagerScript.new()
	add_child_autofree(cm)

	assert_eq(cm._get_lod_for_distance(100.0), 0,
		"100m should be LOD 0")
	assert_eq(cm._get_lod_for_distance(256.0), 0,
		"256m (boundary) should be LOD 0")
	assert_eq(cm._get_lod_for_distance(300.0), 1,
		"300m should be LOD 1")
	assert_eq(cm._get_lod_for_distance(512.0), 1,
		"512m (boundary) should be LOD 1")
	assert_eq(cm._get_lod_for_distance(800.0), 2,
		"800m should be LOD 2")
	assert_eq(cm._get_lod_for_distance(1024.0), 2,
		"1024m (boundary) should be LOD 2")
	assert_eq(cm._get_lod_for_distance(1500.0), -1,
		"1500m should be -1 (unload)")


# ─── Test 6: Monument Minimum Distance ───

func test_monument_minimum_distance() -> void:
	var positions := MonumentSpawner.generate_monument_positions(
		42, 4096, func(x, z): return 10.0
	)

	assert_eq(positions.size(), MonumentSpawner.MONUMENT_COUNT,
		"Should generate exactly %d monuments" % MonumentSpawner.MONUMENT_COUNT)

	for i in positions.size():
		for j in range(i + 1, positions.size()):
			var pos_a: Vector3 = positions[i]["position"]
			var pos_b: Vector3 = positions[j]["position"]
			var dist := Vector2(pos_a.x, pos_a.z).distance_to(Vector2(pos_b.x, pos_b.z))
			assert_gte(dist, MonumentSpawner.MIN_DISTANCE_BETWEEN_MONUMENTS,
				"Monuments %d and %d should be >= %dm apart (actual: %.1fm)" % [
					i, j, MonumentSpawner.MIN_DISTANCE_BETWEEN_MONUMENTS, dist])


# ─── Test 7: Water Level Detection ───

func test_water_level_detection() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 2
	noise.frequency = 0.002

	# Terrain below water level is underwater
	assert_true(
		WaterSystem.is_underwater(100.0, 100.0, 2.0, noise),
		"Terrain at height 2.0 should be underwater (base level = 5.0)"
	)

	# Terrain above water level is not underwater
	assert_false(
		WaterSystem.is_underwater(100.0, 100.0, 20.0, noise),
		"Terrain at height 20.0 should NOT be underwater"
	)

	# Water level should be positive
	var water_height := WaterSystem.get_water_level(100.0, 100.0, noise)
	assert_gt(water_height, 0.0, "Water level should be positive")

	# Lake generation
	var lakes := WaterSystem.get_lake_positions(42, 4096)
	assert_eq(lakes.size(), WaterSystem.LAKE_COUNT,
		"Should generate %d lakes" % WaterSystem.LAKE_COUNT)
	for lake in lakes:
		assert_true(lake.has("center"), "Lake should have center")
		assert_true(lake.has("radius"), "Lake should have radius")
		assert_gte(lake["radius"], WaterSystem.LAKE_MIN_RADIUS,
			"Lake radius should be >= min")
