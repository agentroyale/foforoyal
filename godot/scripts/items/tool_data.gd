class_name ToolData
extends ItemData
## Tool data: gathering stats, durability, effectiveness matrix.

enum ToolType {
	HAND = 0,
	HATCHET = 1,
	PICKAXE = 2,
	HAMMER = 3,
}

@export var gather_power: float = 1.0
@export var max_durability: int = 50
@export var tool_type: ToolType = ToolType.HAND

const DEFAULT_EFFECTIVENESS := 0.3

## ToolType -> { NodeType(int) -> multiplier }
static var effectiveness_matrix: Dictionary = {
	ToolType.HAND:    { 0: 0.5, 1: 0.5, 2: 0.3, 3: 0.3 },
	ToolType.HATCHET: { 0: 1.0, 1: 0.5, 2: 0.3, 3: 0.3 },
	ToolType.PICKAXE: { 0: 0.5, 1: 1.0, 2: 1.0, 3: 1.0 },
	ToolType.HAMMER:  { 0: 0.5, 1: 0.5, 2: 0.5, 3: 0.5 },
}


static func get_effectiveness(tool_type_val: ToolType, node_type: int) -> float:
	if tool_type_val in effectiveness_matrix:
		var node_map: Dictionary = effectiveness_matrix[tool_type_val]
		if node_type in node_map:
			return node_map[node_type]
	return DEFAULT_EFFECTIVENESS
