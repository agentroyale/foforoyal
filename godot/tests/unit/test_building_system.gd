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


# ─── Test 8: Foundation Side Socket Compatibility ───

func test_foundation_side_socket_compatibility() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.FOUNDATION_SIDE
	socket.allowed_pieces = [BuildingPieceData.PieceType.FOUNDATION]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FOUNDATION),
		"FOUNDATION_SIDE socket should accept FOUNDATION"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"FOUNDATION_SIDE socket should reject WALL"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR),
		"FOUNDATION_SIDE socket should reject FLOOR"
	)


# ─── Test 9: Foundation Side Socket Position ───

func test_foundation_side_socket_position() -> void:
	var foundation := StaticBody3D.new()
	add_child_autofree(foundation)
	foundation.global_position = Vector3(10, 0, 20)

	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.FOUNDATION_SIDE
	socket.allowed_pieces = [BuildingPieceData.PieceType.FOUNDATION]
	socket.position = Vector3(0, 0, -3.0)
	foundation.add_child(socket)

	assert_almost_eq(socket.global_position.x, 10.0, 0.01,
		"Foundation side socket X should match parent X")
	assert_almost_eq(socket.global_position.y, 0.0, 0.01,
		"Foundation side socket Y should be 0 (ground level)")
	assert_almost_eq(socket.global_position.z, 17.0, 0.01,
		"Foundation side socket Z should be parent Z + (-3.0) = 17.0")


# ─── Test 10: Floor Edge Accepts Walls ───

func test_floor_edge_accepts_walls() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.FLOOR_EDGE
	socket.allowed_pieces = [
		BuildingPieceData.PieceType.WALL,
		BuildingPieceData.PieceType.DOORWAY,
	]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"FLOOR_EDGE socket should accept WALL"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.DOORWAY),
		"FLOOR_EDGE socket should accept DOORWAY"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.FOUNDATION),
		"FLOOR_EDGE socket should reject FOUNDATION"
	)


# ─── Test 11: Wall Socket Height Alignment ───

func test_wall_socket_height_alignment() -> void:
	# Simulate a wall placed on a foundation at Y=0.1
	var wall := StaticBody3D.new()
	add_child_autofree(wall)
	wall.global_position = Vector3(0, 0.1, 0)

	var socket_top := BuildingSocket.new()
	socket_top.socket_type = BuildingSocket.SocketType.WALL_TOP
	socket_top.position = Vector3(0, 3.0, 0)
	wall.add_child(socket_top)

	# SocketWallTop local Y=3.0 + wall Y=0.1 = global Y=3.1
	assert_almost_eq(socket_top.global_position.y, 3.1, 0.01,
		"Wall top socket should be at Y=3.1 (0.1 + 3.0)")

	# This matches SocketFloorTop on foundation (also at Y=3.1)
	var foundation := StaticBody3D.new()
	add_child_autofree(foundation)
	foundation.global_position = Vector3(0, 0, 0)

	var socket_floor_top := BuildingSocket.new()
	socket_floor_top.socket_type = BuildingSocket.SocketType.FOUNDATION_TOP
	socket_floor_top.position = Vector3(0, 3.1, 0)
	foundation.add_child(socket_floor_top)

	assert_almost_eq(socket_top.global_position.y, socket_floor_top.global_position.y, 0.01,
		"Wall top socket and foundation floor-top socket should align at same Y")


# ─── Test 12: New PieceType Enum Values ───

func test_new_piece_type_enum_values() -> void:
	assert_eq(BuildingPieceData.PieceType.TRIANGLE_FOUNDATION, 5,
		"TRIANGLE_FOUNDATION should be 5")
	assert_eq(BuildingPieceData.PieceType.STAIRS, 6,
		"STAIRS should be 6")
	assert_eq(BuildingPieceData.PieceType.ROOF, 7,
		"ROOF should be 7")
	assert_eq(BuildingPieceData.PieceType.WINDOW_FRAME, 8,
		"WINDOW_FRAME should be 8")
	assert_eq(BuildingPieceData.PieceType.HALF_WALL, 9,
		"HALF_WALL should be 9")
	assert_eq(BuildingPieceData.PieceType.WALL_ARCHED, 10,
		"WALL_ARCHED should be 10")
	assert_eq(BuildingPieceData.PieceType.WALL_GATED, 11,
		"WALL_GATED should be 11")
	assert_eq(BuildingPieceData.PieceType.WALL_WINDOW_ARCHED, 12,
		"WALL_WINDOW_ARCHED should be 12")
	assert_eq(BuildingPieceData.PieceType.WALL_WINDOW_CLOSED, 13,
		"WALL_WINDOW_CLOSED should be 13")
	assert_eq(BuildingPieceData.PieceType.CEILING, 14,
		"CEILING should be 14")
	assert_eq(BuildingPieceData.PieceType.FLOOR_WOOD, 15,
		"FLOOR_WOOD should be 15")
	assert_eq(BuildingPieceData.PieceType.PILLAR, 16,
		"PILLAR should be 16")


# ─── Test 13: New SocketType Enum Values ───

func test_new_socket_type_enum_values() -> void:
	assert_eq(BuildingSocket.SocketType.STAIRS_BOTTOM, 6,
		"STAIRS_BOTTOM should be 6")
	assert_eq(BuildingSocket.SocketType.STAIRS_TOP, 7,
		"STAIRS_TOP should be 7")
	assert_eq(BuildingSocket.SocketType.ROOF_BOTTOM, 8,
		"ROOF_BOTTOM should be 8")


# ─── Test 14: Wall Top Socket Accepts Roof ───

func test_wall_top_socket_accepts_roof() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_TOP
	socket.allowed_pieces = [
		BuildingPieceData.PieceType.FLOOR,
		BuildingPieceData.PieceType.ROOF,
	]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR),
		"WALL_TOP socket should accept FLOOR"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.ROOF),
		"WALL_TOP socket should accept ROOF"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"WALL_TOP socket should reject WALL"
	)


# ─── Test 15: Foundation Wall Socket Accepts New Pieces ───

func test_foundation_wall_socket_accepts_new_pieces() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_BOTTOM
	socket.allowed_pieces = [
		BuildingPieceData.PieceType.WALL,
		BuildingPieceData.PieceType.DOORWAY,
		BuildingPieceData.PieceType.STAIRS,
		BuildingPieceData.PieceType.WINDOW_FRAME,
		BuildingPieceData.PieceType.HALF_WALL,
	]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.STAIRS),
		"WALL_BOTTOM socket should accept STAIRS"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WINDOW_FRAME),
		"WALL_BOTTOM socket should accept WINDOW_FRAME"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.HALF_WALL),
		"WALL_BOTTOM socket should accept HALF_WALL"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.ROOF),
		"WALL_BOTTOM socket should reject ROOF"
	)


# ─── Test 16: Half Wall Socket Accepts Stacking ───

func test_half_wall_socket_accepts_stacking() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_BOTTOM
	socket.allowed_pieces = [
		BuildingPieceData.PieceType.HALF_WALL,
		BuildingPieceData.PieceType.FLOOR,
	]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.HALF_WALL),
		"Half wall top socket should accept another HALF_WALL"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR),
		"Half wall top socket should accept FLOOR"
	)


# ─── Test 17: Triangle Foundation Needs No Socket ───

func test_triangle_foundation_needs_no_socket() -> void:
	var placer := BuildingPlacer.new()
	add_child_autofree(placer)
	placer._create_ghost_materials()

	var data := BuildingPieceData.new()
	data.piece_type = BuildingPieceData.PieceType.TRIANGLE_FOUNDATION

	var is_foundation := data.piece_type in [
		BuildingPieceData.PieceType.FOUNDATION,
		BuildingPieceData.PieceType.TRIANGLE_FOUNDATION,
	]
	assert_true(is_foundation,
		"TRIANGLE_FOUNDATION should be treated as foundation type (no socket required)")


# ─── Test 18: KayKit Wall Variants Accept in Wall Sockets ───

func test_kaykit_wall_variants_in_wall_sockets() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_BOTTOM
	socket.allowed_pieces = [1, 3, 6, 8, 9, 10, 11, 12, 13, 16]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL_ARCHED),
		"WALL_BOTTOM should accept WALL_ARCHED"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL_GATED),
		"WALL_BOTTOM should accept WALL_GATED"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL_WINDOW_ARCHED),
		"WALL_BOTTOM should accept WALL_WINDOW_ARCHED"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.WALL_WINDOW_CLOSED),
		"WALL_BOTTOM should accept WALL_WINDOW_CLOSED"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.PILLAR),
		"WALL_BOTTOM should accept PILLAR"
	)


# ─── Test 19: Wall Top Socket Accepts Ceiling and Floor Wood ───

func test_wall_top_accepts_ceiling_and_floor_wood() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.WALL_TOP
	socket.allowed_pieces = [2, 7, 14, 15]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.CEILING),
		"WALL_TOP should accept CEILING"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR_WOOD),
		"WALL_TOP should accept FLOOR_WOOD"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR),
		"WALL_TOP should accept FLOOR"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.ROOF),
		"WALL_TOP should accept ROOF"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"WALL_TOP should reject WALL"
	)


# ─── Test 20: Foundation Top Accepts Floor Variants ───

func test_foundation_top_accepts_floor_variants() -> void:
	var socket := BuildingSocket.new()
	socket.socket_type = BuildingSocket.SocketType.FOUNDATION_TOP
	socket.allowed_pieces = [2, 14, 15]
	add_child_autofree(socket)

	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR),
		"FOUNDATION_TOP should accept FLOOR"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.CEILING),
		"FOUNDATION_TOP should accept CEILING"
	)
	assert_true(
		socket.can_accept(BuildingPieceData.PieceType.FLOOR_WOOD),
		"FOUNDATION_TOP should accept FLOOR_WOOD"
	)
	assert_false(
		socket.can_accept(BuildingPieceData.PieceType.WALL),
		"FOUNDATION_TOP should reject WALL"
	)


# ─── Test 21: Underground Placement Rejected ───

func test_underground_placement_rejected() -> void:
	var placer := BuildingPlacer.new()
	add_child_autofree(placer)
	placer._create_ghost_materials()

	# Without WorldGenerator or physics, _is_below_terrain should return false
	# (safe fallback — allows placement when terrain info is unavailable)
	assert_false(
		placer._is_below_terrain(Vector3(0, 10, 0)),
		"Above-ground position should not be flagged as underground (no terrain data)"
	)
	assert_false(
		placer._is_below_terrain(Vector3(0, 0, 0)),
		"Ground-level position should not be flagged as underground (no terrain data)"
	)
