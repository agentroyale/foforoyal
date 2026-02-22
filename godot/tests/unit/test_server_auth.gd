extends GutTest
## Server-authoritative movement tests.
## Validates jitter buffer, server simulation, prediction thresholds,
## snapshot reconciliation, input validation, and input redundancy.


# ─── Test 1: simulate_tick Deterministic ───

func test_simulate_tick_deterministic() -> void:
	var player := PlayerController.new()
	player.name = "Player"
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.3
	shape_node.shape = capsule
	player.add_child(shape_node)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 1.8
	player.add_child(pivot)
	add_child_autofree(player)
	await get_tree().physics_frame

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var delta := 1.0 / 60.0

	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var pos_before := player.global_position
	player.simulate_tick(input, delta)
	var pos_after_1 := player.global_position
	var vel_after_1 := player.velocity

	player.global_position = pos_before
	player.velocity = Vector3.ZERO
	player.simulate_tick(input, delta)
	var pos_after_2 := player.global_position
	var vel_after_2 := player.velocity

	assert_almost_eq(pos_after_1.x, pos_after_2.x, 0.001,
		"X position should be deterministic")
	assert_almost_eq(pos_after_1.z, pos_after_2.z, 0.001,
		"Z position should be deterministic")
	assert_almost_eq(vel_after_1.y, vel_after_2.y, 0.001,
		"Y velocity should be deterministic")


# ─── Test 2: Jitter Buffer Push + Consume ───

func test_jitter_buffer_push_consume() -> void:
	var buf := InputJitterBuffer.new()

	assert_eq(buf.get_buffer_size(), 0, "Buffer starts empty")
	assert_eq(buf.get_last_consumed_seq(), -1, "No consumed seq initially")

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	buf.push(0, input)
	assert_eq(buf.get_buffer_size(), 1, "Buffer has 1 after push")

	# Tick through delay period (BUFFER_DELAY_TICKS = 4)
	for i in InputJitterBuffer.BUFFER_DELAY_TICKS:
		buf.tick()

	# Next tick should consume the buffered input
	var consumed := buf.tick()
	assert_eq(buf.get_last_consumed_seq(), 0, "Should have consumed seq 0")
	assert_eq(consumed.get("direction", Vector2.ZERO), Vector2(0, -1),
		"Consumed input should match pushed input")


# ─── Test 3: Jitter Buffer Duplicate Discard ───

func test_jitter_buffer_duplicate_discard() -> void:
	var buf := InputJitterBuffer.new()

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	buf.push(0, input)
	buf.push(0, input)  # duplicate
	buf.push(0, input)  # duplicate

	assert_eq(buf.get_buffer_size(), 1, "Duplicates should be discarded")


# ─── Test 4: Jitter Buffer Ordering ───

func test_jitter_buffer_ordering() -> void:
	var buf := InputJitterBuffer.new()

	# Push out of order
	var input_2 := {"direction": Vector2(1, 0), "jump": false, "sprint": false, "crouch": false}
	var input_0 := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var input_1 := {"direction": Vector2(-1, 0), "jump": false, "sprint": false, "crouch": false}

	buf.push(2, input_2)
	buf.push(0, input_0)
	buf.push(1, input_1)

	assert_eq(buf.get_buffer_size(), 3, "All 3 inputs buffered")

	# Consume: should get seq 0 first (sorted)
	for i in InputJitterBuffer.BUFFER_DELAY_TICKS + 1:
		buf.tick()
	assert_eq(buf.get_last_consumed_seq(), 0, "First consumed should be seq 0 (sorted)")


# ─── Test 5: Jitter Buffer Starving (Empty) ───

func test_jitter_buffer_starving() -> void:
	var buf := InputJitterBuffer.new()

	# No inputs pushed — should repeat empty dict
	var result := buf.tick()
	assert_eq(result.size(), 0, "Empty buffer returns empty dict")
	assert_false(buf.is_starving(), "Not starving if never started")

	# Push one, consume it, then check starving
	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	buf.push(0, input)

	# Tick through delay + consume
	for i in InputJitterBuffer.BUFFER_DELAY_TICKS + 2:
		buf.tick()

	assert_true(buf.is_starving(), "Should be starving after consuming all inputs")


# ─── Test 6: Jitter Buffer Old Seq Discarded ───

func test_jitter_buffer_old_seq_discarded() -> void:
	var buf := InputJitterBuffer.new()

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	buf.push(5, input)

	# Consume seq 5
	for i in InputJitterBuffer.BUFFER_DELAY_TICKS + 2:
		buf.tick()
	assert_eq(buf.get_last_consumed_seq(), 5, "Consumed seq 5")

	# Try to push old seq (should be discarded)
	buf.push(3, input)
	buf.push(4, input)
	assert_eq(buf.get_buffer_size(), 0, "Old seqs should be discarded")


# ─── Test 7: Prediction Small Error Ignored ───

func test_prediction_small_error_ignored() -> void:
	var pred := ClientPrediction.new()

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var state := {"position": Vector3(0, 0, -1), "velocity_y": 0.0, "is_crouching": false}
	pred.record_input(input, state)

	var result := pred.reconcile(Vector3(0.03, 0, -1), 0.0, 0, false)
	assert_false(result["needs_correction"],
		"Should not correct when error < 5cm threshold")
	assert_almost_eq(result["error_magnitude"] as float, 0.03, 0.01,
		"Error magnitude should be ~3cm")


# ─── Test 8: Prediction Medium Error Smooth ───

func test_prediction_medium_error_smooth() -> void:
	var pred := ClientPrediction.new()

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var state := {"position": Vector3(0, 0, -1), "velocity_y": 0.0, "is_crouching": false}
	pred.record_input(input, state)

	var result := pred.reconcile(Vector3(0.5, 0, -1), 0.0, 0, false)
	assert_true(result["needs_correction"],
		"Should correct when error > 5cm")
	var err: float = result["error_magnitude"]
	assert_true(err > ClientPrediction.CORRECTION_THRESHOLD and err < ClientPrediction.SMOOTH_THRESHOLD,
		"Error should be in smooth correction range (5cm-2m)")


# ─── Test 9: Prediction Large Error Snap ───

func test_prediction_large_error_snap() -> void:
	var pred := ClientPrediction.new()

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var state := {"position": Vector3(0, 0, 0), "velocity_y": 0.0, "is_crouching": false}
	pred.record_input(input, state)

	var result := pred.reconcile(Vector3(10, 0, 0), 0.0, 0, false)
	assert_true(result["needs_correction"], "Should correct")
	var err: float = result["error_magnitude"]
	assert_true(err > ClientPrediction.SNAP_THRESHOLD,
		"Error (%.1fm) should be above snap threshold (5m)" % err)


# ─── Test 10: Snapshot Reconcile Trims Buffer ───

func test_snapshot_reconcile_trims_buffer() -> void:
	var pred := ClientPrediction.new()

	for i in 10:
		var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
		var state := {"position": Vector3(0, 0, -float(i + 1)), "velocity_y": 0.0, "is_crouching": false}
		pred.record_input(input, state)

	assert_eq(pred.get_buffer_size(), 10, "Buffer should have 10 entries")

	var _result := pred.reconcile(Vector3(0, 0, -6), 0.0, 5, false)
	assert_eq(pred.get_buffer_size(), 4,
		"Buffer should have 4 entries after acking seq 5 (seqs 6-9)")


# ─── Test 11: Input Validation Clamp Direction ───

func test_input_validation_clamp_direction() -> void:
	var normal := Vector2(0.5, -0.5)
	var result := ServerValidation.validate_input_direction(normal)
	assert_almost_eq(result.x, 0.5, 0.001, "Normal X unchanged")
	assert_almost_eq(result.y, -0.5, 0.001, "Normal Y unchanged")

	var cheat := Vector2(5.0, 5.0)
	var clamped := ServerValidation.validate_input_direction(cheat)
	assert_almost_eq(clamped.length(), 1.0, 0.01,
		"Cheat direction should be clamped to unit length")

	var zero := Vector2.ZERO
	var zero_result := ServerValidation.validate_input_direction(zero)
	assert_almost_eq(zero_result.length(), 0.0, 0.001, "Zero direction stays zero")


# ─── Test 12: Prediction Stats Tracking ───

func test_prediction_stats_tracking() -> void:
	var pred := ClientPrediction.new()

	assert_eq(pred.correction_count, 0, "Starts with 0 corrections")
	assert_almost_eq(pred.last_correction_error, 0.0, 0.001, "Starts with 0 error")

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var state := {"position": Vector3(0, 0, 0), "velocity_y": 0.0, "is_crouching": false}
	pred.record_input(input, state)

	var result := pred.reconcile(Vector3(1.0, 0, 0), 0.0, 0, false)
	assert_true(result["needs_correction"], "Should need correction")
	assert_eq(pred.correction_count, 1, "Should have 1 correction")
	assert_true(pred.last_correction_error > 0.0, "Should have recorded error")


# ─── Test 13: Jitter Buffer Overflow ───

func test_jitter_buffer_overflow() -> void:
	var buf := InputJitterBuffer.new()

	# Push more than BUFFER_CAPACITY
	for i in 40:
		buf.push(i, {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false})

	assert_eq(buf.get_buffer_size(), InputJitterBuffer.BUFFER_CAPACITY,
		"Buffer should be capped at BUFFER_CAPACITY (%d)" % InputJitterBuffer.BUFFER_CAPACITY)


# ─── Test 14: Sync Tick Interval 30Hz ───

func test_sync_tick_interval_30hz() -> void:
	assert_eq(NetworkSync.SYNC_TICK_INTERVAL, 2,
		"Sync tick interval should be 2 (60Hz/2 = 30Hz)")


# ─── Test 15: Prediction Thresholds ───

func test_prediction_thresholds() -> void:
	assert_almost_eq(ClientPrediction.CORRECTION_THRESHOLD, 0.05, 0.001,
		"Correction threshold should be 5cm")
	assert_almost_eq(ClientPrediction.SMOOTH_THRESHOLD, 2.0, 0.001,
		"Smooth threshold should be 2m")
	assert_almost_eq(ClientPrediction.SNAP_THRESHOLD, 5.0, 0.001,
		"Snap threshold should be 5m")


# ─── Test 16: Jitter Buffer Delay Constant ───

func test_jitter_buffer_delay() -> void:
	assert_eq(InputJitterBuffer.BUFFER_DELAY_TICKS, 4,
		"Jitter buffer delay should be 4 ticks (~67ms at 60Hz)")
	assert_eq(InputJitterBuffer.BUFFER_CAPACITY, 32,
		"Jitter buffer capacity should be 32")


# ─── Test 17: Server Simulate Tick With Input ───

func test_server_simulate_tick_with_input() -> void:
	var player := PlayerController.new()
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	shape_node.shape = capsule
	player.add_child(shape_node)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 1.8
	player.add_child(pivot)
	add_child_autofree(player)
	await get_tree().physics_frame

	var input := {"direction": Vector2(0, -1), "jump": false, "sprint": false, "crouch": false}
	var pos_before := player.global_position
	player.server_simulate_tick(input, 1.0 / 60.0)

	assert_eq(player._last_server_input, input,
		"server_simulate_tick should store last input")
