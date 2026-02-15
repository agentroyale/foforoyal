class_name ClientPrediction
extends RefCounted
## Client-side movement prediction with server reconciliation.
## Records input snapshots and replays unacknowledged inputs on correction.

const BUFFER_SIZE := 64
const CORRECTION_THRESHOLD := 0.1

var _input_buffer: Array[Dictionary] = []
var _sequence: int = 0
var _last_server_sequence: int = -1


func record_input(direction: Vector2, jump: bool, sprint: bool, crouch: bool) -> int:
	var input := {
		"sequence": _sequence,
		"direction": direction,
		"jump": jump,
		"sprint": sprint,
		"crouch": crouch,
	}
	_input_buffer.append(input)
	if _input_buffer.size() > BUFFER_SIZE:
		_input_buffer.pop_front()
	_sequence += 1
	return input["sequence"]


func get_sequence() -> int:
	return _sequence


func get_buffer_size() -> int:
	return _input_buffer.size()


func reconcile(server_position: Vector3, server_sequence: int) -> Dictionary:
	## Compares server state with predicted state.
	## Returns {"needs_correction": bool, "server_position": Vector3, "pending_inputs": Array}
	_last_server_sequence = server_sequence

	# Remove acknowledged inputs
	while _input_buffer.size() > 0 and _input_buffer[0]["sequence"] <= server_sequence:
		_input_buffer.pop_front()

	return {
		"needs_correction": true,
		"server_position": server_position,
		"pending_inputs": _input_buffer.duplicate(),
	}


static func needs_correction(client_pos: Vector3, server_pos: Vector3) -> bool:
	return client_pos.distance_to(server_pos) > CORRECTION_THRESHOLD


static func input_to_dict(direction: Vector2, jump: bool, sprint: bool, crouch: bool) -> Dictionary:
	return {
		"direction": direction,
		"jump": jump,
		"sprint": sprint,
		"crouch": crouch,
	}
