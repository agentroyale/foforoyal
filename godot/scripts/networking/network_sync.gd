class_name NetworkSync
extends Node
## Server-authoritative player sync.
## Client sends raw INPUTS to server, server simulates move_and_slide(),
## server broadcasts authoritative SNAPSHOTS.
## Client predicts locally and reconciles against server snapshots.
##
## Interest management: grid-based spatial hashing (128m cells, 3x3 neighbors).
## Delta compression: skip send when position/rotation unchanged.
## Fixed tick: sync aligned to physics ticks, not float timer.

const SYNC_INTERVAL := 0.033  # ~30Hz (legacy, used when USE_FIXED_TICK=false)
const SYNC_TICK_INTERVAL := 2  # 60Hz physics / 2 = 30Hz sync
const POSITION_SNAP_THRESHOLD := 10.0  # Teleport if too far off

# Interest management
const USE_INTEREST_MANAGEMENT := true
const INTEREST_CELL_SIZE := 128.0  # Meters per grid cell
const INTEREST_REBUILD_INTERVAL := 0.5  # Seconds between grid rebuilds

# Delta compression (for broadcast to remote players)
const USE_DELTA_COMPRESSION := true
const POSITION_SEND_THRESHOLD := 0.1  # 10cm
const ROTATION_SEND_THRESHOLD := 0.05  # ~3 degrees

# Fixed tick
const USE_FIXED_TICK := true

# Movement mode constants (packed in input RPC)
const MOVE_MODE_NORMAL := 0
const MOVE_MODE_PARACHUTE := 1
const MOVE_MODE_DISABLED := 2

var _sync_timer: float = 0.0
var _sync_tick: int = 0
var _interpolation: NetworkInterpolation = null
var _lag_comp: LagCompensation = null
var _prediction: ClientPrediction = null

# Delta compression state (for broadcasts to remote players)
var _last_broadcast_pos := Vector3.ZERO
var _last_broadcast_rot := 0.0
var _last_broadcast_pitch := 0.0

# Server snapshot state
var _snapshot_id: int = 0

# Interest management (server-only, static so CombatNetcode can access)
static var _interest_grid: Dictionary = {}  # Vector2i -> Array[int]
static var _peer_cells: Dictionary = {}  # int -> Vector2i
static var _peer_positions: Dictionary = {}  # int -> Vector3
static var _rebuild_timer: float = 0.0
static var _grid_initialized: bool = false

# Lag compensation registry (server-only, static so CombatNetcode can access)
static var lag_comp_instances: Dictionary = {}  # peer_id -> LagCompensation

# Server-side sequence tracking (last received input seq per peer)
static var _last_processed_seq: Dictionary = {}  # peer_id -> int

# Server-side jitter buffers (one per remote peer)
static var _jitter_buffers: Dictionary = {}  # peer_id -> InputJitterBuffer

# Client-side: previous input for redundancy
var _prev_input_seq: int = -1
var _prev_input_dir: Vector2 = Vector2.ZERO
var _prev_input_jump: bool = false
var _prev_input_sprint: bool = false
var _prev_input_crouch: bool = false


func _ready() -> void:
	var player := get_parent() as CharacterBody3D
	if not player:
		return

	# Remote players on CLIENTS get interpolation (server sets positions directly)
	if not player.is_multiplayer_authority() and not multiplayer.is_server():
		_interpolation = NetworkInterpolation.new()
		_interpolation.name = "NetworkInterpolation"
		player.add_child.call_deferred(_interpolation)
		# Disable physics for remote players on clients (interpolation handles rendering)
		player.set_physics_process(false)

	# Server tracks all player positions for lag compensation
	if multiplayer.is_server():
		_lag_comp = LagCompensation.new()
		var peer_id := player.get_multiplayer_authority()
		lag_comp_instances[peer_id] = _lag_comp

	# Local player gets client prediction (non-host clients only)
	if player.is_multiplayer_authority() and not multiplayer.is_server():
		_prediction = ClientPrediction.new()
		if player is PlayerController:
			player._prediction = _prediction

	# When a new peer joins, reset delta compression so we force a full broadcast
	if player.is_multiplayer_authority():
		NetworkManager.player_connected.connect(_on_peer_joined)

	_last_broadcast_pos = player.global_position
	_last_broadcast_rot = player.rotation.y


func _exit_tree() -> void:
	var player := get_parent() as CharacterBody3D
	if player and multiplayer.is_server():
		var peer_id := player.get_multiplayer_authority()
		lag_comp_instances.erase(peer_id)
		_last_processed_seq.erase(peer_id)
		_jitter_buffers.erase(peer_id)
	if NetworkManager and NetworkManager.player_connected.is_connected(_on_peer_joined):
		NetworkManager.player_connected.disconnect(_on_peer_joined)


## Force full broadcast on next tick when a new peer joins (defeats delta compression).
func _on_peer_joined(_peer_id: int) -> void:
	_last_broadcast_pos = Vector3(INF, INF, INF)
	_last_broadcast_rot = INF
	_last_broadcast_pitch = INF


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

	# === CLIENT (authority): send inputs to server ===
	if player.is_multiplayer_authority() and not multiplayer.is_server():
		_sync_tick += 1
		if _sync_tick >= SYNC_TICK_INTERVAL:
			_sync_tick = 0
			_send_client_input(player)

	# === HOST (server + authority): broadcast own state directly ===
	if player.is_multiplayer_authority() and multiplayer.is_server():
		_sync_tick += 1
		if _sync_tick >= SYNC_TICK_INTERVAL:
			_sync_tick = 0
			_broadcast_host_state(player)

	# === SERVER: consume from jitter buffer + simulate remote players + send snapshots ===
	if multiplayer.is_server() and not player.is_multiplayer_authority():
		var peer_id := player.get_multiplayer_authority()
		var jbuf: InputJitterBuffer = _jitter_buffers.get(peer_id)

		# Consume input from jitter buffer and simulate physics
		if player is PlayerController and jbuf:
			var input: Dictionary = jbuf.tick()
			player.server_simulate_tick(input, delta)

		# Send snapshot back to owning client + broadcast to nearby peers
		_sync_tick += 1
		if _sync_tick >= SYNC_TICK_INTERVAL:
			_sync_tick = 0
			_send_server_snapshot(player)

	# Server records positions for lag compensation
	if multiplayer.is_server() and _lag_comp:
		var peer_id := player.get_multiplayer_authority()
		_lag_comp.record_snapshot(peer_id, player.global_position, player.rotation.y)


# === Client → Server: raw inputs ===

func _send_client_input(player: CharacterBody3D) -> void:
	var rot_y := player.rotation.y
	var pitch := _get_camera_pitch(player)
	var seq := (_prediction.get_sequence() - 1) if _prediction else 0
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var jump := Input.is_action_just_pressed("jump")
	var sprint := Input.is_action_pressed("sprint")
	var crouch := Input.is_action_pressed("crouch")
	var move_mode := _pack_move_mode(player)
	var anim_flags := _pack_anim_flags(player)

	# Build redundant previous input (for packet loss resilience)
	var redundant := _build_redundant_input()

	_send_player_input.rpc_id(1, seq, dir, jump, sprint, crouch,
			rot_y, pitch, move_mode, anim_flags, redundant)
	if NetworkMetrics:
		NetworkMetrics.record_rpc(31)  # ~25 current + 6 redundant

	# Save current as previous for next packet
	_prev_input_seq = seq
	_prev_input_dir = dir
	_prev_input_jump = jump
	_prev_input_sprint = sprint
	_prev_input_crouch = crouch


func _build_redundant_input() -> PackedFloat32Array:
	## Pack previous input for redundancy: [seq, dir.x, dir.y, jump, sprint, crouch]
	if _prev_input_seq < 0:
		return PackedFloat32Array()
	var data := PackedFloat32Array()
	data.resize(6)
	data[0] = float(_prev_input_seq)
	data[1] = _prev_input_dir.x
	data[2] = _prev_input_dir.y
	data[3] = 1.0 if _prev_input_jump else 0.0
	data[4] = 1.0 if _prev_input_sprint else 0.0
	data[5] = 1.0 if _prev_input_crouch else 0.0
	return data


@rpc("any_peer", "unreliable_ordered")
func _send_player_input(seq: int, direction: Vector2, jump: bool,
		sprint: bool, crouch: bool, rot_y: float, pitch: float,
		move_mode: int, anim_flags: int,
		redundant: PackedFloat32Array = PackedFloat32Array()) -> void:
	## Client → Server: raw input with sequence number + redundant previous input.
	if not multiplayer.is_server():
		return

	var player := get_parent() as CharacterBody3D
	if not player:
		return

	var sender_id := multiplayer.get_remote_sender_id()

	# Track highest received seq (for snapshot ack reference)
	var last_seq: int = _last_processed_seq.get(sender_id, -1)
	if seq > last_seq:
		_last_processed_seq[sender_id] = seq

	# Get or create jitter buffer for this peer
	var jbuf: InputJitterBuffer
	if _jitter_buffers.has(sender_id):
		jbuf = _jitter_buffers[sender_id]
	else:
		jbuf = InputJitterBuffer.new()
		_jitter_buffers[sender_id] = jbuf

	# Validate + sanitize input
	direction = ServerValidation.validate_input_direction(direction)

	# Apply look direction (client-authoritative rotation — instant, not buffered)
	player.rotation.y = rot_y
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot:
		pivot.rotation.x = pitch

	# Apply animation state on server (for listen server rendering + model)
	if player is PlayerController:
		var pc := player as PlayerController
		pc.network_is_aiming = bool(anim_flags & 2)
		pc.remote_on_floor = bool(anim_flags & 4)
		pc.network_weapon_type = (anim_flags >> 4) & 0xF

	# Route input to the correct controller
	if move_mode == MOVE_MODE_PARACHUTE:
		var parachute := player.get_node_or_null("ParachuteController")
		if parachute and parachute.has_method("set_input"):
			parachute.set_input(direction)
			if jump:
				var dc := player.get_tree().current_scene.get_node_or_null("DropController")
				if dc and dc.has_method("_eject_player"):
					dc._eject_player(player)
	elif move_mode == MOVE_MODE_NORMAL:
		# Process redundant (previous) input first — packet loss recovery
		if redundant.size() >= 6:
			var r_seq := int(redundant[0])
			var r_dir := ServerValidation.validate_input_direction(
					Vector2(redundant[1], redundant[2]))
			var r_input := {
				"direction": r_dir,
				"jump": redundant[3] > 0.5,
				"sprint": redundant[4] > 0.5,
				"crouch": redundant[5] > 0.5,
			}
			jbuf.push(r_seq, r_input)  # Buffer handles duplicates

		# Push current input into jitter buffer
		var input := {
			"direction": direction,
			"jump": jump,
			"sprint": sprint,
			"crouch": crouch,
		}
		jbuf.push(seq, input)


# === Server → Client: authoritative snapshot ===

func _send_server_snapshot(player: CharacterBody3D) -> void:
	var peer_id := player.get_multiplayer_authority()
	var pos := player.global_position
	var rot_y := player.rotation.y
	var pitch := _get_camera_pitch(player)
	var vel_y := player.velocity.y
	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var anim_flags := _pack_anim_flags(player)
	# Use last CONSUMED seq from jitter buffer (not last received)
	var jbuf: InputJitterBuffer = _jitter_buffers.get(peer_id)
	var last_seq: int = jbuf.get_last_consumed_seq() if jbuf else _last_processed_seq.get(peer_id, 0)

	# Track peer position for interest management
	_peer_positions[peer_id] = pos

	# Send authoritative snapshot to owning client
	_snapshot_id += 1
	var pc := player as PlayerController
	var is_crouch := pc.is_crouching if pc else false
	_receive_snapshot.rpc_id(peer_id, _snapshot_id, last_seq, pos,
			vel_y, is_crouch, h_speed, anim_flags)
	if NetworkMetrics:
		NetworkMetrics.record_rpc(40)

	# Broadcast to nearby clients (excluding owner and server)
	_broadcast_to_nearby(peer_id, pos, rot_y, pitch, h_speed, anim_flags)


func _broadcast_host_state(player: CharacterBody3D) -> void:
	var pos := player.global_position
	var rot_y := player.rotation.y
	var pitch := _get_camera_pitch(player)

	# Delta compression: skip if nothing changed
	if USE_DELTA_COMPRESSION:
		var pos_delta := pos.distance_to(_last_broadcast_pos)
		var rot_delta := absf(rot_y - _last_broadcast_rot)
		var pitch_delta := absf(pitch - _last_broadcast_pitch)
		if pos_delta < POSITION_SEND_THRESHOLD and rot_delta < ROTATION_SEND_THRESHOLD and pitch_delta < ROTATION_SEND_THRESHOLD:
			return

	_last_broadcast_pos = pos
	_last_broadcast_rot = rot_y
	_last_broadcast_pitch = pitch

	_peer_positions[1] = pos
	var h_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var anim_flags := _pack_anim_flags(player)

	_broadcast_to_nearby(1, pos, rot_y, pitch, h_speed, anim_flags)


func _broadcast_to_nearby(sender_id: int, pos: Vector3, rot_y: float,
		pitch: float, h_speed: float, anim_flags: int) -> void:
	# Apply delta compression for broadcast
	if USE_DELTA_COMPRESSION and sender_id != 1:
		var pos_delta := pos.distance_to(_last_broadcast_pos)
		var rot_delta := absf(rot_y - _last_broadcast_rot)
		var pitch_delta := absf(pitch - _last_broadcast_pitch)
		if pos_delta < POSITION_SEND_THRESHOLD and rot_delta < ROTATION_SEND_THRESHOLD and pitch_delta < ROTATION_SEND_THRESHOLD:
			return
		_last_broadcast_pos = pos
		_last_broadcast_rot = rot_y
		_last_broadcast_pitch = pitch

	var server_time := Time.get_ticks_msec()
	if USE_INTEREST_MANAGEMENT:
		var nearby := _get_nearby_peers(sender_id)
		for peer_id in nearby:
			if peer_id != sender_id and peer_id != 1:
				_receive_state.rpc_id(peer_id, pos, rot_y, pitch, server_time, h_speed, anim_flags)
				if NetworkMetrics:
					NetworkMetrics.record_rpc(28)
	else:
		for peer_id in NetworkManager.connected_peers:
			if peer_id != sender_id and peer_id != 1:
				_receive_state.rpc_id(peer_id, pos, rot_y, pitch, server_time, h_speed, anim_flags)
				if NetworkMetrics:
					NetworkMetrics.record_rpc(28)


@rpc("any_peer", "unreliable_ordered")
func _receive_snapshot(snapshot_id: int, last_input_seq: int,
		pos: Vector3, vel_y: float, is_crouching: bool,
		h_speed: float, anim_flags: int) -> void:
	## Server → Authority Client: authoritative snapshot for reconciliation.
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return  # Only accept snapshots from server
	var player := get_parent() as PlayerController
	if player and player.is_multiplayer_authority():
		player.apply_server_snapshot(pos, vel_y, last_input_seq, is_crouching)


@rpc("any_peer", "unreliable_ordered")
func _receive_state(pos: Vector3, rot_y: float, pitch: float, _server_time_msec: int = 0, h_speed: float = 0.0, anim_flags: int = 0) -> void:
	if not multiplayer.is_server() and multiplayer.get_remote_sender_id() != 1:
		return  # Only accept state from server
	NetworkManager.record_sync_received()
	_apply_remote_state(pos, rot_y, pitch, h_speed, anim_flags)


func _apply_remote_state(pos: Vector3, rot_y: float, pitch: float, h_speed: float = 0.0, anim_flags: int = 0) -> void:
	var player := get_parent() as CharacterBody3D
	if not player or player.is_multiplayer_authority():
		return

	# Unpack animation state onto PlayerController
	if player is PlayerController:
		player.is_crouching = bool(anim_flags & 1)
		player.network_is_aiming = bool(anim_flags & 2)
		player.remote_on_floor = bool(anim_flags & 4)
		player.network_weapon_type = (anim_flags >> 4) & 0xF
		player.network_move_speed = h_speed

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


# === Helpers ===

func _get_camera_pitch(player: CharacterBody3D) -> float:
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot:
		return pivot.rotation.x
	return 0.0


func _pack_move_mode(player: CharacterBody3D) -> int:
	if player is PlayerController and player.movement_disabled:
		return MOVE_MODE_DISABLED
	var parachute := player.get_node_or_null("ParachuteController")
	if parachute and parachute.get("is_dropping"):
		return MOVE_MODE_PARACHUTE
	return MOVE_MODE_NORMAL


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
	_last_processed_seq.clear()
	_jitter_buffers.clear()


## Pack animation-relevant state into a single int for network sync.
## Bits: 0=crouching, 1=aiming, 2=on_floor, 4-7=weapon_type
func _pack_anim_flags(player: CharacterBody3D) -> int:
	var flags := 0
	if player is PlayerController and player.is_crouching:
		flags |= 1
	# Check aiming via camera
	var cam := player.get_node_or_null("CameraPivot")
	if cam and cam is PlayerCamera and cam.is_aiming:
		flags |= 2
	if player.is_on_floor():
		flags |= 4
	# Pack weapon type in bits 4-7 (from inventory active item)
	var inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if inv:
		var item := inv.get_active_item()
		if item is WeaponData:
			flags |= ((item as WeaponData).weapon_type & 0xF) << 4
	return flags
