class_name PlayerCamera
extends Node3D
## TPS over-the-shoulder camera with ADS, shoulder swap, and screen shake.
## Scroll wheel zoom removed — fixed TPS distance with ADS toggle.

const BASE_SENSITIVITY := 0.002
const PITCH_MIN := -89.0
const PITCH_MAX := 89.0
const CLIP_MARGIN := 0.2
const ORBIT_SNAP_SPEED := 8.0

const DEFAULT_CAMERA_DISTANCE := 5.0
const SHOULDER_OFFSET := 0.6
const ADS_SHOULDER_OFFSET := 1.0
const ADS_CAMERA_DISTANCE := 2.5
const ADS_FOV := 60.0
const DEFAULT_NORMAL_FOV := 75.0
const ADS_SENSITIVITY_MULT := 0.6
const ADS_LERP_SPEED := 10.0
const SHOULDER_LERP_SPEED := 8.0
const SHAKE_DECAY := 6.0
const SWAY_AMPLITUDE := 0.15
const SWAY_SPEED := 2.5
const SWAY_CROUCH_MULT := 0.5

var mouse_captured := true
var is_aiming := false
var camera_distance_override := -1.0  ## Set >= 0 to override default distance (used by drop)
var _camera_distance := DEFAULT_CAMERA_DISTANCE
var _target_shoulder_side := 1.0  # 1.0 = right, -1.0 = left
var _current_shoulder_side := 1.0
var _shake_intensity := 0.0
var _orbiting := false
var adjust_mode := false  ## set by WeaponAdjust to prevent orbit snap-back
var _orbit_yaw := 0.0
var _sway_time := 0.0
var _sway_offset := Vector2.ZERO

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if not _is_local_player():
		camera.current = false
		set_process_unhandled_input(false)
		set_process(false)
		return
	if not _is_mobile():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_orbiting = event.pressed and _camera_distance > 0.0

	if event is InputEventMouseMotion and mouse_captured:
		_handle_mouse_motion(event)

	# ADS hold (RMB) — hold to aim, release to stop
	if event.is_action("secondary_action"):
		var placer := get_parent().get_node_or_null("BuildingPlacer") as BuildingPlacer
		if not placer or not placer.is_build_mode:
			is_aiming = event.is_pressed()

	# Shoulder swap (Q)
	if event.is_action_pressed("shoulder_swap"):
		_target_shoulder_side = -_target_shoulder_side


func _process(delta: float) -> void:
	# Consume touch camera delta (mobile)
	_apply_touch_camera_delta()

	# Always show model in TPS
	var model := get_parent().get_node_or_null("PlayerModel")
	if model:
		model.visible = _camera_distance > 0.5

	# Orbit snap back (disabled during weapon adjust mode)
	if not _orbiting and not adjust_mode and absf(_orbit_yaw) > 0.001:
		_orbit_yaw = lerpf(_orbit_yaw, 0.0, ORBIT_SNAP_SPEED * delta)
		if absf(_orbit_yaw) < 0.01:
			_orbit_yaw = 0.0
	rotation.y = _orbit_yaw

	# ADS lerp — camera distance and FOV (override takes priority, e.g. during BR drop)
	var target_distance := ADS_CAMERA_DISTANCE if is_aiming else DEFAULT_CAMERA_DISTANCE
	if camera_distance_override >= 0.0:
		target_distance = camera_distance_override
	_camera_distance = lerpf(_camera_distance, target_distance, ADS_LERP_SPEED * delta)
	var normal_fov := _get_settings_fov()
	var target_fov := ADS_FOV if is_aiming else normal_fov
	camera.fov = lerpf(camera.fov, target_fov, ADS_LERP_SPEED * delta)

	# Shoulder offset lerp (wider when ADS to clear the head)
	_current_shoulder_side = lerpf(_current_shoulder_side, _target_shoulder_side, SHOULDER_LERP_SPEED * delta)
	var offset_amount := ADS_SHOULDER_OFFSET if is_aiming else SHOULDER_OFFSET
	var shoulder_x := offset_amount * _current_shoulder_side

	# Screen shake decay
	if _shake_intensity > 0.0:
		_shake_intensity = maxf(_shake_intensity - SHAKE_DECAY * delta, 0.0)
		camera.h_offset = randf_range(-_shake_intensity, _shake_intensity)
		camera.v_offset = randf_range(-_shake_intensity, _shake_intensity)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	# Weapon sway (breathing) when ADS
	_update_sway(delta)

	# Camera distance + wall clipping (ray from shoulder offset origin)
	# Skip wall clipping when distance override is active (e.g. during BR drop)
	if _camera_distance > 0.0:
		if camera_distance_override >= 0.0:
			# Override mode: direct position, no wall clipping
			camera.position.z = _camera_distance
		else:
			var space := get_world_3d().direct_space_state
			if space:
				var from := global_position + global_transform.basis.x * shoulder_x
				var to := from + global_transform.basis.z * _camera_distance
				var query := PhysicsRayQueryParameters3D.create(from, to)
				query.exclude = [get_parent().get_rid()]
				var result := space.intersect_ray(query)
				if result:
					var safe_dist := from.distance_to(result["position"]) - CLIP_MARGIN
					camera.position.z = maxf(safe_dist, 0.0)
				else:
					camera.position.z = _camera_distance
			else:
				camera.position.z = _camera_distance
		camera.position.x = shoulder_x
	else:
		camera.position = Vector3.ZERO


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var sens := _get_effective_sensitivity()
	var sens_mult := ADS_SENSITIVITY_MULT if is_aiming else 1.0

	if _orbiting:
		_orbit_yaw -= event.relative.x * sens * sens_mult
	else:
		get_parent().rotate_y(-event.relative.x * sens * sens_mult)

	var new_pitch := rotation.x - event.relative.y * sens * sens_mult
	rotation.x = clamp(new_pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _update_sway(delta: float) -> void:
	if not is_aiming:
		if _sway_offset.length() > 0.001:
			# Remove residual sway
			get_parent().rotate_y(deg_to_rad(_sway_offset.x))
			rotation.x += deg_to_rad(_sway_offset.y)
			rotation.x = clamp(rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		_sway_time = 0.0
		_sway_offset = Vector2.ZERO
		return

	_sway_time += delta
	var amplitude := SWAY_AMPLITUDE
	var player := get_parent() as CharacterBody3D
	if player and player is PlayerController and player.is_crouching:
		amplitude *= SWAY_CROUCH_MULT

	var sway_x := sin(_sway_time * SWAY_SPEED * TAU) * amplitude
	var sway_y := sin(_sway_time * SWAY_SPEED * TAU * 0.7 + 0.5) * amplitude * 0.6

	var prev := _sway_offset
	_sway_offset = Vector2(sway_x, sway_y)
	var diff := _sway_offset - prev

	get_parent().rotate_y(deg_to_rad(-diff.x))
	rotation.x += deg_to_rad(-diff.y)
	rotation.x = clamp(rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func apply_shake(intensity: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _toggle_mouse_capture() -> void:
	if mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true


func _is_local_player() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return get_parent().is_multiplayer_authority()


func get_pitch_degrees() -> float:
	return rad_to_deg(rotation.x)


func set_pitch_degrees(degrees: float) -> void:
	rotation.x = deg_to_rad(clamp(degrees, PITCH_MIN, PITCH_MAX))


func _get_effective_sensitivity() -> float:
	## Returns base sensitivity scaled by GameSettings multiplier.
	var gs: Node = get_node_or_null("/root/GameSettings")
	var mult: float = gs.mouse_sensitivity if gs else 1.0
	return BASE_SENSITIVITY * mult


func _get_settings_fov() -> float:
	## Returns FOV from GameSettings, falling back to default.
	var gs: Node = get_node_or_null("/root/GameSettings")
	var result: float = gs.fov if gs else DEFAULT_NORMAL_FOV
	return result


func _is_mobile() -> bool:
	var mi: Node = get_node_or_null("/root/MobileInput")
	return mi != null and mi.is_mobile


func _apply_touch_camera_delta() -> void:
	var mi: Node = get_node_or_null("/root/MobileInput")
	if not mi or not mi.is_mobile:
		return
	var td: Vector2 = mi.consume_camera_delta()
	if td.length_squared() < 0.0001:
		return
	var touch_sens: float = mi.touch_sensitivity
	var sens: float = BASE_SENSITIVITY * touch_sens
	var sens_mult: float = ADS_SENSITIVITY_MULT if is_aiming else 1.0
	get_parent().rotate_y(-td.x * sens * sens_mult)
	var new_pitch: float = rotation.x - td.y * sens * sens_mult
	rotation.x = clamp(new_pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
