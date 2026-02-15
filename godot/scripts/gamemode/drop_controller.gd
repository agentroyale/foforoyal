extends Node
## Controls the BR drop sequence: flight path traversal + player jump/parachute.
## Spawns a visual airplane that flies across the map.

signal drop_started(path: Dictionary)
signal player_jumped(peer_id: int)
signal player_landed(peer_id: int)
signal all_players_landed()

const FLIGHT_SPEED := 60.0  # m/s along path
const PLANE_SCENE_PATH := "res://scenes/gamemode/drop_plane.tscn"

var _path: Dictionary = {}
var _progress: float = 0.0
var _active: bool = false
var _players_in_flight: Dictionary = {}  # peer_id -> true (still on plane)
var _players_jumping: Dictionary = {}  # peer_id -> true (in air)
var _players_landed: Dictionary = {}  # peer_id -> true
var _plane_visual: Node3D = null
var _jump_prompt_label: Label = null


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
	_spawn_plane()
	_show_jump_prompt()
	drop_started.emit(_path)


func _process(delta: float) -> void:
	if not _active:
		return
	if _path.is_empty():
		return
	_progress += (FLIGHT_SPEED * delta) / _path["length"]
	_progress = clampf(_progress, 0.0, 1.0)
	# Move plane + players still on it
	var flight_pos := FlightPath.get_position_at_progress(_path["start"], _path["end"], _progress)
	if _plane_visual:
		_plane_visual.global_position = flight_pos
		# Orient plane in flight direction
		var dir: Vector3 = _path["direction"]
		_plane_visual.look_at(flight_pos + dir, Vector3.UP)
	for peer_id in _players_in_flight:
		var player := _get_player(peer_id)
		if player:
			player.global_position = flight_pos + Vector3(0, -2, 0)
			player.velocity = Vector3.ZERO
	# Auto-eject at end of path
	if _progress >= 1.0:
		var remaining := _players_in_flight.keys().duplicate()
		for peer_id in remaining:
			_do_jump(peer_id)
	# Check if all landed
	if _players_in_flight.is_empty() and _players_jumping.is_empty() and not _players_landed.is_empty():
		_finish_drop()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("jump"):
		# Local player wants to jump
		var local_id := 1
		if multiplayer.has_multiplayer_peer():
			local_id = multiplayer.get_unique_id()
		if _players_in_flight.has(local_id):
			request_jump(local_id)


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
	# Check completion after landing
	if _players_in_flight.is_empty() and _players_jumping.is_empty() and not _players_landed.is_empty():
		_finish_drop()


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
	_hide_jump_prompt()
	# Enable parachute on the player
	var player := _get_player(peer_id)
	if player:
		var pc := player.get_node_or_null("ParachuteController")
		if pc and pc.has_method("start_drop"):
			pc.start_drop()


func _finish_drop() -> void:
	_active = false
	# Remove plane visual
	if _plane_visual:
		_plane_visual.queue_free()
		_plane_visual = null
	_hide_jump_prompt()
	all_players_landed.emit()
	MatchManager.notify_all_landed()


func _spawn_plane() -> void:
	var scene := load(PLANE_SCENE_PATH) as PackedScene
	if scene:
		_plane_visual = scene.instantiate()
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(_plane_visual)


func _show_jump_prompt() -> void:
	# Show "Press SPACE to jump" on a CanvasLayer
	var canvas := CanvasLayer.new()
	canvas.name = "JumpPromptLayer"
	canvas.layer = 8
	_jump_prompt_label = Label.new()
	_jump_prompt_label.text = "Aperte SPACE para pular!"
	_jump_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_jump_prompt_label.offset_left = -200.0
	_jump_prompt_label.offset_right = 200.0
	_jump_prompt_label.offset_top = 120.0
	_jump_prompt_label.offset_bottom = 160.0
	_jump_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jump_prompt_label.add_theme_font_size_override("font_size", 28)
	_jump_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_jump_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_jump_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_jump_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_jump_prompt_label)
	add_child(canvas)


func _hide_jump_prompt() -> void:
	var canvas := get_node_or_null("JumpPromptLayer")
	if canvas:
		canvas.queue_free()
	_jump_prompt_label = null


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
