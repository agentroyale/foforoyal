extends Node
## Autoload singleton managing all placed building pieces.
## Provides spatial queries, overlap detection, and socket lookup.

signal piece_placed(piece: BuildingPiece)
signal piece_removed(piece: BuildingPiece)

const SOCKET_SNAP_DISTANCE := 5.0
const OVERLAP_CHECK_RADIUS := 0.3

var placed_pieces: Array[BuildingPiece] = []


func register_piece(piece: BuildingPiece) -> void:
	placed_pieces.append(piece)
	piece.piece_destroyed.connect(_on_piece_destroyed)
	BuildingStability.calculate_stability(piece)
	piece_placed.emit(piece)


func _on_piece_destroyed(piece: BuildingPiece) -> void:
	placed_pieces.erase(piece)
	var sfx := get_node_or_null("/root/SFXGenerator")
	if sfx:
		sfx.play_destroy(piece.current_tier, piece.global_position)
	piece_removed.emit(piece)


func find_best_socket(world_position: Vector3, piece_type: BuildingPieceData.PieceType) -> BuildingSocket:
	var best_socket: BuildingSocket = null
	var best_dist := SOCKET_SNAP_DISTANCE
	for piece in placed_pieces:
		for socket in piece.get_sockets():
			if not socket.can_accept(piece_type):
				continue
			var dist := socket.global_position.distance_to(world_position)
			if dist < best_dist:
				best_dist = dist
				best_socket = socket
	return best_socket


func check_overlap(position: Vector3, piece_type: BuildingPieceData.PieceType) -> bool:
	for piece in placed_pieces:
		if piece.global_position.distance_to(position) < OVERLAP_CHECK_RADIUS:
			if piece.piece_data and piece.piece_data.piece_type == piece_type:
				return true
	return false


func get_piece_count() -> int:
	return placed_pieces.size()


# ─── Multiplayer RPCs ───

@rpc("any_peer", "reliable")
func request_place_piece(piece_data_path: String, pos: Vector3, rot: Vector3, player_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != player_id:
		return

	var piece_data := load(piece_data_path) as BuildingPieceData
	if not piece_data or not piece_data.piece_scene:
		return

	# Validate: no overlap
	if check_overlap(pos, piece_data.piece_type):
		return

	# Validate: building privilege
	if not BuildingPrivilege.can_build(get_tree(), pos, sender_id):
		return

	# Validate: range from player
	var player_node := _find_player_node(sender_id)
	if player_node and not ServerValidation.validate_placement(player_node.global_position, pos):
		return

	# Spawn the piece (will be synced via MultiplayerSpawner)
	var instance := piece_data.piece_scene.instantiate() as BuildingPiece
	instance.piece_data = piece_data
	instance.global_position = pos
	instance.global_rotation = rot
	get_tree().current_scene.add_child(instance)

	# Find and set support socket for stability
	var best_socket := find_best_socket(pos, piece_data.piece_type)
	if best_socket:
		best_socket.occupy(instance)
		instance.support_parent_socket = best_socket

	register_piece(instance)


@rpc("any_peer", "reliable")
func request_demolish_piece(piece_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var piece := get_node_or_null(piece_path) as BuildingPiece
	if not piece:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not BuildingPrivilege.can_build(get_tree(), piece.global_position, sender_id):
		return
	piece.take_damage(piece.max_hp * 10.0)  # Overkill to destroy


func _find_player_node(peer_id: int) -> Node3D:
	var players := get_tree().get_nodes_in_group("players")
	for p in players:
		if p.get_multiplayer_authority() == peer_id:
			return p as Node3D
	return null
