extends Node
## Handles parachute deployment during BR drop.
## Attach as child of PlayerController.
## Controls camera zoom, weapon visibility, and animation during drop phases.
## Supports server-authoritative input via set_input().

signal parachute_opened()
signal landed()

const FREEFALL_SPEED := 20.0
const PARACHUTE_DESCENT_SPEED := 5.0
const PARACHUTE_HORIZONTAL_SPEED := 10.0
const DEPLOY_ALTITUDE := 50.0
const FLIGHT_CAMERA_DISTANCE := 15.0
const FREEFALL_CAMERA_DISTANCE := 12.0

var is_dropping: bool = false
var parachute_deployed: bool = false
var _parachute_visual: Node3D = null
var _parachute_input: Vector2 = Vector2.ZERO  # Server-side input from RPC


func set_input(direction: Vector2) -> void:
	## Called by NetworkSync on server to set parachute movement direction.
	_parachute_input = direction


func start_drop() -> void:
	is_dropping = true
	parachute_deployed = false
	var player := get_parent() as CharacterBody3D
	if player and player.has_method("disable_movement"):
		player.disable_movement()
	# Zoom camera out to see the plane from outside
	_set_camera_override(FLIGHT_CAMERA_DISTANCE)
	# Hide weapon and force freefall animation
	_set_drop_mode(true)


func _physics_process(delta: float) -> void:
	if not is_dropping:
		return
	var player := get_parent() as CharacterBody3D
	if not player:
		return
	# Check altitude for parachute deploy
	var altitude := _get_ground_distance(player)
	if not parachute_deployed and altitude <= DEPLOY_ALTITUDE:
		_deploy_parachute(player)
	# Movement
	if parachute_deployed:
		_parachute_movement(player, delta)
	else:
		_freefall_movement(player, delta)
	player.move_and_slide()
	# Landing detection
	if player.is_on_floor() and is_dropping:
		_land(player)


func _freefall_movement(player: CharacterBody3D, _delta: float) -> void:
	player.velocity = Vector3(0, -FREEFALL_SPEED, 0)


func _parachute_movement(player: CharacterBody3D, _delta: float) -> void:
	var input_dir: Vector2
	# Server uses input received via RPC; local player reads Input directly
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not player.is_multiplayer_authority():
		input_dir = _parachute_input
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	player.velocity = Vector3(
		direction.x * PARACHUTE_HORIZONTAL_SPEED,
		-PARACHUTE_DESCENT_SPEED,
		direction.z * PARACHUTE_HORIZONTAL_SPEED,
	)


func _deploy_parachute(player: CharacterBody3D) -> void:
	parachute_deployed = true
	parachute_opened.emit()
	# Camera back to normal TPS distance
	_set_camera_override(-1.0)
	# Spawn visual
	var scene := load("res://scenes/gamemode/parachute.tscn") as PackedScene
	if scene:
		_parachute_visual = scene.instantiate()
		player.add_child(_parachute_visual)


func _land(player: CharacterBody3D) -> void:
	is_dropping = false
	parachute_deployed = false
	_parachute_input = Vector2.ZERO
	# Remove visual
	if _parachute_visual:
		_parachute_visual.queue_free()
		_parachute_visual = null
	# Restore camera, weapon, animation
	_set_camera_override(-1.0)
	_set_drop_mode(false)
	# Re-enable player movement
	if player.has_method("enable_movement"):
		player.enable_movement()
	player.velocity = Vector3.ZERO
	landed.emit()
	# Notify drop controller
	var dc := get_tree().current_scene.get_node_or_null("DropController")
	if dc and dc.has_method("notify_landed"):
		var peer_id := player.get_multiplayer_authority() if multiplayer.has_multiplayer_peer() else 1
		dc.notify_landed(peer_id)


func _set_camera_override(distance: float) -> void:
	var player := get_parent()
	if not player:
		return
	var cam := player.get_node_or_null("CameraPivot") as PlayerCamera
	if cam:
		cam.camera_distance_override = distance


func _set_drop_mode(enabled: bool) -> void:
	var player := get_parent()
	if not player:
		return
	var model := player.get_node_or_null("PlayerModel") as PlayerModel
	if model:
		if enabled:
			model.enter_drop_mode()
		else:
			model.exit_drop_mode()


func _get_ground_distance(player: CharacterBody3D) -> float:
	var space := player.get_world_3d().direct_space_state
	if not space:
		return 999.0
	var from := player.global_position
	var to := from + Vector3(0, -500, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return 999.0
	return from.y - (result["position"] as Vector3).y
