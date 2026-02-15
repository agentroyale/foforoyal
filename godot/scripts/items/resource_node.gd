class_name ResourceNode
extends StaticBody3D
## Harvestable resource node: trees, rocks, ores.
## Hit with tools to gather resources. Depletes and respawns.

signal node_hit(damage: float, yield_amount: int)
signal node_depleted()
signal node_respawned()

enum NodeType {
	TREE = 0,
	ROCK = 1,
	METAL_ORE = 2,
	SULFUR_ORE = 3,
}

@export var node_type: NodeType = NodeType.TREE
@export var max_hp: float = 100.0
@export var yield_item: ItemData
@export var base_yield_per_hit: int = 10
@export var respawn_time: float = 300.0

const HIT_SPOT_BONUS := 1.5
const HIT_SPOT_RADIUS := 0.5

const VARIANT_SCENES: Dictionary = {
	NodeType.TREE: [
		"res://assets/kaykit/forest/Tree_1_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_1_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_1_C_Color1.gltf",
		"res://assets/kaykit/forest/Tree_2_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_2_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_2_C_Color1.gltf",
		"res://assets/kaykit/forest/Tree_3_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_3_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_4_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_4_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_5_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_5_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_5_C_Color1.gltf",
		"res://assets/kaykit/forest/Tree_6_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_6_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_7_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_7_B_Color1.gltf",
		"res://assets/kaykit/forest/Tree_Bare_1_A_Color1.gltf",
		"res://assets/kaykit/forest/Tree_Bare_2_A_Color1.gltf",
	],
	NodeType.ROCK: [
		"res://assets/kaykit/forest/Rock_1_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_1_B_Color1.gltf",
		"res://assets/kaykit/forest/Rock_1_C_Color1.gltf",
		"res://assets/kaykit/forest/Rock_2_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_2_B_Color1.gltf",
		"res://assets/kaykit/forest/Rock_3_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_3_B_Color1.gltf",
		"res://assets/kaykit/forest/Rock_4_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_4_B_Color1.gltf",
		"res://assets/kaykit/forest/Rock_5_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_5_B_Color1.gltf",
		"res://assets/kaykit/forest/Rock_6_A_Color1.gltf",
		"res://assets/kaykit/forest/Rock_6_B_Color1.gltf",
	],
	NodeType.METAL_ORE: [
		"res://assets/kaykit/forest/Rock_1_E_Color1.gltf",
		"res://assets/kaykit/forest/Rock_2_C_Color1.gltf",
		"res://assets/kaykit/forest/Rock_3_E_Color1.gltf",
		"res://assets/kaykit/forest/Rock_4_E_Color1.gltf",
		"res://assets/kaykit/forest/Rock_5_E_Color1.gltf",
	],
	NodeType.SULFUR_ORE: [
		"res://assets/kaykit/forest/Rock_1_H_Color1.gltf",
		"res://assets/kaykit/forest/Rock_2_E_Color1.gltf",
		"res://assets/kaykit/forest/Rock_3_H_Color1.gltf",
		"res://assets/kaykit/forest/Rock_4_H_Color1.gltf",
		"res://assets/kaykit/forest/Rock_5_H_Color1.gltf",
	],
}

static var _scene_cache: Dictionary = {}

var current_hp: float = 100.0
var is_depleted: bool = false
var _respawn_timer: float = 0.0

@onready var hit_spot: Marker3D = $HitSpot
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	current_hp = max_hp
	add_to_group("resource_nodes")
	add_to_group("network_synced")
	_apply_visual_variant()
	if hit_spot:
		_randomize_hit_spot()


func _process(delta: float) -> void:
	if is_depleted:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()


func take_hit(tool: ToolData, hit_position: Vector3 = Vector3.ZERO) -> int:
	if is_depleted:
		return 0

	var tool_type := tool.tool_type if tool else ToolData.ToolType.HAND
	var power := tool.gather_power if tool else 1.0
	var effectiveness := ToolData.get_effectiveness(tool_type, node_type)
	var damage := power * effectiveness

	# Check hit spot bonus
	var yield_multiplier := 1.0
	if hit_spot and hit_position != Vector3.ZERO:
		var dist := hit_spot.global_position.distance_to(hit_position)
		if dist <= HIT_SPOT_RADIUS:
			yield_multiplier = HIT_SPOT_BONUS

	current_hp -= damage
	var yield_amount := int(base_yield_per_hit * effectiveness * yield_multiplier)
	yield_amount = maxi(yield_amount, 1)

	node_hit.emit(damage, yield_amount)

	if hit_spot:
		_randomize_hit_spot()

	if current_hp <= 0.0:
		_deplete()

	return yield_amount


func _deplete() -> void:
	current_hp = 0.0
	is_depleted = true
	_respawn_timer = respawn_time
	if _visual:
		_visual.visible = false
	if hit_spot:
		hit_spot.visible = false
	set_collision_layer(0)
	node_depleted.emit()


func _respawn() -> void:
	current_hp = max_hp
	is_depleted = false
	if _visual:
		_visual.visible = true
	if hit_spot:
		hit_spot.visible = true
	set_collision_layer(1)
	_randomize_hit_spot()
	node_respawned.emit()


func _apply_visual_variant() -> void:
	var variants: Array = VARIANT_SCENES.get(node_type, [])
	if variants.is_empty():
		return
	var path: String = variants[randi() % variants.size()]
	if not ResourceLoader.exists(path):
		return
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var scene: PackedScene = _scene_cache[path]
	if not scene:
		return
	if _visual:
		_visual.queue_free()
	_visual = scene.instantiate()
	_visual.name = "Visual"
	add_child(_visual)
	var scale_factor := randf_range(0.8, 1.2)
	_visual.scale = Vector3.ONE * scale_factor


func _randomize_hit_spot() -> void:
	if not hit_spot:
		return
	hit_spot.position = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(0.5, 2.0),
		randf_range(-0.5, 0.5)
	)
