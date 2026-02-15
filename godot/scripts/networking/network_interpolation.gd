class_name NetworkInterpolation
extends Node
## Smoothly interpolates remote player positions between sync updates.
## Attach to player node; only active for non-authority (remote) players.

const INTERPOLATION_SPEED := 15.0

var _target_position := Vector3.ZERO
var _target_rotation_y := 0.0
var _target_pitch := 0.0
var _initialized := false


func set_target(pos: Vector3, rot_y: float, pitch: float) -> void:
	_target_position = pos
	_target_rotation_y = rot_y
	_target_pitch = pitch
	_initialized = true


func _physics_process(delta: float) -> void:
	var player := get_parent() as Node3D
	if not player or player.is_multiplayer_authority():
		return
	if not _initialized:
		return

	player.global_position = player.global_position.lerp(
		_target_position, INTERPOLATION_SPEED * delta
	)
	player.rotation.y = lerp_angle(
		player.rotation.y, _target_rotation_y, INTERPOLATION_SPEED * delta
	)

	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot:
		pivot.rotation.x = lerp_angle(
			pivot.rotation.x, _target_pitch, INTERPOLATION_SPEED * delta
		)
