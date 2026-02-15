class_name BuildingPiece
extends StaticBody3D
## Base class for all placed building pieces.
## Manages tier, HP, damage sides, and sockets.

signal piece_destroyed(piece: BuildingPiece)
signal piece_upgraded(piece: BuildingPiece, new_tier: BuildingTier.Tier)
signal stability_changed(piece: BuildingPiece, new_stability: float)

@export var piece_data: BuildingPieceData

var current_tier: BuildingTier.Tier = BuildingTier.Tier.TWIG
var current_hp: float = 10.0
var max_hp: float = 10.0
var stability: float = 1.0
var support_parent_socket: BuildingSocket = null

const SOFT_SIDE_MULTIPLIER := 2.0
const HARD_SIDE_MULTIPLIER := 1.0

## Forward direction for soft/hard side detection.
## Soft side = hit from behind (dot > 0). Hard side = hit from front (dot <= 0).
var forward_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	_apply_tier(current_tier)
	add_to_group("building_pieces")
	add_to_group("network_synced")


func _apply_tier(tier: BuildingTier.Tier) -> void:
	current_tier = tier
	max_hp = BuildingTier.get_max_hp(tier)
	current_hp = max_hp


func get_damage_multiplier(hit_direction: Vector3) -> float:
	var dot := forward_direction.dot(hit_direction.normalized())
	if dot > 0.0:
		return SOFT_SIDE_MULTIPLIER
	return HARD_SIDE_MULTIPLIER


func take_damage(amount: float, hit_direction: Vector3 = Vector3.ZERO) -> void:
	# In multiplayer, only server processes building damage
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var mult := get_damage_multiplier(hit_direction) if hit_direction != Vector3.ZERO else 1.0
	current_hp -= amount * mult
	if current_hp <= 0.0:
		_destroy()


func upgrade() -> bool:
	if BuildingTier.is_max_tier(current_tier):
		return false
	var new_tier := BuildingTier.get_next_tier(current_tier)
	_apply_tier(new_tier)
	piece_upgraded.emit(self, new_tier)
	if Engine.has_singleton("SFXGenerator") or get_node_or_null("/root/SFXGenerator"):
		var sfx := get_node_or_null("/root/SFXGenerator")
		if sfx:
			sfx.play_upgrade(new_tier, global_position)
	return true


func _destroy() -> void:
	var children := get_supported_children()
	piece_destroyed.emit(self)
	for child in get_children():
		if child is BuildingSocket:
			child.vacate()
	queue_free()
	BuildingStability.on_piece_destroyed(children)


func get_support_parent() -> BuildingPiece:
	if support_parent_socket and is_instance_valid(support_parent_socket):
		var owner_piece := support_parent_socket.get_parent()
		if owner_piece is BuildingPiece:
			return owner_piece as BuildingPiece
	return null


func get_supported_children() -> Array[BuildingPiece]:
	var children: Array[BuildingPiece] = []
	for child in get_children():
		if child is BuildingSocket and child.is_occupied and is_instance_valid(child.occupying_piece):
			if child.occupying_piece is BuildingPiece:
				children.append(child.occupying_piece as BuildingPiece)
	return children


func get_sockets() -> Array[BuildingSocket]:
	var sockets: Array[BuildingSocket] = []
	for child in get_children():
		if child is BuildingSocket:
			sockets.append(child)
	return sockets


func interact(player: Node3D) -> void:
	upgrade()
