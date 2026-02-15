class_name FlightPath
extends RefCounted
## Pure-logic flight path generation for the BR drop phase.
## No Node dependency — designed for easy unit testing.

const FLIGHT_ALTITUDE := 100.0
const PATH_MARGIN := 50.0  # Don't start/end at map edge


static func generate_path(map_size: float, seed_val: int) -> Dictionary:
	## Returns { "start": Vector3, "end": Vector3, "direction": Vector3, "length": float }
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var angle := rng.randf_range(0.0, TAU)
	var half := map_size / 2.0
	var center := Vector3(half, FLIGHT_ALTITUDE, half)
	var radius := half - PATH_MARGIN
	var start := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	var end := center - Vector3(cos(angle), 0.0, sin(angle)) * radius
	var direction := (end - start).normalized()
	var length := start.distance_to(end)
	return {
		"start": start,
		"end": end,
		"direction": direction,
		"length": length,
	}


static func get_position_at_progress(start: Vector3, end: Vector3, t: float) -> Vector3:
	return start.lerp(end, clampf(t, 0.0, 1.0))
