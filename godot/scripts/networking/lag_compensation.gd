class_name LagCompensation
extends RefCounted
## Stores position history for all players. Server uses this to rewind
## player positions when validating hit detection.

const HISTORY_DURATION := 1.0
const MAX_SNAPSHOTS := 64

var _position_history: Dictionary = {}  # peer_id -> Array[Dictionary]


func record_snapshot(peer_id: int, position: Vector3, rotation_y: float) -> void:
	if peer_id not in _position_history:
		_position_history[peer_id] = []
	var history: Array = _position_history[peer_id]
	history.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"position": position,
		"rotation_y": rotation_y,
	})
	while history.size() > MAX_SNAPSHOTS:
		history.pop_front()


func get_position_at_time(peer_id: int, timestamp: float) -> Dictionary:
	if peer_id not in _position_history:
		return {}
	var history: Array = _position_history[peer_id]
	if history.is_empty():
		return {}

	# Find two snapshots bracketing the timestamp and interpolate
	for i in range(history.size() - 1):
		var t0: float = history[i]["time"]
		var t1: float = history[i + 1]["time"]
		if t0 <= timestamp and t1 >= timestamp:
			var t := (timestamp - t0) / (t1 - t0) if t1 != t0 else 0.0
			return {
				"position": (history[i]["position"] as Vector3).lerp(
					history[i + 1]["position"], t
				),
				"rotation_y": lerp_angle(
					history[i]["rotation_y"], history[i + 1]["rotation_y"], t
				),
			}

	# If timestamp is after all snapshots, return latest
	return history.back()


func get_snapshot_count(peer_id: int) -> int:
	if peer_id not in _position_history:
		return 0
	return (_position_history[peer_id] as Array).size()


func clear_peer(peer_id: int) -> void:
	_position_history.erase(peer_id)


func clear_all() -> void:
	_position_history.clear()
