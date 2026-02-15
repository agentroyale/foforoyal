class_name HitzoneSystem
extends RefCounted
## Pure static logic mapping hitzones to damage multipliers.

enum Hitzone { HEAD = 0, CHEST = 1, LIMBS = 2 }

const HITZONE_MULTIPLIERS: Dictionary = {
	Hitzone.HEAD: 2.0,
	Hitzone.CHEST: 1.0,
	Hitzone.LIMBS: 0.5,
}


static func get_multiplier(hitzone: Hitzone) -> float:
	if hitzone in HITZONE_MULTIPLIERS:
		return HITZONE_MULTIPLIERS[hitzone]
	return 1.0


static func detect_hitzone(hit_position: Vector3, target_position: Vector3, target_height: float = 1.8) -> Hitzone:
	## Head: top 20%, Chest: middle 40%, Limbs: bottom 40%.
	var relative_y := hit_position.y - target_position.y
	var normalized_y := relative_y / target_height if target_height > 0.0 else 0.5

	if normalized_y >= 0.8:
		return Hitzone.HEAD
	elif normalized_y >= 0.4:
		return Hitzone.CHEST
	else:
		return Hitzone.LIMBS
