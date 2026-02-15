class_name BuildingSocket
extends Marker3D
## Snap point on a building piece where other pieces can attach.
## Socket's local -Z axis points "outward" from the parent piece.

enum SocketType {
	FOUNDATION_TOP,
	WALL_BOTTOM,
	WALL_TOP,
	FLOOR_EDGE,
	DOORWAY,
	FOUNDATION_SIDE,
	STAIRS_BOTTOM,
	STAIRS_TOP,
	ROOF_BOTTOM,
}

@export var socket_type: SocketType = SocketType.WALL_BOTTOM
@export var allowed_pieces: Array[BuildingPieceData.PieceType] = []

var is_occupied: bool = false
var occupying_piece: Node3D = null


func can_accept(piece_type: BuildingPieceData.PieceType) -> bool:
	return not is_occupied and piece_type in allowed_pieces


func occupy(piece: Node3D) -> void:
	is_occupied = true
	occupying_piece = piece


func vacate() -> void:
	is_occupied = false
	occupying_piece = null
