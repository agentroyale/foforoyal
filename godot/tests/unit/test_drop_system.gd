extends GutTest
## Tests for FlightPath, ParachuteController, and movement_disabled.


# ─── Test 1: Flight path crosses map ───

func test_flight_path_crosses_map() -> void:
	var path := FlightPath.generate_path(1024.0, 42)
	assert_true(path.has("start"))
	assert_true(path.has("end"))
	assert_true(path.has("direction"))
	assert_true(path.has("length"))
	assert_gt(path["length"], 800.0, "Path should cross most of the map")


# ─── Test 2: Flight path deterministic ───

func test_flight_path_deterministic() -> void:
	var p1 := FlightPath.generate_path(1024.0, 123)
	var p2 := FlightPath.generate_path(1024.0, 123)
	assert_eq(p1["start"], p2["start"])
	assert_eq(p1["end"], p2["end"])
	assert_eq(p1["direction"], p2["direction"])


# ─── Test 3: Different seeds give different paths ───

func test_flight_path_different_seeds() -> void:
	var p1 := FlightPath.generate_path(1024.0, 1)
	var p2 := FlightPath.generate_path(1024.0, 2)
	assert_ne(p1["start"], p2["start"], "Different seeds = different paths")


# ─── Test 4: Position at progress 0 = start ───

func test_position_at_start() -> void:
	var path := FlightPath.generate_path(1024.0, 42)
	var pos := FlightPath.get_position_at_progress(path["start"], path["end"], 0.0)
	assert_eq(pos, path["start"])


# ─── Test 5: Position at progress 0.5 = midpoint ───

func test_position_at_midpoint() -> void:
	var path := FlightPath.generate_path(1024.0, 42)
	var pos := FlightPath.get_position_at_progress(path["start"], path["end"], 0.5)
	var expected := path["start"].lerp(path["end"], 0.5)
	assert_almost_eq(pos.x, expected.x, 0.1)
	assert_almost_eq(pos.z, expected.z, 0.1)


# ─── Test 6: Position at progress 1 = end ───

func test_position_at_end() -> void:
	var path := FlightPath.generate_path(1024.0, 42)
	var pos := FlightPath.get_position_at_progress(path["start"], path["end"], 1.0)
	assert_eq(pos, path["end"])


# ─── Test 7: Flight altitude ───

func test_flight_altitude() -> void:
	var path := FlightPath.generate_path(1024.0, 42)
	assert_almost_eq(path["start"].y, FlightPath.FLIGHT_ALTITUDE, 0.1)
	assert_almost_eq(path["end"].y, FlightPath.FLIGHT_ALTITUDE, 0.1)


# ─── Test 8: Parachute deploy altitude constant ───

func test_parachute_deploy_altitude() -> void:
	var pc_script := load("res://scripts/player/parachute_controller.gd") as GDScript
	var pc := Node.new()
	pc.set_script(pc_script)
	add_child_autofree(pc)
	assert_eq(pc.DEPLOY_ALTITUDE, 50.0)
	assert_eq(pc.FREEFALL_SPEED, 20.0)
	assert_eq(pc.PARACHUTE_DESCENT_SPEED, 5.0)


# ─── Test 9: Movement disabled flag ───

func test_movement_disabled() -> void:
	var player := PlayerController.new()
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	col.shape = capsule
	player.add_child(col)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	player.add_child(pivot)
	add_child_autofree(player)

	assert_false(player.movement_disabled, "Default: enabled")
	player.disable_movement()
	assert_true(player.movement_disabled, "Disabled after call")
	player.enable_movement()
	assert_false(player.movement_disabled, "Re-enabled")


# ─── Test 10: Parachute start_drop sets state ───

func test_parachute_start_drop() -> void:
	var pc_script := load("res://scripts/player/parachute_controller.gd") as GDScript
	var pc := Node.new()
	pc.set_script(pc_script)
	# Need a parent with disable_movement
	var parent := CharacterBody3D.new()
	parent.name = "Player"
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	col.shape = capsule
	parent.add_child(col)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	parent.add_child(pivot)
	# Add script manually for disable_movement
	parent.set_script(load("res://scripts/player/player_controller.gd"))
	pc.name = "ParachuteController"
	parent.add_child(pc)
	add_child_autofree(parent)

	assert_false(pc.is_dropping, "Not dropping initially")
	pc.start_drop()
	assert_true(pc.is_dropping, "Dropping after start_drop")
	assert_true(parent.movement_disabled, "Movement disabled during drop")
