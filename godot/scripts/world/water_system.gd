class_name WaterSystem
extends RefCounted
## Determines water placement: base water level, rivers, lakes.
## All static methods.

const BASE_WATER_LEVEL := 5.0  # Terrain below this is underwater
const RIVER_NOISE_THRESHOLD := 0.85  # Higher = narrower rivers
const LAKE_COUNT := 2
const LAKE_MIN_RADIUS := 24.0
const LAKE_MAX_RADIUS := 48.0


static func get_water_level(world_x: float, world_z: float, noise: FastNoiseLite) -> float:
	## Returns water surface height at position.
	## Returns -INF if no water at this location.
	# Check river noise (uses a separate frequency band)
	var river_n := absf(noise.get_noise_2d(world_x * 0.3, world_z * 0.3))
	if river_n > RIVER_NOISE_THRESHOLD:
		return BASE_WATER_LEVEL + 1.0  # Rivers sit slightly above base
	return BASE_WATER_LEVEL


static func is_underwater(world_x: float, world_z: float, terrain_height: float, noise: FastNoiseLite) -> bool:
	## Returns true if terrain at this position is below water level.
	var water_h := get_water_level(world_x, world_z, noise)
	return terrain_height < water_h


static func get_lake_positions(seed_value: int, map_size: int, count: int = LAKE_COUNT) -> Array[Dictionary]:
	## Returns [{center: Vector2, radius: float}] for lakes on the map.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7777  # offset from other systems
	var lakes: Array[Dictionary] = []
	var attempts := 0
	while lakes.size() < count and attempts < count * 20:
		attempts += 1
		var margin := LAKE_MAX_RADIUS * 2.0
		var cx := rng.randf_range(margin, map_size - margin)
		var cz := rng.randf_range(margin, map_size - margin)
		var radius := rng.randf_range(LAKE_MIN_RADIUS, LAKE_MAX_RADIUS)
		# Check distance from existing lakes
		var valid := true
		for existing in lakes:
			var dist := Vector2(cx, cz).distance_to(existing["center"])
			if dist < existing["radius"] + radius + 64.0:
				valid = false
				break
		if valid:
			lakes.append({"center": Vector2(cx, cz), "radius": radius})
	return lakes


static func is_in_lake(world_x: float, world_z: float, lakes: Array[Dictionary]) -> bool:
	## Check if position is inside any lake.
	var pos := Vector2(world_x, world_z)
	for lake in lakes:
		if pos.distance_to(lake["center"]) <= lake["radius"]:
			return true
	return false
