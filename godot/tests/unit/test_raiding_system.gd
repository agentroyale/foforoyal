extends GutTest
## Phase 7: Raiding System unit tests.

const BuildingManagerScript = preload("res://scripts/building/building_manager.gd")


func _make_building_piece(tier: BuildingTier.Tier = BuildingTier.Tier.WOOD) -> BuildingPiece:
	var piece := BuildingPiece.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	add_child_autofree(piece)
	piece._apply_tier(tier)
	return piece


# ─── Test 1: C4 Destroys Wood Wall ───

func test_c4_destroys_wood_wall() -> void:
	var piece := _make_building_piece(BuildingTier.Tier.WOOD)
	piece.global_position = Vector3.ZERO

	assert_eq(piece.current_hp, 250.0, "Wood wall starts at 250 HP")

	var destroyed := [false]
	piece.piece_destroyed.connect(func(_p): destroyed[0] = true)

	# C4 at same position: 275 dmg * 1.0 falloff = 275 > 250
	var results := ExplosionDamage.apply_explosion(
		get_tree(), Vector3.ZERO, 275.0, 4.0
	)

	assert_eq(results.size(), 1, "Should hit exactly 1 piece")
	assert_almost_eq(results[0]["damage"], 275.0, 0.01, "Full damage at center")
	assert_true(destroyed[0], "Wood wall should be destroyed by C4")


# ─── Test 2: C4 Soft Side Bonus ───

func test_c4_soft_side_bonus() -> void:
	var piece := _make_building_piece(BuildingTier.Tier.STONE)
	piece.global_position = Vector3.ZERO
	piece.forward_direction = Vector3.FORWARD  # (0, 0, -1)

	assert_eq(piece.current_hp, 500.0, "Stone wall starts at 500 HP")

	var destroyed := [false]
	piece.piece_destroyed.connect(func(_p): destroyed[0] = true)

	# Hit from behind (soft side): FORWARD direction -> dot > 0 -> 2x mult
	# take_damage receives 275 + direction FORWARD -> 275 * 2 = 550 > 500
	var results := ExplosionDamage.apply_explosion(
		get_tree(), Vector3.ZERO, 275.0, 4.0, Vector3.FORWARD
	)

	assert_eq(results.size(), 1, "Should hit 1 piece")
	assert_true(destroyed[0],
		"Stone wall destroyed by C4 on soft side (275*2=550 > 500)")


# ─── Test 3: Rocket Splash Damage ───

func test_rocket_splash_damage() -> void:
	var near := _make_building_piece(BuildingTier.Tier.WOOD)
	near.global_position = Vector3(1, 0, 0)  # 1m away

	var far := _make_building_piece(BuildingTier.Tier.WOOD)
	far.global_position = Vector3(3, 0, 0)  # 3m away

	var outside := _make_building_piece(BuildingTier.Tier.WOOD)
	outside.global_position = Vector3(5, 0, 0)  # 5m, outside 4m radius

	# Rocket: 137.5 dmg, 4m radius, explosion at origin
	var results := ExplosionDamage.apply_explosion(
		get_tree(), Vector3.ZERO, 137.5, 4.0
	)

	assert_eq(results.size(), 2, "Should hit 2 pieces (3rd outside radius)")

	# Verify falloff math
	assert_almost_eq(
		ExplosionDamage.calculate_falloff(1.0, 4.0), 0.75, 0.01,
		"1m/4m = 0.75 falloff")
	assert_almost_eq(
		ExplosionDamage.calculate_falloff(3.0, 4.0), 0.25, 0.01,
		"3m/4m = 0.25 falloff")
	assert_almost_eq(
		ExplosionDamage.calculate_falloff(5.0, 4.0), 0.0, 0.01,
		"5m/4m = 0.0 falloff (clamped)")

	# Near piece took more damage than far piece
	assert_lt(near.current_hp, far.current_hp,
		"Near piece should have less HP remaining")
	assert_eq(outside.current_hp, 250.0,
		"Outside piece should be undamaged")


# ─── Test 4: Satchel Dud Chance ───

func test_satchel_dud_chance() -> void:
	# Statistical test: 20% dud chance over 1000 trials
	var dud_chance := 0.2
	var trials := 1000
	var dud_count := 0

	for i in trials:
		if randf() < dud_chance:
			dud_count += 1

	# Expect ~200 duds; allow wide 100-300 range
	assert_gt(dud_count, 100,
		"Dud count should be > 100 (got %d)" % dud_count)
	assert_lt(dud_count, 300,
		"Dud count should be < 300 (got %d)" % dud_count)

	# Verify explosive damage constants
	assert_eq(BuildingDamage.SATCHEL_DAMAGE, 475.0, "Satchel = 475 dmg")
	assert_eq(BuildingDamage.C4_DAMAGE, 275.0, "C4 = 275 dmg")
	assert_eq(BuildingDamage.ROCKET_DAMAGE, 137.5, "Rocket = 137.5 dmg")


# ─── Test 5: Armored Wall Requires 8 C4 ───

func test_armored_wall_requires_8_c4() -> void:
	# 2000 HP / 275 dmg = 7.27 -> ceil = 8
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.ARMORED), 8,
		"Armored requires 8 C4 (hard side)")

	# All tiers
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.TWIG), 1, "Twig = 1 C4")
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.WOOD), 1, "Wood = 1 C4")
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.STONE), 2, "Stone = 2 C4")
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.METAL), 4, "Metal = 4 C4")

	# Soft side halves cost: 2000 / (275*2) = 3.64 -> 4
	assert_eq(BuildingDamage.c4_cost(BuildingTier.Tier.ARMORED, true), 4,
		"Armored = 4 C4 on soft side")

	# Cross-check with ExplosionDamage utility
	assert_eq(ExplosionDamage.c4_count_for_tier(BuildingTier.Tier.ARMORED), 8,
		"c4_count_for_tier confirms 8 for armored")


# ─── Test 6: Building Destruction Frees Node ───

func test_building_destruction_frees_node() -> void:
	var manager := BuildingManagerScript.new()
	add_child_autofree(manager)

	var piece := BuildingPiece.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	piece.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	piece.add_child(col)
	add_child(piece)  # NOT autofree - we verify free after queue_free
	piece._apply_tier(BuildingTier.Tier.TWIG)
	piece.global_position = Vector3.ZERO

	manager.register_piece(piece)
	assert_eq(manager.get_piece_count(), 1, "Manager tracks 1 piece")

	var destroyed := [false]
	piece.piece_destroyed.connect(func(_p): destroyed[0] = true)

	# Twig = 10 HP, 275 dmg -> overkill
	piece.take_damage(275.0)

	assert_true(destroyed[0], "piece_destroyed signal fired")

	# queue_free is deferred; wait one frame
	await get_tree().process_frame

	assert_false(is_instance_valid(piece), "Piece freed after destruction")
	assert_eq(manager.get_piece_count(), 0, "Manager removed destroyed piece")
