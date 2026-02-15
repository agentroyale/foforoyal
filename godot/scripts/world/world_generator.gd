extends Node
## Seed-based procedural world generation orchestrator.
## Autoload — coordinates terrain, biome, resource, and monument generation.

signal world_initialized(seed_value: int)

const MAP_SIZE := 1024
const CHUNK_SIZE := 256
const GRID_SIZE := 4  # MAP_SIZE / CHUNK_SIZE

var world_seed: int = 0
var is_initialized: bool = false

var _noise_height: FastNoiseLite
var _noise_temperature: FastNoiseLite
var _noise_moisture: FastNoiseLite
var _noise_water: FastNoiseLite

var _lakes: Array[Dictionary] = []
var _monument_positions: Array[Dictionary] = []


func _ready() -> void:
	# Default seed from hash of OS time if not set externally
	pass


func initialize(seed_value: int) -> void:
	## Setup all noise generators and pre-generate global features.
	world_seed = seed_value
	_setup_noise()
	is_initialized = true  # Set early — noise is ready, get_height_at works
	_lakes = WaterSystem.get_lake_positions(world_seed, MAP_SIZE)
	_monument_positions = MonumentSpawner.generate_monument_positions(
		world_seed, MAP_SIZE, get_height_at
	)
	world_initialized.emit(seed_value)


func generate_chunk_data(chunk_x: int, chunk_z: int) -> ChunkData:
	## Generates all data for a single chunk.
	assert(is_initialized, "WorldGenerator not initialized. Call initialize(seed) first.")
	var data := ChunkData.new()
	data.chunk_x = chunk_x
	data.chunk_z = chunk_z

	# Heightmap
	data.heightmap = TerrainGenerator.generate_heightmap(
		_noise_height, chunk_x, chunk_z, CHUNK_SIZE
	)

	# Biome grid
	data.biome_grid = _generate_biome_grid(chunk_x, chunk_z)

	# Resource spawn points
	data.resource_positions = ResourceSpawner.generate_spawn_points(
		data, {}, world_seed
	)

	# Monument positions that fall in this chunk
	var chunk_origin := Vector3(chunk_x * CHUNK_SIZE, 0, chunk_z * CHUNK_SIZE)
	var chunk_end := chunk_origin + Vector3(CHUNK_SIZE, 0, CHUNK_SIZE)
	for m in _monument_positions:
		var pos: Vector3 = m["position"]
		if pos.x >= chunk_origin.x and pos.x < chunk_end.x and pos.z >= chunk_origin.z and pos.z < chunk_end.z:
			data.monument_positions.append(m)

	data.water_level = WaterSystem.BASE_WATER_LEVEL
	data.is_generated = true
	return data


func get_height_at(world_x: float, world_z: float) -> float:
	## Returns terrain height at any world position.
	assert(is_initialized, "WorldGenerator not initialized.")
	var n := _noise_height.get_noise_2d(world_x, world_z)
	return (n + 1.0) * 0.5 * TerrainGenerator.HEIGHT_SCALE


func get_biome_at(world_x: float, world_z: float) -> int:
	## Returns BiomeData.BiomeType at a world position.
	var temp := (_noise_temperature.get_noise_2d(world_x, world_z) + 1.0) * 0.5
	var moist := (_noise_moisture.get_noise_2d(world_x, world_z) + 1.0) * 0.5
	return BiomeData.get_biome_from_climate(temp, moist)


func get_monument_positions() -> Array[Dictionary]:
	return _monument_positions


func get_lakes() -> Array[Dictionary]:
	return _lakes


func _setup_noise() -> void:
	# Height noise — terrain elevation
	_noise_height = FastNoiseLite.new()
	_noise_height.seed = world_seed
	_noise_height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_height.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_height.fractal_octaves = 5
	_noise_height.frequency = 0.004

	# Temperature noise — latitude-like variation
	_noise_temperature = FastNoiseLite.new()
	_noise_temperature.seed = world_seed + 1
	_noise_temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_temperature.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_temperature.fractal_octaves = 3
	_noise_temperature.frequency = 0.002

	# Moisture noise — rainfall variation
	_noise_moisture = FastNoiseLite.new()
	_noise_moisture.seed = world_seed + 2
	_noise_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_moisture.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_moisture.fractal_octaves = 4
	_noise_moisture.frequency = 0.0032

	# Water noise — river paths
	_noise_water = FastNoiseLite.new()
	_noise_water.seed = world_seed + 3
	_noise_water.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_water.fractal_octaves = 2
	_noise_water.frequency = 0.002


func _generate_biome_grid(chunk_x: int, chunk_z: int) -> PackedByteArray:
	## Generates 16x16 biome classification grid for a chunk.
	var grid := PackedByteArray()
	grid.resize(ChunkData.BIOME_GRID_SIDE * ChunkData.BIOME_GRID_SIDE)
	var origin_x := chunk_x * CHUNK_SIZE
	var origin_z := chunk_z * CHUNK_SIZE
	var cell_size := float(CHUNK_SIZE) / ChunkData.BIOME_GRID_SIDE  # 16m

	for z in ChunkData.BIOME_GRID_SIDE:
		for x in ChunkData.BIOME_GRID_SIDE:
			var world_x := origin_x + (x + 0.5) * cell_size
			var world_z := origin_z + (z + 0.5) * cell_size
			grid[z * ChunkData.BIOME_GRID_SIDE + x] = get_biome_at(world_x, world_z)
	return grid
