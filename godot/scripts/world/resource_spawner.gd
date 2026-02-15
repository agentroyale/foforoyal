class_name ResourceSpawner
extends RefCounted
## Deterministically spawns resource nodes based on biome and seed.
## Same seed + chunk always produces the same placement.
## All static methods.

const SPAWN_CELL_SIZE := 16.0  # One potential spawn per 16x16m cell
const MIN_DISTANCE_FROM_WATER := 4.0

## Resource node scene paths
const RESOURCE_SCENES: Array[String] = [
	"res://scenes/world/tree_node.tscn",
	"res://scenes/world/rock_node.tscn",
	"res://scenes/world/metal_ore_node.tscn",
	"res://scenes/world/sulfur_ore_node.tscn",
]


static func generate_spawn_points(chunk_data: ChunkData, biome_map: Dictionary, world_seed: int) -> Array[Dictionary]:
	## Returns [{type: int (NodeType), position: Vector3, rotation_y: float}]
	## biome_map: {BiomeType -> BiomeData} or unused if using static densities.
	var results: Array[Dictionary] = []
	var chunk_seed := world_seed + chunk_data.chunk_x * 1000 + chunk_data.chunk_z
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var cells_per_side := int(ChunkData.CHUNK_SIZE / SPAWN_CELL_SIZE)  # 8
	var origin := chunk_data.get_world_origin()

	for cz in cells_per_side:
		for cx in cells_per_side:
			# Determine biome at this cell center
			var biome_x := int(cx * SPAWN_CELL_SIZE / 16.0)  # map to 16x16 biome grid
			var biome_z := int(cz * SPAWN_CELL_SIZE / 16.0)
			var biome_type: int = chunk_data.get_biome_at_local(biome_x, biome_z)

			# Try each resource type
			for node_type in 4:  # TREE, ROCK, METAL_ORE, SULFUR_ORE
				var density := BiomeData.get_density_for_type(biome_type, node_type)
				if rng.randf() < density:
					# Random position within cell
					var local_x := cx * SPAWN_CELL_SIZE + rng.randf_range(4.0, SPAWN_CELL_SIZE - 4.0)
					var local_z := cz * SPAWN_CELL_SIZE + rng.randf_range(4.0, SPAWN_CELL_SIZE - 4.0)

					# Get height at position
					var height := TerrainGenerator.get_height_from_map(
						chunk_data.heightmap, local_x, local_z, ChunkData.CHUNK_SIZE
					)

					# Skip if underwater
					if height < WaterSystem.BASE_WATER_LEVEL + MIN_DISTANCE_FROM_WATER:
						continue

					var world_pos := origin + Vector3(local_x, height, local_z)
					var rot_y := rng.randf_range(0.0, TAU)

					results.append({
						"type": node_type,
						"position": world_pos,
						"rotation_y": rot_y,
					})
	return results


static func get_scene_path(node_type: int) -> String:
	## Returns the scene path for a ResourceNode.NodeType.
	if node_type >= 0 and node_type < RESOURCE_SCENES.size():
		return RESOURCE_SCENES[node_type]
	return ""
