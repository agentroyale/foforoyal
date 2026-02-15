class_name DamageCalculator
extends RefCounted
## Pure static damage formula: base * hitzone * (1-armor) * distance_factor.


static func calculate_damage(
	base_damage: float,
	hitzone_mult: float = 1.0,
	armor_protection: float = 0.0,
	distance: float = 0.0,
	max_range: float = 0.0,
	falloff_start: float = 0.0
) -> float:
	var armor_factor := clampf(1.0 - armor_protection, 0.0, 1.0)
	var distance_factor := _get_distance_factor(distance, max_range, falloff_start)
	return base_damage * hitzone_mult * armor_factor * distance_factor


static func _get_distance_factor(
	distance: float,
	max_range: float,
	falloff_start: float
) -> float:
	if max_range <= 0.0:
		return 1.0
	if distance <= falloff_start:
		return 1.0
	if distance >= max_range:
		return 0.0
	var falloff_range := max_range - falloff_start
	if falloff_range <= 0.0:
		return 1.0
	return 1.0 - ((distance - falloff_start) / falloff_range)
