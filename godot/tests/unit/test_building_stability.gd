extends GutTest
## Tests for BuildingStability structural integrity system.


func _make_piece(piece_type: BuildingPieceData.PieceType) -> BuildingPiece:
	var piece := BuildingPiece.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	var data := BuildingPieceData.new()
	data.piece_type = piece_type
	piece.piece_data = data
	add_child_autofree(piece)
	return piece


func _make_socket(parent_piece: BuildingPiece, allowed: Array[BuildingPieceData.PieceType]) -> BuildingSocket:
	var socket := BuildingSocket.new()
	socket.allowed_pieces = allowed
	parent_piece.add_child(socket)
	return socket


# ─── Test 1: Foundation Has Full Stability ───

func test_foundation_has_full_stability() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)
	assert_eq(foundation.stability, 1.0, "Foundation should have stability 1.0")


# ─── Test 2: Wall on Foundation Stability ───

func test_wall_on_foundation_stability() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var socket := _make_socket(foundation, [BuildingPieceData.PieceType.WALL])
	var wall := _make_piece(BuildingPieceData.PieceType.WALL)
	wall.support_parent_socket = socket
	socket.occupy(wall)

	BuildingStability.calculate_stability(wall)
	assert_almost_eq(wall.stability, 0.86, 0.001, "Wall on foundation should have stability 0.86")


# ─── Test 3: Doorway Lower Than Wall ───

func test_doorway_lower_than_wall() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var socket := _make_socket(foundation, [BuildingPieceData.PieceType.DOORWAY])
	var doorway := _make_piece(BuildingPieceData.PieceType.DOORWAY)
	doorway.support_parent_socket = socket
	socket.occupy(doorway)

	BuildingStability.calculate_stability(doorway)
	assert_almost_eq(doorway.stability, 0.70, 0.001, "Doorway on foundation should have stability 0.70")


# ─── Test 4: Pillar High Stability ───

func test_pillar_high_stability() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var socket := _make_socket(foundation, [BuildingPieceData.PieceType.PILLAR])
	var pillar := _make_piece(BuildingPieceData.PieceType.PILLAR)
	pillar.support_parent_socket = socket
	socket.occupy(pillar)

	BuildingStability.calculate_stability(pillar)
	assert_almost_eq(pillar.stability, 0.90, 0.001, "Pillar on foundation should have stability 0.90")


# ─── Test 5: Floor on Wall Chain ───

func test_floor_on_wall_chain() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var wall_socket := _make_socket(foundation, [BuildingPieceData.PieceType.WALL])
	var wall := _make_piece(BuildingPieceData.PieceType.WALL)
	wall.support_parent_socket = wall_socket
	wall_socket.occupy(wall)
	BuildingStability.calculate_stability(wall)

	var floor_socket := _make_socket(wall, [BuildingPieceData.PieceType.FLOOR])
	var floor_piece := _make_piece(BuildingPieceData.PieceType.FLOOR)
	floor_piece.support_parent_socket = floor_socket
	floor_socket.occupy(floor_piece)
	BuildingStability.calculate_stability(floor_piece)

	# 1.0 * 0.86 * 0.80 = 0.688
	assert_almost_eq(floor_piece.stability, 0.688, 0.001,
		"Floor on wall on foundation should have stability 0.688")


# ─── Test 6: Half Wall Low Stability ───

func test_half_wall_low_stability() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var socket := _make_socket(foundation, [BuildingPieceData.PieceType.HALF_WALL])
	var half_wall := _make_piece(BuildingPieceData.PieceType.HALF_WALL)
	half_wall.support_parent_socket = socket
	socket.occupy(half_wall)

	BuildingStability.calculate_stability(half_wall)
	assert_almost_eq(half_wall.stability, 0.50, 0.001, "Half wall on foundation should have stability 0.50")


# ─── Test 7: Cascade Collapse ───

func test_cascade_collapse() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var wall_socket := _make_socket(foundation, [BuildingPieceData.PieceType.WALL])
	var wall := _make_piece(BuildingPieceData.PieceType.WALL)
	wall.support_parent_socket = wall_socket
	wall_socket.occupy(wall)
	BuildingStability.calculate_stability(wall)

	var floor_socket := _make_socket(wall, [BuildingPieceData.PieceType.FLOOR])
	var floor_piece := _make_piece(BuildingPieceData.PieceType.FLOOR)
	floor_piece.support_parent_socket = floor_socket
	floor_socket.occupy(floor_piece)
	BuildingStability.calculate_stability(floor_piece)

	# Destroy wall — floor should be orphaned and cascade destroyed
	wall._destroy()

	# Wait for queue_free to process
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(floor_piece),
		"Floor should be destroyed after wall is destroyed (cascade)")


# ─── Test 8: Independent Foundations ───

func test_independent_foundations() -> void:
	var foundation_a := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation_a)

	var foundation_b := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation_b)

	foundation_a._destroy()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(is_instance_valid(foundation_b), "Foundation B should be unaffected")
	assert_eq(foundation_b.stability, 1.0, "Foundation B stability should remain 1.0")


# ─── Test 9: Min Stability Threshold ───

func test_min_stability_threshold() -> void:
	# Chain of half_walls: each reduces by 0.5
	# Depth 5: 0.5^5 = 0.03125 < MIN_STABILITY (0.05) → should collapse
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	BuildingStability.calculate_stability(foundation)

	var parent: BuildingPiece = foundation
	var last_piece: BuildingPiece = null
	for i in range(5):
		var socket := _make_socket(parent, [BuildingPieceData.PieceType.HALF_WALL])
		var hw := _make_piece(BuildingPieceData.PieceType.HALF_WALL)
		hw.support_parent_socket = socket
		socket.occupy(hw)
		BuildingStability.calculate_stability(hw)
		parent = hw
		last_piece = hw

	# The 5th piece should have been destroyed (stability 0.5^5 = 0.03125 < 0.05)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(last_piece),
		"5th half_wall should collapse (stability 0.03 < MIN_STABILITY 0.05)")


# ─── Test 10: Foundations Unaffected by Recalc ───

func test_foundations_unaffected_by_recalc() -> void:
	var foundation := _make_piece(BuildingPieceData.PieceType.FOUNDATION)
	foundation.stability = 0.5  # Force a bad value
	BuildingStability.calculate_stability(foundation)
	assert_eq(foundation.stability, 1.0, "Foundation stability should always be 1.0 after recalc")

	var tri := _make_piece(BuildingPieceData.PieceType.TRIANGLE_FOUNDATION)
	tri.stability = 0.1
	BuildingStability.calculate_stability(tri)
	assert_eq(tri.stability, 1.0, "Triangle foundation should always be 1.0 after recalc")
