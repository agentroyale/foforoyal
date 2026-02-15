extends GutTest
## Phase 11: UI Visual Upgrades unit tests — HealthBar, DeathScreen, Minimap.


# ─── Health Bar Tests ───

func _make_health_bar() -> HealthBarUI:
	var hb := HealthBarUI.new()
	add_child_autofree(hb)
	return hb


func test_health_bar_initial_state() -> void:
	var hb := _make_health_bar()
	# Default values: full health
	assert_almost_eq(hb._display_hp, 1.0, 0.01, "Display HP starts at 1.0")
	assert_almost_eq(hb._trail_hp, 1.0, 0.01, "Trail HP starts at 1.0")
	assert_almost_eq(hb._target_hp, 1.0, 0.01, "Target HP starts at 1.0")


func test_health_bar_set_health() -> void:
	var hb := _make_health_bar()
	hb.set_health(75.0, 100.0)
	assert_almost_eq(hb._target_hp, 0.75, 0.01, "Target = 0.75 at 75/100")
	assert_almost_eq(hb._current_hp, 75.0, 0.01, "Current HP stored")
	assert_almost_eq(hb._max_hp, 100.0, 0.01, "Max HP stored")


func test_health_bar_damage_starts_trail_delay() -> void:
	var hb := _make_health_bar()
	hb.set_health(100.0, 100.0)  # Full
	hb.set_health(50.0, 100.0)   # Damage!
	assert_gt(hb._trail_timer, 0.0, "Trail timer set on damage")
	assert_almost_eq(hb._trail_hp, 1.0, 0.01, "Trail HP hasn't moved yet")


func test_health_bar_healing_no_trail_delay() -> void:
	var hb := _make_health_bar()
	hb.set_health(50.0, 100.0)
	hb._trail_timer = 0.0  # Reset any existing timer
	hb.set_health(80.0, 100.0)  # Heal
	assert_almost_eq(hb._trail_timer, 0.0, 0.01, "No trail delay on heal")


func test_health_bar_clamps_hp() -> void:
	var hb := _make_health_bar()
	hb.set_health(150.0, 100.0)
	assert_almost_eq(hb._target_hp, 1.0, 0.01, "Target clamped to 1.0 (overheal)")
	hb.set_health(-10.0, 100.0)
	assert_almost_eq(hb._target_hp, 0.0, 0.01, "Target clamped to 0.0 (negative)")


func test_health_bar_zero_max_hp() -> void:
	var hb := _make_health_bar()
	hb.set_health(50.0, 0.0)
	# Should not crash — max_hp gets clamped to 1.0 internally
	assert_almost_eq(hb._max_hp, 1.0, 0.01, "Max HP floor is 1.0")


func test_health_bar_pulse_active_when_low() -> void:
	var hb := _make_health_bar()
	hb.set_health(20.0, 100.0)
	# Simulate a frame
	hb._process(0.1)
	assert_gt(hb._pulse_time, 0.0, "Pulse active at 20% HP")


func test_health_bar_pulse_inactive_when_healthy() -> void:
	var hb := _make_health_bar()
	hb.set_health(80.0, 100.0)
	hb._process(0.1)
	assert_almost_eq(hb._pulse_time, 0.0, 0.01, "No pulse at 80% HP")


# ─── Death Screen Tests ───

func _make_death_screen() -> DeathScreenUI:
	var ds := DeathScreenUI.new()
	add_child_autofree(ds)
	return ds


func test_death_screen_starts_hidden() -> void:
	var ds := _make_death_screen()
	assert_false(ds.visible, "Death screen hidden at start")
	assert_false(ds._active, "Death screen not active at start")


func test_death_screen_show_makes_visible() -> void:
	var ds := _make_death_screen()
	ds.show_death(1)  # Bullet
	assert_true(ds.visible, "Death screen visible after show_death")
	assert_true(ds._active, "Death screen active")


func test_death_screen_damage_type_text() -> void:
	var ds := _make_death_screen()
	ds.show_death(0)  # Melee
	assert_eq(ds._cause_label.text, "Killed by melee attack", "Melee cause text")

	# Reset for next test
	ds._active = false
	ds.show_death(3)  # Fall
	assert_eq(ds._cause_label.text, "Killed by falling", "Fall cause text")


func test_death_screen_unknown_damage_type() -> void:
	var ds := _make_death_screen()
	ds.show_death(-1)
	assert_eq(ds._cause_label.text, "", "No cause text for unknown type")


func test_death_screen_hide() -> void:
	var ds := _make_death_screen()
	ds.show_death(0)
	ds.hide_death()
	assert_false(ds._active, "Not active after hide")


func test_death_screen_respawn_signal() -> void:
	var ds := _make_death_screen()
	var counter := [0]
	ds.respawn_requested.connect(func(): counter[0] += 1)
	ds.show_death(0)
	ds._on_respawn_pressed()
	assert_eq(counter[0], 1, "Respawn signal emitted once")
	assert_false(ds._active, "Not active after respawn")


func test_death_screen_no_double_show() -> void:
	var ds := _make_death_screen()
	ds.show_death(0)
	ds.show_death(1)  # Should be ignored (already active)
	# Cause text should still be from first call
	assert_eq(ds._cause_label.text, "Killed by melee attack", "Second show ignored")


# ─── Minimap Tests ───

func _make_minimap() -> MinimapUI:
	var mm := MinimapUI.new()
	add_child_autofree(mm)
	return mm


func test_minimap_initial_size() -> void:
	var mm := _make_minimap()
	assert_eq(mm.custom_minimum_size, Vector2(MinimapUI.MAP_SIZE, MinimapUI.MAP_SIZE), "Minimap size set")


func test_minimap_world_to_screen_center() -> void:
	var mm := _make_minimap()
	mm.size = Vector2(MinimapUI.MAP_SIZE, MinimapUI.MAP_SIZE)
	var center := mm.size * 0.5
	# Player at origin, target at origin, no rotation -> should be center
	var result := mm._world_to_minimap(Vector3.ZERO, Vector3.ZERO, 0.0, center)
	assert_almost_eq(result.x, center.x, 0.1, "Same position = center X")
	assert_almost_eq(result.y, center.y, 0.1, "Same position = center Y")


func test_minimap_world_to_screen_north() -> void:
	var mm := _make_minimap()
	mm.size = Vector2(MinimapUI.MAP_SIZE, MinimapUI.MAP_SIZE)
	var center := mm.size * 0.5
	# Object north of player (negative Z in Godot) with no rotation
	# Should appear above center on minimap (negative Y on screen)
	var result := mm._world_to_minimap(
		Vector3(0, 0, -40), Vector3.ZERO, 0.0, center
	)
	assert_lt(result.y, center.y, "North object appears above center")
	assert_almost_eq(result.x, center.x, 0.1, "North object centered horizontally")


func test_minimap_world_to_screen_east() -> void:
	var mm := _make_minimap()
	mm.size = Vector2(MinimapUI.MAP_SIZE, MinimapUI.MAP_SIZE)
	var center := mm.size * 0.5
	# Object east (+X) of player
	var result := mm._world_to_minimap(
		Vector3(40, 0, 0), Vector3.ZERO, 0.0, center
	)
	assert_gt(result.x, center.x, "East object appears right of center")
	assert_almost_eq(result.y, center.y, 0.1, "East object centered vertically")


func test_minimap_rotation_rotates_world() -> void:
	var mm := _make_minimap()
	mm.size = Vector2(MinimapUI.MAP_SIZE, MinimapUI.MAP_SIZE)
	var center := mm.size * 0.5
	# Player rotated 90 degrees (PI/2) — facing east
	# Object at north (0,0,-40) should now appear to the LEFT on minimap
	var result := mm._world_to_minimap(
		Vector3(0, 0, -40), Vector3.ZERO, PI * 0.5, center
	)
	assert_lt(result.x, center.x, "North object moves left when player faces east")


func test_minimap_toggle_visibility() -> void:
	var mm := _make_minimap()
	assert_true(mm._visible, "Minimap visible by default")
	# Simulate M key press
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	mm._unhandled_input(event)
	assert_false(mm._visible, "Minimap hidden after M press")
	mm._unhandled_input(event)
	assert_true(mm._visible, "Minimap visible again after second M press")


func test_minimap_constants_reasonable() -> void:
	var mm := _make_minimap()
	assert_gt(MinimapUI.MAP_RADIUS, 0.0, "MAP_RADIUS positive")
	assert_gt(MinimapUI.WORLD_RANGE, 0.0, "WORLD_RANGE positive")
	assert_gt(MinimapUI.MAP_SIZE, MinimapUI.MAP_RADIUS * 2.0 - 20, "MAP_SIZE fits the radius")
