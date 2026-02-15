extends Node
## Autoload singleton managing ENet multiplayer peer lifecycle.
## Handles server hosting, client joining, and peer tracking.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_started()

const DEFAULT_PORT := 27015
const MAX_CLIENTS := 64

# ENet bandwidth limits (bytes/sec). 0 = unlimited.
const SERVER_OUT_BANDWIDTH := 256 * 1024  # 256 KB/s outbound
const SERVER_IN_BANDWIDTH := 128 * 1024   # 128 KB/s inbound
const CLIENT_OUT_BANDWIDTH := 32 * 1024   # 32 KB/s outbound (clients send little)
const CLIENT_IN_BANDWIDTH := 256 * 1024   # 256 KB/s inbound

var connected_peers: Dictionary = {}  # peer_id -> { "join_time": int }
var _active_peer: bool = false  # Tracks whether we explicitly set a peer


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
	if "--server" in OS.get_cmdline_args():
		var err := host_server()
		if err == OK:
			print("[NetworkManager] Headless server started on port %d" % DEFAULT_PORT)
		else:
			push_error("[NetworkManager] Failed to start headless server: %s" % error_string(err))


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
	player_disconnected.emit(id)
	print("[NetworkManager] Peer disconnected: %d (total: %d)" % [id, connected_peers.size()])


func _on_connected_to_server() -> void:
	connected_peers[multiplayer.get_unique_id()] = { "join_time": Time.get_ticks_msec() }
	connection_succeeded.emit()
	print("[NetworkManager] Connected to server as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	connection_failed.emit()
	push_warning("[NetworkManager] Connection failed")
