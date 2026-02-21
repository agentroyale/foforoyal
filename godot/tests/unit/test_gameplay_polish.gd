extends GutTest
## Tests for gameplay polish: footsteps, combat sfx, damage numbers, weapon bob.


func test_footstep_streams_valid() -> void:
	var fs := get_node_or_null("/root/FootstepSfx")
	assert_not_null(fs, "FootstepSfx autoload exists")
	if not fs:
		return
	assert_eq(fs._walk_streams.size(), 3, "3 walk variants")
	assert_eq(fs._run_streams.size(), 3, "3 run variants")
	assert_eq(fs._crouch_streams.size(), 2, "2 crouch variants")
	assert_eq(fs._land_streams.size(), 2, "2 land variants")
	for stream in fs._walk_streams:
		assert_gt(stream.data.size(), 0, "Walk stream has PCM data")
	for stream in fs._run_streams:
		assert_gt(stream.data.size(), 0, "Run stream has PCM data")


func test_footstep_pool_cycling() -> void:
	var fs := get_node_or_null("/root/FootstepSfx")
	if not fs:
		pass_test("FootstepSfx not loaded in test env")
		return
	var initial: int = fs._next_player
	fs.play_walk()
	assert_eq(fs._next_player, (initial + 1) % fs.POOL_SIZE, "Pool index advances")


func test_footstep_step_intervals() -> void:
	var fs := get_node_or_null("/root/FootstepSfx")
	if not fs:
		pass_test("FootstepSfx not loaded")
		return
	assert_almost_eq(fs.WALK_INTERVAL, 0.5, 0.001, "Walk interval 0.5s")
	assert_almost_eq(fs.RUN_INTERVAL, 0.32, 0.001, "Run interval 0.32s")
	assert_almost_eq(fs.CROUCH_INTERVAL, 0.7, 0.001, "Crouch interval 0.7s")


func test_combat_sfx_streams_valid() -> void:
	var cs := get_node_or_null("/root/CombatSfx")
	assert_not_null(cs, "CombatSfx autoload exists")
	if not cs:
		return
	assert_not_null(cs._hit_body, "hit_body stream exists")
	assert_not_null(cs._hit_headshot, "hit_headshot stream exists")
	assert_not_null(cs._damage_taken, "damage_taken stream exists")
	assert_not_null(cs._kill_confirm, "kill_confirm stream exists")
	assert_not_null(cs._heartbeat, "heartbeat stream exists")
	assert_gt(cs._hit_body.data.size(), 0, "hit_body has PCM data")
	assert_gt(cs._kill_confirm.data.size(), 0, "kill_confirm has PCM data")
	assert_gt(cs._heartbeat.data.size(), 0, "heartbeat has PCM data")


func test_combat_sfx_play_no_crash() -> void:
	var cs := get_node_or_null("/root/CombatSfx")
	if not cs:
		pass_test("CombatSfx not loaded in test env")
		return
	cs.play_hit_body()
	cs.play_hit_headshot()
	cs.play_damage_taken()
	cs.play_kill_confirm()
	cs.play_heartbeat()
	assert_true(true, "All CombatSfx play methods execute without crash")


func test_combat_sfx_pool_cycling() -> void:
	var cs := get_node_or_null("/root/CombatSfx")
	if not cs:
		pass_test("CombatSfx not loaded")
		return
	var initial: int = cs._next_player
	cs.play_hit_body()
	assert_eq(cs._next_player, (initial + 1) % cs.POOL_SIZE, "CombatSfx pool advances")


func test_damage_number_create_chest() -> void:
	var dn := DamageNumber.create(42.0, Vector3(10, 5, 10), HitzoneSystem.Hitzone.CHEST)
	assert_not_null(dn, "DamageNumber created")
	assert_true(dn is Label3D, "DamageNumber is Label3D")
	assert_eq(dn.text, "42", "Text matches rounded damage")
	assert_eq(dn.font_size, 48, "Chest font size is 48")
	assert_true(dn.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Billboard enabled")
	assert_true(dn.no_depth_test, "No depth test")
	dn.free()


func test_damage_number_create_head() -> void:
	var dn := DamageNumber.create(100.0, Vector3.ZERO, HitzoneSystem.Hitzone.HEAD)
	assert_not_null(dn)
	assert_eq(dn.font_size, 64, "Head font size is 64")
	assert_almost_eq(dn.modulate.r, 1.0, 0.01, "Head color red channel")
	assert_almost_eq(dn.modulate.g, 0.2, 0.01, "Head color green channel")
	dn.free()


func test_damage_number_create_limbs() -> void:
	var dn := DamageNumber.create(15.0, Vector3.ZERO, HitzoneSystem.Hitzone.LIMBS)
	assert_not_null(dn)
	assert_eq(dn.text, "15", "Limb damage text correct")
	assert_eq(dn.font_size, 48, "Limb font size is 48")
	assert_almost_eq(dn.modulate.r, 0.7, 0.01, "Limb color grey")
	dn.free()


func test_damage_number_rounding() -> void:
	var dn := DamageNumber.create(33.7, Vector3.ZERO, HitzoneSystem.Hitzone.CHEST)
	assert_eq(dn.text, "34", "Damage rounds to nearest int")
	dn.free()


func test_weapon_bob_no_pivot() -> void:
	var wv := WeaponVisual.new()
	# Should not crash even without pivot
	wv.update_bob(0.016, 5.0, false)
	wv.update_bob(0.016, 0.0, false)
	assert_true(true, "update_bob without pivot doesn't crash")


func test_weapon_bob_with_pivot() -> void:
	var root := Node3D.new()
	add_child(root)
	var pivot := Node3D.new()
	pivot.name = "WeaponPivot"
	pivot.position = Vector3(0.1, 0.2, 0.0)
	root.add_child(pivot)

	var wv := WeaponVisual.new()
	wv._pivot = pivot
	wv._base_pivot_position = pivot.position

	# Bob with speed > 0.5 should move pivot
	wv.update_bob(0.1, 5.0, false)
	var moved := pivot.position.distance_to(Vector3(0.1, 0.2, 0.0)) > 0.0001
	assert_true(moved, "Pivot displaced during bob")

	# Bob with speed 0 + large delta should lerp back to base
	wv.update_bob(10.0, 0.0, false)
	assert_almost_eq(pivot.position.x, 0.1, 0.01, "Pivot returns to base X")
	assert_almost_eq(pivot.position.y, 0.2, 0.01, "Pivot returns to base Y")

	wv._pivot = null
	root.queue_free()


func test_weapon_bob_crouch_reduces_amplitude() -> void:
	var root := Node3D.new()
	add_child(root)
	var pivot := Node3D.new()
	pivot.position = Vector3.ZERO
	root.add_child(pivot)

	var wv := WeaponVisual.new()
	wv._pivot = pivot
	wv._base_pivot_position = Vector3.ZERO

	# Normal bob
	wv._bob_time = 0.0
	wv.update_bob(0.1, 3.0, false)
	var normal_offset := pivot.position.length()

	# Crouch bob (reset)
	pivot.position = Vector3.ZERO
	wv._bob_time = 0.0
	wv.update_bob(0.1, 3.0, true)
	var crouch_offset := pivot.position.length()

	assert_lt(crouch_offset, normal_offset + 0.0001, "Crouch reduces bob amplitude")

	wv._pivot = null
	root.queue_free()
