extends Node
## Manages spawning/despawning player scenes when peers connect/disconnect.
## Attach to the main scene. Requires a "Players" sibling node as container.

@export var player_scene: PackedScene

var _spawn_points: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(5, 1, 5),
	Vector3(-5, 1, -5),
	Vector3(10, 1, 0),
]


func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	if multiplayer.is_server():
		_spawn_player(1)
		for peer_id in NetworkManager.connected_peers:
			if peer_id != 1:
				_spawn_player(peer_id)


func _on_player_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_despawn_player(peer_id)


func _spawn_player(peer_id: int) -> void:
	var container := get_node_or_null("../Players")
	if not container:
		push_error("[PlayerSpawner] No 'Players' container node found")
		return
	if container.has_node(str(peer_id)):
		return
	if not player_scene:
		push_error("[PlayerSpawner] No player_scene assigned")
		return

	var player := player_scene.instantiate()
	player.name = str(peer_id)
	container.add_child(player, true)
	player.set_multiplayer_authority(peer_id)
	player.global_position = _get_spawn_position(peer_id)
	print("[PlayerSpawner] Spawned player for peer %d" % peer_id)


func _despawn_player(peer_id: int) -> void:
	var container := get_node_or_null("../Players")
	if not container:
		return
	var player_node := container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
		print("[PlayerSpawner] Despawned player for peer %d" % peer_id)


func _get_spawn_position(peer_id: int) -> Vector3:
	# In BR mode, spawn in lobby area
	if MatchManager.is_br_mode():
		var lobby := get_tree().current_scene.get_node_or_null("LobbyArea")
		if lobby and lobby.has_method("get_spawn_position"):
			var idx := MatchManager.alive_players.size()
			return lobby.get_spawn_position(idx)
	# Spawn near map center where terrain actually exists
	var center := float(WorldGenerator.MAP_SIZE) / 2.0
	var offset_x := float((peer_id * 7) % 20) - 10.0
	var offset_z := float((peer_id * 13) % 20) - 10.0
	var x := center + 16.0 + offset_x
	var z := center + 16.0 + offset_z
	var height := WorldGenerator.get_height_at(x, z)
	var safe_y := maxf(height, 0.0) + 2.0
	return Vector3(x, safe_y, z)
