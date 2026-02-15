class_name ChunkData
extends RefCounted
## Holds all generated data for a single 256x256 chunk.

const CHUNK_SIZE := 256
const HEIGHTMAP_SIDE := 17  # 16 quads + 1 edge = 17 vertices per axis
const BIOME_GRID_SIDE := 16  # one biome ID per 16x16m cell

var chunk_x: int = 0  # Grid coordinate (0-15)
var chunk_z: int = 0
var heightmap: PackedFloat32Array  # 17x17 = 289 entries
var biome_grid: PackedByteArray  # 16x16 = 256 entries (BiomeType values)
var resource_positions: Array[Dictionary] = []  # [{type: int, position: Vector3, rotation_y: float}]
var monument_positions: Array[Dictionary] = []  # [{type: int, position: Vector3, rotation_y: float}]
var water_level: float = 0.0
var is_generated: bool = false
var lod_level: int = 0  # 0=full, 1=half, 2=quarter


func get_world_origin() -> Vector3:
	## Returns world position of chunk's corner (min x, 0, min z).
	return Vector3(chunk_x * CHUNK_SIZE, 0.0, chunk_z * CHUNK_SIZE)


func get_world_center() -> Vector3:
	## Returns world position of chunk's center.
	var half := CHUNK_SIZE * 0.5
	return Vector3(chunk_x * CHUNK_SIZE + half, 0.0, chunk_z * CHUNK_SIZE + half)


func get_biome_at_local(local_x: int, local_z: int) -> int:
	## Returns BiomeType at a local grid cell (0-15, 0-15).
	local_x = clampi(local_x, 0, BIOME_GRID_SIDE - 1)
	local_z = clampi(local_z, 0, BIOME_GRID_SIDE - 1)
	return biome_grid[local_z * BIOME_GRID_SIDE + local_x]


func get_height_at_local(local_x: int, local_z: int) -> float:
	## Returns height at a heightmap vertex (0-16, 0-16).
	local_x = clampi(local_x, 0, HEIGHTMAP_SIDE - 1)
	local_z = clampi(local_z, 0, HEIGHTMAP_SIDE - 1)
	return heightmap[local_z * HEIGHTMAP_SIDE + local_x]
