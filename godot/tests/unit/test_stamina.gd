extends GutTest
## Tests for StaminaSystem and StaminaBarUI.


# ─── StaminaSystem Tests ───

func _make_stamina() -> StaminaSystem:
	var ss := StaminaSystem.new()
	add_child_autofree(ss)
	return ss


func test_stamina_starts_full() -> void:
	var ss := _make_stamina()
	assert_almost_eq(ss.current_stamina, 100.0, 0.01, "Starts at max")
	assert_almost_eq(ss.max_stamina, 100.0, 0.01, "Max is 100")


func test_stamina_drains_when_sprinting() -> void:
	var ss := _make_stamina()
	ss.set_draining(true)
	ss._process(1.0)
	assert_lt(ss.current_stamina, 100.0, "Stamina decreased after draining")
	assert_almost_eq(ss.current_stamina, 100.0 - StaminaSystem.DRAIN_RATE, 0.5, "Drained correct amount")


func test_stamina_regens_after_delay() -> void:
	var ss := _make_stamina()
	# Drain some
	ss.set_draining(true)
	ss._process(2.0)
	ss.set_draining(false)
	var after_drain := ss.current_stamina

	# Regen delay - should NOT regen yet
	ss._process(0.5)
	assert_almost_eq(ss.current_stamina, after_drain, 0.5, "No regen during cooldown")

	# Wait for cooldown to expire
	ss._process(0.6)
	assert_almost_eq(ss.current_stamina, after_drain, 0.5, "Still no regen right at cooldown edge")

	# Now regen should kick in
	ss._process(0.5)
	assert_gt(ss.current_stamina, after_drain, "Regens after delay")


func test_stamina_depleted_signal() -> void:
	var ss := _make_stamina()
	var counter := [0]
	ss.stamina_depleted.connect(func(): counter[0] += 1)

	ss.set_draining(true)
	# Drain to zero (100 / 15 per sec ≈ 6.67 sec)
	ss._process(7.0)
	assert_almost_eq(ss.current_stamina, 0.0, 0.01, "Stamina at zero")
	assert_eq(counter[0], 1, "Depleted signal emitted")


func test_stamina_cant_sprint_when_depleted() -> void:
	var ss := _make_stamina()
	ss.set_draining(true)
	ss._process(7.0)  # Deplete
	ss.set_draining(false)
	assert_false(ss.can_sprint(), "Cannot sprint at 0 stamina")

	# Regen a little but not enough
	ss._process(1.5)  # past regen delay
	ss._process(0.3)  # small regen
	assert_false(ss.can_sprint(), "Cannot sprint below MIN_TO_SPRINT")


func test_stamina_can_sprint_after_recovery() -> void:
	var ss := _make_stamina()
	ss.set_draining(true)
	ss._process(7.0)  # Deplete
	ss.set_draining(false)

	# Regen past threshold (need MIN_TO_SPRINT=10, regen at 20/s, delay 1s)
	ss._process(1.0)  # cooldown
	ss._process(0.6)  # 12 stamina regened
	assert_true(ss.can_sprint(), "Can sprint after recovering above threshold")


func test_stamina_floors_at_zero() -> void:
	var ss := _make_stamina()
	ss.set_draining(true)
	ss._process(100.0)  # Way past zero
	assert_almost_eq(ss.current_stamina, 0.0, 0.01, "Stamina floors at 0")


func test_stamina_caps_at_max() -> void:
	var ss := _make_stamina()
	ss.current_stamina = 50.0
	ss._regen_cooldown = 0.0
	ss._process(100.0)  # Way past max
	assert_almost_eq(ss.current_stamina, 100.0, 0.01, "Stamina caps at max")


func test_stamina_percent() -> void:
	var ss := _make_stamina()
	ss.current_stamina = 75.0
	assert_almost_eq(ss.get_stamina_percent(), 0.75, 0.01, "75% correct")


# ─── StaminaBarUI Tests ───

func _make_stamina_bar() -> StaminaBarUI:
	var sb := StaminaBarUI.new()
	add_child_autofree(sb)
	return sb


func test_stamina_bar_initial_state() -> void:
	var sb := _make_stamina_bar()
	assert_almost_eq(sb._display_val, 1.0, 0.01, "Display starts full")
	assert_almost_eq(sb._target_val, 1.0, 0.01, "Target starts full")


func test_stamina_bar_set_stamina() -> void:
	var sb := _make_stamina_bar()
	sb.set_stamina(60.0, 100.0)
	assert_almost_eq(sb._target_val, 0.6, 0.01, "Target = 0.6 at 60/100")
	assert_almost_eq(sb._current_stamina, 60.0, 0.01, "Current stored")


func test_stamina_bar_draining_flag() -> void:
	var sb := _make_stamina_bar()
	sb.set_draining(true)
	assert_true(sb._is_draining, "Draining flag set")
	sb.set_draining(false)
	assert_false(sb._is_draining, "Draining flag cleared")


func test_stamina_bar_pulse_when_depleted() -> void:
	var sb := _make_stamina_bar()
	sb.set_stamina(5.0, 100.0)
	sb._process(0.1)
	assert_gt(sb._pulse_time, 0.0, "Pulse active at 5%")


func test_stamina_bar_no_pulse_when_healthy() -> void:
	var sb := _make_stamina_bar()
	sb.set_stamina(80.0, 100.0)
	sb._process(0.1)
	assert_almost_eq(sb._pulse_time, 0.0, 0.01, "No pulse at 80%")


func test_stamina_bar_clamps() -> void:
	var sb := _make_stamina_bar()
	sb.set_stamina(150.0, 100.0)
	assert_almost_eq(sb._target_val, 1.0, 0.01, "Clamped to 1.0")
	sb.set_stamina(-10.0, 100.0)
	assert_almost_eq(sb._target_val, 0.0, 0.01, "Clamped to 0.0")
