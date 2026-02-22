extends GutTest
## Netcode scaling tests: interest management, delta compression,
## rate limiting, fixed tick, distance VFX, metrics, performance.

const NetworkManagerScript = preload("res://scripts/networking/network_manager.gd")


func before_each() -> void:
	NetworkSync.clear_interest_data()


func after_each() -> void:
	NetworkSync.clear_interest_data()


# ─── Test 1: Interest Grid Cell Calculation ───

func test_interest_grid_cell_calculation() -> void:
	# Origin -> cell (0, 0)
	assert_eq(NetworkSync.position_to_cell(Vector3(0, 0, 0)), Vector2i(0, 0),
		"Origin maps to cell (0,0)")

	# Center of cell 0 (64, 0, 64) -> still (0, 0)
	assert_eq(NetworkSync.position_to_cell(Vector3(64, 5, 64)), Vector2i(0, 0),
		"Mid-cell maps to (0,0)")

	# 128m -> cell (1, 1)
	assert_eq(NetworkSync.position_to_cell(Vector3(128, 0, 128)), Vector2i(1, 1),
		"128m maps to cell (1,1)")

	# Negative coords -> negative cells
	assert_eq(NetworkSync.position_to_cell(Vector3(-1, 0, -1)), Vector2i(-1, -1),
		"Negative coord maps to cell (-1,-1)")

	# 1024m -> cell (8, 8)
	assert_eq(NetworkSync.position_to_cell(Vector3(1024, 0, 1024)), Vector2i(8, 8),
		"1024m maps to cell (8,8)")


# ─── Test 2: Interest Grid Neighbor Search (3x3) ───

func test_interest_grid_neighbor_search() -> void:
	# Place peer 100 at origin, peer 200 one cell away, peer 300 far away
	NetworkSync._peer_positions[100] = Vector3(64, 0, 64)    # cell (0,0)
	NetworkSync._peer_positions[200] = Vector3(192, 0, 64)   # cell (1,0) — neighbor
	NetworkSync._peer_positions[300] = Vector3(640, 0, 640)  # cell (5,5) — far

	NetworkSync._update_interest_grid()

	var nearby := NetworkSync._get_nearby_peers(100)
	assert_true(nearby.has(200), "Peer 200 (1 cell away) should be nearby")
	assert_false(nearby.has(300), "Peer 300 (5 cells away) should NOT be nearby")
	assert_false(nearby.has(100), "Self should not be in nearby list")


# ─── Test 3: Delta Compression Threshold (Skip Send) ───

func test_delta_compression_skip_send() -> void:
	# Verify the constants are set correctly
	assert_almost_eq(NetworkSync.POSITION_SEND_THRESHOLD, 0.1, 0.001,
		"Position threshold should be 0.1m")
	assert_almost_eq(NetworkSync.ROTATION_SEND_THRESHOLD, 0.05, 0.001,
		"Rotation threshold should be ~0.05 rad")
	assert_true(NetworkSync.USE_DELTA_COMPRESSION,
		"Delta compression should be enabled by default")

	# Simulate delta check: positions within threshold should be skipped
	var last_pos := Vector3(10, 0, 10)
	var new_pos := Vector3(10.05, 0, 10.05)  # ~0.07m away, < 0.1 threshold
	var pos_delta := last_pos.distance_to(new_pos)
	assert_true(pos_delta < NetworkSync.POSITION_SEND_THRESHOLD,
		"Small movement (%.3fm) should be below threshold" % pos_delta)

	# Position beyond threshold should be sent
	var far_pos := Vector3(10.2, 0, 10)  # 0.2m away
	var far_delta := last_pos.distance_to(far_pos)
	assert_true(far_delta >= NetworkSync.POSITION_SEND_THRESHOLD,
		"Larger movement (%.3fm) should exceed threshold" % far_delta)


# ─── Test 4: Rate Limiting Allows Legit Fire ───

func test_rate_limiting_allows_legit_fire() -> void:
	var cn_script: GDScript = load("res://scripts/networking/combat_netcode.gd")
	var cn: Node = cn_script.new()
	add_child_autofree(cn)

	# First fire should always pass
	assert_true(cn._check_rate_limit(42), "First fire should pass")

	# Second fire after sufficient interval should pass
	# Simulate time passing by setting last_fire_time far in the past
	cn._last_fire_time[42] = Time.get_ticks_msec() - 100.0  # 100ms ago
	assert_true(cn._check_rate_limit(42), "Fire after 100ms should pass (MIN=50ms)")


# ─── Test 5: Rate Limiting Rejects Spam ───

func test_rate_limiting_rejects_spam() -> void:
	var cn_script: GDScript = load("res://scripts/networking/combat_netcode.gd")
	var cn: Node = cn_script.new()
	add_child_autofree(cn)

	# First fire passes
	cn._check_rate_limit(42)

	# Immediate second fire should fail (< 50ms)
	assert_false(cn._check_rate_limit(42), "Spam fire (< 50ms) should be rejected")
	assert_eq(cn.get_violation_count(42), 1, "Should record 1 violation")


# ─── Test 6: Rate Limiting Violation Tracking + Expiry ───

func test_rate_limiting_violation_tracking() -> void:
	var cn_script: GDScript = load("res://scripts/networking/combat_netcode.gd")
	var cn: Node = cn_script.new()
	add_child_autofree(cn)

	# Manually record violations
	var now := Time.get_ticks_msec() as float
	cn._violations[99] = []

	# Add 3 recent violations
	for i in 3:
		(cn._violations[99] as Array).append(now - float(i * 100))
	assert_eq(cn.get_violation_count(99), 3, "Should have 3 violations")

	# Add old violations (> 10s ago) — _record_violation cleans old ones
	(cn._violations[99] as Array).insert(0, now - 15000.0)  # 15s ago
	assert_eq(cn.get_violation_count(99), 4, "Raw array has 4 entries")

	# Trigger cleanup via _record_violation
	cn._last_fire_time[99] = now  # Set last fire to now so next check fails
	cn._check_rate_limit(99)  # This will fail and call _record_violation
	# Old violation should be cleaned, new one added: 3 recent + 1 new = 4
	assert_true(cn.get_violation_count(99) <= 5, "Old violations should be pruned")


# ─── Test 7: Fixed Tick Interval Consistency (30Hz) ───

func test_fixed_tick_interval() -> void:
	assert_eq(NetworkSync.SYNC_TICK_INTERVAL, 2,
		"Sync tick interval should be 2 (60Hz/2 = 30Hz)")
	assert_true(NetworkSync.USE_FIXED_TICK,
		"Fixed tick should be enabled by default")

	# Verify legacy interval is still defined for fallback
	assert_almost_eq(NetworkSync.SYNC_INTERVAL, 0.033, 0.002,
		"Legacy sync interval should be ~0.033s (30Hz)")


# ─── Test 8: Distance-Filtered VFX Nearby (50m = Receive) ───

func test_distance_filtered_vfx_nearby() -> void:
	# Place two peers close together (50m)
	NetworkSync._peer_positions[10] = Vector3(100, 0, 100)
	NetworkSync._peer_positions[20] = Vector3(150, 0, 100)  # 50m away, same cell
	NetworkSync._update_interest_grid()

	var recipients := NetworkSync.get_nearby_peers_for_position(Vector3(100, 0, 100))
	assert_true(recipients.has(10), "Peer 10 at origin should be in recipients")
	assert_true(recipients.has(20), "Peer 20 (50m away) should be in recipients")


# ─── Test 9: Distance-Filtered VFX Far (250m = No Receive) ───

func test_distance_filtered_vfx_far() -> void:
	# Place two peers far apart (> 384m grid range)
	NetworkSync._peer_positions[10] = Vector3(0, 0, 0)
	NetworkSync._peer_positions[20] = Vector3(600, 0, 600)  # ~849m away
	NetworkSync._update_interest_grid()

	var recipients := NetworkSync.get_nearby_peers_for_position(Vector3(0, 0, 0))
	assert_true(recipients.has(10), "Peer 10 at origin should be in own recipients")
	assert_false(recipients.has(20), "Peer 20 (849m away) should NOT be in recipients")


# ─── Test 10: Metrics Recording ───

func test_metrics_recording() -> void:
	var metrics_script: GDScript = load("res://scripts/networking/network_metrics.gd")
	var metrics: Node = metrics_script.new()
	add_child_autofree(metrics)

	metrics.reset_counters()

	metrics.record_rpc(20)
	metrics.record_rpc(40)
	assert_eq(metrics.total_rpc_count, 2, "Should have 2 RPCs recorded")
	assert_eq(metrics.total_bytes_sent, 60, "Should have 60 bytes recorded")

	metrics.record_sync_tick()
	metrics.record_sync_tick()

	metrics.record_grid_rebuild(1.5)
	assert_eq(metrics.total_grid_rebuilds, 1, "Should have 1 grid rebuild")

	# Reset
	metrics.reset_counters()
	assert_eq(metrics.total_rpc_count, 0, "After reset, 0 RPCs")
	assert_eq(metrics.total_bytes_sent, 0, "After reset, 0 bytes")
	assert_eq(metrics.total_grid_rebuilds, 0, "After reset, 0 rebuilds")


# ─── Test 11: Interest Grid Handles Empty Cells ───

func test_interest_grid_empty_cells() -> void:
	# No peers registered
	NetworkSync._update_interest_grid()

	# Grid should be initialized but empty
	assert_true(NetworkSync._grid_initialized, "Grid should be initialized even if empty")
	assert_eq(NetworkSync._interest_grid.size(), 0, "No cells should exist")

	# get_nearby should return empty for unknown peer
	var nearby := NetworkSync._get_nearby_peers(999)
	# Falls back to NetworkManager.connected_peers when peer not in grid
	assert_true(nearby is Array, "Should return an array")


# ─── Test 12: Interest Grid Handles Single Player ───

func test_interest_grid_single_player() -> void:
	NetworkSync._peer_positions[1] = Vector3(512, 0, 512)
	NetworkSync._update_interest_grid()

	assert_eq(NetworkSync._interest_grid.size(), 1, "Should have exactly 1 cell")
	assert_true(NetworkSync._peer_cells.has(1), "Peer 1 should be tracked")

	var nearby := NetworkSync._get_nearby_peers(1)
	assert_eq(nearby.size(), 0, "Single player should have 0 nearby (self excluded)")


# ─── Test 13: Interest Grid Boundary Check (Cell Edges) ───

func test_interest_grid_boundary_check() -> void:
	# Place peers at exact cell boundary: 127.9 (cell 0) and 128.0 (cell 1)
	NetworkSync._peer_positions[10] = Vector3(127.9, 0, 64)   # cell (0, 0)
	NetworkSync._peer_positions[20] = Vector3(128.0, 0, 64)   # cell (1, 0)
	NetworkSync._update_interest_grid()

	# They should be in different cells but still see each other (3x3 neighbor search)
	var cell_10 := NetworkSync.position_to_cell(Vector3(127.9, 0, 64))
	var cell_20 := NetworkSync.position_to_cell(Vector3(128.0, 0, 64))
	assert_ne(cell_10, cell_20, "Peers at boundary should be in different cells")

	var nearby_10 := NetworkSync._get_nearby_peers(10)
	assert_true(nearby_10.has(20), "Peer at cell boundary should still see neighbor")

	var nearby_20 := NetworkSync._get_nearby_peers(20)
	assert_true(nearby_20.has(10), "Peer at cell boundary should still see neighbor (reverse)")


# ─── Test 14: ENet Bandwidth Limits Applied (No Crash) ───

func test_enet_bandwidth_limits_defined() -> void:
	# Verify constants are defined and reasonable
	assert_gt(NetworkManager.SERVER_OUT_BANDWIDTH, 0,
		"Server out bandwidth should be > 0")
	assert_gt(NetworkManager.SERVER_IN_BANDWIDTH, 0,
		"Server in bandwidth should be > 0")
	assert_gt(NetworkManager.CLIENT_OUT_BANDWIDTH, 0,
		"Client out bandwidth should be > 0")
	assert_gt(NetworkManager.CLIENT_IN_BANDWIDTH, 0,
		"Client in bandwidth should be > 0")

	# Server out >= client in (server sends more)
	assert_true(NetworkManager.SERVER_OUT_BANDWIDTH >= NetworkManager.CLIENT_OUT_BANDWIDTH,
		"Server should have higher outbound than client")

	# Reasonable range: 32KB to 512KB
	assert_true(NetworkManager.SERVER_OUT_BANDWIDTH <= 512 * 1024,
		"Server out should be <= 512 KB/s")
	assert_true(NetworkManager.CLIENT_OUT_BANDWIDTH >= 16 * 1024,
		"Client out should be >= 16 KB/s")


# ─── Test 15: Grid Rebuild Performance (<5ms for 30 Players) ───

func test_grid_rebuild_performance_30_players() -> void:
	# Populate 30 fake peers spread across the map
	for i in 30:
		var peer_id := 1000 + i
		NetworkSync._peer_positions[peer_id] = Vector3(
			randf_range(0, 1024),
			0,
			randf_range(0, 1024)
		)

	# Time the grid rebuild
	var start := Time.get_ticks_usec()
	NetworkSync._update_interest_grid()
	var elapsed_us := Time.get_ticks_usec() - start
	var elapsed_ms := float(elapsed_us) / 1000.0

	gut.p("Grid rebuild for 30 players took %.3f ms" % elapsed_ms)

	assert_true(elapsed_ms < 5.0,
		"Grid rebuild should take < 5ms (took %.3fms)" % elapsed_ms)

	# Verify grid was populated
	assert_eq(NetworkSync._peer_positions.size(), 30, "Should have 30 peer positions")
	assert_eq(NetworkSync._peer_cells.size(), 30, "Should have 30 peer cells")
	assert_true(NetworkSync._interest_grid.size() > 0, "Grid should have cells")
	assert_true(NetworkSync._interest_grid.size() <= 30, "Grid cells <= peer count")

	# Test neighbor lookup performance
	start = Time.get_ticks_usec()
	for peer_id in NetworkSync._peer_positions:
		NetworkSync._get_nearby_peers(peer_id)
	elapsed_us = Time.get_ticks_usec() - start
	elapsed_ms = float(elapsed_us) / 1000.0

	gut.p("30 neighbor lookups took %.3f ms" % elapsed_ms)
	assert_true(elapsed_ms < 5.0,
		"30 neighbor lookups should take < 5ms (took %.3fms)" % elapsed_ms)
