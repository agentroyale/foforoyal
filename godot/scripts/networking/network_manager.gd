extends Node
## Autoload singleton managing ENet multiplayer peer lifecycle.
## Handles server hosting, client joining, and peer tracking.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_started()
signal rtt_updated(rtt_ms: float)

const DEFAULT_PORT := 27015
const MAX_CLIENTS := 64
const PING_INTERVAL := 2.0  # Seconds between pings

# ENet bandwidth limits (bytes/sec). 0 = unlimited.
const SERVER_OUT_BANDWIDTH := 256 * 1024  # 256 KB/s outbound
const SERVER_IN_BANDWIDTH := 128 * 1024   # 128 KB/s inbound
const CLIENT_OUT_BANDWIDTH := 32 * 1024   # 32 KB/s outbound (clients send little)
const CLIENT_IN_BANDWIDTH := 256 * 1024   # 256 KB/s inbound

var connected_peers: Dictionary = {}  # peer_id -> { "join_time": int }
var _active_peer: bool = false  # Tracks whether we explicitly set a peer

# RTT measurement
var peer_rtt: Dictionary = {}  # peer_id -> float (ms), server tracks all peers
var local_rtt: float = 0.0  # Client's own RTT in ms
var _ping_timer: float = 0.0

# Jitter tracking (client-side) — rolling window of last N RTT samples
const RTT_HISTORY_SIZE := 10
var _rtt_history: Array[float] = []
var local_jitter: float = 0.0  # Standard deviation of recent RTTs in ms

# Packet loss tracking (client-side) — based on sync sequence gaps
var _expected_syncs: int = 0
var _received_syncs: int = 0
var _loss_window_timer: float = 0.0
const LOSS_WINDOW := 5.0  # Calculate loss every 5s
var local_packet_loss: float = 0.0  # 0.0 to 1.0


func host_server(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS, 0, SERVER_IN_BANDWIDTH, SERVER_OUT_BANDWIDTH)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_active_peer = true
	_connect_signals()
	connected_peers[1] = { "join_time": Time.get_ticks_msec() }
	server_started.emit()
	return OK


func join_server(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, 0, CLIENT_IN_BANDWIDTH, CLIENT_OUT_BANDWIDTH)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_active_peer = true
	_connect_signals()
	return OK


func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_active_peer = false
	connected_peers.clear()


func is_server() -> bool:
	return _active_peer and multiplayer.is_server()


func is_online() -> bool:
	return _active_peer and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_local_peer_id() -> int:
	if is_online():
		return multiplayer.get_unique_id()
	return 1


func get_peer_count() -> int:
	return connected_peers.size()


func _ready() -> void:
	var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--server" in all_args:
		# Throttle headless server to 60 FPS to avoid burning 100% CPU on idle loops
		Engine.max_fps = 60
		var port := _parse_arg_int("--port", DEFAULT_PORT)
		var err := host_server(port)
		if err == OK:
			print("[NetworkManager] Headless server started on port %d (max_fps=60)" % port)
			call_deferred("_load_server_scene")
		else:
			push_error("[NetworkManager] Failed to start headless server: %s" % error_string(err))


func _load_server_scene() -> void:
	print("[NetworkManager] Loading game world...")
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")


func _parse_arg_int(prefix: String, default_val: int) -> int:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return int(arg.split("=")[1])
	return default_val


func _process(delta: float) -> void:
	if not _active_peer:
		return
	# Client sends ping every PING_INTERVAL seconds
	if not multiplayer.is_server() and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_ping_timer += delta
		if _ping_timer >= PING_INTERVAL:
			_ping_timer = 0.0
			_ping_rpc.rpc_id(1, Time.get_ticks_msec())

		# Packet loss window — expects ~20 syncs/sec per remote player
		_loss_window_timer += delta
		var remote_count := maxi(connected_peers.size() - 1, 0)  # exclude self
		_expected_syncs += roundi(20.0 * remote_count * delta)  # 20Hz sync rate
		if _loss_window_timer >= LOSS_WINDOW:
			if _expected_syncs > 0:
				var received_ratio: float = float(_received_syncs) / float(_expected_syncs)
				local_packet_loss = clampf(1.0 - received_ratio, 0.0, 1.0)
			else:
				local_packet_loss = 0.0
			_expected_syncs = 0
			_received_syncs = 0
			_loss_window_timer = 0.0


@rpc("any_peer", "unreliable")
func _ping_rpc(client_time_msec: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	# Server also estimates peer RTT from its perspective (approximate)
	# Real RTT is measured client-side, but server needs an estimate for lag comp
	peer_rtt[sender_id] = peer_rtt.get(sender_id, 0.0)  # Updated by client report below
	_pong_rpc.rpc_id(sender_id, client_time_msec)


@rpc("authority", "unreliable")
func _pong_rpc(client_time_msec: int) -> void:
	local_rtt = float(Time.get_ticks_msec() - client_time_msec)
	# Jitter: track RTT history and compute stddev
	_rtt_history.append(local_rtt)
	while _rtt_history.size() > RTT_HISTORY_SIZE:
		_rtt_history.remove_at(0)
	local_jitter = _compute_stddev(_rtt_history)
	rtt_updated.emit(local_rtt)
	# Report RTT to server so it can use it for lag compensation
	_report_rtt.rpc_id(1, local_rtt)


@rpc("any_peer", "unreliable")
func _report_rtt(rtt_ms: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	peer_rtt[sender_id] = rtt_ms


func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)


func _on_peer_connected(id: int) -> void:
	connected_peers[id] = { "join_time": Time.get_ticks_msec() }
	player_connected.emit(id)
	print("[NetworkManager] Peer connected: %d (total: %d)" % [id, connected_peers.size()])


func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	peer_rtt.erase(id)
	player_disconnected.emit(id)
	print("[NetworkManager] Peer disconnected: %d (total: %d)" % [id, connected_peers.size()])


func _on_connected_to_server() -> void:
	connected_peers[multiplayer.get_unique_id()] = { "join_time": Time.get_ticks_msec() }
	connection_succeeded.emit()
	print("[NetworkManager] Connected to server as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	connection_failed.emit()
	push_warning("[NetworkManager] Connection failed")


## Called by NetworkSync when a sync packet arrives (for packet loss tracking).
func record_sync_received() -> void:
	_received_syncs += 1


func _compute_stddev(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var sum := 0.0
	for v in values:
		sum += v
	var mean := sum / float(values.size())
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	variance /= float(values.size())
	return sqrt(variance)
