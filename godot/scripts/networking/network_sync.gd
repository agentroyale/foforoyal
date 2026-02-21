class_name NetworkSync
extends Node
## Handles position/rotation sync for a player node.
## Authority sends state to server, server rebroadcasts to nearby peers.
## Remote players use NetworkInterpolation for smooth rendering.
## Integrates LagCompensation for server-side hit validation.
##
## Interest management: grid-based spatial hashing (128m cells, 3x3 neighbors).
## Delta compression: skip send when position/rotation unchanged.
## Fixed tick: sync aligned to physics ticks, not float timer.

const SYNC_INTERVAL := 0.05  # 20 ticks/sec (legacy, used when USE_FIXED_TICK=false)
const SYNC_TICK_INTERVAL := 3  # 60Hz physics / 3 = 20Hz sync
const POSITION_SNAP_THRESHOLD := 10.0  # Teleport if too far off

# Interest management
const USE_INTEREST_MANAGEMENT := true
const INTEREST_CELL_SIZE := 128.0  # Meters per grid cell
const INTEREST_REBUILD_INTERVAL := 0.5  # Seconds between grid rebuilds

# Delta compression
const USE_DELTA_COMPRESSION := true
const POSITION_SEND_THRESHOLD := 0.1  # 10cm
const ROTATION_SEND_THRESHOLD := 0.05  # ~3 degrees

# Fixed tick
const USE_FIXED_TICK := true

var _sync_timer: float = 0.0
var _sync_tick: int = 0
var _interpolation: NetworkInterpolation = null
var _lag_comp: LagCompensation = null
var _last_validated_pos := Vector3.ZERO
var _prediction: ClientPrediction = null

# Delta compression state
var _last_sent_pos := Vector3.ZERO
var _last_sent_rot := 0.0
var _last_sent_pitch := 0.0

# Interest management (server-only, static so CombatNetcode can access)
static var _interest_grid: Dictionary = {}  # Vector2i -> Array[int]
static var _peer_cells: Dictionary = {}  # int -> Vector2i
static var _peer_positions: Dictionary = {}  # int -> Vector3
static var _rebuild_timer: float = 0.0
static var _grid_initialized: bool = false

# Lag compensation registry (server-only, static so CombatNetcode can access)
static var lag_comp_instances: Dictionary = {}  # peer_id -> LagCompensation


func _ready() -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	# Remote players on CLIENTS get interpolation (server sets positions directly)
	if not player.is_multiplayer_authority() and not multiplayer.is_server():
		_interpolation = NetworkInterpolation.new()
		_interpolation.name = "NetworkInterpolation"
		player.add_child.call_deferred(_interpolation)
		# Disable physics for remote players (interpolation handles movement)
		player.set_physics_process(false)

	# Server tracks all player positions for lag compensation
	if multiplayer.is_server():
		_lag_comp = LagCompensation.new()
		var peer_id := player.get_multiplayer_authority()
		lag_comp_instances[peer_id] = _lag_comp

	# Local player gets client prediction
	if player.is_multiplayer_authority() and not multiplayer.is_server():
		_prediction = ClientPrediction.new()

	# When a new peer joins, reset delta compression so we force a full sync
	if player.is_multiplayer_authority():
		NetworkManager.player_connected.connect(_on_peer_joined)

	_last_validated_pos = player.global_position
	_last_sent_pos = player.global_position
	_last_sent_rot = player.rotation.y


func _exit_tree() -> void:
	var player := get_parent() as CharacterBody3D
	if player and multiplayer.is_server():
		var peer_id := player.get_multiplayer_authority()
		lag_comp_instances.erase(peer_id)
	if NetworkManager and NetworkManager.player_connected.is_connected(_on_peer_joined):
		NetworkManager.player_connected.disconnect(_on_peer_joined)


## Force full sync on next tick when a new peer joins (defeats delta compression).
func _on_peer_joined(_peer_id: int) -> void:
	_last_sent_pos = Vector3(INF, INF, INF)
	_last_sent_rot = INF
	_last_sent_pitch = INF


func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	if not multiplayer.has_multiplayer_peer():
		return

	# Server rebuilds interest grid periodically
	if multiplayer.is_server() and USE_INTEREST_MANAGEMENT:
		_rebuild_timer += delta
		if _rebuild_timer >= INTEREST_REBUILD_INTERVAL:
			_rebuild_timer = 0.0
			_update_interest_grid()

	# Authority sends position updates
	if player.is_multiplayer_authority():
		var should_send := false

		if USE_FIXED_TICK:
			_sync_tick += 1
			if _sync_tick >= SYNC_TICK_INTERVAL:
				_sync_tick = 0
				should_send = true
		else:
			_sync_timer += delta
			if _sync_timer >= SYNC_INTERVAL:
				_sync_timer = 0.0
				should_send = true

		if should_send:
			var pos := player.global_position
			var rot_y := player.rotation.y
			var pitch := 0.0
			var pivot := player.get_node_or_null("CameraPivot") as Node3D
			if pivot:
				pitch = pivot.rotation.x

			# Delta compression: skip if nothing changed
			if USE_DELTA_COMPRESSION:
				var pos_delta := pos.distance_to(_last_sent_pos)
				var rot_delta := absf(rot_y - _last_sent_rot)
				var pitch_delta := absf(pitch - _last_sent_pitch)
				if pos_delta < POSITION_SEND_THRESHOLD and rot_delta < ROTATION_SEND_THRESHOLD and pitch_delta < ROTATION_SEND_THRESHOLD:
					return

			_last_sent_pos = pos
			_last_sent_rot = rot_y
			_last_sent_pitch = pitch
			var server_time := Time.get_ticks_msec()
			_send_state.rpc(pos, rot_y, pitch, server_time)
			if NetworkMetrics:
				NetworkMetrics.record_rpc(24)  # ~24 bytes per position sync (added timestamp)

	# Server records positions for lag compensation
	if multiplayer.is_server() and _lag_comp:
		var peer_id := player.get_multiplayer_authority()
		_lag_comp.record_snapshot(peer_id, player.global_position, player.rotation.y)


@rpc("any_peer", "unreliable_ordered")
func _send_state(pos: Vector3, rot_y: float, pitch: float, send_time_msec: int = 0) -> void:
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

		# Track peer position for interest management
		_peer_positions[sender_id] = pos

		# Update player position on server (for non-host players)
		if sender_id != 1:
			player.global_position = pos
			player.rotation.y = rot_y
			var pivot := player.get_node_or_null("CameraPivot") as Node3D
			if pivot:
				pivot.rotation.x = pitch

		# Rebroadcast to nearby clients with server timestamp
		var server_time := Time.get_ticks_msec()
		if USE_INTEREST_MANAGEMENT:
			var nearby := _get_nearby_peers(sender_id)
			for peer_id in nearby:
				if peer_id != sender_id and peer_id != 1:
					_receive_state.rpc_id(peer_id, pos, rot_y, pitch, server_time)
					if NetworkMetrics:
						NetworkMetrics.record_rpc(24)
		else:
			for peer_id in NetworkManager.connected_peers:
				if peer_id != sender_id and peer_id != 1:
					_receive_state.rpc_id(peer_id, pos, rot_y, pitch, server_time)

	# If we're not the server but received this (shouldn't happen with proper routing)
	elif not player.is_multiplayer_authority():
		_apply_remote_state(pos, rot_y, pitch)


@rpc("authority", "unreliable_ordered")
func _receive_state(pos: Vector3, rot_y: float, pitch: float, _server_time_msec: int = 0) -> void:
	NetworkManager.record_sync_received()
	_apply_remote_state(pos, rot_y, pitch)


func _apply_remote_state(pos: Vector3, rot_y: float, pitch: float) -> void:
	var player := get_parent() as CharacterBody3D
	if not player or player.is_multiplayer_authority():
		return

	# Use local receive time for snapshot interpolation buffer
	var receive_time := Time.get_ticks_msec() as float

	# Snap if too far (teleport/spawn) — feed directly and also add snapshot
	if player.global_position.distance_to(pos) > POSITION_SNAP_THRESHOLD:
		player.global_position = pos
		player.rotation.y = rot_y
		var pivot := player.get_node_or_null("CameraPivot") as Node3D
		if pivot:
			pivot.rotation.x = pitch

	# Add to interpolation buffer
	if _interpolation:
		_interpolation.add_snapshot(receive_time, pos, rot_y, pitch)


func get_lag_compensation() -> LagCompensation:
	return _lag_comp


func get_position_at_time(peer_id: int, timestamp: float) -> Dictionary:
	if _lag_comp:
		return _lag_comp.get_position_at_time(peer_id, timestamp)
	return {}


# === Interest Management ===

static func position_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / INTEREST_CELL_SIZE),
		floori(pos.z / INTEREST_CELL_SIZE)
	)


static func _update_interest_grid() -> void:
	_interest_grid.clear()
	for peer_id in _peer_positions:
		var pos: Vector3 = _peer_positions[peer_id]
		var cell := position_to_cell(pos)
		_peer_cells[peer_id] = cell
		if not _interest_grid.has(cell):
			_interest_grid[cell] = []
		_interest_grid[cell].append(peer_id)
	_grid_initialized = true
	if NetworkMetrics:
		NetworkMetrics.record_grid_rebuild()


static func _get_nearby_peers(sender_id: int) -> Array:
	if not _grid_initialized or not _peer_cells.has(sender_id):
		# Fallback: return all peers
		return NetworkManager.connected_peers.keys()

	var result: Array = []
	var center_cell: Vector2i = _peer_cells[sender_id]

	# Search 3x3 grid neighborhood
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dz)
			if _interest_grid.has(cell):
				for peer_id in _interest_grid[cell]:
					if peer_id != sender_id and not result.has(peer_id):
						result.append(peer_id)
	return result


## Get nearby peers for a given position (used by CombatNetcode for VFX filtering).
static func get_nearby_peers_for_position(pos: Vector3) -> Array:
	if not _grid_initialized:
		return NetworkManager.connected_peers.keys()

	var result: Array = []
	var center_cell := position_to_cell(pos)

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := Vector2i(center_cell.x + dx, center_cell.y + dz)
			if _interest_grid.has(cell):
				for peer_id in _interest_grid[cell]:
					if not result.has(peer_id):
						result.append(peer_id)
	return result


## Clear all static state (for tests / disconnect).
static func clear_interest_data() -> void:
	_interest_grid.clear()
	_peer_cells.clear()
	_peer_positions.clear()
	_rebuild_timer = 0.0
	_grid_initialized = false
	lag_comp_instances.clear()
