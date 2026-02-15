extends GutTest
## TPS Hybrid Shooting System unit tests.


# ─── Helpers ───

func _make_camera() -> PlayerCamera:
	var pivot := PlayerCamera.new()
	pivot.name = "CameraPivot"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	pivot.add_child(cam)
	return pivot


func _make_weapon(
	weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.PISTOL,
	damage: float = 25.0,
	muzzle: Vector3 = Vector3(0, 0, -0.3)
) -> WeaponData:
	var w := WeaponData.new()
	w.item_name = "TestGun"
	w.max_stack_size = 1
	w.category = ItemData.Category.WEAPON
	w.weapon_type = weapon_type
	w.base_damage = damage
	w.fire_rate = 0.1
	w.max_range = 100.0
	w.falloff_start = 50.0
	w.magazine_size = 10
	w.reload_time = 1.0
	w.muzzle_offset = muzzle
	return w


func _make_recoil_pattern(offsets: Array[Vector2] = [], recovery: float = 5.0) -> RecoilPattern:
	var rp := RecoilPattern.new()
	rp.offsets = offsets
	rp.recovery_speed = recovery
	return rp


func _make_crosshair() -> CrosshairUI:
	var ch := CrosshairUI.new()
	add_child_autofree(ch)
	return ch


func _make_player_with_camera() -> CharacterBody3D:
	var player := CharacterBody3D.new()
	var pivot := _make_camera()
	player.add_child(pivot)
	var inv := PlayerInventory.new()
	inv.name = "PlayerInventory"
	player.add_child(inv)
	var wc := WeaponController.new()
	wc.name = "WeaponController"
	player.add_child(wc)
	add_child_autofree(player)
	return player


# ─── Test 1: Shoulder Offset Default Right ───

func test_shoulder_offset_default_right() -> void:
	var cam := _make_camera()
	add_child_autofree(cam)
	assert_eq(cam._target_shoulder_side, 1.0, "Default shoulder side is right (1.0)")
	assert_eq(cam._current_shoulder_side, 1.0, "Current shoulder side starts right (1.0)")


# ─── Test 2: Shoulder Swap Toggles ───

func test_shoulder_swap_toggles() -> void:
	var cam := _make_camera()
	add_child_autofree(cam)
	assert_eq(cam._target_shoulder_side, 1.0, "Starts right")

	# Simulate swap
	cam._target_shoulder_side = -cam._target_shoulder_side
	assert_eq(cam._target_shoulder_side, -1.0, "After swap: left (-1.0)")

	cam._target_shoulder_side = -cam._target_shoulder_side
	assert_eq(cam._target_shoulder_side, 1.0, "After double swap: right (1.0)")


# ─── Test 3: ADS FOV Less Than Normal ───

func test_ads_fov_less_than_normal() -> void:
	assert_lt(PlayerCamera.ADS_FOV, PlayerCamera.DEFAULT_NORMAL_FOV,
		"ADS FOV (%s) < Normal FOV (%s)" % [PlayerCamera.ADS_FOV, PlayerCamera.DEFAULT_NORMAL_FOV])


# ─── Test 4: ADS Sensitivity Reduced ───

func test_ads_sensitivity_reduced() -> void:
	assert_lt(PlayerCamera.ADS_SENSITIVITY_MULT, 1.0,
		"ADS sensitivity mult (%s) < 1.0" % PlayerCamera.ADS_SENSITIVITY_MULT)


# ─── Test 5: Crosshair Fire Expands ───

func test_crosshair_fire_expands() -> void:
	var ch := _make_crosshair()
	assert_eq(ch._fire_expand, 0.0, "No expand at start")

	ch.fire_pulse()
	assert_gt(ch._fire_expand, 0.0, "Expand > 0 after fire_pulse()")
	assert_eq(ch._fire_expand, CrosshairUI.FIRE_EXPAND,
		"Expand equals FIRE_EXPAND constant")


# ─── Test 6: Crosshair Hitmarker Headshot Longer ───

func test_crosshair_hitmarker_headshot_longer() -> void:
	var ch := _make_crosshair()

	ch.show_hitmarker(false)
	var normal_timer := ch._hitmarker_timer

	ch.show_hitmarker(true)
	var headshot_timer := ch._hitmarker_timer

	assert_gt(headshot_timer, normal_timer,
		"Headshot timer (%s) > normal timer (%s)" % [headshot_timer, normal_timer])
	assert_true(ch._hitmarker_is_headshot, "Headshot flag set")


# ─── Test 7: Weapon Visual Creates Muzzle ───

func test_weapon_visual_creates_muzzle() -> void:
	# WeaponVisual needs a real Skeleton3D
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("root")
	skeleton.add_bone("hips")
	skeleton.set_bone_parent(1, 0)
	skeleton.add_bone("spine")
	skeleton.set_bone_parent(2, 1)
	skeleton.add_bone("chest")
	skeleton.set_bone_parent(3, 2)
	skeleton.add_bone("upperarm.r")
	skeleton.set_bone_parent(4, 3)
	skeleton.add_bone("lowerarm.r")
	skeleton.set_bone_parent(5, 4)
	skeleton.add_bone("wrist.r")
	skeleton.set_bone_parent(6, 5)
	skeleton.add_bone("hand.r")
	skeleton.set_bone_parent(7, 6)
	skeleton.add_bone("handslot.r")
	skeleton.set_bone_parent(8, 7)
	add_child_autofree(skeleton)

	var weapon := _make_weapon()
	var wv := WeaponVisual.new()
	wv.setup(skeleton, weapon)

	# After setup, muzzle should exist (might be zero because skeleton has no transforms)
	# But the bone attachment and marker should be created
	assert_not_null(wv._bone_attachment, "Bone attachment created")
	assert_not_null(wv._muzzle_marker, "Muzzle marker created")

	wv.clear()


# ─── Test 8: Bone Aim Pitch Split ───

func test_bone_aim_pitch_split() -> void:
	# Verify the constants sum to 1.0 (full pitch coverage)
	var total := PlayerModel.SPINE_PITCH_WEIGHT + PlayerModel.CHEST_PITCH_WEIGHT
	assert_almost_eq(total, 1.0, 0.001,
		"Spine (%s) + Chest (%s) = 1.0" % [PlayerModel.SPINE_PITCH_WEIGHT, PlayerModel.CHEST_PITCH_WEIGHT])
	assert_almost_eq(PlayerModel.SPINE_PITCH_WEIGHT, 0.4, 0.001, "Spine weight = 0.4")
	assert_almost_eq(PlayerModel.CHEST_PITCH_WEIGHT, 0.6, 0.001, "Chest weight = 0.6")


# ─── Test 9: Recoil Halved in ADS ───

func test_recoil_halved_in_ads() -> void:
	var player := _make_player_with_camera()
	var wc := player.get_node("WeaponController") as WeaponController
	var inv := player.get_node("PlayerInventory") as PlayerInventory
	var cam := player.get_node("CameraPivot") as PlayerCamera

	var weapon := _make_weapon()
	weapon.recoil_pattern = _make_recoil_pattern(
		[Vector2(0.0, 10.0)] as Array[Vector2], 5.0
	)
	inv.hotbar.add_item(weapon, 1)
	wc.equip_weapon(weapon)

	# Fire without ADS
	cam.is_aiming = false
	wc._fire(weapon)
	var recoil_no_ads := wc.get_accumulated_recoil().y

	# Reset
	wc._accumulated_recoil = Vector2.ZERO
	wc._shot_count = 0

	# Fire with ADS
	cam.is_aiming = true
	wc._fire(weapon)
	var recoil_ads := wc.get_accumulated_recoil().y

	assert_almost_eq(recoil_ads, recoil_no_ads * 0.5, 0.01,
		"ADS recoil (%s) = half of normal (%s)" % [recoil_ads, recoil_no_ads])


# ─── Test 10: Hit Confirmed Signal ───

func test_hit_confirmed_signal() -> void:
	var player := _make_player_with_camera()
	var wc := player.get_node("WeaponController") as WeaponController

	var received := []
	wc.hit_confirmed.connect(func(hitzone: int, is_kill: bool):
		received.append({"hitzone": hitzone, "is_kill": is_kill})
	)

	# Manually emit to verify signal connectivity
	wc.hit_confirmed.emit(HitzoneSystem.Hitzone.HEAD, true)

	assert_eq(received.size(), 1, "Signal received once")
	assert_eq(received[0]["hitzone"], HitzoneSystem.Hitzone.HEAD, "Hitzone is HEAD")
	assert_true(received[0]["is_kill"], "Is kill")

	# Test chest hit
	wc.hit_confirmed.emit(HitzoneSystem.Hitzone.CHEST, false)
	assert_eq(received.size(), 2, "Second signal received")
	assert_eq(received[1]["hitzone"], HitzoneSystem.Hitzone.CHEST, "Hitzone is CHEST")
	assert_false(received[1]["is_kill"], "Not a kill")


# ─── Test 11: Fire Burst Uses Animation Length ───

func test_fire_burst_uses_animation_length() -> void:
	var model := PlayerModel.new()
	model.name = "PlayerModel"
	var player := CharacterBody3D.new()
	player.add_child(model)
	add_child_autofree(player)

	# PlayerModel creates its own AnimationPlayer in _ready.
	# Add a dummy animation to test fire burst duration.
	var anim := Animation.new()
	anim.length = 0.75
	var lib := AnimationLibrary.new()
	lib.add_animation("TestShoot", anim)
	model._anim_player.add_animation_library("test", lib)

	model._play_fire_burst("test/TestShoot")

	assert_almost_eq(model._fire_burst_timer, 0.75, 0.001,
		"Fire burst timer matches animation length (0.75)")
	assert_eq(model._current_anim, "test/TestShoot",
		"Current anim set to fire burst anim")


# ─── Test 12: Aim Animation During Walk ───

func test_aim_animation_during_walk() -> void:
	# Test _play_anim_hold: sets _wants_hold and plays animation.
	# Note: full locomotion test requires physics world (is_on_floor),
	# so we test the hold mechanism directly.
	var model := PlayerModel.new()
	model.name = "PlayerModel"
	var player := CharacterBody3D.new()
	player.add_child(model)
	add_child_autofree(player)

	# Add dummy animations only if not already loaded from GLBs
	if not model._anim_player.has_animation("ranged/Ranged_1H_Aiming"):
		var anim := Animation.new()
		anim.length = 1.0
		var lib := AnimationLibrary.new()
		lib.add_animation("Ranged_1H_Aiming", anim)
		model._anim_player.add_animation_library("ranged", lib)

	# _play_anim_hold should set _wants_hold and play
	model._play_anim_hold("ranged/Ranged_1H_Aiming")

	assert_eq(model._current_anim, "ranged/Ranged_1H_Aiming",
		"Hold plays the aiming animation")
	assert_true(model._wants_hold,
		"_wants_hold is set for hold animations")

	# _play_anim should reset _wants_hold
	if not model._anim_player.has_animation("general/Idle_A"):
		var idle_anim := Animation.new()
		idle_anim.length = 2.0
		idle_anim.loop_mode = Animation.LOOP_LINEAR
		var gen_lib := AnimationLibrary.new()
		gen_lib.add_animation("Idle_A", idle_anim)
		model._anim_player.add_animation_library("general", gen_lib)

	model._play_anim("general/Idle_A")

	assert_eq(model._current_anim, "general/Idle_A",
		"Normal play switches animation")
	assert_false(model._wants_hold,
		"_wants_hold reset by normal play")
