class_name ServerValidation
extends RefCounted
## Static server-side validation for all player RPCs.
## Rejects invalid or suspicious requests.

const MAX_SPEED := 10.0  # Slightly above sprint (6.5) + tolerance
const MAX_PLACEMENT_RANGE := 6.0  # Slightly above placement distance (5.0)
const MAX_INTERACT_RANGE := 5.0  # Slightly above interaction distance (4.0)


static func validate_movement(old_pos: Vector3, new_pos: Vector3, delta: float) -> bool:
	## Reject movement faster than max speed allows.
	if delta <= 0.0:
		return false
	var distance := old_pos.distance_to(new_pos)
	var speed := distance / delta
	return speed <= MAX_SPEED


# Per-peer timing for accurate speed validation
static var _last_receive_time: Dictionary = {}  # peer_id -> int (msec)

static func validate_movement_v2(peer_id: int, old_pos: Vector3, new_pos: Vector3) -> bool:
	## Validate movement speed using real elapsed time between packets.
	## More accurate than fixed delta — handles jitter and packet loss.
	var now := Time.get_ticks_msec()
	var last: int = _last_receive_time.get(peer_id, now - 50)
	var elapsed_ms := now - last
	_last_receive_time[peer_id] = now
	var delta := clampf(float(elapsed_ms) / 1000.0, 0.01, 0.5)
	var distance := old_pos.distance_to(new_pos)
	var speed := distance / delta
	return speed <= MAX_SPEED * 1.5  # 50% tolerance for jitter


static func clear_timing_data() -> void:
	_last_receive_time.clear()


static func validate_placement(player_pos: Vector3, placement_pos: Vector3) -> bool:
	## Reject building placement too far from the player.
	var distance := player_pos.distance_to(placement_pos)
	return distance <= MAX_PLACEMENT_RANGE


static func validate_interaction(player_pos: Vector3, target_pos: Vector3) -> bool:
	## Reject interactions too far from the player.
	var distance := player_pos.distance_to(target_pos)
	return distance <= MAX_INTERACT_RANGE


static func validate_damage(damage: float, weapon_max_damage: float) -> bool:
	## Reject damage exceeding weapon's maximum.
	return damage >= 0.0 and damage <= weapon_max_damage * 2.5  # Allow headshot + soft side
