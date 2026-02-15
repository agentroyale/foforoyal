extends GutTest
## Phase 3: Tool Cupboard unit tests.

const PLAYER_ID_1 := 1
const PLAYER_ID_2 := 2
const PLAYER_ID_3 := 3


func _make_tc(pos: Vector3 = Vector3.ZERO) -> ToolCupboard:
	var tc := ToolCupboard.new()
	# BuildingPiece needs MeshInstance3D + CollisionShape3D children
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	tc.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	tc.add_child(col)
	add_child_autofree(tc)
	tc.global_position = pos
	return tc


# ─── Test 1: Player inside TC, authorized → can build ───

func test_player_inside_tc_authorized() -> void:
	var tc := _make_tc(Vector3(100, 0, 100))
	tc.authorize_player(PLAYER_ID_1)

	# Position inside TC radius (50 units)
	var build_pos := Vector3(120, 0, 100)  # 20 units away
	var status := BuildingPrivilege.check_privilege(get_tree(), build_pos, PLAYER_ID_1)

	assert_eq(status, BuildingPrivilege.PrivilegeStatus.AUTHORIZED,
		"Authorized player inside TC should have AUTHORIZED status")
	assert_true(BuildingPrivilege.can_build(get_tree(), build_pos, PLAYER_ID_1),
		"Authorized player should be able to build")


# ─── Test 2: Player inside TC, NOT authorized → can't build ───

func test_player_inside_tc_unauthorized() -> void:
	var tc := _make_tc(Vector3(100, 0, 100))
	tc.authorize_player(PLAYER_ID_1)

	# Player 2 is NOT authorized
	var build_pos := Vector3(120, 0, 100)
	var status := BuildingPrivilege.check_privilege(get_tree(), build_pos, PLAYER_ID_2)

	assert_eq(status, BuildingPrivilege.PrivilegeStatus.UNAUTHORIZED,
		"Unauthorized player inside TC should have UNAUTHORIZED status")
	assert_false(BuildingPrivilege.can_build(get_tree(), build_pos, PLAYER_ID_2),
		"Unauthorized player should NOT be able to build")


# ─── Test 3: Player outside all TCs → free building ───

func test_player_outside_all_tc() -> void:
	var tc := _make_tc(Vector3(100, 0, 100))
	tc.authorize_player(PLAYER_ID_1)

	# Position far outside TC radius
	var build_pos := Vector3(500, 0, 500)  # way beyond 50 units
	var status := BuildingPrivilege.check_privilege(get_tree(), build_pos, PLAYER_ID_2)

	assert_eq(status, BuildingPrivilege.PrivilegeStatus.NO_TC,
		"Player outside all TCs should have NO_TC status")
	assert_true(BuildingPrivilege.can_build(get_tree(), build_pos, PLAYER_ID_2),
		"Player outside all TCs should build freely")


# ─── Test 4: Add and remove authorization ───

func test_add_remove_authorization() -> void:
	var tc := _make_tc()

	assert_false(tc.is_authorized(PLAYER_ID_1), "Initially not authorized")

	tc.authorize_player(PLAYER_ID_1)
	assert_true(tc.is_authorized(PLAYER_ID_1), "Authorized after add")

	tc.authorize_player(PLAYER_ID_2)
	assert_true(tc.is_authorized(PLAYER_ID_2), "Second player authorized")
	assert_eq(tc.authorized_players.size(), 2, "Should have 2 authorized players")

	# Adding same player again should not duplicate
	tc.authorize_player(PLAYER_ID_1)
	assert_eq(tc.authorized_players.size(), 2, "No duplicates allowed")

	tc.deauthorize_player(PLAYER_ID_1)
	assert_false(tc.is_authorized(PLAYER_ID_1), "Deauthorized after remove")
	assert_true(tc.is_authorized(PLAYER_ID_2), "Other player still authorized")


# ─── Test 5: Clear auth removes all ───

func test_clear_auth_removes_all() -> void:
	var tc := _make_tc()
	tc.authorize_player(PLAYER_ID_1)
	tc.authorize_player(PLAYER_ID_2)
	tc.authorize_player(PLAYER_ID_3)
	assert_eq(tc.authorized_players.size(), 3, "3 players authorized")

	tc.clear_authorization()
	assert_eq(tc.authorized_players.size(), 0, "All cleared")
	assert_false(tc.is_authorized(PLAYER_ID_1), "Player 1 no longer authorized")
	assert_false(tc.is_authorized(PLAYER_ID_2), "Player 2 no longer authorized")
	assert_false(tc.is_authorized(PLAYER_ID_3), "Player 3 no longer authorized")


# ─── Test 6: Multiple overlapping TCs ───

func test_multiple_overlapping_tcs() -> void:
	# TC1 at origin, player 1 authorized
	var tc1 := _make_tc(Vector3(0, 0, 0))
	tc1.authorize_player(PLAYER_ID_1)

	# TC2 at (30, 0, 0), player 2 authorized — overlaps with TC1
	var tc2 := _make_tc(Vector3(30, 0, 0))
	tc2.authorize_player(PLAYER_ID_2)

	# Position in overlap zone (15, 0, 0) — within 50u of both TCs
	var overlap_pos := Vector3(15, 0, 0)

	# Player 1: authorized in TC1, not in TC2 → should be AUTHORIZED (any TC grants)
	assert_true(BuildingPrivilege.can_build(get_tree(), overlap_pos, PLAYER_ID_1),
		"Player 1 authorized in TC1 should build in overlap")

	# Player 2: authorized in TC2, not in TC1 → should be AUTHORIZED
	assert_true(BuildingPrivilege.can_build(get_tree(), overlap_pos, PLAYER_ID_2),
		"Player 2 authorized in TC2 should build in overlap")

	# Player 3: not authorized in either → UNAUTHORIZED
	assert_false(BuildingPrivilege.can_build(get_tree(), overlap_pos, PLAYER_ID_3),
		"Player 3 unauthorized in both TCs should NOT build")

	# Verify covering TCs count
	var covering := BuildingPrivilege.get_covering_tcs(get_tree(), overlap_pos)
	assert_eq(covering.size(), 2, "Should have 2 covering TCs in overlap zone")
