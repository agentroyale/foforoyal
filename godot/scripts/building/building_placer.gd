class_name BuildingPlacer
extends Node3D
## Handles build mode: ghost preview, socket snapping, grid placement, rotation.
## Attach as child of the Player scene.

signal build_mode_changed(active: bool)
signal piece_placed_signal(piece: BuildingPiece)
signal piece_changed(piece_data: BuildingPieceData)

var is_build_mode: bool = false
var current_rotation: int = 0  # 0, 90, 180, 270
var can_place: bool = false
var current_piece_data: BuildingPieceData = null
var snapped_socket: BuildingSocket = null
var _prev_snapped_socket: BuildingSocket = null

const PLACEMENT_DISTANCE := 10.0
const ROTATION_STEP := 90
const GRID_SIZE := 3.0  # Matches foundation size

const PIECE_PATHS: Array[String] = [
	"res://resources/building_pieces/foundation_data.tres",
	"res://resources/building_pieces/wall_data.tres",
	"res://resources/building_pieces/floor_data.tres",
	"res://resources/building_pieces/doorway_data.tres",
	"res://resources/building_pieces/door_data.tres",
	"res://resources/building_pieces/tool_cupboard_data.tres",
	"res://resources/building_pieces/triangle_foundation_data.tres",
	"res://resources/building_pieces/stairs_data.tres",
	"res://resources/building_pieces/roof_data.tres",
	"res://resources/building_pieces/window_frame_data.tres",
	"res://resources/building_pieces/half_wall_data.tres",
	"res://resources/building_pieces/wall_arched_data.tres",
	"res://resources/building_pieces/wall_gated_data.tres",
	"res://resources/building_pieces/wall_window_arched_data.tres",
	"res://resources/building_pieces/wall_window_closed_data.tres",
	"res://resources/building_pieces/ceiling_data.tres",
	"res://resources/building_pieces/floor_wood_data.tres",
	"res://resources/building_pieces/pillar_data.tres",
]

var _pieces: Array[BuildingPieceData] = []
var _current_piece_index := 0

var ghost_instance: Node3D = null
var ghost_material_valid: StandardMaterial3D
var ghost_material_invalid: StandardMaterial3D
var _grid_mesh: MeshInstance3D = null
var _grid_material: ShaderMaterial = null


func _ready() -> void:
	_create_ghost_materials()
	_create_grid_mesh()
	_load_piece_data()


func _load_piece_data() -> void:
	for path in PIECE_PATHS:
		if ResourceLoader.exists(path):
			var data := load(path) as BuildingPieceData
			if data:
				_pieces.append(data)
	if not _pieces.is_empty():
		current_piece_data = _pieces[0]


func _create_ghost_materials() -> void:
	ghost_material_valid = StandardMaterial3D.new()
	ghost_material_valid.albedo_color = Color(0.0, 1.0, 0.0, 0.4)
	ghost_material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_valid.no_depth_test = true

	ghost_material_invalid = StandardMaterial3D.new()
	ghost_material_invalid.albedo_color = Color(1.0, 0.0, 0.0, 0.4)
	ghost_material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_invalid.no_depth_test = true


func _create_grid_mesh() -> void:
	_grid_mesh = MeshInstance3D.new()
	_grid_mesh.name = "BuildGrid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)  # 20 grid cells visible
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	_grid_mesh.mesh = plane
	_grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if ResourceLoader.exists("res://shaders/build_grid.gdshader"):
		var shader := load("res://shaders/build_grid.gdshader") as Shader
		_grid_material = ShaderMaterial.new()
		_grid_material.shader = shader
		_grid_material.set_shader_parameter("grid_size", GRID_SIZE)
		_grid_material.set_shader_parameter("line_width", 0.04)
		_grid_material.set_shader_parameter("grid_color", Color(0.3, 0.8, 1.0, 0.35))
		_grid_material.set_shader_parameter("fade_distance", 25.0)
		_grid_material.render_priority = -1
		_grid_mesh.material_override = _grid_material

	_grid_mesh.visible = false
	_grid_mesh.transparency = 0.5
	add_child(_grid_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not get_parent().is_multiplayer_authority():
		return
	if event.is_action_pressed("build_mode"):
		toggle_build_mode()

	if not is_build_mode:
		return

	if event.is_action_pressed("rotate_building"):
		rotate_ghost()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("demolish"):
		_try_demolish()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("primary_action"):
		if try_place():
			get_viewport().set_input_as_handled()

	# Scroll to cycle building pieces in build mode
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_piece(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_piece(-1)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_build_mode:
		if ghost_instance:
			_update_ghost_position()
		if _grid_mesh:
			_update_grid_position()


func toggle_build_mode() -> void:
	is_build_mode = not is_build_mode
	build_mode_changed.emit(is_build_mode)
	if is_build_mode:
		_show_ghost()
		if _grid_mesh:
			_grid_mesh.visible = true
	else:
		_hide_ghost()
		if _grid_mesh:
			_grid_mesh.visible = false


func set_piece_data(data: BuildingPieceData) -> void:
	current_piece_data = data
	piece_changed.emit(data)
	if is_build_mode:
		_hide_ghost()
		_show_ghost()


func _cycle_piece(direction: int) -> void:
	if _pieces.is_empty():
		return
	_current_piece_index = (_current_piece_index + direction) % _pieces.size()
	if _current_piece_index < 0:
		_current_piece_index += _pieces.size()
	set_piece_data(_pieces[_current_piece_index])


func rotate_ghost() -> void:
	current_rotation = (current_rotation + ROTATION_STEP) % 360
	if ghost_instance:
		ghost_instance.rotation_degrees.y = current_rotation


func _snap_to_grid(pos: Vector3) -> Vector3:
	## Snap position to the building grid.
	var half := GRID_SIZE / 2.0
	return Vector3(
		snappedf(pos.x - half, GRID_SIZE) + half,
		pos.y,
		snappedf(pos.z - half, GRID_SIZE) + half,
	)


func _update_grid_position() -> void:
	## Keep the grid centered on the player, snapped to grid.
	var player_pos: Vector3 = (get_parent() as Node3D).global_position
	_grid_mesh.global_position = _snap_to_grid(Vector3(
		player_pos.x, player_pos.y + 0.05, player_pos.z
	))


func _update_ghost_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var ray_origin := camera.global_position
	var ray_dir := -camera.global_basis.z

	# Check for socket snapping first
	var target_pos := ray_origin + ray_dir * PLACEMENT_DISTANCE
	snapped_socket = null
	var manager := _get_manager()
	if current_piece_data and manager:
		snapped_socket = manager.find_best_socket(target_pos, current_piece_data.piece_type)

	if snapped_socket:
		ghost_instance.global_position = snapped_socket.global_position
		ghost_instance.global_rotation = snapped_socket.global_rotation
		ghost_instance.rotate_y(deg_to_rad(current_rotation))
	else:
		# Raycast to find ground — shoot from camera through crosshair
		var space_state := get_world_3d().direct_space_state
		var ray_end := ray_origin + ray_dir * PLACEMENT_DISTANCE
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.exclude = [get_parent().get_rid()]
		query.collision_mask = 0xFFFFFFFF
		var result := space_state.intersect_ray(query)

		var hit_pos: Vector3
		if result:
			hit_pos = result.position
		else:
			# Fallback: secondary raycast straight down from target position
			var down_origin := target_pos + Vector3.UP * 50.0
			var down_end := target_pos + Vector3.DOWN * 50.0
			var down_query := PhysicsRayQueryParameters3D.create(down_origin, down_end)
			down_query.exclude = [get_parent().get_rid()]
			var down_result := space_state.intersect_ray(down_query)
			if down_result:
				hit_pos = down_result.position
			else:
				hit_pos = target_pos

		# Snap all pieces to grid
		hit_pos = _snap_to_grid(hit_pos)

		# Ensure foundation sits ON TOP of terrain, not inside it
		# Shoot a ray down from the snapped position to find exact ground height
		var ground_origin := Vector3(hit_pos.x, hit_pos.y + 50.0, hit_pos.z)
		var ground_end := Vector3(hit_pos.x, hit_pos.y - 50.0, hit_pos.z)
		var ground_query := PhysicsRayQueryParameters3D.create(ground_origin, ground_end)
		ground_query.exclude = [get_parent().get_rid()]
		var ground_result := space_state.intersect_ray(ground_query)
		if ground_result:
			hit_pos.y = ground_result.position.y

		ghost_instance.global_position = hit_pos
		ghost_instance.rotation_degrees.y = current_rotation

	# Detect socket change for snap sound
	if snapped_socket != _prev_snapped_socket:
		if snapped_socket != null:
			var sfx := get_node_or_null("/root/SFXGenerator")
			if sfx:
				sfx.play_snap(snapped_socket.global_position)
		_prev_snapped_socket = snapped_socket

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

	var is_foundation := current_piece_data.piece_type in [
		BuildingPieceData.PieceType.FOUNDATION,
		BuildingPieceData.PieceType.TRIANGLE_FOUNDATION,
	]
	var needs_socket := not is_foundation
	var has_valid_socket := snapped_socket != null

	# Check building privilege (TC authorization)
	var has_privilege := BuildingPrivilege.can_build(
		get_tree(), ghost_instance.global_position, _get_player_id()
	)

	var is_underground := _is_below_terrain(ghost_instance.global_position)

	can_place = not has_overlap and (not needs_socket or has_valid_socket) and has_privilege and not is_underground
	_set_ghost_material(ghost_material_valid if can_place else ghost_material_invalid)


func try_place() -> bool:
	if not can_place or not current_piece_data:
		var sfx := get_node_or_null("/root/SFXGenerator")
		if sfx:
			sfx.play_invalid(ghost_instance.global_position if ghost_instance else Vector3.ZERO)
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
	get_tree().current_scene.add_child(instance)
	instance.global_position = pos
	instance.global_rotation = rot

	if snapped_socket:
		snapped_socket.occupy(instance)
		instance.support_parent_socket = snapped_socket

	var manager := _get_manager()
	if manager:
		manager.register_piece(instance)

	BuildingStability.calculate_stability(instance)

	var sfx := get_node_or_null("/root/SFXGenerator")
	if sfx:
		sfx.play_place(instance.current_tier, pos)

	piece_placed_signal.emit(instance)
	return true


func _show_ghost() -> void:
	if not current_piece_data or not current_piece_data.piece_scene:
		return
	ghost_instance = current_piece_data.piece_scene.instantiate()
	if ghost_instance is StaticBody3D:
		(ghost_instance as StaticBody3D).set_collision_layer(0)
		(ghost_instance as StaticBody3D).set_collision_mask(0)
	# Disable scripts on ghost children to avoid side effects
	for child in ghost_instance.get_children():
		if child.has_method("set_process"):
			child.set_process(false)
			child.set_physics_process(false)
	_set_ghost_material(ghost_material_invalid)
	add_child(ghost_instance)


func _hide_ghost() -> void:
	if ghost_instance:
		ghost_instance.queue_free()
		ghost_instance = null
	snapped_socket = null
	current_rotation = 0


func _set_ghost_material(mat: StandardMaterial3D) -> void:
	if not ghost_instance:
		return
	# Apply to all MeshInstance3D children recursively
	_apply_material_recursive(ghost_instance, mat)


func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _is_below_terrain(pos: Vector3) -> bool:
	## Returns true if pos is significantly below the terrain surface.
	const TOLERANCE := 0.5  # Allow slight embedding for uneven terrain

	# Try WorldGenerator first (procedural terrain)
	var world_gen := get_node_or_null("/root/WorldGenerator")
	if world_gen and world_gen.has_method("get_height_at") and world_gen.get("is_initialized"):
		var terrain_y: float = world_gen.get_height_at(pos.x, pos.z)
		return pos.y < terrain_y - TOLERANCE

	# Fallback: raycast upward from position — if we hit something, we're underground
	var space_state := get_world_3d()
	if not space_state:
		return false
	var direct_state := space_state.direct_space_state
	if not direct_state:
		return false
	var ray_start := pos + Vector3.UP * 0.1
	var ray_end := pos + Vector3.UP * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1  # Terrain layer
	var result := direct_state.intersect_ray(query)
	return result and not result.is_empty()


func _get_manager() -> Node:
	return get_node_or_null("/root/BuildingManager")


func _try_demolish() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var ray_origin := camera.global_position
	var ray_dir := -camera.global_basis.z
	var space_state := get_world_3d().direct_space_state
	var ray_end := ray_origin + ray_dir * PLACEMENT_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_parent().get_rid()]
	var result := space_state.intersect_ray(query)
	if not result:
		return
	var hit: Object = result.collider
	if hit is BuildingPiece:
		var piece := hit as BuildingPiece
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			var manager := _get_manager()
			if manager:
				manager.request_demolish_piece.rpc_id(1, piece.get_path())
		else:
			piece.take_damage(piece.max_hp * 10.0)


func _get_player_id() -> int:
	# In singleplayer, return 1. In multiplayer, return the network peer ID.
	if multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
