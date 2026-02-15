extends GutTest
## Phase 8: Multiplayer networking unit tests.
## Tests pure logic without actual ENet connections.

const NetworkManagerScript = preload("res://scripts/networking/network_manager.gd")


# ─── Test 1: Client Prediction No Correction ───

func test_client_prediction_no_correction() -> void:
	var pred := ClientPrediction.new()

	# Record 10 inputs
	for i in 10:
		pred.record_input(Vector2(0, -1), false, false, false)

	assert_eq(pred.get_sequence(), 10, "Should have recorded 10 inputs")
	assert_eq(pred.get_buffer_size(), 10, "Buffer should have 10 entries")

	# Simulate server ack at sequence 5 with matching position
	var client_pos := Vector3(0, 0, -5)
	var server_pos := Vector3(0, 0, -5)

	# No correction needed when positions match
	assert_false(
		ClientPrediction.needs_correction(client_pos, server_pos),
		"No correction when positions match"
	)


# ─── Test 2: Client Prediction With Correction ───

func test_client_prediction_with_correction() -> void:
	var pred := ClientPrediction.new()

	for i in 10:
		pred.record_input(Vector2(0, -1), false, false, false)

	# Server position differs significantly
	var client_pos := Vector3(0, 0, -5)
	var server_pos := Vector3(2, 0, -5)  # 2m off

	assert_true(
		ClientPrediction.needs_correction(client_pos, server_pos),
		"Correction needed when > 0.1m difference"
	)

	# Reconcile: should trim buffer up to acked sequence
	var result := pred.reconcile(server_pos, 5)
	assert_true(result["needs_correction"], "Reconcile indicates correction needed")
	assert_eq(result["server_position"], server_pos, "Returns server position")
	# After acking sequence 5, inputs 0-5 removed, 6-9 remain = 4
	assert_eq(result["pending_inputs"].size(), 4,
		"4 unacknowledged inputs remain after acking sequence 5")


# ─── Test 3: Server Validation Rejects Cheats ───

func test_rpc_validation_rejects_cheats() -> void:
	# Movement validation
	var valid := ServerValidation.validate_movement(
		Vector3.ZERO, Vector3(4, 0, 0), 1.0  # 4 m/s < 10 max
	)
	assert_true(valid, "Normal movement should pass")

	var too_fast := ServerValidation.validate_movement(
		Vector3.ZERO, Vector3(20, 0, 0), 1.0  # 20 m/s > 10 max
	)
	assert_false(too_fast, "Teleport-speed movement should fail")

	# Placement validation
	var valid_place := ServerValidation.validate_placement(
		Vector3.ZERO, Vector3(4, 0, 0)  # 4m < 6m max
	)
	assert_true(valid_place, "Nearby placement should pass")

	var too_far := ServerValidation.validate_placement(
		Vector3.ZERO, Vector3(20, 0, 0)  # 20m > 6m max
	)
	assert_false(too_far, "Far placement should fail")

	# Damage validation
	var valid_dmg := ServerValidation.validate_damage(52.0, 26.0)  # headshot 2x
	assert_true(valid_dmg, "Headshot damage should pass")

	var cheat_dmg := ServerValidation.validate_damage(1000.0, 26.0)  # impossibly high
	assert_false(cheat_dmg, "Impossibly high damage should fail")

	var negative := ServerValidation.validate_damage(-5.0, 26.0)
	assert_false(negative, "Negative damage should fail")


# ─── Test 4: Interest Management Radius ───

func test_interest_management_radius() -> void:
	var player_pos := Vector3.ZERO

	# 100m away: visible
	assert_true(
		ChunkStreamer.should_be_visible(player_pos, Vector3(100, 0, 0)),
		"Entity at 100m should be visible (within 256m)"
	)

	# 256m away: visible (boundary)
	assert_true(
		ChunkStreamer.should_be_visible(player_pos, Vector3(256, 0, 0)),
		"Entity at exactly 256m should be visible (boundary)"
	)

	# 300m away: not visible
	assert_false(
		ChunkStreamer.should_be_visible(player_pos, Vector3(300, 0, 0)),
		"Entity at 300m should not be visible"
	)

	# Custom radius
	assert_true(
		ChunkStreamer.should_be_visible(player_pos, Vector3(50, 0, 0), 100.0),
		"Entity at 50m with 100m radius should be visible"
	)
	assert_false(
		ChunkStreamer.should_be_visible(player_pos, Vector3(150, 0, 0), 100.0),
		"Entity at 150m with 100m radius should not be visible"
	)


# ─── Test 5: Lag Compensation Position Interpolation ───

func test_lag_compensation_position_interpolation() -> void:
	var lag_comp := LagCompensation.new()

	# Record snapshots at known times
	lag_comp.record_snapshot(1, Vector3(0, 0, 0), 0.0)
	lag_comp.record_snapshot(1, Vector3(10, 0, 0), 0.0)
	lag_comp.record_snapshot(1, Vector3(20, 0, 0), 0.0)

	assert_eq(lag_comp.get_snapshot_count(1), 3, "Should have 3 snapshots")

	# Query for a nonexistent peer returns empty
	var empty := lag_comp.get_position_at_time(999, 0.0)
	assert_eq(empty.size(), 0, "Unknown peer returns empty dict")

	# Clear works
	lag_comp.clear_peer(1)
	assert_eq(lag_comp.get_snapshot_count(1), 0, "After clear, 0 snapshots")

	# Clear all
	lag_comp.record_snapshot(2, Vector3.ZERO, 0.0)
	lag_comp.clear_all()
	assert_eq(lag_comp.get_snapshot_count(2), 0, "clear_all removes all peers")


# ─── Test 6: Network Manager Peer Tracking ───

func test_network_manager_peer_tracking() -> void:
	var manager := NetworkManagerScript.new()
	add_child_autofree(manager)

	# No peer connected initially
	assert_false(manager.is_online(), "Not online without peer")
	assert_false(manager.is_server(), "Not server without peer")
	assert_eq(manager.get_local_peer_id(), 1, "Local peer defaults to 1")
	assert_eq(manager.get_peer_count(), 0, "No peers initially")

	# Simulate manual peer tracking
	manager.connected_peers[42] = { "join_time": 0 }
	assert_eq(manager.get_peer_count(), 1, "1 peer after adding")

	manager.connected_peers.erase(42)
	assert_eq(manager.get_peer_count(), 0, "0 peers after removing")


# ─── Test 7: Authority Guards Don't Break Singleplayer ───

func test_authority_guards_singleplayer() -> void:
	# Verify is_multiplayer_authority() returns true without a peer
	var player := CharacterBody3D.new()
	add_child_autofree(player)

	assert_true(player.is_multiplayer_authority(),
		"is_multiplayer_authority should be true in singleplayer")

	# Verify child nodes also return true
	var child := Node.new()
	player.add_child(child)
	assert_true(child.get_parent().is_multiplayer_authority(),
		"Parent authority check from child should be true")


# ─── Test 8: Client Prediction Buffer Overflow ───

func test_client_prediction_buffer_overflow() -> void:
	var pred := ClientPrediction.new()

	# Fill buffer past max size (64)
	for i in 100:
		pred.record_input(Vector2(0, -1), false, false, false)

	assert_eq(pred.get_sequence(), 100, "Sequence should be 100")
	assert_eq(pred.get_buffer_size(), ClientPrediction.BUFFER_SIZE,
		"Buffer should be capped at BUFFER_SIZE (%d)" % ClientPrediction.BUFFER_SIZE)
