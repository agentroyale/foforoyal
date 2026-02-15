class_name MonumentSpawner
extends RefCounted
## Places pre-built structures/landmarks at deterministic positions.
## All static methods.

enum MonumentType {
	LIGHTHOUSE = 0,
	WAREHOUSE = 1,
	GAS_STATION = 2,
	POWER_PLANT = 3,
}

const MONUMENT_COUNT := 8
const MIN_DISTANCE_BETWEEN_MONUMENTS := 512.0
const MAP_MARGIN := 256.0  # Keep away from map edges
const MAX_ATTEMPTS := 200

const MONUMENT_NAMES := {
	MonumentType.LIGHTHOUSE: "Lighthouse",
	MonumentType.WAREHOUSE: "Warehouse",
	MonumentType.GAS_STATION: "Gas Station",
	MonumentType.POWER_PLANT: "Power Plant",
}


static func generate_monument_positions(world_seed: int, map_size: int, heightmap_func: Callable) -> Array[Dictionary]:
	## Returns [{type: MonumentType, position: Vector3, rotation_y: float}]
	## heightmap_func: func(x: float, z: float) -> float
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 5555  # offset from other systems
	var positions: Array[Dictionary] = []
	var attempts := 0

	while positions.size() < MONUMENT_COUNT and attempts < MAX_ATTEMPTS:
		attempts += 1
		var x := rng.randf_range(MAP_MARGIN, map_size - MAP_MARGIN)
		var z := rng.randf_range(MAP_MARGIN, map_size - MAP_MARGIN)

		# Check minimum distance from all existing monuments
		var valid := true
		for existing in positions:
			var existing_pos: Vector3 = existing["position"]
			var dist := Vector2(x, z).distance_to(Vector2(existing_pos.x, existing_pos.z))
			if dist < MIN_DISTANCE_BETWEEN_MONUMENTS:
				valid = false
				break

		if not valid:
			continue

		var height: float = heightmap_func.call(x, z)

		# Skip underwater positions
		if height < WaterSystem.BASE_WATER_LEVEL + 2.0:
			continue

		var monument_type := rng.randi_range(0, MonumentType.size() - 1) as MonumentType
		var rotation_y := rng.randf_range(0.0, TAU)

		positions.append({
			"type": monument_type,
			"position": Vector3(x, height, z),
			"rotation_y": rotation_y,
		})

	return positions


static func get_monument_name(type: MonumentType) -> String:
	return MONUMENT_NAMES.get(type, "Unknown")
