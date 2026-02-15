class_name BuildingDamage
extends RefCounted
## Raid cost reference table. Calculates how many explosives are needed
## to destroy each building tier (hard side, no splash).

## C4: 275 dmg, no dud
## Satchel: 475 dmg, 20% dud
## Rocket: 137.5 dmg, no dud (splash)

const C4_DAMAGE := 275.0
const SATCHEL_DAMAGE := 475.0
const ROCKET_DAMAGE := 137.5


static func explosives_to_destroy(tier: int, explosive_damage: float, side_multiplier: float = 1.0) -> int:
	var hp := float(BuildingTier.get_max_hp(tier))
	var effective := explosive_damage * side_multiplier
	if effective <= 0.0:
		return -1
	return ceili(hp / effective)


static func c4_cost(tier: int, soft_side: bool = false) -> int:
	var mult := BuildingPiece.SOFT_SIDE_MULTIPLIER if soft_side else BuildingPiece.HARD_SIDE_MULTIPLIER
	return explosives_to_destroy(tier, C4_DAMAGE, mult)


static func satchel_cost(tier: int, soft_side: bool = false) -> int:
	var mult := BuildingPiece.SOFT_SIDE_MULTIPLIER if soft_side else BuildingPiece.HARD_SIDE_MULTIPLIER
	return explosives_to_destroy(tier, SATCHEL_DAMAGE, mult)


static func rocket_cost(tier: int, soft_side: bool = false) -> int:
	var mult := BuildingPiece.SOFT_SIDE_MULTIPLIER if soft_side else BuildingPiece.HARD_SIDE_MULTIPLIER
	return explosives_to_destroy(tier, ROCKET_DAMAGE, mult)
