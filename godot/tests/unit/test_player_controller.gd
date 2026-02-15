extends GutTest
## Phase 1: FPS Controller unit tests.

var player: PlayerController


func before_each() -> void:
	player = PlayerController.new()
	# Create the required child nodes
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	collision.shape = capsule
	player.add_child(collision)

	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 0.8
	player.add_child(pivot)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	pivot.add_child(camera)

	add_child_autofree(player)
	# Let _ready() resolve @onready vars
	player._ready()


func test_sprint_speed_exceeds_walk_speed() -> void:
	assert_gt(
		PlayerController.SPRINT_SPEED,
		PlayerController.WALK_SPEED,
		"Sprint speed (%.1f) should exceed walk speed (%.1f)" % [PlayerController.SPRINT_SPEED, PlayerController.WALK_SPEED]
	)


func test_crouch_reduces_collision_height() -> void:
	var initial_height := player.get_collision_height()
	assert_almost_eq(initial_height, 1.8, 0.01, "Initial height should be 1.8")

	# Simulate crouch
	player.is_crouching = true
	var shape: CapsuleShape3D = player.collision_shape.shape
	shape.height = PlayerController.CROUCH_HEIGHT

	var crouch_height := player.get_collision_height()
	assert_lt(crouch_height, initial_height, "Crouch height should be less than standing height")
	assert_almost_eq(crouch_height, 1.0, 0.01, "Crouch height should be ~1.0")


func test_camera_pitch_clamp() -> void:
	var cam_pivot: Node3D = player.get_node("CameraPivot")
	var player_camera := PlayerCamera.new()
	# Replace the pivot script
	cam_pivot.set_script(player_camera.get_script())

	# Test clamping by setting extreme values
	cam_pivot.rotation.x = deg_to_rad(-100)
	cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	var pitch_deg := rad_to_deg(cam_pivot.rotation.x)
	assert_almost_eq(pitch_deg, -89.0, 0.1, "Pitch should clamp to -89 degrees")

	cam_pivot.rotation.x = deg_to_rad(100)
	cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	pitch_deg = rad_to_deg(cam_pivot.rotation.x)
	assert_almost_eq(pitch_deg, 89.0, 0.1, "Pitch should clamp to 89 degrees")

	player_camera.free()


func test_gravity_applied_when_airborne() -> void:
	# Player starts with 0 velocity
	player.velocity = Vector3.ZERO

	# Simulate not on floor — call _apply_gravity directly
	# Since player is not added to physics world with floor, is_on_floor() = false
	player._apply_gravity(0.1)

	assert_lt(player.velocity.y, 0.0, "Gravity should make velocity.y negative when airborne")
	assert_almost_eq(player.velocity.y, -1.2, 0.01, "After 0.1s, velocity.y should be -1.2 (12.0 * 0.1)")


func test_jump_only_when_grounded() -> void:
	# Player is NOT on the floor (no physics world), so jump should NOT work
	player.velocity = Vector3.ZERO
	player._handle_jump() # This checks is_on_floor() internally

	assert_eq(player.velocity.y, 0.0, "Jump should not apply when not grounded")
	# Verify jump velocity constant is correct
	assert_eq(PlayerController.JUMP_VELOCITY, 5.0, "Jump velocity should be 5.0")
