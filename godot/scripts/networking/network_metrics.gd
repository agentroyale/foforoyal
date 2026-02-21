extends Node
## Autoload: Network and performance telemetry.
## Server: tracks RPC count, bytes, sync ticks, grid rebuilds. Logs every 5s.
## Client: tracks RTT, jitter, packet loss, FPS, physics time. Writes CSV log.
## CSV log path: user://perf_log.csv (append mode, one row per LOG_INTERVAL).

const LOG_INTERVAL := 5.0
const CSV_PATH := "user://perf_log.csv"

var _rpc_count: int = 0
var _bytes_sent: int = 0
var _sync_ticks: int = 0
var _grid_rebuilds: int = 0
var _grid_rebuild_time_total: float = 0.0
var _log_timer: float = 0.0
var _csv_file: FileAccess = null

# Exposed for tests
var total_rpc_count: int = 0
var total_bytes_sent: int = 0
var total_grid_rebuilds: int = 0

# Client-side frame time tracking
var _frame_count: int = 0
var _physics_time_sum: float = 0.0
var _min_fps: int = 9999
var _max_physics_ms: float = 0.0


func _ready() -> void:
	# Open CSV in append mode — survives across sessions
	_csv_file = FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if _csv_file:
		_csv_file.store_line("timestamp,role,fps,min_fps,physics_ms,max_physics_ms,rtt_ms,jitter_ms,loss_pct,peers,rpc_s,kb_s,syncs,rebuilds,memory_mb")
		_csv_file.flush()


func _physics_process(delta: float) -> void:
	_log_timer += delta
	_frame_count += 1
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_physics_time_sum += phys_ms
	_max_physics_ms = maxf(_max_physics_ms, phys_ms)
	var fps := Engine.get_frames_per_second()
	_min_fps = mini(_min_fps, fps)

	if _log_timer >= LOG_INTERVAL:
		if _is_server():
			_print_server_summary()
		_write_csv_row()
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
	_frame_count = 0
	_physics_time_sum = 0.0
	_min_fps = 9999
	_max_physics_ms = 0.0


func get_rpc_per_second() -> float:
	if LOG_INTERVAL > 0:
		return float(_rpc_count) / LOG_INTERVAL
	return 0.0


func get_kb_per_second() -> float:
	if LOG_INTERVAL > 0:
		return float(_bytes_sent) / 1024.0 / LOG_INTERVAL
	return 0.0


func _print_server_summary() -> void:
	var peer_count := NetworkManager.get_peer_count() if NetworkManager else 0
	var rpc_s := get_rpc_per_second()
	var kb_s := get_kb_per_second()
	var avg_rebuild := 0.0
	if _grid_rebuilds > 0:
		avg_rebuild = _grid_rebuild_time_total / float(_grid_rebuilds)

	print("[NetworkMetrics] peers=%d | %.1f KB/s | %.0f RPC/s | %d syncs | %d rebuilds (avg %.2fms)" % [
		peer_count, kb_s, rpc_s, _sync_ticks, _grid_rebuilds, avg_rebuild
	])


func _write_csv_row() -> void:
	if not _csv_file:
		# Try reopening in append mode
		_csv_file = FileAccess.open(CSV_PATH, FileAccess.READ_WRITE)
		if _csv_file:
			_csv_file.seek_end()
		else:
			return

	var role := "server" if _is_server() else "client"
	var avg_fps := Engine.get_frames_per_second()
	var avg_physics := _physics_time_sum / float(maxi(_frame_count, 1))
	var rtt := NetworkManager.local_rtt if NetworkManager else 0.0
	var jitter := NetworkManager.local_jitter if NetworkManager else 0.0
	var loss := NetworkManager.local_packet_loss * 100.0 if NetworkManager else 0.0
	var peers := NetworkManager.get_peer_count() if NetworkManager else 0
	var rpc_s := get_rpc_per_second()
	var kb_s := get_kb_per_second()
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	var timestamp := Time.get_datetime_string_from_system(true)
	var line := "%s,%s,%d,%d,%.2f,%.2f,%.0f,%.1f,%.1f,%d,%.0f,%.1f,%d,%d,%.1f" % [
		timestamp, role, avg_fps, _min_fps, avg_physics, _max_physics_ms,
		rtt, jitter, loss, peers, rpc_s, kb_s, _sync_ticks, _grid_rebuilds, mem_mb
	]
	_csv_file.store_line(line)
	_csv_file.flush()

	# Reset interval counters
	_rpc_count = 0
	_bytes_sent = 0
	_sync_ticks = 0
	_grid_rebuilds = 0
	_grid_rebuild_time_total = 0.0
	_frame_count = 0
	_physics_time_sum = 0.0
	_min_fps = 9999
	_max_physics_ms = 0.0


func _is_server() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		if _csv_file:
			_csv_file.close()
			_csv_file = null
