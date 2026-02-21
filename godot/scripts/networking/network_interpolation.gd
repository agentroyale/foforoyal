class_name NetworkInterpolation
extends Node
## Snapshot interpolation buffer for smooth remote player rendering.
## Stores a circular buffer of position snapshots and renders with a fixed
## delay (RENDER_DELAY) behind real-time, interpolating between snapshots.
## Handles jitter, packet loss, and out-of-order delivery gracefully.

const BUFFER_SIZE := 8
const RENDER_DELAY_MS := 100.0  # 100ms = 2 ticks at 20Hz
const MAX_EXTRAPOLATION_MS := 200.0  # Max time to extrapolate if buffer starves
const SNAP_THRESHOLD := 10.0  # Teleport if distance exceeds this

var _buffer: Array = []  # Array of {time_ms, position, rotation_y, pitch}
var _initialized := false


func add_snapshot(time_ms: float, pos: Vector3, rot_y: float, pitch: float) -> void:
	var snapshot := {
		"time_ms": time_ms,
		"position": pos,
		"rotation_y": rot_y,
		"pitch": pitch,
	}

	# Insert sorted by time (usually appended at end)
	var last_snap: Dictionary = _buffer.back() as Dictionary if not _buffer.is_empty() else {}
	if _buffer.is_empty() or time_ms >= (last_snap["time_ms"] as float):
		_buffer.append(snapshot)
	else:
		# Out of order — find insertion point
		for i in range(_buffer.size()):
			var entry: Dictionary = _buffer[i] as Dictionary
			if time_ms < (entry["time_ms"] as float):
				_buffer.insert(i, snapshot)
				break

	# Trim to buffer size (remove oldest)
	while _buffer.size() > BUFFER_SIZE:
		_buffer.pop_front()

	_initialized = true


func _physics_process(delta: float) -> void:
	delta = minf(delta, 0.1)  # Delta cap
	var player := get_parent() as Node3D
	if not player or player.is_multiplayer_authority():
		return
	if not _initialized or _buffer.is_empty():
		return

	var now_ms := Time.get_ticks_msec() as float
	var render_time := now_ms - RENDER_DELAY_MS

	# Find the two snapshots bracketing render_time
	var from_idx := -1
	var to_idx := -1

	for i in range(_buffer.size() - 1):
		var s0: Dictionary = _buffer[i] as Dictionary
		var s1: Dictionary = _buffer[i + 1] as Dictionary
		if (s0["time_ms"] as float) <= render_time and (s1["time_ms"] as float) >= render_time:
			from_idx = i
			to_idx = i + 1
			break

	if from_idx >= 0 and to_idx >= 0:
		# Normal interpolation between two snapshots
		var snap_from: Dictionary = _buffer[from_idx] as Dictionary
		var snap_to: Dictionary = _buffer[to_idx] as Dictionary
		var t0: float = snap_from["time_ms"]
		var t1: float = snap_to["time_ms"]
		var t: float = (render_time - t0) / (t1 - t0) if t1 != t0 else 0.0
		t = clampf(t, 0.0, 1.0)

		var pos: Vector3 = (snap_from["position"] as Vector3).lerp(
			snap_to["position"], t)
		var rot_y: float = lerp_angle(snap_from["rotation_y"], snap_to["rotation_y"], t)
		var pitch: float = lerp_angle(snap_from["pitch"], snap_to["pitch"], t)

		_apply_state(player, pos, rot_y, pitch)
	elif render_time < (_buffer[0]["time_ms"] as float):
		# Render time is before all snapshots — use oldest
		var oldest: Dictionary = _buffer[0] as Dictionary
		_apply_state(player, oldest["position"], oldest["rotation_y"], oldest["pitch"])
	else:
		# Render time is after all snapshots — extrapolate from last two
		_extrapolate(player, render_time)


func _extrapolate(player: Node3D, render_time: float) -> void:
	var snap: Dictionary = _buffer.back() as Dictionary
	if _buffer.size() < 2:
		# Only one snapshot, snap to it
		_apply_state(player, snap["position"], snap["rotation_y"], snap["pitch"])
		return

	var last: Dictionary = _buffer.back() as Dictionary
	var prev: Dictionary = _buffer[_buffer.size() - 2] as Dictionary
	var last_time: float = last["time_ms"]
	var prev_time: float = prev["time_ms"]
	var dt: float = last_time - prev_time
	var overshoot: float = render_time - last_time

	# Clamp extrapolation
	if overshoot > MAX_EXTRAPOLATION_MS or dt <= 0.0:
		_apply_state(player, last["position"], last["rotation_y"], last["pitch"])
		return

	var factor: float = overshoot / dt
	var vel: Vector3 = (last["position"] as Vector3) - (prev["position"] as Vector3)
	var pos: Vector3 = (last["position"] as Vector3) + vel * factor
	var rot_y: float = last["rotation_y"]
	var pitch: float = last["pitch"]

	_apply_state(player, pos, rot_y, pitch)


func get_buffer_size() -> int:
	return _buffer.size()


func _apply_state(player: Node3D, pos: Vector3, rot_y: float, pitch: float) -> void:
	# Snap if too far (teleport)
	if player.global_position.distance_to(pos) > SNAP_THRESHOLD:
		player.global_position = pos
	else:
		player.global_position = pos

	player.rotation.y = rot_y

	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot:
		pivot.rotation.x = pitch
