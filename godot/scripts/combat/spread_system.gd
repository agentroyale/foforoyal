class_name SpreadSystem
extends RefCounted
## Pure static spread/bloom calculator. WarZ-style accuracy model.
## No scene tree dependency — all inputs passed as arguments.

enum MovementState { IDLE = 0, WALKING = 1, SPRINTING = 2, CROUCHING = 3, AIRBORNE = 4 }

const BLOOM_DECAY_SPEED := 8.0
const FIRST_SHOT_THRESHOLD := 0.4
const CROUCH_RECOIL_MULT := 0.7


static func get_movement_multiplier(state: MovementState) -> float:
	match state:
		MovementState.IDLE: return 1.0
		MovementState.WALKING: return 1.5
		MovementState.SPRINTING: return 2.5
		MovementState.CROUCHING: return 0.6
		MovementState.AIRBORNE: return 3.0
	return 1.0


static func calculate_current_spread(base_spread: float, bloom: float, movement_mult: float) -> float:
	var raw := (base_spread + bloom) * movement_mult
	return clampf(raw, 0.0, base_spread * 12.0)


static func calculate_bloom_after_shot(current_bloom: float, bloom_per_shot: float, max_bloom: float) -> float:
	return minf(current_bloom + bloom_per_shot, max_bloom)


static func decay_bloom(current_bloom: float, delta: float, decay_rate: float) -> float:
	return maxf(current_bloom - decay_rate * delta, 0.0)


static func is_first_shot_accurate(time_since_last_shot: float) -> bool:
	return time_since_last_shot >= FIRST_SHOT_THRESHOLD


static func get_first_shot_spread(min_spread: float) -> float:
	return min_spread


static func apply_spread_to_direction(base_dir: Vector3, spread_degrees: float) -> Vector3:
	if spread_degrees <= 0.001:
		return base_dir.normalized()
	var spread_rad := deg_to_rad(spread_degrees)
	var r := randf() * tan(spread_rad)
	var theta := randf() * TAU
	var up := Vector3.UP if absf(base_dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := base_dir.cross(up).normalized()
	var actual_up := right.cross(base_dir).normalized()
	var offset := (right * cos(theta) + actual_up * sin(theta)) * r
	return (base_dir + offset).normalized()


static func get_movement_state(speed: float, is_crouching: bool, is_on_floor: bool, walk_speed: float, sprint_speed: float) -> MovementState:
	if not is_on_floor:
		return MovementState.AIRBORNE
	if is_crouching:
		return MovementState.CROUCHING
	if speed >= sprint_speed - 0.1:
		return MovementState.SPRINTING
	if speed > 0.5:
		return MovementState.WALKING
	return MovementState.IDLE


static func get_crouch_recoil_multiplier() -> float:
	return CROUCH_RECOIL_MULT
