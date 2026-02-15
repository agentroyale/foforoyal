class_name BuildingStability
extends RefCounted
## Structural stability system for building pieces.
## All methods are static — no instance needed.

const MIN_STABILITY := 0.05

## Transfer multipliers per PieceType (Rust-style).
const TRANSFER_MULTIPLIERS := {
	BuildingPieceData.PieceType.FOUNDATION: 1.0,
	BuildingPieceData.PieceType.TRIANGLE_FOUNDATION: 1.0,
	BuildingPieceData.PieceType.WALL: 0.86,
	BuildingPieceData.PieceType.DOORWAY: 0.70,
	BuildingPieceData.PieceType.WINDOW_FRAME: 0.70,
	BuildingPieceData.PieceType.WALL_ARCHED: 0.70,
	BuildingPieceData.PieceType.WALL_GATED: 0.70,
	BuildingPieceData.PieceType.WALL_WINDOW_ARCHED: 0.70,
	BuildingPieceData.PieceType.WALL_WINDOW_CLOSED: 0.70,
	BuildingPieceData.PieceType.PILLAR: 0.90,
	BuildingPieceData.PieceType.HALF_WALL: 0.50,
	BuildingPieceData.PieceType.FLOOR: 0.80,
	BuildingPieceData.PieceType.CEILING: 0.80,
	BuildingPieceData.PieceType.FLOOR_WOOD: 0.80,
	BuildingPieceData.PieceType.STAIRS: 0.80,
	BuildingPieceData.PieceType.ROOF: 0.80,
	BuildingPieceData.PieceType.DOOR: 1.0,
}


static func is_foundation(piece: BuildingPiece) -> bool:
	if not piece.piece_data:
		return false
	return piece.piece_data.piece_type in [
		BuildingPieceData.PieceType.FOUNDATION,
		BuildingPieceData.PieceType.TRIANGLE_FOUNDATION,
	]


static func get_transfer_multiplier(piece: BuildingPiece) -> float:
	if not piece.piece_data:
		return 0.80
	return TRANSFER_MULTIPLIERS.get(piece.piece_data.piece_type, 0.80)


static func calculate_stability(piece: BuildingPiece) -> void:
	if is_foundation(piece):
		piece.stability = 1.0
		piece.stability_changed.emit(piece, 1.0)
		return

	var parent := piece.get_support_parent()
	if parent:
		var new_stability := parent.stability * get_transfer_multiplier(piece)
		if new_stability < MIN_STABILITY:
			piece.stability = 0.0
			piece.stability_changed.emit(piece, 0.0)
			piece._destroy()
			return
		piece.stability = new_stability
		piece.stability_changed.emit(piece, new_stability)
	else:
		piece.stability = get_transfer_multiplier(piece)
		piece.stability_changed.emit(piece, piece.stability)


static func on_piece_destroyed(orphaned_children: Array[BuildingPiece]) -> void:
	for child in orphaned_children:
		if not is_instance_valid(child):
			continue
		if is_foundation(child):
			continue
		# Parent was destroyed — cascade collapse
		child._destroy()
