class_name BuildingPieceData
extends Resource
## Data resource for a building piece type (foundation, wall, etc.).

enum PieceType {
	FOUNDATION,          # 0
	WALL,                # 1
	FLOOR,               # 2
	DOORWAY,             # 3
	DOOR,                # 4
	TRIANGLE_FOUNDATION, # 5
	STAIRS,              # 6
	ROOF,                # 7
	WINDOW_FRAME,        # 8
	HALF_WALL,           # 9
	WALL_ARCHED,         # 10
	WALL_GATED,          # 11
	WALL_WINDOW_ARCHED,  # 12
	WALL_WINDOW_CLOSED,  # 13
	CEILING,             # 14
	FLOOR_WOOD,          # 15
	PILLAR,              # 16
	TOOL_CUPBOARD,       # 17
}

@export var icon: Texture2D
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


static func get_category(type: PieceType) -> int:
	match type:
		PieceType.FOUNDATION, PieceType.TRIANGLE_FOUNDATION, PieceType.PILLAR:
			return 0
		PieceType.WALL, PieceType.DOORWAY, PieceType.DOOR, PieceType.WINDOW_FRAME, \
		PieceType.HALF_WALL, PieceType.WALL_ARCHED, PieceType.WALL_GATED, \
		PieceType.WALL_WINDOW_ARCHED, PieceType.WALL_WINDOW_CLOSED:
			return 1
		PieceType.FLOOR, PieceType.FLOOR_WOOD, PieceType.CEILING, PieceType.STAIRS:
			return 2
		PieceType.ROOF, PieceType.TOOL_CUPBOARD, _:
			return 3
