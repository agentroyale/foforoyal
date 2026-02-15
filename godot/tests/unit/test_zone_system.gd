extends GutTest
## Tests for ZoneSystem: inside/outside checks, radius interpolation, damage.


# ─── Test 1: Inside zone returns false ───

func test_inside_zone() -> void:
	var center := Vector3(512, 0, 512)
	var radius := 200.0
	var pos := Vector3(512, 10, 512)
	assert_false(ZoneSystem.is_outside_zone(pos, center, radius))


# ─── Test 2: Outside zone returns true ───

func test_outside_zone() -> void:
	var center := Vector3(512, 0, 512)
	var radius := 100.0
	var pos := Vector3(712, 10, 512)  # 200m away
	assert_true(ZoneSystem.is_outside_zone(pos, center, radius))


# ─── Test 3: Edge of zone ───

func test_edge_of_zone() -> void:
	var center := Vector3(0, 0, 0)
	var radius := 100.0
	# Exactly at radius should be outside (strict >)
	var pos_at := Vector3(100, 0, 0)
	# Just inside
	var pos_inside := Vector3(99.9, 0, 0)
	assert_false(ZoneSystem.is_outside_zone(pos_inside, center, radius))


# ─── Test 4: Y coordinate ignored (2D check) ───

func test_zone_check_ignores_y() -> void:
	var center := Vector3(0, 0, 0)
	var radius := 100.0
	var pos_high := Vector3(50, 999, 50)
	assert_false(ZoneSystem.is_outside_zone(pos_high, center, radius))


# ─── Test 5: Radius interpolation start ───

func test_radius_at_start() -> void:
	var radius := ZoneSystem.get_current_radius(0, 0.0, true)
	assert_almost_eq(radius, 480.0, 0.1, "Phase 0 start = 480")


# ─── Test 6: Radius interpolation midpoint ───

func test_radius_at_midpoint() -> void:
	# Phase 0: 480 -> 300, shrink 60s. At 30s = midpoint
	var radius := ZoneSystem.get_current_radius(0, 30.0, true)
	var expected := lerpf(480.0, 300.0, 0.5)
	assert_almost_eq(radius, expected, 1.0, "Midpoint radius")


# ─── Test 7: Radius interpolation end ───

func test_radius_at_end() -> void:
	var radius := ZoneSystem.get_current_radius(0, 60.0, true)
	assert_almost_eq(radius, 300.0, 0.1, "Phase 0 end = 300")


# ─── Test 8: Damage per phase ───

func test_damage_per_phase() -> void:
	assert_almost_eq(ZoneSystem.get_damage_per_second(0), 1.0, 0.01)
	assert_almost_eq(ZoneSystem.get_damage_per_second(1), 2.0, 0.01)
	assert_almost_eq(ZoneSystem.get_damage_per_second(2), 5.0, 0.01)
	assert_almost_eq(ZoneSystem.get_damage_per_second(3), 10.0, 0.01)
	assert_almost_eq(ZoneSystem.get_damage_per_second(4), 20.0, 0.01)


# ─── Test 9: 5 phases defined ───

func test_five_phases() -> void:
	assert_eq(ZoneSystem.PHASE_COUNT, 5)
	for i in range(5):
		var data := ZoneSystem.get_phase_data(i)
		assert_false(data.is_empty(), "Phase %d should have data" % i)


# ─── Test 10: Final phase ends at zero ───

func test_final_phase_zero() -> void:
	var data := ZoneSystem.get_phase_data(4)
	assert_almost_eq(data["end_radius"], 0.0, 0.01, "Phase 4 end = 0")


# ─── Test 11: Zone center deterministic ───

func test_zone_center_deterministic() -> void:
	var c1 := ZoneSystem.get_zone_center(1, 1024.0, 42)
	var c2 := ZoneSystem.get_zone_center(1, 1024.0, 42)
	assert_eq(c1, c2, "Same seed = same center")


# ─── Test 12: Zone center inside map ───

func test_zone_center_inside_map() -> void:
	for phase in range(5):
		for seed_val in [1, 42, 999, 12345]:
			var center := ZoneSystem.get_zone_center(phase, 1024.0, seed_val)
			var data := ZoneSystem.get_phase_data(phase)
			var radius: float = data.get("start_radius", 0.0)
			assert_true(center.x >= radius, "Center.x >= radius (phase %d)" % phase)
			assert_true(center.z >= radius, "Center.z >= radius (phase %d)" % phase)
			assert_true(center.x <= 1024.0 - radius, "Center.x <= map-radius (phase %d)" % phase)
			assert_true(center.z <= 1024.0 - radius, "Center.z <= map-radius (phase %d)" % phase)


# ─── Test 13: distance_to_zone_edge ───

func test_distance_to_zone_edge() -> void:
	var center := Vector3(0, 0, 0)
	var radius := 100.0
	# Inside: negative
	var inside := ZoneSystem.distance_to_zone_edge(Vector3(50, 0, 0), center, radius)
	assert_true(inside < 0.0, "Inside = negative distance")
	# Outside: positive
	var outside := ZoneSystem.distance_to_zone_edge(Vector3(150, 0, 0), center, radius)
	assert_almost_eq(outside, 50.0, 0.1, "50m outside")
