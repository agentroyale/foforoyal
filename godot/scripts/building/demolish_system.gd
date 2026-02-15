class_name DemolishSystem
extends Node
## Hold E for DEMOLISH_TIME seconds on a building piece to demolish it.
## Requires building privilege (TC auth).

signal demolish_started(piece: BuildingPiece)
signal demolish_progress(progress: float)
signal demolish_cancelled()
signal demolish_completed(piece: BuildingPiece)

const DEMOLISH_TIME := 10.0

var _target_piece: BuildingPiece = null
var _hold_timer: float = 0.0
var _is_demolishing: bool = false
var _player_id: int = 0


func start_demolish(piece: BuildingPiece, player_id: int) -> bool:
	if not piece:
		return false

	# Check building privilege
	if not BuildingPrivilege.can_build(get_tree(), piece.global_position, player_id):
		return false

	_target_piece = piece
	_player_id = player_id
	_hold_timer = 0.0
	_is_demolishing = true
	demolish_started.emit(piece)
	return true


func cancel_demolish() -> void:
	if _is_demolishing:
		_is_demolishing = false
		_target_piece = null
		_hold_timer = 0.0
		demolish_cancelled.emit()


func _process(delta: float) -> void:
	if not _is_demolishing:
		return

	if not is_instance_valid(_target_piece):
		cancel_demolish()
		return

	_hold_timer += delta
	demolish_progress.emit(_hold_timer / DEMOLISH_TIME)

	if _hold_timer >= DEMOLISH_TIME:
		_complete_demolish()


func _complete_demolish() -> void:
	var piece := _target_piece
	_is_demolishing = false
	_target_piece = null
	_hold_timer = 0.0

	if is_instance_valid(piece):
		demolish_completed.emit(piece)
		piece.queue_free()


func is_demolishing() -> bool:
	return _is_demolishing


func get_progress() -> float:
	if not _is_demolishing:
		return 0.0
	return _hold_timer / DEMOLISH_TIME
