class_name ClientPrediction
extends RefCounted
## Client-side movement prediction with server reconciliation.
## Records input + state snapshots in ring buffers.
## On server snapshot, returns pending inputs for replay.

const BUFFER_SIZE := 128
const CORRECTION_THRESHOLD := 0.05  # 5cm — any error above this corrects
const SMOOTH_THRESHOLD := 2.0       # below this: visual blend smooth
const SNAP_THRESHOLD := 5.0         # above this: hard teleport

var _input_buffer: Array[Dictionary] = []
var _state_buffer: Array[Dictionary] = []
var _sequence: int = 0
var _last_acked_seq: int = -1

# Stats for debug HUD
var last_correction_error: float = 0.0
var correction_count: int = 0


func record_input(input: Dictionary, state_after: Dictionary) -> int:
	## Store an input + the resulting predicted state. Returns the sequence number.
	var seq := _sequence
	var inp := input.duplicate()
	inp["sequence"] = seq
	var st := state_after.duplicate()
	st["sequence"] = seq
	_input_buffer.append(inp)
	_state_buffer.append(st)
	# Trim old entries
	while _input_buffer.size() > BUFFER_SIZE:
		_input_buffer.pop_front()
		_state_buffer.pop_front()
	_sequence += 1
	return seq


func reconcile(server_pos: Vector3, server_vel_y: float, server_seq: int,
		server_is_crouching: bool) -> Dictionary:
	## Compare server state against predicted state for server_seq.
	## Returns {needs_correction, error_magnitude, correction_offset,
	##          server_position, server_velocity_y, server_is_crouching,
	##          pending_inputs}.
	_last_acked_seq = server_seq

	# Find predicted state for this sequence
	var predicted_pos := Vector3.ZERO
	var found := false
	var trim_to := -1
	for i in _state_buffer.size():
		if _state_buffer[i]["sequence"] == server_seq:
			predicted_pos = _state_buffer[i]["position"]
			found = true
			trim_to = i
			break

	# Remove acknowledged entries
	if trim_to >= 0:
		_input_buffer = _input_buffer.slice(trim_to + 1)
		_state_buffer = _state_buffer.slice(trim_to + 1)

	if not found:
		return {"needs_correction": false, "error_magnitude": 0.0,
				"correction_offset": Vector3.ZERO, "pending_inputs": []}

	var error := server_pos.distance_to(predicted_pos)
	if error < CORRECTION_THRESHOLD:
		return {"needs_correction": false, "error_magnitude": error,
				"correction_offset": Vector3.ZERO, "pending_inputs": []}

	# Track stats
	last_correction_error = error
	correction_count += 1

	# Collect pending inputs for replay
	var pending: Array[Dictionary] = []
	for inp in _input_buffer:
		pending.append(inp)

	return {
		"needs_correction": true,
		"error_magnitude": error,
		"correction_offset": server_pos - predicted_pos,
		"server_position": server_pos,
		"server_velocity_y": server_vel_y,
		"server_is_crouching": server_is_crouching,
		"pending_inputs": pending,
	}


func get_sequence() -> int:
	return _sequence


func get_pending_count() -> int:
	return _input_buffer.size()


## Convenience for tests: returns current buffer size.
func get_buffer_size() -> int:
	return _input_buffer.size()
