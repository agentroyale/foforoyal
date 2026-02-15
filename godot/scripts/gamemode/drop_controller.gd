extends Node
## Controls the BR drop sequence: flight path traversal + player jump/parachute.

signal drop_started(path: Dictionary)
signal player_jumped(peer_id: int)
signal player_landed(peer_id: int)
signal all_players_landed()

const FLIGHT_SPEED := 60.0  # m/s along path

var _path: Dictionary = {}
var _progress: float = 0.0
var _active: bool = false
var _players_in_flight: Dictionary = {}  # peer_id -> true (still on plane)
var _players_jumping: Dictionary = {}  # peer_id -> true (in air)
var _players_landed: Dictionary = {}  # peer_id -> true


func start_drop(map_size: float, seed_val: int) -> void:
	_path = FlightPath.generate_path(map_size, seed_val)
	_progress = 0.0
	_active = true
	_players_in_flight.clear()
	_players_jumping.clear()
	_players_landed.clear()
	# All alive players start on the plane
	for peer_id in MatchManager.alive_players:
		_players_in_flight[peer_id] = true
	drop_started.emit(_path)


func _process(delta: float) -> void:
	if not _active:
		return
	if _path.is_empty():
		return
	_progress += (FLIGHT_SPEED * delta) / _path["length"]
	_progress = clampf(_progress, 0.0, 1.0)
	# Move players still on the plane
	var flight_pos := FlightPath.get_position_at_progress(_path["start"], _path["end"], _progress)
	for peer_id in _players_in_flight:
		var player := _get_player(peer_id)
		if player:
			player.global_position = flight_pos
			player.velocity = Vector3.ZERO
	# Auto-eject at end of path
	if _progress >= 1.0:
		var remaining := _players_in_flight.keys().duplicate()
		for peer_id in remaining:
			_do_jump(peer_id)
	# Check if all landed
	if _players_in_flight.is_empty() and _players_jumping.is_empty() and not _players_landed.is_empty():
		_active = false
		all_players_landed.emit()
		MatchManager.notify_all_landed()


func request_jump(peer_id: int) -> void:
	if not _active:
		return
	if not _players_in_flight.has(peer_id):
		return
	_do_jump(peer_id)


func notify_landed(peer_id: int) -> void:
	if _players_jumping.has(peer_id):
		_players_jumping.erase(peer_id)
		_players_landed[peer_id] = true
		player_landed.emit(peer_id)


func is_active() -> bool:
	return _active


func is_player_in_flight(peer_id: int) -> bool:
	return _players_in_flight.has(peer_id)


func get_flight_progress() -> float:
	return _progress


func _do_jump(peer_id: int) -> void:
	_players_in_flight.erase(peer_id)
	_players_jumping[peer_id] = true
	player_jumped.emit(peer_id)
	# Enable parachute on the player
	var player := _get_player(peer_id)
	if player:
		var pc := player.get_node_or_null("ParachuteController")
		if pc and pc.has_method("start_drop"):
			pc.start_drop()


func _get_player(peer_id: int) -> CharacterBody3D:
	var container := get_tree().current_scene.get_node_or_null("Players")
	if container:
		var node := container.get_node_or_null(str(peer_id))
		if node:
			return node as CharacterBody3D
	# Singleplayer fallback
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player:
		return player as CharacterBody3D
	return null


# === RPCs ===

@rpc("any_peer", "reliable")
func _request_jump_rpc() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	request_jump(sender)
