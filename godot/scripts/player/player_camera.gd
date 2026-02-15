class_name PlayerCamera
extends Node3D
## Camera with mouse look. Scroll wheel toggles between first and third person.

const SENSITIVITY := 0.002
const PITCH_MIN := -89.0
const PITCH_MAX := 89.0
const ZOOM_STEP := 0.5
const ZOOM_MIN := 0.0  # first person
const ZOOM_MAX := 6.0
const CLIP_MARGIN := 0.2  # offset from wall to avoid clipping

var mouse_captured := true
var _camera_distance := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if not get_parent().is_multiplayer_authority():
		camera.current = false
		set_process_unhandled_input(false)
		set_process(false)
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		_handle_mouse_motion(event)

	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()

	if event is InputEventMouseButton and event.pressed and mouse_captured:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_camera_distance + ZOOM_STEP, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_camera_distance - ZOOM_STEP, ZOOM_MIN)


func _process(_delta: float) -> void:
	# Show/hide player model based on camera distance
	var model := get_parent().get_node_or_null("PlayerModel")
	if model:
		model.visible = _camera_distance > 0.5

	if _camera_distance > 0.0:
		# Third person: cast ray to prevent wall clipping
		var space := get_world_3d().direct_space_state
		if space:
			var from := global_position
			var to := global_position + global_transform.basis.z * _camera_distance
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
	else:
		camera.position.z = 0.0


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Rotate player body horizontally
	get_parent().rotate_y(-event.relative.x * SENSITIVITY)

	# Rotate camera pivot vertically (pitch)
	rotate_x(-event.relative.y * SENSITIVITY)
	rotation.x = clamp(rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _toggle_mouse_capture() -> void:
	if mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true


func get_pitch_degrees() -> float:
	return rad_to_deg(rotation.x)


func set_pitch_degrees(degrees: float) -> void:
	rotation.x = deg_to_rad(clamp(degrees, PITCH_MIN, PITCH_MAX))
