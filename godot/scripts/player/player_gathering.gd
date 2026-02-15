class_name PlayerGathering
extends Node
## Handles resource gathering: swing timer, hit detection, yield to inventory.

signal swing_started()
signal item_gathered(item: ItemData, count: int)
signal swing_finished()

const SWING_COOLDOWN := 0.5

var _swing_timer: float = 0.0
var _can_swing: bool = true


func _process(delta: float) -> void:
	if not _can_swing:
		_swing_timer -= delta
		if _swing_timer <= 0.0:
			_can_swing = true
			swing_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event.is_action_pressed("primary_action") and _can_swing:
		var placer := get_parent().get_node_or_null("BuildingPlacer") as BuildingPlacer
		if placer and placer.is_build_mode:
			return

		# Weapon takes priority over gathering
		var weapon_ctrl := get_parent().get_node_or_null("WeaponController") as WeaponController
		if weapon_ctrl:
			var inv := get_parent().get_node_or_null("PlayerInventory") as PlayerInventory
			if inv and inv.get_active_item() is WeaponData:
				weapon_ctrl.try_fire()
				return

		_try_gather()


func _try_gather() -> void:
	var ray := get_parent().get_node_or_null("CameraPivot/InteractionRay") as RayCast3D
	if not ray or not ray.is_colliding():
		_start_swing()
		return

	var collider := ray.get_collider()
	if collider is ResourceNode:
		var resource_node := collider as ResourceNode
		var hit_pos := ray.get_collision_point()
		_gather_from_node(resource_node, hit_pos)

	_start_swing()


func _gather_from_node(resource_node: ResourceNode, hit_position: Vector3) -> void:
	var player_inv := get_parent().get_node_or_null("PlayerInventory") as PlayerInventory
	if not player_inv:
		return

	var tool := player_inv.get_active_tool()
	var yield_amount := resource_node.take_hit(tool, hit_position)

	if yield_amount > 0 and resource_node.yield_item:
		var overflow := player_inv.add_item_to_inventory(resource_node.yield_item, yield_amount)
		item_gathered.emit(resource_node.yield_item, yield_amount - overflow)


func _start_swing() -> void:
	_can_swing = false
	_swing_timer = SWING_COOLDOWN
	swing_started.emit()
