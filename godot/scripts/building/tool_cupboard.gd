class_name ToolCupboard
extends BuildingPiece
## Tool Cupboard: grants building privilege within its radius.
## Players must be authorized to build/demolish inside the TC area.

signal authorization_changed()

const TC_RADIUS := 50.0

## Player IDs (or node references) authorized to build in this TC's area.
var authorized_players: Array[int] = []

var _area: Area3D


func _ready() -> void:
	super._ready()
	add_to_group("tool_cupboards")
	_setup_area()


func _setup_area() -> void:
	_area = get_node_or_null("PrivilegeArea") as Area3D
	if not _area:
		_area = Area3D.new()
		_area.name = "PrivilegeArea"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = TC_RADIUS
		shape.shape = sphere
		_area.add_child(shape)
		_area.collision_layer = 0
		_area.collision_mask = 2  # Player layer
		_area.monitorable = false
		add_child(_area)


func authorize_player(player_id: int) -> void:
	if player_id not in authorized_players:
		authorized_players.append(player_id)
		authorization_changed.emit()


func deauthorize_player(player_id: int) -> void:
	authorized_players.erase(player_id)
	authorization_changed.emit()


func clear_authorization() -> void:
	authorized_players.clear()
	authorization_changed.emit()


func is_authorized(player_id: int) -> bool:
	return player_id in authorized_players


func is_position_in_range(world_position: Vector3) -> bool:
	return global_position.distance_to(world_position) <= TC_RADIUS


func interact(player: Node3D) -> void:
	# Override BuildingPiece.interact — opens TC auth panel instead of upgrading.
	# The UI system will handle this in Phase 3 UI task.
	pass


func get_area() -> Area3D:
	return _area
