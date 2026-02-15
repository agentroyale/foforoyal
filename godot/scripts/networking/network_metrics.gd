extends Node
## Autoload: Server-side telemetry for network performance monitoring.
## Tracks RPC count, estimated bytes, sync ticks, and interest grid rebuilds.
## Logs a summary every LOG_INTERVAL seconds.

const LOG_INTERVAL := 5.0

var _rpc_count: int = 0
var _bytes_sent: int = 0
var _sync_ticks: int = 0
var _grid_rebuilds: int = 0
var _grid_rebuild_time_total: float = 0.0
var _log_timer: float = 0.0

# Exposed for tests
var total_rpc_count: int = 0
var total_bytes_sent: int = 0
var total_grid_rebuilds: int = 0


func _physics_process(delta: float) -> void:
	if not _is_server():
		return

	_log_timer += delta
	if _log_timer >= LOG_INTERVAL:
		_print_summary()
		_log_timer = 0.0


func record_rpc(estimated_bytes: int = 0) -> void:
	_rpc_count += 1
	_bytes_sent += estimated_bytes
	total_rpc_count += 1
	total_bytes_sent += estimated_bytes


func record_sync_tick() -> void:
	_sync_ticks += 1


func record_grid_rebuild(duration_ms: float = 0.0) -> void:
	_grid_rebuilds += 1
	_grid_rebuild_time_total += duration_ms
	total_grid_rebuilds += 1


func reset_counters() -> void:
	_rpc_count = 0
	_bytes_sent = 0
	_sync_ticks = 0
	_grid_rebuilds = 0
	_grid_rebuild_time_total = 0.0
	total_rpc_count = 0
	total_bytes_sent = 0
	total_grid_rebuilds = 0
	_log_timer = 0.0


func get_rpc_per_second() -> float:
	if LOG_INTERVAL > 0:
		return float(_rpc_count) / LOG_INTERVAL
	return 0.0


func get_kb_per_second() -> float:
	if LOG_INTERVAL > 0:
		return float(_bytes_sent) / 1024.0 / LOG_INTERVAL
	return 0.0


func _print_summary() -> void:
	var peer_count := NetworkManager.get_peer_count() if NetworkManager else 0
	var rpc_s := get_rpc_per_second()
	var kb_s := get_kb_per_second()
	var avg_rebuild := 0.0
	if _grid_rebuilds > 0:
		avg_rebuild = _grid_rebuild_time_total / float(_grid_rebuilds)

	print("[NetworkMetrics] peers=%d | %.1f KB/s | %.0f RPC/s | %d syncs | %d rebuilds (avg %.2fms)" % [
		peer_count, kb_s, rpc_s, _sync_ticks, _grid_rebuilds, avg_rebuild
	])

	# Reset interval counters (keep totals)
	_rpc_count = 0
	_bytes_sent = 0
	_sync_ticks = 0
	_grid_rebuilds = 0
	_grid_rebuild_time_total = 0.0


func _is_server() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server()
