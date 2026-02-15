extends Node3D
## Headless stress test: spawns N simulated players to measure network performance.
## Usage: godot-4 --headless scenes/testing/bot_stress_test.tscn --server --bots=30
## Monitors NetworkMetrics output for 5 minutes then exits.

const BOT_SPEED := 5.0
const DIRECTION_CHANGE_INTERVAL := 2.0
const TEST_DURATION := 300.0  # 5 minutes
const DEFAULT_BOT_COUNT := 30

var _bots: Array[Dictionary] = []  # [{peer_id, position, direction, dir_timer}]
var _elapsed: float = 0.0
var _bot_count: int = DEFAULT_BOT_COUNT


func _ready() -> void:
	# Parse --bots=N from command line
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--bots="):
			_bot_count = int(arg.split("=")[1])

	print("[BotStressTest] Starting with %d bots for %.0fs" % [_bot_count, TEST_DURATION])

	# Register fake peers in NetworkManager
	for i in range(_bot_count):
		var peer_id := 1000 + i
		NetworkManager.connected_peers[peer_id] = { "join_time": Time.get_ticks_msec() }
		var pos := Vector3(
			randf_range(0, 1024),
			0,
			randf_range(0, 1024)
		)
		NetworkSync._peer_positions[peer_id] = pos
		_bots.append({
			"peer_id": peer_id,
			"position": pos,
			"direction": _random_direction(),
			"dir_timer": randf_range(0, DIRECTION_CHANGE_INTERVAL)
		})

	# Force initial grid rebuild
	NetworkSync._update_interest_grid()
	print("[BotStressTest] %d bots spawned, grid initialized" % _bot_count)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _elapsed >= TEST_DURATION:
		_print_final_report()
		get_tree().quit()
		return

	# Move all bots
	for bot in _bots:
		bot["dir_timer"] -= delta
		if bot["dir_timer"] <= 0:
			bot["direction"] = _random_direction()
			bot["dir_timer"] = DIRECTION_CHANGE_INTERVAL

		var pos: Vector3 = bot["position"]
		var dir: Vector3 = bot["direction"]
		pos += dir * BOT_SPEED * delta
		# Clamp to world bounds
		pos.x = clampf(pos.x, 0, 1024)
		pos.z = clampf(pos.z, 0, 1024)
		bot["position"] = pos

		var peer_id: int = bot["peer_id"]
		NetworkSync._peer_positions[peer_id] = pos

		# Simulate sync RPC
		if NetworkMetrics:
			NetworkMetrics.record_rpc(20)

	# Simulate grid rebuild at the normal interval
	NetworkSync._rebuild_timer += delta
	if NetworkSync._rebuild_timer >= NetworkSync.INTEREST_REBUILD_INTERVAL:
		NetworkSync._rebuild_timer = 0.0
		var start := Time.get_ticks_usec()
		NetworkSync._update_interest_grid()
		var duration_ms := float(Time.get_ticks_usec() - start) / 1000.0
		if NetworkMetrics:
			NetworkMetrics.record_grid_rebuild(duration_ms)

	# Simulate fire from random bot every few frames
	if Engine.get_physics_frames() % 10 == 0 and _bots.size() > 0:
		var bot: Dictionary = _bots[randi() % _bots.size()]
		var nearby := NetworkSync._get_nearby_peers(bot["peer_id"])
		for peer_id in nearby:
			if NetworkMetrics:
				NetworkMetrics.record_rpc(40)


func _random_direction() -> Vector3:
	var angle := randf() * TAU
	return Vector3(cos(angle), 0, sin(angle))


func _print_final_report() -> void:
	print("\n========== BOT STRESS TEST COMPLETE ==========")
	print("Duration: %.0fs | Bots: %d" % [_elapsed, _bot_count])
	if NetworkMetrics:
		print("Total RPCs: %d" % NetworkMetrics.total_rpc_count)
		print("Total bytes: %d KB" % (NetworkMetrics.total_bytes_sent / 1024))
		print("Total grid rebuilds: %d" % NetworkMetrics.total_grid_rebuilds)
	print("================================================\n")
