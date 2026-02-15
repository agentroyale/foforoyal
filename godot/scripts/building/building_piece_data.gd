class_name BuildingPieceData
extends Resource
## Data resource for a building piece type (foundation, wall, etc.).

enum PieceType {
	FOUNDATION,
	WALL,
	FLOOR,
	DOORWAY,
	DOOR,
}

@export var piece_name: String = ""
@export var piece_type: PieceType = PieceType.FOUNDATION
@export var piece_scene: PackedScene
@export var build_costs: Array[int] = [10, 50, 100, 200, 400]
@export var upgrade_costs: Array[int] = [40, 50, 100, 200, 0]


func get_max_hp(tier: BuildingTier.Tier) -> int:
	return BuildingTier.get_max_hp(tier)


func get_build_cost(tier: BuildingTier.Tier) -> int:
	return build_costs[tier]


func get_upgrade_cost(tier: BuildingTier.Tier) -> int:
	return upgrade_costs[tier]
