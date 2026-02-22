class_name ServerValidation
extends RefCounted
## Static server-side validation for all player RPCs.
## Rejects invalid or suspicious requests.
## Movement validation is no longer needed (server simulates physics directly).

const MAX_SPEED := 10.0  # Kept for reference / legacy tests
const MAX_PLACEMENT_RANGE := 6.0  # Slightly above placement distance (5.0)
const MAX_INTERACT_RANGE := 5.0  # Slightly above interaction distance (4.0)


static func validate_input_direction(direction: Vector2) -> Vector2:
	## Sanitize input direction: clamp to unit length.
	if direction.length_squared() > 1.01:
		return direction.normalized()
	return direction


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
