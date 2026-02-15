class_name ZoneSystem
extends RefCounted
## Pure-logic zone calculations for the shrinking safe zone.
## No Node dependency — designed for easy unit testing.

const PHASE_COUNT := 5

## Phase data: [start_radius, end_radius, shrink_time, hold_time, damage_per_sec]
const PHASES: Array[Array] = [
	[480.0, 300.0, 60.0, 120.0, 1.0],
	[300.0, 180.0, 45.0, 90.0, 2.0],
	[180.0, 80.0, 30.0, 60.0, 5.0],
	[80.0, 30.0, 20.0, 30.0, 10.0],
	[30.0, 0.0, 15.0, 0.0, 20.0],
]


static func get_phase_data(phase: int) -> Dictionary:
	if phase < 0 or phase >= PHASE_COUNT:
		return {}
	var p: Array = PHASES[phase]
	return {
		"start_radius": p[0],
		"end_radius": p[1],
		"shrink_time": p[2],
		"hold_time": p[3],
		"damage": p[4],
	}


static func is_outside_zone(pos: Vector3, center: Vector3, radius: float) -> bool:
	## Check XZ plane distance only (2D circle).
	var dx := pos.x - center.x
	var dz := pos.z - center.z
	return (dx * dx + dz * dz) > (radius * radius)


static func distance_to_zone_edge(pos: Vector3, center: Vector3, radius: float) -> float:
	var dx := pos.x - center.x
	var dz := pos.z - center.z
	var dist_from_center := sqrt(dx * dx + dz * dz)
	return dist_from_center - radius


static func get_current_radius(phase: int, elapsed: float, is_shrinking: bool) -> float:
	var data := get_phase_data(phase)
	if data.is_empty():
		return 0.0
	if not is_shrinking:
		return data["start_radius"]
	var t := clampf(elapsed / data["shrink_time"], 0.0, 1.0) if data["shrink_time"] > 0.0 else 1.0
	return lerpf(data["start_radius"], data["end_radius"], t)


static func get_zone_center(phase: int, map_size: float, seed_val: int) -> Vector3:
	## Deterministic center that migrates toward map center each phase.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var center := Vector3(map_size / 2.0, 0.0, map_size / 2.0)
	if phase <= 0:
		return center
	# Each phase, offset shrinks
	var offset := Vector3.ZERO
	for i in range(phase):
		var max_off := map_size * 0.15 / float(i + 1)
		offset.x += rng.randf_range(-max_off, max_off)
		offset.z += rng.randf_range(-max_off, max_off)
	# Clamp to keep zone fully inside map
	var phase_data := get_phase_data(phase)
	var radius: float = phase_data.get("start_radius", 100.0)
	var result := center + offset
	result.x = clampf(result.x, radius, map_size - radius)
	result.z = clampf(result.z, radius, map_size - radius)
	return result


static func get_damage_per_second(phase: int) -> float:
	var data := get_phase_data(phase)
	if data.is_empty():
		return 0.0
	return data["damage"]
