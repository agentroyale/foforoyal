extends GutTest
## Phase 2: Building System unit tests.

const BuildingManagerScript = preload("res://scripts/building/building_manager.gd")


# ─── Test 1: Socket Compatibility ───

func test_socket_compatibility() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_BOTTOM
	socket.allowed_pieces = [
		BuildingPieceData.PieceType.WALL,
		BuildingPieceData.PieceType.DOORWAY,
	]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"WALL_BOTTOM socket should accept WALL"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.DOORWAY),
		"WALL_BOTTOM socket should accept DOORWAY"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.DOOR),
		"WALL_BOTTOM socket should reject DOOR"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.FOUNDATION),
		"WALL_BOTTOM socket should reject FOUNDATION"
	)


# ─── Test 2: Socket Snap Position ───

func test_socket_snap_position() -> void:
	var foundation := StaticBody3D.new()
	add_child_autofree(foundation)
	foundation.global_position = Vector3(10, 0, 20)

	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_BOTTOM
	socket.allowed_pieces = [BuildingPieceData.PieceType.WALL]
	socket.position = Vector3(0, 0.1, -1.5)
	foundation.add_child(socket)

	# Socket global = parent global + local offset
	assert_almost_eq(socket.global_position.x, 10.0, 0.01,
		"Socket X should match foundation X")
	assert_almost_eq(socket.global_position.y, 0.1, 0.01,
		"Socket Y should be 0.1 (local offset)")
	assert_almost_eq(socket.global_position.z, 18.5, 0.01,
		"Socket Z should be foundation Z + (-1.5) = 18.5")


# ─── Test 3: Rotation Increments ───

func test_rotation_increments() -> void:
	var placer := BuildingPlacer.new()
	add_child_autofree(placer)
	placer._create_ghost_materials()

	assert_eq(placer.current_rotation, 0, "Initial rotation should be 0")

	placer.rotate_ghost()
	assert_eq(placer.current_rotation, 90, "After 1 rotation: 90")

	placer.rotate_ghost()
	assert_eq(placer.current_rotation, 180, "After 2 rotations: 180")

	placer.rotate_ghost()
	assert_eq(placer.current_rotation, 270, "After 3 rotations: 270")

	placer.rotate_ghost()
	assert_eq(placer.current_rotation, 0, "After 4 rotations: wraps to 0")


# ─── Test 4: Overlap Rejection ───

func test_overlap_rejection() -> void:
	var manager := BuildingManagerScript.new()
	add_child_autofree(manager)

	# Create a placed piece with piece_data
	var piece := BuildingPiece.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	add_child_autofree(piece)

	var data := BuildingPieceData.new()
	data.piece_type = BuildingPieceData.PieceType.WALL
	piece.piece_data = data
	piece.global_position = Vector3(5, 0, 5)

	manager.register_piece(piece)

	assert_true(
		manager.check_overlap(Vector3(5, 0, 5), BuildingPieceData.PieceType.WALL),
		"Should detect overlap at same position with same type"
	)
	assert_false(
		manager.check_overlap(Vector3(50, 0, 50), BuildingPieceData.PieceType.WALL),
		"Should NOT detect overlap at distant position"
	)
	assert_false(
		manager.check_overlap(Vector3(5, 0, 5), BuildingPieceData.PieceType.FOUNDATION),
		"Should NOT detect overlap with different type at same position"
	)


# ─── Test 5: Tier Upgrade Increases HP ───

func test_tier_upgrade_increases_hp() -> void:
	# Test static data
	assert_eq(BuildingTier.get_max_hp(BuildingTier.Tier.TWIG), 10, "Twig HP = 10")
	assert_eq(BuildingTier.get_max_hp(BuildingTier.Tier.WOOD), 250, "Wood HP = 250")
	assert_eq(BuildingTier.get_max_hp(BuildingTier.Tier.STONE), 500, "Stone HP = 500")
	assert_eq(BuildingTier.get_max_hp(BuildingTier.Tier.METAL), 1000, "Metal HP = 1000")
	assert_eq(BuildingTier.get_max_hp(BuildingTier.Tier.ARMORED), 2000, "Armored HP = 2000")

	# Test upgrade flow on a piece
	var piece := BuildingPiece.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	add_child_autofree(piece)
	piece._apply_tier(BuildingTier.Tier.TWIG)

	assert_eq(piece.current_tier, BuildingTier.Tier.TWIG, "Starts as Twig")
	assert_eq(piece.current_hp, 10.0, "Twig HP = 10")

	var upgraded := piece.upgrade()
	assert_true(upgraded, "Upgrade from Twig should succeed")
	assert_eq(piece.current_tier, BuildingTier.Tier.WOOD, "Now Wood")
	assert_eq(piece.current_hp, 250.0, "Wood HP = 250")

	piece.upgrade()
	assert_eq(piece.current_hp, 500.0, "Stone HP = 500")

	piece.upgrade()
	assert_eq(piece.current_hp, 1000.0, "Metal HP = 1000")

	piece.upgrade()
	assert_eq(piece.current_hp, 2000.0, "Armored HP = 2000")

	var max_upgrade := piece.upgrade()
	assert_false(max_upgrade, "Cannot upgrade beyond Armored")


# ─── Test 6: Soft Side Multiplier ───

func test_soft_side_multiplier() -> void:
	var piece := BuildingPiece.new()
	piece.forward_direction = Vector3.FORWARD  # (0, 0, -1)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	add_child_autofree(piece)

	# Hit from behind (soft side): direction same as forward → dot > 0
	var soft_mult := piece.get_damage_multiplier(Vector3.FORWARD)
	assert_eq(soft_mult, 2.0, "Soft side (from behind) should return 2.0")

	# Hit from front (hard side): direction opposite to forward → dot < 0
	var hard_mult := piece.get_damage_multiplier(Vector3.BACK)
	assert_eq(hard_mult, 1.0, "Hard side (from front) should return 1.0")


# ─── Test 7: Building Piece Data Resource ───

func test_building_piece_data_resource() -> void:
	var data := BuildingPieceData.new()
	data.piece_name = "TestFoundation"
	data.piece_type = BuildingPieceData.PieceType.FOUNDATION
	data.build_costs = [10, 50, 100, 200, 400]
	data.upgrade_costs = [40, 50, 100, 200, 0]

	assert_eq(data.piece_name, "TestFoundation")
	assert_eq(data.piece_type, BuildingPieceData.PieceType.FOUNDATION)

	# Verify all 5 tiers have valid data
	for tier_idx in range(5):
		var tier := tier_idx as BuildingTier.Tier
		assert_gt(data.get_max_hp(tier), 0,
			"Tier %d should have positive HP" % tier_idx)
		assert_gte(data.build_costs[tier_idx], 0,
			"Tier %d should have non-negative build cost" % tier_idx)

	# Verify HP progression is strictly increasing
	var prev_hp := 0
	for tier_idx in range(5):
		var hp := data.get_max_hp(tier_idx as BuildingTier.Tier)
		assert_gt(hp, prev_hp, "Tier %d HP should exceed tier %d" % [tier_idx, tier_idx - 1])
		prev_hp = hp
