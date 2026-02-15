extends GutTest
## WarZ-style spread/bloom system unit tests.


# ─── Helpers ───

func _make_weapon(
	base_spread: float = 0.5,
	min_spread: float = 0.1,
	bloom_per_shot: float = 0.8,
	max_bloom: float = 5.0,
	bloom_decay_rate: float = 8.0,
	weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.PISTOL
) -> WeaponData:
	var w := WeaponData.new()
	w.item_name = "TestGun"
	w.max_stack_size = 1
	w.category = ItemData.Category.WEAPON
	w.weapon_type = weapon_type
	w.base_damage = 25.0
	w.fire_rate = 0.1
	w.max_range = 100.0
	w.falloff_start = 50.0
	w.magazine_size = 10
	w.reload_time = 1.0
	w.base_spread = base_spread
	w.min_spread = min_spread
	w.bloom_per_shot = bloom_per_shot
	w.max_bloom = max_bloom
	w.bloom_decay_rate = bloom_decay_rate
	return w


func _make_player_with_weapon_ctrl() -> CharacterBody3D:
	var player := CharacterBody3D.new()
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	player.add_child(pivot)
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	var wc := WeaponController.new()
	wc.name = "WeaponController"
	player.add_child(wc)
	add_child_autofree(player)
	return player


# ─── Test 1: Movement Multiplier Values ───

func test_movement_multipliers() -> void:
	var idle := SpreadSystem.get_movement_multiplier(SpreadSystem.MovementState.IDLE)
	var walk := SpreadSystem.get_movement_multiplier(SpreadSystem.MovementState.WALKING)
	var sprint := SpreadSystem.get_movement_multiplier(SpreadSystem.MovementState.SPRINTING)
	var crouch := SpreadSystem.get_movement_multiplier(SpreadSystem.MovementState.CROUCHING)
	var air := SpreadSystem.get_movement_multiplier(SpreadSystem.MovementState.AIRBORNE)

	assert_eq(idle, 1.0, "Idle = 1.0x")
	assert_gt(walk, idle, "Walking > idle")
	assert_gt(sprint, walk, "Sprinting > walking")
	assert_lt(crouch, idle, "Crouching < idle")
	assert_gt(air, sprint, "Airborne > sprinting")


# ─── Test 2: Bloom Increases Per Shot And Caps ───

func test_bloom_increases_and_caps() -> void:
	var bloom := 0.0
	bloom = SpreadSystem.calculate_bloom_after_shot(bloom, 0.8, 5.0)
	assert_almost_eq(bloom, 0.8, 0.01, "First shot: 0.8 bloom")

	bloom = SpreadSystem.calculate_bloom_after_shot(bloom, 0.8, 5.0)
	assert_almost_eq(bloom, 1.6, 0.01, "Second shot: 1.6 bloom")

	bloom = 4.5
	bloom = SpreadSystem.calculate_bloom_after_shot(bloom, 0.8, 5.0)
	assert_almost_eq(bloom, 5.0, 0.01, "Capped at max_bloom 5.0")


# ─── Test 3: Bloom Decays Over Time ───

func test_bloom_decays() -> void:
	var bloom := 4.0
	bloom = SpreadSystem.decay_bloom(bloom, 0.5, 8.0)
	assert_almost_eq(bloom, 0.0, 0.01, "4.0 - (8.0 * 0.5) = 0.0")

	bloom = 4.0
	bloom = SpreadSystem.decay_bloom(bloom, 0.25, 8.0)
	assert_almost_eq(bloom, 2.0, 0.01, "4.0 - (8.0 * 0.25) = 2.0")


# ─── Test 4: First Shot Accuracy Check ───

func test_first_shot_accuracy() -> void:
	assert_true(SpreadSystem.is_first_shot_accurate(0.5), "0.5s pause = first shot accurate")
	assert_true(SpreadSystem.is_first_shot_accurate(999.0), "Long pause = first shot accurate")
	assert_false(SpreadSystem.is_first_shot_accurate(0.1), "0.1s = NOT first shot accurate")
	assert_false(SpreadSystem.is_first_shot_accurate(0.0), "0.0s = NOT first shot accurate")


# ─── Test 5: Spread Deviates Direction ───

func test_spread_deviates_direction() -> void:
	var base_dir := Vector3(0, 0, -1)

	var zero_spread := SpreadSystem.apply_spread_to_direction(base_dir, 0.0)
	assert_almost_eq(zero_spread.x, 0.0, 0.001, "Zero spread: no X deviation")
	assert_almost_eq(zero_spread.z, -1.0, 0.001, "Zero spread: Z stays -1")

	var deviated := SpreadSystem.apply_spread_to_direction(base_dir, 5.0)
	var angle := rad_to_deg(acos(clampf(base_dir.dot(deviated), -1.0, 1.0)))
	assert_lt(angle, 5.5, "Deviation angle <= spread + tolerance")
	assert_almost_eq(deviated.length(), 1.0, 0.001, "Result is normalized")


# ─── Test 6: Movement State Detection ───

func test_movement_state_detection() -> void:
	var air := SpreadSystem.get_movement_state(5.0, true, false, 4.0, 6.5)
	assert_eq(air, SpreadSystem.MovementState.AIRBORNE, "Not on floor = AIRBORNE")

	var crouch := SpreadSystem.get_movement_state(2.0, true, true, 4.0, 6.5)
	assert_eq(crouch, SpreadSystem.MovementState.CROUCHING, "Crouching on floor = CROUCHING")

	var sprint := SpreadSystem.get_movement_state(6.5, false, true, 4.0, 6.5)
	assert_eq(sprint, SpreadSystem.MovementState.SPRINTING, "Speed >= sprint = SPRINTING")

	var walk := SpreadSystem.get_movement_state(3.0, false, true, 4.0, 6.5)
	assert_eq(walk, SpreadSystem.MovementState.WALKING, "Speed > 0.5 = WALKING")

	var idle := SpreadSystem.get_movement_state(0.2, false, true, 4.0, 6.5)
	assert_eq(idle, SpreadSystem.MovementState.IDLE, "Speed < 0.5 = IDLE")


# ─── Test 7: Crouch Recoil Multiplier ───

func test_crouch_recoil_multiplier() -> void:
	var mult := SpreadSystem.get_crouch_recoil_multiplier()
	assert_almost_eq(mult, 0.7, 0.001, "Crouch recoil mult = 0.7 (30% reduction)")


# ─── Test 8: Full Spread Calculation ───

func test_spread_calculation_combines_all() -> void:
	var base := 0.5
	var bloom := 2.0
	var movement_mult := 1.5

	var spread := SpreadSystem.calculate_current_spread(base, bloom, movement_mult)
	assert_almost_eq(spread, (0.5 + 2.0) * 1.5, 0.01, "(base+bloom) * mult = 3.75")

	var crouch_spread := SpreadSystem.calculate_current_spread(base, bloom, 0.6)
	assert_almost_eq(crouch_spread, (0.5 + 2.0) * 0.6, 0.01, "Crouch spread = 1.5")
	assert_lt(crouch_spread, spread, "Crouch tighter than walking")


# ─── Test 9: WeaponController Bloom On Fire ───

func test_weapon_controller_bloom_on_fire() -> void:
	var player := _make_player_with_weapon_ctrl()
	var wc := player.get_node("WeaponController") as WeaponController
	var inv := player.get_node("PlayerInventory") as PlayerInventory

	var weapon := _make_weapon(0.5, 0.1, 0.8, 5.0, 8.0)
	inv.hotbar.add_item(weapon, 1)
	wc.equip_weapon(weapon)

	assert_almost_eq(wc.get_current_bloom(), 0.0, 0.01, "Bloom starts at 0")

	wc._fire(weapon)
	assert_almost_eq(wc.get_current_bloom(), 0.8, 0.01, "Bloom = 0.8 after 1 shot")

	wc._fire(weapon)
	assert_almost_eq(wc.get_current_bloom(), 1.6, 0.01, "Bloom = 1.6 after 2 shots")

	wc._update_bloom_decay(0.1)
	assert_almost_eq(wc.get_current_bloom(), 0.8, 0.1, "Bloom decayed after 0.1s")


# ─── Test 10: Crosshair Spread To Pixels ───

func test_crosshair_spread_conversion() -> void:
	var ch := CrosshairUI.new()
	add_child_autofree(ch)

	ch.set_spread(0.0)
	assert_almost_eq(ch._spread_gap, 0.0, 0.01, "Zero spread = zero gap")

	ch.set_spread(2.0)
	assert_almost_eq(ch._spread_gap, 2.0 * CrosshairUI.SPREAD_TO_PIXELS, 0.01,
		"2 degrees = %s pixels" % (2.0 * CrosshairUI.SPREAD_TO_PIXELS))
	assert_gt(ch._spread_gap, 0.0, "Non-zero spread = non-zero gap")
