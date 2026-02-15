class_name ExplosionDamage
extends RefCounted
## Static explosion damage calculator. Applies splash to building pieces.


static func apply_explosion(
	tree: SceneTree,
	origin: Vector3,
	base_damage: float,
	radius: float,
	hit_direction: Vector3 = Vector3.ZERO
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var pieces := tree.get_nodes_in_group("building_pieces")
	for node in pieces:
		var piece := node as BuildingPiece
		if not piece or not is_instance_valid(piece):
			continue
		var dist := origin.distance_to(piece.global_position)
		if dist > radius:
			continue
		var falloff := calculate_falloff(dist, radius)
		var effective_damage := base_damage * falloff
		piece.take_damage(effective_damage, hit_direction)
		results.append({
			"piece": piece,
			"distance": dist,
			"falloff": falloff,
			"damage": effective_damage,
		})
	return results


static func calculate_falloff(distance: float, radius: float) -> float:
	## Linear falloff: 1.0 at center, 0.0 at edge.
	if radius <= 0.0:
		return 1.0
	return clampf(1.0 - (distance / radius), 0.0, 1.0)


static func c4_count_for_tier(tier: int, c4_damage: float = 275.0) -> int:
	var hp := float(BuildingTier.get_max_hp(tier))
	return ceili(hp / c4_damage)
