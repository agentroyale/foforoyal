class_name NetworkSync
extends Node
## Handles position/rotation sync for a player node.
## Authority sends state to server, server rebroadcasts to all.
## Remote players use NetworkInterpolation for smooth rendering.
## Integrates LagCompensation for server-side hit validation.

const SYNC_INTERVAL := 0.05  # 20 ticks/sec
const POSITION_SNAP_THRESHOLD := 10.0  # Teleport if too far off

var _sync_timer: float = 0.0
var _interpolation: NetworkInterpolation = null
var _lag_comp: LagCompensation = null
var _last_validated_pos := Vector3.ZERO
var _prediction: ClientPrediction = null


func _ready() -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	# Remote players get interpolation
	if not player.is_multiplayer_authority():
		_interpolation = NetworkInterpolation.new()
		_interpolation.name = "NetworkInterpolation"
		player.add_child(_interpolation)
		# Disable physics for remote players (interpolation handles movement)
		player.set_physics_process(false)

	# Server tracks all player positions for lag compensation
	if multiplayer.is_server():
		_lag_comp = LagCompensation.new()

	# Local player gets client prediction
	if player.is_multiplayer_authority() and not multiplayer.is_server():
		_prediction = ClientPrediction.new()

	_last_validated_pos = player.global_position


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	if not multiplayer.has_multiplayer_peer():
		return

	# Authority sends position updates
	if player.is_multiplayer_authority():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			var pos := player.global_position
			var rot_y := player.rotation.y
			var pitch := 0.0
			var pivot := player.get_node_or_null("CameraPivot") as Node3D
			if pivot:
				pitch = pivot.rotation.x
			_send_state.rpc(pos, rot_y, pitch)

	# Server records positions for lag compensation
	if multiplayer.is_server() and _lag_comp:
		var peer_id := player.get_multiplayer_authority()
		_lag_comp.record_snapshot(peer_id, player.global_position, player.rotation.y)


@rpc("any_peer", "unreliable_ordered")
func _send_state(pos: Vector3, rot_y: float, pitch: float) -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	var sender_id := multiplayer.get_remote_sender_id()

	# Server receives and validates
	if multiplayer.is_server():
		# Validate movement speed
		var delta_time := SYNC_INTERVAL
		if not ServerValidation.validate_movement(_last_validated_pos, pos, delta_time):
			# Suspicious movement -- clamp to max speed
			var dir := (pos - _last_validated_pos).normalized()
			var max_dist := ServerValidation.MAX_SPEED * delta_time
			pos = _last_validated_pos + dir * max_dist

		_last_validated_pos = pos

		# Update player position on server (for non-host players)
		if sender_id != 1:
			player.global_position = pos
			player.rotation.y = rot_y
			var pivot := player.get_node_or_null("CameraPivot") as Node3D
			if pivot:
				pivot.rotation.x = pitch

		# Rebroadcast to all other clients
		for peer_id in NetworkManager.connected_peers:
			if peer_id != sender_id and peer_id != 1:
				_receive_state.rpc_id(peer_id, pos, rot_y, pitch)

	# If we're not the server but received this (shouldn't happen with proper routing)
	elif not player.is_multiplayer_authority():
		_apply_remote_state(pos, rot_y, pitch)


@rpc("authority", "unreliable_ordered")
func _receive_state(pos: Vector3, rot_y: float, pitch: float) -> void:
	_apply_remote_state(pos, rot_y, pitch)


func _apply_remote_state(pos: Vector3, rot_y: float, pitch: float) -> void:
	var player := get_parent() as CharacterBody3D
	if not player or player.is_multiplayer_authority():
		return

	# Snap if too far (teleport/spawn)
	if player.global_position.distance_to(pos) > POSITION_SNAP_THRESHOLD:
		player.global_position = pos
		player.rotation.y = rot_y
		var pivot := player.get_node_or_null("CameraPivot") as Node3D
		if pivot:
			pivot.rotation.x = pitch
		if _interpolation:
			_interpolation.set_target(pos, rot_y, pitch)
		return

	# Normal interpolation
	if _interpolation:
		_interpolation.set_target(pos, rot_y, pitch)


func get_lag_compensation() -> LagCompensation:
	return _lag_comp


func get_position_at_time(peer_id: int, timestamp: float) -> Dictionary:
	if _lag_comp:
		return _lag_comp.get_position_at_time(peer_id, timestamp)
	return {}
