class_name BuildingPlacer
extends Node3D
## Handles build mode: ghost preview, socket snapping, rotation, placement.
## Attach as child of the Player scene.

signal build_mode_changed(active: bool)
signal piece_placed_signal(piece: BuildingPiece)

var is_build_mode: bool = false
var current_rotation: int = 0  # 0, 90, 180, 270
var can_place: bool = false
var current_piece_data: BuildingPieceData = null
var snapped_socket: BuildingSocket = null

const PLACEMENT_DISTANCE := 5.0
const ROTATION_STEP := 90

var ghost_instance: Node3D = null
var ghost_material_valid: StandardMaterial3D
var ghost_material_invalid: StandardMaterial3D


func _ready() -> void:
	_create_ghost_materials()


func _create_ghost_materials() -> void:
	ghost_material_valid = StandardMaterial3D.new()
	ghost_material_valid.albedo_color = Color(0.0, 1.0, 0.0, 0.4)
	ghost_material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_valid.no_depth_test = true

	ghost_material_invalid = StandardMaterial3D.new()
	ghost_material_invalid.albedo_color = Color(1.0, 0.0, 0.0, 0.4)
	ghost_material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_invalid.no_depth_test = true


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event.is_action_pressed("build_mode"):
		toggle_build_mode()

	if not is_build_mode:
		return

	if event.is_action_pressed("rotate_building"):
		rotate_ghost()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("primary_action"):
		try_place()


func _process(_delta: float) -> void:
	if is_build_mode and ghost_instance:
		_update_ghost_position()


func toggle_build_mode() -> void:
	is_build_mode = not is_build_mode
	build_mode_changed.emit(is_build_mode)
	if is_build_mode:
		_show_ghost()
	else:
		_hide_ghost()


func set_piece_data(data: BuildingPieceData) -> void:
	current_piece_data = data
	if is_build_mode:
		_hide_ghost()
		_show_ghost()


func rotate_ghost() -> void:
	current_rotation = (current_rotation + ROTATION_STEP) % 360
	if ghost_instance:
		ghost_instance.rotation_degrees.y = current_rotation


func _update_ghost_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var ray_origin := camera.global_position
	var ray_dir := -camera.global_basis.z
	var target_pos := ray_origin + ray_dir * PLACEMENT_DISTANCE

	# Check for socket snapping
	snapped_socket = null
	var manager := _get_manager()
	if current_piece_data and manager:
		snapped_socket = manager.find_best_socket(target_pos, current_piece_data.piece_type)

	if snapped_socket:
		ghost_instance.global_position = snapped_socket.global_position
		ghost_instance.global_rotation = snapped_socket.global_rotation
		ghost_instance.rotate_y(deg_to_rad(current_rotation))
	else:
		# Free placement (raycast to ground)
		var space_state := get_world_3d().direct_space_state
		var ray_end := ray_origin + ray_dir * PLACEMENT_DISTANCE
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [get_parent().get_rid()]
		var result := space_state.intersect_ray(query)
		if result:
			ghost_instance.global_position = result.position
		else:
			ghost_instance.global_position = target_pos
		ghost_instance.rotation_degrees.y = current_rotation

	_validate_placement()


func _validate_placement() -> void:
	if not current_piece_data:
		can_place = false
		_set_ghost_material(ghost_material_invalid)
		return

	var manager := _get_manager()
	var has_overlap := false
	if manager:
		has_overlap = manager.check_overlap(ghost_instance.global_position, current_piece_data.piece_type)

	var needs_socket := current_piece_data.piece_type != BuildingPieceData.PieceType.FOUNDATION
	var has_valid_socket := snapped_socket != null

	# Check building privilege (TC authorization)
	var has_privilege := BuildingPrivilege.can_build(
		get_tree(), ghost_instance.global_position, _get_player_id()
	)

	can_place = not has_overlap and (not needs_socket or has_valid_socket) and has_privilege
	_set_ghost_material(ghost_material_valid if can_place else ghost_material_invalid)


func try_place() -> bool:
	if not can_place or not current_piece_data:
		return false

	var piece_scene := current_piece_data.piece_scene
	if not piece_scene:
		return false

	var pos := ghost_instance.global_position
	var rot := ghost_instance.global_rotation

	# In multiplayer, send request to server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var manager := _get_manager()
		if manager:
			manager.request_place_piece.rpc_id(
				1,
				current_piece_data.resource_path,
				pos,
				rot,
				_get_player_id()
			)
		return true

	# Singleplayer or server: place directly
	var instance := piece_scene.instantiate() as BuildingPiece
	instance.piece_data = current_piece_data
	instance.global_position = pos
	instance.global_rotation = rot

	get_tree().current_scene.add_child(instance)

	var manager := _get_manager()
	if manager:
		manager.register_piece(instance)

	if snapped_socket:
		snapped_socket.occupy(instance)

	piece_placed_signal.emit(instance)
	return true


func _show_ghost() -> void:
	if not current_piece_data or not current_piece_data.piece_scene:
		return
	ghost_instance = current_piece_data.piece_scene.instantiate()
	if ghost_instance is StaticBody3D:
		(ghost_instance as StaticBody3D).set_collision_layer(0)
		(ghost_instance as StaticBody3D).set_collision_mask(0)
	_set_ghost_material(ghost_material_invalid)
	add_child(ghost_instance)


func _hide_ghost() -> void:
	if ghost_instance:
		ghost_instance.queue_free()
		ghost_instance = null
	snapped_socket = null
	current_rotation = 0


func _set_ghost_material(mat: StandardMaterial3D) -> void:
	if ghost_instance:
		var mesh := ghost_instance.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.material_override = mat


func _get_manager() -> Node:
	return get_node_or_null("/root/BuildingManager")


func _get_player_id() -> int:
	# In singleplayer, return 1. In multiplayer, return the network peer ID.
	if multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
